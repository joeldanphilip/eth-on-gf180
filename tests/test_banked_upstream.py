"""Run the upstream eight-case MAC suite against the banked FIFO variant."""
from pathlib import Path
import os
from cocotb_test.simulator import run

ROOT = Path(__file__).resolve().parents[1]
UP = ROOT / 'vendor/verilog-ethernet'

def test_banked_upstream():
    rtl = UP/'rtl'
    axis = UP/'lib/axis/rtl'
    sources = [rtl/(name+'.v') for name in
               ['eth_mac_1g_fifo','eth_mac_1g','axis_gmii_rx','axis_gmii_tx','lfsr']]
    sources += [axis/'axis_adapter.v', ROOT/'rtl/axis_async_fifo_banked.v',
                axis/'axis_async_fifo_adapter.v']
    closure = os.environ.get('CLOSURE_RTL') == '1'
    registered = os.environ.get('REGISTERED_FIFO') == '1'
    lookahead_args = ['-D', 'FULL_LOOKAHEAD'] if os.environ.get('FULL_LOOKAHEAD') == '1' else []
    if os.environ.get('WRITE_AHEAD') == '1':
        lookahead_args += ['-D', 'WRITE_AHEAD']
    if os.environ.get('READ_ONEHOT') == '1':
        lookahead_args += ['-D', 'READ_ONEHOT']
    if os.environ.get('DECOUPLE_READ') == '1':
        lookahead_args += ['-D', 'DECOUPLE_READ']
    if os.environ.get('PHYSICAL_PIPELINE') == '1':
        lookahead_args += ['-D', 'READ_BANK_ONEHOT', '-D', 'PIPELINED_WRITE']
    if closure:
        sources = [ROOT/'rtl/axis_gmii_rx_lookahead.v' if path.name == 'axis_gmii_rx.v' else path for path in sources]
    run(verilog_sources=[str(path) for path in sources],
        toplevel='eth_mac_1g_fifo', module='test_eth_mac_1g_fifo',
        python_search=[str(UP/'tb/eth_mac_1g_fifo')],
        parameters={'TX_FIFO_DEPTH':int(os.environ.get('TEST_FIFO_DEPTH', '4096')), 'RX_FIFO_DEPTH':int(os.environ.get('TEST_FIFO_DEPTH', '4096')),
                    'TX_FIFO_RAM_PIPELINE':2, 'RX_FIFO_RAM_PIPELINE':2},
        compile_args=lookahead_args + (['-D','ONEHOT_WRITE'] if closure else []) + (['-D','REGISTER_FULL_FLAGS'] if registered else []) + (['-D','ELASTIC_READ'] if os.environ.get('ELASTIC_READ') == '1' else []) + (['-D','FAST_CONTROL'] if os.environ.get('FAST_CONTROL') == '1' else []) + (['-D','REGISTER_EMPTY'] if os.environ.get('REGISTER_EMPTY') == '1' else []),
        sim_build=str(ROOT/('build/physical_pipeline_upstream' if os.environ.get('PHYSICAL_PIPELINE') == '1' else 'build/registered_upstream' if registered else 'build/closure_upstream' if closure else 'build/banked_upstream')))
