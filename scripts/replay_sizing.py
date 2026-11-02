"""Replay accepted sizing swaps on Yosys JSON, preserving wires/constants.

OpenSTA's raw Verilog export in this setup omitted constant drivers. Instead of
repairing that text, apply only validated same-family type substitutions to the
known-good source netlist and let Yosys write Verilog.
"""
import argparse
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('profile', type=Path)
parser.add_argument('--allow-downsize', action='store_true')
args = parser.parse_args()
design = json.loads((args.profile/'mac_hold.json').read_text())
module = design['modules']['eth_mac_1g_fifo']
cells = module['cells']
before = len(cells)
swaps = re.findall(r'^SIZING round=\d+ (\S+) (\S+) -> (\S+) ',
                   (args.profile/'resize.log').read_text(), re.M)
for instance, old, new in swaps:
    assert cells[instance]['type'] == old, f'Unexpected source cell: {instance}'
    old_family, old_drive = old.rsplit('_', 1)
    new_family, new_drive = new.rsplit('_', 1)
    assert old_family == new_family
    assert int(new_drive) > 0 and int(new_drive) != int(old_drive)
    assert args.allow_downsize or int(new_drive) > int(old_drive)
    ports = {name:port['direction'] for name,port in design['modules'][new]['ports'].items()}
    assert ports == cells[instance]['port_directions'], f'Pin mismatch: {instance}'
    cells[instance]['type'] = new
assert len(cells) == before
(args.profile/'mac_resized.json').write_text(json.dumps(design))
print(f'Replayed {len(swaps)} drive-grade substitutions; all wiring and constants retained')
