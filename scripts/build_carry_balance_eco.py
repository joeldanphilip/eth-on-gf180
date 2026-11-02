"""SAT-prove and emit a balanced implementation of the remaining carry AND tree."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
is_tx = '--tx' in sys.argv
is_tx_and = '--tx-and' in sys.argv
OUT = ROOT / ('build/tx_and_reduction' if is_tx_and else 'build/tx_reduction' if is_tx else 'build/carry_eco')
OUT.mkdir(exist_ok=True)
cells = {}
source = ROOT / ('build/tx_reduction/cone.tsv' if is_tx or is_tx_and else 'build/empty_eco/cone.tsv')
for line in source.read_text().splitlines():
    row = line.split('\t')
    if row[0] == 'CELL':
        cells[row[1]] = {'type': row[2], 'pins': {}}
    elif row[0] == 'PIN':
        cells[row[1]]['pins'][row[2]] = row[4]
drivers = {c['pins'].get('Z', c['pins'].get('ZN')): name for name, c in cells.items()}
root_name = '_301829_' if is_tx_and else '_301804_' if is_tx else '_278991_'
root_pin = 'ZN' if is_tx else 'Z'
root_net = cells[root_name]['pins'][root_pin]
selected, leaves = set(), []

def gather(net):
    name = drivers.get(net)
    family = 'or' if is_tx else 'and'
    if name and any(f'__{family}{n}_' in cells[name]['type'] for n in (2, 3, 4)):
        selected.add(name)
        for pin, child in cells[name]['pins'].items():
            if pin.startswith('A'):
                gather(child)
    elif net not in leaves:
        leaves.append(net)

if is_tx_and:
    selected.add(root_name)
    gather(cells['_301828_']['pins']['Z'])
    reduction_width = len(leaves)
    bypass = [net for pin, net in cells[root_name]['pins'].items()
              if pin.startswith('A') and net != cells['_301828_']['pins']['Z']]
    assert len(bypass) == 2
    leaves.extend(net for net in bypass if net not in leaves)
elif is_tx:
    selected.add(root_name)
    for pin, net in cells[root_name]['pins'].items():
        if pin.startswith('A'):
            gather(net)
else:
    gather(root_net)
assert 5 <= len(leaves) <= 16
nets = sorted({net for name in selected for net in cells[name]['pins'].values()})
nn = {net: f'n{i}' for i, net in enumerate(nets)}
width = len(leaves)
gold = [f'module gold_carry(input [{width-1}:0] x, output y);', 'wire '+','.join(nn.values())+';']
gold += [f'assign {nn[net]}=x[{i}];' for i, net in enumerate(leaves)]
for i, name in enumerate(sorted(selected)):
    cell = cells[name]
    pins = ','.join(f'.{pin}({nn[net]})' for pin, net in cell['pins'].items())
    gold.append(f'{cell["type"]} g{i}({pins});')
gold.extend([f'assign y={nn[root_net]};', 'endmodule'])
(OUT / 'gold.v').write_text('\n'.join(gold))
reduction_inputs = leaves[:reduction_width] if is_tx_and else leaves
groups = [reduction_inputs[i:i+4] for i in range(0, len(reduction_inputs), 4)]
new = [f'module carry_eco(input [{width-1}:0] x, output y);',
       'wire '+','.join(f'g{i}' for i in range(len(groups)))+';']
tcl = ['set block [ord::get_db_block]', f'set old [$block findInst {root_name}]',
       'lassign [$old getLocation] eco_x eco_y', 'set prune {}',
       'foreach term [$old getITerms] {if {[[$term getMTerm] getIoType] eq "INPUT"} {lappend prune [$term getNet]}}',
       f'[$old findITerm {root_pin}] disconnect']

def add(cell, name, pins):
    tcl.extend([f'set master [[ord::get_db] findMaster gf180mcu_fd_sc_mcu9t5v0__{cell}]',
                'if {$master eq "NULL"} {error "Missing carry ECO master"}',
                f'set inst [odb::dbInst_create $block $master {name}]',
                '$inst setLocation $eco_x $eco_y', '$inst setPlacementStatus PLACED'])
    for pin, net in pins:
        assert not any(c in net for c in '{}\n')
        tcl.append(f'[$inst findITerm {pin}] connect [$block findNet {{{net}}}]')

for i, group in enumerate(groups):
    ports = ','.join(f'.A{j+1}(x[{leaves.index(net)}])' for j, net in enumerate(group))
    cell = f'{"nor" if is_tx else "nand"}{len(group)}_4'
    inputs = [(f'A{j+1}', net) for j, net in enumerate(group)]
    if len(group) == 1:
        cell = 'inv_4'
        ports = f'.I(x[{leaves.index(group[0])}])'
        inputs = [('I', group[0])]
    new.append(f'gf180mcu_fd_sc_mcu9t5v0__{cell} g_{i}({ports},.ZN(g{i}));')
    tcl.append(f'odb::dbNet_create $block carryeco_n{i}')
    add(cell, f'carryeco_g{i}', inputs + [('ZN', f'carryeco_n{i}')])
ports = ','.join(f'.A{i+1}(g{i})' for i in range(len(groups)))
if is_tx_and:
    assert len(groups) == 3
    new.append('wire permit;')
    new.append(f'gf180mcu_fd_sc_mcu9t5v0__nor2_4 permit_g(.A1(x[{leaves.index(bypass[0])}]),.A2(x[{leaves.index(bypass[1])}]),.ZN(permit));')
    new.extend([f'gf180mcu_fd_sc_mcu9t5v0__oai31_4 finish({ports},.B(permit),.ZN(y));', 'endmodule'])
    tcl.append('odb::dbNet_create $block carryeco_permit')
    add('nor2_4', 'carryeco_permit_g', [('A1', bypass[0]), ('A2', bypass[1]), ('ZN', 'carryeco_permit')])
    add('oai31_4', 'carryeco_finish', [(f'A{i+1}', f'carryeco_n{i}') for i in range(3)] + [('B', 'carryeco_permit'), ('ZN', root_net)])
else:
    family = 'and' if is_tx else 'nor'
    pin = 'Z' if is_tx else 'ZN'
    new.extend([f'gf180mcu_fd_sc_mcu9t5v0__{family}{len(groups)}_4 finish({ports},.{pin}(y));', 'endmodule'])
    add(f'{family}{len(groups)}_4', 'carryeco_finish', [(f'A{i+1}', f'carryeco_n{i}') for i in range(len(groups))] + [(pin, root_net)])
tcl.extend(['odb::dbInst_destroy $old',
            'set old_cone [dict create '+' '.join(name+' 1' for name in selected)+']',
            'while {[llength $prune]} {',
            'set net [lindex $prune 0]; set prune [lrange $prune 1 end]',
            'if {$net eq "NULL" || [llength [$net getBTerms]]} {continue}',
            'set sinks 0; set drivers {}',
            'foreach term [$net getITerms] {if {[[$term getMTerm] getIoType] eq "OUTPUT"} {lappend drivers $term} else {incr sinks}}',
            'if {$sinks || [llength $drivers] != 1} {continue}',
            'set inst [[lindex $drivers 0] getInst]',
            'if {![dict exists $old_cone [$inst getName]]} {continue}',
            'foreach term [$inst getITerms] {if {[[$term getMTerm] getIoType] eq "INPUT"} {lappend prune [$term getNet]}}',
            'odb::dbInst_destroy $inst', '}',
            f'puts "CARRY_ECO old_tree={len(selected)} new_tree={len(groups)+(2 if is_tx_and else 1)} SAT=PASS"'])
(OUT / 'candidate.v').write_text('\n'.join(new))
(OUT / 'miter.v').write_text(f'module miter(input [{width-1}:0] x, output ok); wire a,b; gold_carry old(x,a); carry_eco replacement(x,b); assign ok=a==b; endmodule')
lib = ROOT / 'build/gf180_physical_pipeline/ss.lib'
script = f'read_liberty -ignore_miss_func {lib}; read_verilog {OUT}/gold.v {OUT}/candidate.v {OUT}/miter.v; hierarchy -top miter; flatten; proc; opt; sat -verify -prove ok 1 -show-inputs'
(OUT / 'proof.ys').write_text(script)
with (OUT / 'proof.log').open('w') as fd:
    subprocess.run([str(ROOT / 'scripts/yosys'), '-Q', '-T', '-s', str(OUT / 'proof.ys')], stdout=fd, stderr=subprocess.STDOUT, check=True)
(OUT / 'insert.tcl').write_text(('\n'.join(tcl)+'\n').replace('carryeco', 'txandreduce' if is_tx_and else 'txreduce' if is_tx else 'carryeco'))
print(f'CARRY_ECO leaves={width} old_cells={len(selected)} new_cells={len(groups)+(2 if is_tx_and else 1)} SAT=PASS')
