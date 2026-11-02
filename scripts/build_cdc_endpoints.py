"""Resolve semantic FIFO crossings to unchanged physical flop instances.

The final checker requires every named instance/pin and timing path to exist.
This is a deterministic inventory of this mapped, 4096-entry frame-FIFO build,
not a generic CDC signoff tool or a metastability/MTBF proof.
"""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'build/gf180_physical_pipeline/mac_mapped.v'
text = source.read_text()
regs = {}
pattern = r'  (gf180mcu_fd_sc_mcu9t5v0__\w*dff\w*) (\S+) \(\n(.*?)\n  \);'
for model, instance, pins in re.findall(pattern, text, re.S):
    output = re.search(r'\.Q\((.*?)\)', pins)
    clock = re.search(r'\.CLK\((.*?)\)', pins)
    if output and clock:
        net = re.sub(r'\s+', '', output[1]).lstrip('\\')
        assert net not in regs, f'Duplicate flop output {net}'
        regs[net] = {'instance': instance, 'clock': clock[1]}

rows = []
def crossing(label, source_net, dest_net):
    a, b = regs[source_net], regs[dest_net]
    assert a['clock'] != b['clock'], (label, a, b)
    rows.append({'label': label, 'source_net': source_net, 'dest_net': dest_net,
                 'source_cell': a['instance'], 'dest_pin': b['instance'] + '/D',
                 'source_clock': a['clock'], 'dest_clock': b['clock'],
                 'max_delay_ns': 8.0})

for side in ('rx', 'tx'):
    prefix = side + '_fifo.fifo_inst.'
    for bit in range(13):
        crossing(f'{side}_read_gray_{bit}', prefix+f'rd_ptr_gray_reg[{bit}]',
                 prefix+f'rd_ptr_gray_sync1_reg[{bit}]')
        crossing(f'{side}_frame_commit_{bit}', prefix+f'wr_ptr_sync_commit_reg[{bit}]',
                 prefix+f'wr_ptr_commit_sync_reg[{bit}]')
        # The elastic empty lookahead also consumes the stable handshake bus.
        crossing(f'{side}_commit_empty_{bit}', prefix+f'wr_ptr_sync_commit_reg[{bit}]',
                 prefix+'elastic_empty_reg')
    crossing(side+'_update_toggle', prefix+'write_update_pending_reg',
             prefix+'wr_ptr_update_sync1_reg')
    crossing(side+'_update_ack', prefix+'wr_ptr_update_sync3_reg',
             prefix+'wr_ptr_update_ack_sync1_reg')
for status in ('overflow', 'bad_frame', 'good_frame'):
    # sync1 is the source-domain toggle; sync2 is the first receiving stage.
    crossing('rx_status_'+status, 'rx_fifo.fifo_inst.'+status+'_sync1_reg',
             'rx_fifo.fifo_inst.'+status+'_sync2_reg')

out = ROOT / 'build/cdc_endpoints'
out.mkdir(exist_ok=True)
(out/'manifest.json').write_text(json.dumps({
    'mapped_source': str(source.relative_to(ROOT)),
    'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'checks': rows,
    'contract': 'Conservative one-source-period flight time for Gray and stable handshake data; no MTBF claim.',
}, indent=2)+'\n')
lines = ['set cdc_crossings {']
for r in rows:
    lines.append('  {'+' '.join(str(r[k]) for k in
                 ('label', 'source_cell', 'dest_pin', 'max_delay_ns'))+'}')
lines.append('}')
(out/'endpoints.tcl').write_text('\n'.join(lines)+'\n')
print(f'CDC_ENDPOINTS checks={len(rows)} manifest={out / "manifest.json"}')
