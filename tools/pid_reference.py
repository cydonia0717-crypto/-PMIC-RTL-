#!/usr/bin/env python3
"""Bit-exact mathematical PID oracle, independent of RTL state sequencing."""
from dataclasses import dataclass
@dataclass
class PID:
 integral:int=0
 previous:int=0
 def step(self,target,measured,kp,ki,kd,derivative,dmin,dmax):
  e=target-measured
  ci=max(-8388352,min(8388352,self.integral+ki*e))
  total=kp*e+ci+(kd*(e-self.previous) if derivative else 0)
  raw=total//256  # Arithmetic right shift rounds negative values toward -infinity.
  duty=max(dmin,min(dmax,raw))
  if not ((raw>dmax and e>0) or (raw<dmin and e<0)):self.integral=ci
  self.previous=e
  return duty,self.integral,e
