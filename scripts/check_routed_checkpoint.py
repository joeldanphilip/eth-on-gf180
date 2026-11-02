"""Reject incomplete/stale detailed routes and nonzero final route/antenna DRC."""
import argparse
import json
from pathlib import Path
import re

p = argparse.ArgumentParser()
p.add_argument('--work-home', type=Path, required=True)
args = p.parse_args()
base = Path('gf180/ethernet_pipeline_4096/base')
results = args.work_home/'results'/base
reports = args.work_home/'reports'/base
log = args.work_home/'logs'/base/'5_2_route.log'
text = log.read_text(errors='replace') if log.is_file() else ''
counts = re.findall(r'Number of violations\s*=\s*(\d+)', text)
antenna_nets = re.findall(r'Found (\d+) net violations', text)
antenna_pins = re.findall(r'Found (\d+) pin violations', text)
errors = []
for name in ('5_1_grt.odb', '5_2_route.odb', '5_route.odb', '5_route.sdc'):
    if not (results/name).is_file(): errors.append(f'Missing {name}')
if 'Complete detail routing.' not in text: errors.append('Router completion marker missing')
if re.search(r'^\[ERROR\]|^Error:', text, re.M): errors.append('Tool error in route log')
if not counts or int(counts[-1]) != 0: errors.append('Final router DRC count is missing or nonzero')
if not antenna_nets or int(antenna_nets[-1]) != 0: errors.append('Final antenna net count is missing or nonzero')
if not antenna_pins or int(antenna_pins[-1]) != 0: errors.append('Final antenna pin count is missing or nonzero')
if log.is_file() and (results/'5_1_grt.odb').is_file():
    if log.stat().st_mtime < (results/'5_1_grt.odb').stat().st_mtime:
        errors.append('Route log predates the global-route checkpoint')
result = {'check': 'Detailed-route checkpoint', 'pass': not errors,
          'final_route_violations': int(counts[-1]) if counts else None,
          'final_antenna_nets': int(antenna_nets[-1]) if antenna_nets else None,
          'final_antenna_pins': int(antenna_pins[-1]) if antenna_pins else None,
          'log': str(log), 'errors': errors}
reports.mkdir(parents=True, exist_ok=True)
(reports/'route_acceptance.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
raise SystemExit(0 if result['pass'] else 1)
