#!/usr/bin/env python3
"""Render measured RTL behavior; data comes from the closed-loop trace."""
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
rows=[list(map(int,x.split())) for x in Path('build/closed_loop.csv').read_text().splitlines()]
x=[r[0] for r in rows];target=[r[1] for r in rows];voltage=[r[2] for r in rows];duty=[r[3] for r in rows]
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'svg.fonttype':'none'})
fig,axes=plt.subplots(2,1,figsize=(9,4.8),sharex=True,gridspec_kw={'height_ratios':[2,1]},layout='constrained')
axes[0].plot(x,target,color='#334155',linestyle='--',label='Setpoint')
axes[0].plot(x,voltage,color='#0284c7',label='ADC voltage (behavioral plant)')
axes[0].set_ylabel('ADC counts');axes[0].legend(loc='lower right');axes[0].set_ylim(0,3000)
axes[1].plot(x,duty,color='#7c3aed',label='RTL duty command');axes[1].set_ylabel('Duty counts / 64');axes[1].set_xlabel('Control sample')
for ax in axes:
 ax.axvline(400,color='#64748b',alpha=.6,linewidth=1);ax.axvline(800,color='#64748b',alpha=.6,linewidth=1);ax.grid(alpha=.2)
axes[0].annotate('Setpoint step',xy=(400,2600),xytext=(445,2820),fontsize=9)
axes[0].annotate('Load disturbance',xy=(800,2400),xytext=(825,2100),fontsize=9)
fig.suptitle('Digital PI + PWM: RTL closed-loop response',fontweight='bold')
fig.savefig('docs/closed-loop.svg');fig.savefig('build/closed-loop.png',dpi=160)
svg=Path('docs/closed-loop.svg')
svg.write_text('\n'.join(line.rstrip() for line in svg.read_text().splitlines())+'\n')
