"""Validate physical cell coverage and record immutable input/tool fingerprints."""
import collections
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
flow_root = root/'tools/ORFS_physical'
platform = flow_root/'flow/platforms/gf180'
parser = argparse.ArgumentParser()
parser.add_argument('--profile', default='build/gf180_read_onehot_finish')
parser.add_argument('--stem', default='mac_resized')
parser.add_argument('--output', default='build/physical/input_manifest.json')
parser.add_argument('--soc', action='store_true')
parser.add_argument('--design-config', default='physical/decoupled_design.mk')
args = parser.parse_args()
source = root/args.profile
design = json.loads((source/(args.stem+'.json')).read_text())
module = design['modules']['eth_mac_1g_fifo']
parameters = module['parameter_default_values']
fifo_parameters = {name: int(parameters[name], 2) for name in
                   ['TX_FIFO_DEPTH', 'RX_FIFO_DEPTH', 'TX_FIFO_RAM_PIPELINE', 'RX_FIFO_RAM_PIPELINE']}
assert fifo_parameters['TX_FIFO_DEPTH'] == fifo_parameters['RX_FIFO_DEPTH'] == 4096, fifo_parameters
assert fifo_parameters['TX_FIFO_RAM_PIPELINE'] == fifo_parameters['RX_FIFO_RAM_PIPELINE'] == 2, fifo_parameters
cells = module['cells']
cells = {name: cell for name, cell in cells.items() if cell['type'] != '$scopeinfo'}
usage = collections.Counter(c['type'] for c in cells.values())
lef = platform/'lef/gf180mcu_5LM_1TM_9K_9t_sc.lef'
masters = set(re.findall(r'^MACRO\s+(\S+)', lef.read_text(), re.M))
gds = {p.stem for p in (platform/'gds/9t').glob('*.gds')}
assert not (set(usage)-masters), ('Missing LEF', sorted(set(usage)-masters))
assert not (set(usage)-gds), ('Missing GDS', sorted(set(usage)-gds))
paths = [source/(args.stem+'.v'), root/'sta/mac.sdc', lef,
         platform/'lef/gf180mcu_5LM_1TM_9K_9t_tech.lef',
         root/'physical/layer_rc.tcl', root/'physical/design.mk']
paths += [source/(name+'.lib') for name in ['ss', 'ff', 'tt']]
if args.soc:
    paths += [root/args.design_config, root/'physical/decoupled_design.mk', root/'physical/soc_interface.tcl',
              root/'physical/qor_soc_cts.tcl', root/'physical/decoupled_pre_grt.tcl',
              root/'physical/connect_constants.tcl',
              root/'rtl/axis_async_fifo_banked.v']
manifest = {
    'design': 'eth_mac_1g_fifo', 'fifo_entries_tx_rx': 4096, 'period_ns': 8,
    'mapped_fifo_parameters': fifo_parameters,
    'standard_cell_instances': len(cells), 'used_cell_types': dict(usage),
    'all_used_cells_have_lef_and_gds': True,
    'openroad': subprocess.check_output([str(root/'physical/bin/openroad'), '-version'], text=True).strip(),
    'klayout': subprocess.check_output([str(root/'physical/bin/klayout'), '-v'], text=True).strip(),
    'orfs_commit': subprocess.check_output(['git', '-C', str(flow_root), 'rev-parse', 'HEAD'], text=True).strip(),
    'technology_checkout': str(platform),
    'profile': args.profile, 'netlist_stem': args.stem,
    'io_contract': ('SoC neighbors balanced to representative MAC clock leaf; '
                    '1.0/0.2 ns interface budgets; top-level skew validation required'
                    if args.soc else 'Original example root-clock I/O budgets'),
    'sha256': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
    'scope': 'MAC block implementation; routed timing, connectivity, GDS completeness and foundry checks remain stage-specific results',
}
out = root/args.output
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(manifest, indent=2)+'\n')
print(json.dumps({k:v for k,v in manifest.items() if k not in ('used_cell_types', 'sha256')}, indent=2))
