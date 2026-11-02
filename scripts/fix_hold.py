"""Generate a logically identical mapped netlist with delay on hold endpoints.

Only D pins listed by STA are changed. Four positive BUF_X1 cells are inserted
per endpoint. Verify every inserted chain resolves to its original data signal.
This is a nominal pre-layout ECO; routing and corner signoff remain necessary.
"""
import json
import os
from pathlib import Path

build = Path(os.environ.get('BUILD_DIR', str(Path(__file__).resolve().parents[1] / 'build')))
buffer_type = os.environ.get('HOLD_BUFFER', 'BUF_X1')
buffer_input = os.environ.get('HOLD_BUFFER_INPUT', 'A')
buffer_output = os.environ.get('HOLD_BUFFER_OUTPUT', 'Z')
ff_prefix = os.environ.get('HOLD_FF_PREFIX', 'DFF')
design = json.loads((build/'mac_mapped.json').read_text())
module = design['modules']['eth_mac_1g_fifo']
cells = module['cells']
indices = [bit for cell in cells.values() for pins in cell['connections'].values()
           for bit in pins if isinstance(bit, int)]
indices += [bit for net in module['netnames'].values()
            for bit in net['bits'] if isinstance(bit, int)]
indices += [bit for port in module['ports'].values()
            for bit in port['bits'] if isinstance(bit, int)]
next_bit = max(indices) + 1
before = len(cells)
roots = {}
changes = {}
endpoints = sorted(set((build/'hold_endpoints.txt').read_text().splitlines()))
for endpoint in endpoints:
    name, pin = endpoint.rsplit('/', 1)
    cell = cells[name]
    if pin != 'D' or not cell['type'].startswith(ff_prefix):
        raise ValueError(f'Unsupported hold endpoint {endpoint}')
    original, = cell['connections'][pin]
    previous = original
    for stage in range(4):
        output = next_bit
        next_bit += 1
        buf_name = f'hold_eco_{len(changes)}_{stage}'
        assert buf_name not in cells
        cells[buf_name] = {'hide_name': 0, 'type': buffer_type, 'parameters': {},
            'attributes': {}, 'port_directions': {buffer_input:'input',buffer_output:'output'},
            'connections': {buffer_input:[previous], buffer_output:[output]}}
        roots[output] = previous
        previous = output
    cell['connections'][pin] = [previous]
    changes[endpoint] = (previous, original)

for final, original in changes.values():
    visited = set()
    while final in roots:
        assert final not in visited
        visited.add(final)
        final = roots[final]
    assert final == original, 'Hold ECO changed logic connectivity'
assert len(cells) == before + 4*len(changes)
(build/'mac_hold.json').write_text(json.dumps(design))
print(f'Inserted {4*len(changes)} identity buffers on {len(changes)} hold endpoints; connectivity verified')
