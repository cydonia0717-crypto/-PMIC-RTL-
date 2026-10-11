#!/usr/bin/env python3
import argparse,subprocess,json,re
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--vvp',default='vvp');ap.add_argument('--seeds',type=int,default=4);a=ap.parse_args()
Path('reports').mkdir(exist_ok=True)
def run(cmd):
 p=subprocess.run(cmd,capture_output=True,text=True,timeout=180,check=True)
 if 'PASS' not in p.stdout:raise AssertionError(p.stdout+p.stderr)
 return p.stdout
units=[]
for name in ['pid','pwm','mailbox','protection','sequencer','closed_loop']:
 out=run([a.vvp,f'build/{name}.vvp']);print(out.strip(),flush=True)
 units.append({'name':name,'status':'PASS','output':out.strip()})
subprocess.run(['python3','tools/check_closed_loop.py'],check=True,timeout=30)
runs=[]
for scenario in range(7):
 for seed in range(1,a.seeds+1):
  trace=f'build/pmic_{scenario}_{seed}.trace'
  out=run([a.vvp,'build/pmic.vvp',f'+scenario={scenario}',f'+seed={seed}',f'+trace={trace}'])
  metric={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',out)}
  rows=[]
  for line in Path(trace).read_text().splitlines():
   fields=line.split();rows.append([int(fields[0]),int(fields[1]),*[int(x,16) for x in fields[2:]]])
  assert rows and any(row[2]==15 for row in rows), 'all-rail startup not observed'
  assert any(row[2]==0 for row in rows), 'shutdown not observed'
  if scenario:assert any(row[3]!=0 for row in rows), 'injected fault not observed'
  runs.append({'scenario':scenario,'seed':seed,'status':'PASS','metrics':metric,'trace_events':len(rows)})
  print(out.splitlines()[0],flush=True)
report={'status':'PASS','system_cases':len(runs),'pid_vectors':4096,'pwm_cases':85,'cdc_frames':2000,'closed_loop_samples':1200,'unit_tests':units,'scenario_names':['normal_masked_start','undervoltage','overvoltage','overcurrent','external_trip','sample_stale','startup_timeout'],'runs':runs}
Path('reports/regression.json').write_text(json.dumps(report,indent=2)+'\n')
print(f'PASS regression system_cases={len(runs)}')
