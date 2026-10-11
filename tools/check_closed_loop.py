#!/usr/bin/env python3
import json
from pathlib import Path
from pid_reference import PID
p=PID();prev_v=0;rows=[]
for line in Path('build/closed_loop.csv').read_text().splitlines():
 k,target,v,duty,integ,hi,load=map(int,line.split())
 drive=hi*4095//64-load;delta=drive-prev_v
 expected_v=max(0,min(4095,prev_v+(abs(delta)//8 if delta>=0 else -(abs(delta)//8))))
 assert v==expected_v,(k,'plant',v,expected_v)
 expected_d,expected_i,_=p.step(target,v,2,1,0,0,0,60)
 assert (duty,integ)==(expected_d,expected_i),(k,'PID',duty,integ,expected_d,expected_i)
 rows.append((k,target,v,duty));prev_v=v
assert len(rows)==1200
windows=[(350,399),(750,799),(1150,1199)]
settling=[]
for start,end in windows:
 segment=rows[start:end+1];err=max(abs(t-v) for _,t,v,_ in segment)
 assert err<=50,('settling window',start,err)
 settling.append({'window':[start,end],'max_error_adc_counts':err})
result={'status':'PASS','samples':1200,'plant':'first-order integer behavioral model; not analog signoff','setpoint_step':{'sample':400,'from':2048,'to':2600},'load_step':{'sample':800,'offset':400},'settling':settling,'final_voltage':prev_v}
Path('reports/closed-loop.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'PASS closed-loop oracle: 1200 PID + plant samples, settling={settling}')
