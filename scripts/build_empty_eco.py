"""Build and SAT-prove a Shannon decomposition of the physical empty cone.

The extracted physical gates, rather than a separately interpreted RTL
equation, are the golden function. All cut-point inputs are unconstrained.
"""
import json
import itertools
import sys
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/empty_eco'
LIB = ROOT / 'build/gf180_physical_pipeline/ss.lib'
cells, leaves, cuts = {}, {}, {}
root_net = None
for line in (OUT / 'cone.tsv').read_text().splitlines():
    row = line.split('\t')
    if row[0] == 'ROOT':
        root_net = row[1]
    elif row[0] == 'CUT':
        cuts[row[1]] = row[2]
    elif row[0] == 'LEAF':
        leaves[row[1]] = row[2]
    elif row[0] == 'CELL':
        cells[row[1]] = {'type': row[2], 'pins': {}, 'xy': row[3:]}
    elif row[0] == 'PIN':
        cells[row[1]]['pins'][row[2]] = row[4]
assert root_net and all(n in leaves for n in cuts.values())
balanced = '--balance' in sys.argv
reduction = []
if balanced:
    drivers = {cell['pins'].get('Z', cell['pins'].get('ZN')): name
               for name, cell in cells.items()}
    root_cell = drivers[root_net]
    assert '__oai31_' in cells[root_cell]['type']
    old_cells = {root_cell}

    def gather(net):
        name = drivers.get(net)
        if name and any('__or'+str(n)+'_' in cells[name]['type'] for n in (2, 3, 4)):
            old_cells.add(name)
            for pin, child in cells[name]['pins'].items():
                if pin.startswith('A'):
                    gather(child)
        elif net not in reduction:
            reduction.append(net)

    for pin in ('A1', 'A2', 'A3'):
        gather(cells[root_cell]['pins'][pin])
    root_b = cells[root_cell]['pins']['B']
    cells = {name: cells[name] for name in old_cells}
    outputs = {cell['pins'].get('Z', cell['pins'].get('ZN')) for cell in cells.values()}
    leaves = {net: 'CUT' for cell in cells.values() for net in cell['pins'].values() if net not in outputs}
    assert 5 <= len(reduction) <= 16
leaf_names = sorted(leaves)
net_names = sorted({root_net, *leaves, *(n for c in cells.values() for n in c['pins'].values())})
names = {n: f'n{i}' for i, n in enumerate(net_names)}
width = len(leaves)

def cone(module, forced=None):
    forced = forced or {}
    lines = [f'module {module}(input [{width-1}:0] x, output y);',
             'wire ' + ','.join(names.values()) + ';']
    for i, net in enumerate(leaf_names):
        value = f"1'b{forced[net]}" if net in forced else f'x[{i}]'
        lines.append(f'assign {names[net]} = {value};')
    for i, cell in enumerate(cells.values()):
        pins = ','.join(f'.{pin}({names[net]})' for pin, net in cell['pins'].items())
        lines.append(f"{cell['type']} g{i}({pins});")
    lines.extend([f'assign y={names[root_net]};', 'endmodule'])
    return '\n'.join(lines) + '\n'

(OUT / 'gold.v').write_text(cone('gold_empty'))
candidate = []
cases = list(itertools.product(range(2), repeat=3))
for reset, advance, commit in cases:
    label = f'{reset}{advance}{commit}'
    candidate.append(cone(f'cof{label}', {cuts['reset']: reset,
                           cuts['advance']: advance, cuts['commit']: commit}))
candidate.append(f'module empty_eco(input [{width-1}:0] x, output y);')
labels = [''.join(map(str, case)) for case in cases]
candidate.append('wire ' + ','.join(f'q{label}' for label in labels) + ';')
for label in labels:
    candidate.append(f'cof{label} c{label}(.x(x),.y(q{label}));')
r, a, c = ((leaf_names.index(cuts[k]) for k in ('reset', 'advance', 'commit'))
           if not balanced else (0, 0, 0))
candidate.append(f'assign y=x[{r}] ? (x[{a}] ? (x[{c}] ? q111 : q110) : (x[{c}] ? q101 : q100)) : '
                 f'(x[{a}] ? (x[{c}] ? q011 : q010) : (x[{c}] ? q001 : q000));')
candidate.append('endmodule')
if balanced:
    candidate = [f'module empty_eco(input [{width-1}:0] x, output y);']
    groups = [reduction[i:i+4] for i in range(0, len(reduction), 4)]
    candidate.append('wire ' + ','.join('g'+str(i) for i in range(len(groups))) + ',any_mismatch;')
    for i, group in enumerate(groups):
        if len(group) == 1:
            candidate.append(f'gf180mcu_fd_sc_mcu9t5v0__inv_4 n{i}(.I(x[{leaf_names.index(group[0])}]),.ZN(g{i}));')
        else:
            ports = ','.join(f'.A{j+1}(x[{leaf_names.index(net)}])' for j, net in enumerate(group))
            candidate.append(f'gf180mcu_fd_sc_mcu9t5v0__nor{len(group)}_4 n{i}({ports},.ZN(g{i}));')
    ports = ','.join(f'.A{i+1}(g{i})' for i in range(len(groups)))
    candidate.append(f'gf180mcu_fd_sc_mcu9t5v0__nand{len(groups)}_4 combine({ports},.ZN(any_mismatch));')
    candidate.append(f'gf180mcu_fd_sc_mcu9t5v0__nand2_4 finish(.A1(any_mismatch),.A2(x[{leaf_names.index(root_b)}]),.ZN(y));')
    candidate.append('endmodule')
(OUT / 'candidate.v').write_text('\n'.join(candidate))
miter = f'''module miter(input [{width-1}:0] x, output ok);
wire g,c;
gold_empty old(.x(x),.y(g));
empty_eco replacement(.x(x),.y(c));
assign ok=(g==c);
endmodule
'''
(OUT / 'miter.v').write_text(miter)

def yosys(script, log):
    (OUT / f'{log}.ys').write_text(script + '\n')
    with (OUT / f'{log}.log').open('w') as fd:
        subprocess.run([str(ROOT / 'scripts/yosys'), '-Q', '-T', '-s',
                        str(OUT / f'{log}.ys')], cwd=ROOT, stdout=fd,
                       stderr=subprocess.STDOUT, check=True)

proof_prefix = f'read_liberty -ignore_miss_func {LIB}; read_verilog {OUT}/gold.v; '
proof_suffix = (f'read_verilog {OUT}/miter.v; hierarchy -top miter; flatten; '
                'proc; opt; sat -verify -prove ok 1 -show-inputs')
yosys(proof_prefix + f'read_verilog {OUT}/candidate.v; ' + proof_suffix, 'proof_generic')
if balanced:
    yosys(f'read_liberty -lib {LIB}; read_verilog {OUT}/candidate.v; '
          f'hierarchy -top empty_eco; check -assert; write_json {OUT}/mapped.json; '
          f'write_verilog -noattr -noexpr {OUT}/mapped.v', 'mapping')
else:
    yosys(f'read_liberty -ignore_miss_func {LIB}; read_verilog {OUT}/candidate.v; '
      'hierarchy -top empty_eco; flatten ' + ' '.join('cof'+x for x in labels) + '; '
      'synth -top empty_eco -noabc; '
      f'abc -liberty {LIB} -constr {ROOT}/sta/gf180.constr -D 3000 '
      '-dont_use *_1 -dont_use *_2 -dont_use *__or3_* -dont_use *__or4_* '
      '-dont_use *__xor3_* -dont_use *__xnor3_*; '
      f'flatten; delete t:$scopeinfo; opt_merge; clean; read_liberty -lib {LIB}; check -assert; '
      f'write_json {OUT}/mapped.json; write_verilog -noattr -noexpr {OUT}/mapped.v', 'mapping')
yosys(proof_prefix + f'read_verilog {OUT}/mapped.v; ' + proof_suffix, 'proof_mapped')
(OUT / 'manifest.json').write_text(json.dumps({
    'root': root_net, 'leaves': leaf_names, 'cuts': cuts,
    'old_cells': len(cells), 'mode': 'balance' if balanced else 'shannon',
    'proof_generic': 'PASS', 'proof_mapped': 'PASS',
}, indent=2) + '\n')
mapped = json.loads((OUT / 'mapped.json').read_text())['modules']['empty_eco']
print(f'EMPTY_ECO old_cone_cells={len(cells)} leaves={width} new_cells={len(mapped["cells"])} SAT=PASS')

def tq(value):
    assert not any(ch in value for ch in '{}\n\r')
    return '{' + value + '}'

# Emit a physical patch using only existing leaf nets and new private nets.
commands = ['set block [ord::get_db_block]',
            'set empty_endpoint [$block findInst _380055_]',
            'set empty_d [$empty_endpoint findITerm D]',
            'lassign [$empty_endpoint getLocation] empty_x empty_y']
bits = {}
for bit, name in zip(mapped['ports']['x']['bits'], leaf_names):
    bits[bit] = name
    commands.append(f'if {{[$block findNet {tq(name)}] eq "NULL"}} {{error "Missing ECO leaf net"}}')
used_bits = {bit for cell in mapped['cells'].values() for bus in cell['connections'].values() for bit in bus}
for bit in sorted(used_bits | set(mapped['ports']['y']['bits']), key=str):
    if bit in bits:
        continue
    bits[bit] = f'emptyeco_n{bit}'
    commands.append(f'if {{[$block findNet {tq(bits[bit])}] ne "NULL"}} {{error "ECO net already exists"}}')
    commands.append(f'odb::dbNet_create $block {tq(bits[bit])}')
    if isinstance(bit, str):
        assert bit in ('0', '1')
        cell, pin = ('tieh', 'Z') if bit == '1' else ('tiel', 'ZN')
        commands.extend([
            f'set master [[ord::get_db] findMaster gf180mcu_fd_sc_mcu9t5v0__{cell}]',
            f'set inst [odb::dbInst_create $block $master emptyeco_tie{bit}]',
            f'[$inst findITerm {pin}] connect [$block findNet {tq(bits[bit])}]',
            '$inst setLocation $empty_x $empty_y', '$inst setPlacementStatus PLACED'])
for i, cell in enumerate(mapped['cells'].values()):
    assert cell['type'].startswith('gf180mcu_fd_sc_mcu9t5v0__')
    commands.extend([f'set master [[ord::get_db] findMaster {tq(cell["type"])}]',
                     'if {$master eq "NULL"} {error "ECO cell lacks physical view"}',
                     f'set inst [odb::dbInst_create $block $master emptyeco_g{i}]',
                     '$inst setLocation $empty_x $empty_y', '$inst setPlacementStatus PLACED'])
    for pin, bus in cell['connections'].items():
        assert len(bus) == 1
        commands.append(f'[$inst findITerm {tq(pin)}] connect [$block findNet {tq(bits[bus[0]])}]')
commands.extend(['$empty_d disconnect',
                 f'$empty_d connect [$block findNet {tq(bits[mapped["ports"]["y"]["bits"][0]])}]',
                 f'puts "EMPTY_ECO_INSERTED cells={len(mapped["cells"])} proof=SAT"'])
commands.extend([
    'set old_cone [dict create ' + ' '.join(tq(name)+' 1' for name in cells) + ']',
    f'set prune [list [$block findNet {tq(root_net)}]]',
    'set pruned 0',
    'while {[llength $prune]} {',
    '  set net [lindex $prune 0]; set prune [lrange $prune 1 end]',
    '  if {$net eq "NULL" || [llength [$net getBTerms]]} {continue}',
    '  set sinks 0; set drivers {}',
    '  foreach term [$net getITerms] {',
    '    if {[[$term getMTerm] getIoType] eq "OUTPUT"} {lappend drivers $term} else {incr sinks}',
    '  }',
    '  if {$sinks || [llength $drivers] != 1} {continue}',
    '  set inst [[lindex $drivers 0] getInst]',
    '  if {![dict exists $old_cone [$inst getName]]} {continue}',
    '  foreach term [$inst getITerms] {',
    '    if {[[$term getMTerm] getIoType] eq "INPUT"} {lappend prune [$term getNet]}',
    '  }',
    '  odb::dbInst_destroy $inst',
    '  incr pruned',
    '}',
    'puts "EMPTY_ECO_PRUNED exclusive_old_cells=$pruned"',
])
(OUT / 'insert.tcl').write_text('\n'.join(commands) + '\n')
