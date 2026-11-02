"""Summarize completed logs; missing checks are reported as missing, never PASS."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
def read(name):
    path = root / 'build' / name
    return path.read_text(errors='replace') if path.exists() else ''

tests = read('test_final.log')
multiclock = read('multiclock.log')
formal = read('verified_formal.log')
mapping = read('mapping.log')
timing = read('timing.log')
hold_timing = read('timing_hold.log')
periodic = read('periodic_formal.log')
summary = {
    'packet_tests_pass': bool(re.search(r'2 passed', tests)) and 'failed' not in tests,
    'latest_multiclock_and_error_tests_pass': '1 passed' in multiclock and 'failed' not in multiclock,
    'fifo_bmc_pass': '[build/verified_fifo_bmc] DONE (PASS' in formal,
    'fifo_cover_pass': '[build/verified_fifo_cover] DONE (PASS' in formal,
    'fifo_periodic_60_pass': '[build/periodic_fifo_periodic] DONE (PASS' in periodic,
    'mapped_netlist_exists': (root / 'build/mac_mapped.v').exists(),
    'mapping_errors': re.findall(r'^ERROR:.*', mapping, re.M),
    'sta_errors': re.findall(r'^Error:.*', timing, re.M),
    'worst_slack': re.findall(r'^worst slack.*', timing, re.M),
    'hold_eco_errors': re.findall(r'^Error:.*', hold_timing, re.M),
    'final_worst_slack': re.findall(r'^worst slack.*', hold_timing, re.M),
    'scope': '30-step reduced FIFO BMC; pre-layout Nangate45 typical STA',
}
for profile in ['gf180', 'gf180_banked', 'gf180_sized', 'gf180_5v', 'gf180_closure', 'gf180_registered', 'gf180_elastic', 'gf180_fast', 'gf180_empty', 'gf180_lookahead', 'gf180_write_ahead', 'gf180_read_onehot', 'gf180_read_onehot_finish']:
    corner_log = read(f'{profile}/timing_ss_ff.log')
    summary[profile] = {
        'ss_ff_slack': re.findall(r'^worst slack.*', corner_log, re.M),
        'tt_slack': re.findall(r'^worst slack.*', read(f'{profile}/timing_tt.log'), re.M),
        'sta_errors': re.findall(r'^Error:.*', corner_log, re.M),
    }
summary['frame_mode_100_pass'] = '[build/frame_bitwuzla_bmc] DONE (PASS' in read('frame_bitwuzla.log')
summary['banked_reduced_equivalence_100_pass'] = '[build/banked_equiv_bmc] DONE (PASS' in read('gf180/banked_formal.log')
summary['rx_unbounded_equivalence_pass'] = '[build/rx_induction_prove] DONE (PASS' in read('gf180/rx_induction.log')
summary['onehot_reduced_equivalence_100_pass'] = '[build/onehot_equiv_bmc] DONE (PASS' in read('gf180/onehot_formal.log')
summary['onehot_full_tx_invariant_pass'] = '[build/onehot_full_tx] DONE (PASS' in read('gf180/onehot_full_invariant.log')
summary['onehot_full_rx_invariant_pass'] = '[build/onehot_full_rx] DONE (PASS' in read('gf180/onehot_full_invariant.log')
summary['elastic_packet_tests_pass'] = bool(re.search(r'2 passed', read('gf180/elastic_credit_simulation.log')))
summary['elastic_fifo_bmc_100_pass'] = '[build/elastic_checked_bmc] DONE (PASS' in read('gf180/elastic_checked_formal.log')
summary['elastic_fifo_cover_320_pass'] = '[build/elastic_checked_cover] DONE (PASS' in read('gf180/elastic_checked_formal.log')
summary['elastic_resized_ss_ff_slack'] = re.findall(r'^worst slack.*', read('gf180_elastic/timing_resized_ss_ff.log'), re.M)
summary['elastic_resized_tt_slack'] = re.findall(r'^worst slack.*', read('gf180_elastic/timing_resized_tt.log'), re.M)
summary['fast_packet_tests_pass'] = bool(re.search(r'2 passed', read('gf180/fast_simulation.log')))
for task in ['bmc', 'cover']:
    summary[f'fast_{task}_pass'] = f'[build/fast_control_{task}] DONE (PASS' in read('gf180/fast_formal.log')
for task in ['tx', 'rx']:
    summary[f'fast_{task}_invariant_pass'] = f'[build/fast_invariant_{task}] DONE (PASS' in read('gf180/fast_formal.log')
for candidate in ['empty', 'lookahead']:
    summary[f'{candidate}_packet_tests_pass'] = bool(re.search(r'2 passed', read(f'gf180/{candidate}_simulation.log')))
    for task in ['bmc', 'cover']:
        summary[f'{candidate}_{task}_pass'] = f'[build/{candidate}_control_{task}] DONE (PASS' in read(f'gf180/{candidate}_formal.log')
    for task in ['tx', 'rx']:
        invariant_log = f'gf180/{candidate}_invariant.log' if candidate == 'empty' else 'gf180/lookahead_formal.log'
        summary[f'{candidate}_{task}_invariant_pass'] = f'[build/{candidate}_invariant_{task}] DONE (PASS' in read(invariant_log)
    summary[f'{candidate}_resized_ss_ff_slack'] = re.findall(r'^worst slack.*', read(f'gf180_{candidate}/timing_resized_ss_ff.log'), re.M)
for candidate in ['write_ahead', 'read_onehot']:
    log = read(f'gf180/{candidate}_formal.log')
    summary[f'{candidate}_packet_tests_pass'] = bool(re.search(r'2 passed', read(f'gf180/{candidate}_simulation.log')))
    for task in ['bmc', 'cover']:
        summary[f'{candidate}_{task}_pass'] = f'[build/{candidate}_{task}] DONE (PASS' in log
    for task in ['tx', 'rx']:
        summary[f'{candidate}_{task}_invariant_pass'] = f'[build/{candidate}_invariant_{task}] DONE (PASS' in log
    summary[f'{candidate}_resized_ss_ff_slack'] = re.findall(r'^worst slack.*', read(f'gf180_{candidate}/timing_resized_ss_ff.log'), re.M)
summary['exhaustive_empty_ss_ff_slack'] = re.findall(r'^worst slack.*', read('gf180_empty_search/timing_resized_ss_ff.log'), re.M)
summary['selected_1g_ss_ff_closed'] = '"timing_met": true' in read('gf180_read_onehot_finish/closure_ss_ff.json')
summary['selected_1g_tt_closed'] = '"timing_met": true' in read('gf180_read_onehot_finish/closure_tt.json')
summary['selected_1g_scope'] = '4096-entry TX/RX, 8 ns clocks, GF180 5 V views, pre-layout ideal clocks; not physical signoff or full-MAC unbounded proof'
print(json.dumps(summary, indent=2))
