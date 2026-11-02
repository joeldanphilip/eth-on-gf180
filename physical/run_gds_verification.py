"""Run the real GF180 variant-C decks and require their actual pass result."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('kind', choices=['drc', 'lvs'])
p.add_argument('--work-home', type=Path, required=True)
args = p.parse_args()
results = args.work_home.resolve() / 'results/gf180/ethernet_pipeline_4096/base'
reports = args.work_home.resolve() / 'reports/gf180/ethernet_pipeline_4096/base'
logs = args.work_home.resolve() / 'logs/gf180/ethernet_pipeline_4096/base'
gds = results / '6_final.gds'
if not gds.is_file():
    raise SystemExit(f'Missing final GDS: {gds}')
native = ROOT / 'physical/bin/klayout-native'
pv = ROOT / 'tools/gf180_pv/klayout'
log = logs / f'gf180_full_{args.kind}.log'
if args.kind == 'drc':
    report = reports / 'gf180_full_drc.lyrdb'
    command = [str(native), '-b', '-r', str(pv/'drc/gf180mcu.drc')]
    settings = {'input': gds, 'topcell': 'eth_mac_1g_fifo', 'report': report,
                'variant': 'gf180mcuC', 'workers': '1', 'threads': '8',
                'run_mode': 'deep', 'decks': 'all'}
    check_input = report
else:
    cdl = results / '6_final_lvs.cdl'
    if not cdl.is_file():
        raise SystemExit(f'Generate the explicit-body CDL first: {cdl}')
    report = reports / 'gf180_full_lvs.lvsdb'
    command = [str(native), '-b', '-r', str(pv/'lvs/gf180mcu.lvs')]
    settings = {'input': gds, 'topcell': 'eth_mac_1g_fifo', 'report': report,
                'schematic': cdl, 'target_netlist': results/'6_gds_extracted.cir',
                'metal_level': '5LM', 'metal_top': '9K', 'mim_option': 'B',
                'run_mode': 'deep', 'check_ports': 'true', 'combine': 'true',
                'purge': 'true', 'purge_nets': 'true', 'simplify': 'true',
                'spice_comments': 'false'}
    check_input = log
for name, value in settings.items():
    command.extend(['-rd', f'{name}={value}'])
print(f'GF180_{args.kind.upper()} starting; full log: {log}', flush=True)
with log.open('w') as fd:
    fd.write('COMMAND ' + repr(command) + '\n')
    fd.flush()
    subprocess.run(command, cwd=ROOT, stdout=fd, stderr=subprocess.STDOUT, check=True)
status = subprocess.run([sys.executable, str(ROOT/'scripts/check_gds_reports.py'),
                         args.kind, str(check_input), '--output',
                         str(reports/f'gf180_full_{args.kind}_summary.json')], cwd=ROOT)
raise SystemExit(status.returncode)
