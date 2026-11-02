"""Replicate critical launch DFFs, preserving their shared D/CLK and initial state.

This is an ideal-clock pre-layout ECO. Clock-tree load/placement must be checked
in physical implementation. A quotient-graph check verifies every consumer still
sees the original logical state and no other connections or constants change.
"""
import argparse
import copy
import json
import re
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('source', type=Path)
p.add_argument('report', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--loads-per-copy', type=int, default=2)
p.add_argument('--buffers', action='store_true', help='Replicate combinational buffers/inverters instead of DFFs')
a = p.parse_args()
assert a.loads_per_copy > 0
design = json.loads(a.source.read_text())
m = design['modules']['eth_mac_1g_fifo']
cells = m['cells']
original = copy.deepcopy(cells)
bits = [b for n in m['netnames'].values() for b in n['bits'] if isinstance(b, int)]
bits += [b for c in cells.values() for pins in c['connections'].values() for b in pins if isinstance(b, int)]
next_bit = max(bits)+1
starts = []
for block in re.split(r'(?=Startpoint:)', a.report.read_text()):
    if 'Path Type: max' in block and 'slack (VIOLATED)' in block:
        if a.buffers:
            for name in reversed(re.findall(r'\s([A-Za-z_][A-Za-z0-9_$]*)/(?:Q|Z|ZN)\s+\(', block)):
                if name not in starts:
                    starts.append(name)
            continue
        match = re.match(r'Startpoint: (\S+)', block)
        if match and match[1] not in starts:
            starts.append(match[1])
aliases = {}
clones = {}
for source in starts:
    c = cells.get(source)
    pattern = r'gf180mcu_fd_sc_mcu9t5v0__(?:buf|clkbuf|clkinv|inv)_\d+' if a.buffers else r'gf180mcu_fd_sc_mcu9t5v0__dffq_\d+'
    if not c or not re.fullmatch(pattern, c['type']):
        continue
    if not a.buffers:
        assert set(c['connections']) == {'D', 'CLK', 'Q'}
    output, = [pin for pin, direction in c['port_directions'].items() if direction == 'output']
    q, = c['connections'][output]
    loads = [(name, pin, i) for name, other in list(cells.items())
             for pin, connections in other['connections'].items()
             if other['port_directions'][pin] == 'input'
             for i, bit in enumerate(connections) if bit == q]
    if len(loads) <= a.loads_per_copy:
        continue
    init = set()
    for net in m['netnames'].values():
        value = net.get('attributes', {}).get('init')
        if value is not None:
            for i, bit in enumerate(net['bits']):
                if bit == q:
                    init.add(value[-1-i])
    assert len(init) <= 1, (source, init)
    for index, start in enumerate(range(a.loads_per_copy, len(loads), a.loads_per_copy), 1):
        name = f'eco_replica_{source}_{index}'
        assert name not in cells
        clone = copy.deepcopy(c)
        clone['connections'][output] = [next_bit]
        cells[name] = clone
        attributes = {'keep': '1'}
        if init:
            attributes['init'] = next(iter(init))
        m['netnames'][name+'_Q'] = {'hide_name': 0, 'bits': [next_bit], 'attributes': attributes}
        aliases[next_bit] = q
        clones[name] = source
        for consumer, pin, i in loads[start:start+a.loads_per_copy]:
            cells[consumer]['connections'][pin][i] = next_bit
        next_bit += 1
    print(f'{source}: {len(loads)} loads split into groups of {a.loads_per_copy}; init={init}')

# Shared D and CLK imply identical state after a clock edge; known initial
# values are copied, so initialized states also match before the first edge.
for name, source in clones.items():
    clone, ref = cells[name], cells[source]
    assert clone['type'] == ref['type'] and clone['parameters'] == ref['parameters']
    for pin, direction in clone['port_directions'].items():
        if direction != 'input':
            continue
        if a.buffers:
            assert [aliases.get(b, b) for b in clone['connections'][pin]] == [aliases.get(b, b) for b in ref['connections'][pin]]
        else:
            assert clone['connections'][pin] == ref['connections'][pin], (name, pin)
for name, ref in original.items():
    actual = copy.deepcopy(cells[name])
    actual['connections'] = {pin: [aliases.get(b, b) for b in pins] for pin, pins in actual['connections'].items()}
    assert actual == ref, name
a.output.write_text(json.dumps(design))
a.output.with_suffix('.certificate.json').write_text(json.dumps({'clones': clones, 'aliases': aliases,
    'mode': 'combinational buffering' if a.buffers else 'shared D/CLK register replication',
    'quotient_graph_matches': True, 'known_initial_states_copied': True,
    'uninitialized_state_scope': 'copies agree after first shared clock edge; functional operation follows startup reset'}, indent=2))
print(f'Inserted {len(clones)} replicas; original cells/connections/constants verified by quotient graph')
