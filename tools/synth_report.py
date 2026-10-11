import json
from pathlib import Path
net=json.loads(Path('build/system-netlist.json').read_text())
for module in net['modules'].values():
 for cell in module['cells'].values():
  assert cell['type'] not in ('$dlatch','$adlatch'),f"latch {cell['type']}"
report={'status':'PASS','whole_system':'proc/opt/memory/check; memories mapped to generic register logic','technology':'generic; no process/Liberty/STA','no_latches':True,'system':json.loads(Path('build/system-stat.json').read_text()),'mapped_pid':json.loads(Path('build/pid-stat.json').read_text())}
Path('reports/synthesis.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS synthesis structural check, no latches, PID generic mapping')
