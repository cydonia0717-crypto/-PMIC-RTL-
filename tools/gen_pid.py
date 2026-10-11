#!/usr/bin/env python3
import random,sys
from pathlib import Path
from pid_reference import PID
r=random.Random(20261011);p=PID();lines=[]
# Persistent histories exercise saturation, unwind, derivative and reset.
for i in range(4096):
 reset=i%128==0
 if reset:p=PID()
 if i%128<20:
  target,measured,kp,ki,kd,deriv,mn,mx=4095,0,256,256,64,1,0,1024
 elif i%128<40:
  target,measured,kp,ki,kd,deriv,mn,mx=0,4095,256,256,64,1,0,1024
 elif i%128<45:
  target,measured,kp,ki,kd,deriv,mn,mx=4095,0,0,32767,0,0,0,65535
 else:
  target,measured=r.randrange(4096),r.randrange(4096)
  kp,ki,kd=r.randrange(32768),r.randrange(32768),r.randrange(32768)
  deriv=r.randrange(2);mn=r.randrange(128);mx=r.randrange(max(mn+1,128),65536)
 duty,integral,error=p.step(target,measured,kp,ki,kd,deriv,mn,mx)
 lines.append(' '.join(map(str,[int(reset),target,measured,kp,ki,kd,deriv,mn,mx,duty,integral,error])))
Path(sys.argv[1]).write_text('\n'.join(lines)+'\n')
