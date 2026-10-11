#!/usr/bin/env python3
import subprocess,json
from pathlib import Path
runs=[]
for scenario in range(7):
 p=subprocess.run(['build/obj_verilator/pmic_verilator',f'+scenario={scenario}','+seed=17',f'+trace=build/verilator_{scenario}.trace'],capture_output=True,text=True,timeout=180,check=True)
 assert 'PASS pmic' in p.stdout,p.stdout
 print(p.stdout.splitlines()[0],flush=True)
 runs.append({'scenario':scenario,'status':'PASS','output':p.stdout.strip()})
Path('reports/cross-simulator.json').write_text(json.dumps({'status':'PASS','runs':runs},indent=2)+'\n')
