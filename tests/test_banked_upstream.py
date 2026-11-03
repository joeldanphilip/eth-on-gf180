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
    lookahead_args = ['-DFULL_LOOKAHEAD'] if os.environ.get('FULL_LOOKAHEAD') == '1' else []
    if os.environ.get('WRITE_AHEAD') == '1':
        lookahead_args += ['-DWRITE_AHEAD']
    if os.environ.get('READ_ONEHOT') == '1':
        lookahead_args += ['-DREAD_ONEHOT']
    if os.environ.get('DECOUPLE_READ') == '1':
        lookahead_args += ['-DDECOUPLE_READ']
    if os.environ.get('PHYSICAL_PIPELINE') == '1':
        lookahead_args += ['-DREAD_BANK_ONEHOT', '-DPIPELINED_WRITE']
    if closure:
        sources = [ROOT/'rtl/axis_gmii_rx_lookahead.v' if path.name == 'axis_gmii_rx.v' else path for path in sources]
    read_pipeline = int(os.environ.get('FIFO_RAM_PIPELINE', '2'))
    simulator_args = ['--Wno-fatal'] if os.environ.get('SIM') == 'verilator' else []
    run(verilog_sources=[str(path) for path in sources],
        toplevel='eth_mac_1g_fifo', module='test_eth_mac_1g_fifo',
        python_search=[str(UP/'tb/eth_mac_1g_fifo')],
        parameters={'TX_FIFO_DEPTH':int(os.environ.get('TEST_FIFO_DEPTH', '4096')), 'RX_FIFO_DEPTH':int(os.environ.get('TEST_FIFO_DEPTH', '4096')),
                    'TX_FIFO_RAM_PIPELINE':read_pipeline, 'RX_FIFO_RAM_PIPELINE':read_pipeline},
        compile_args=simulator_args + lookahead_args + (['-DONEHOT_WRITE'] if closure else []) + (['-DREGISTER_FULL_FLAGS'] if registered else []) + (['-DELASTIC_READ'] if os.environ.get('ELASTIC_READ') == '1' else []) + (['-DFAST_CONTROL'] if os.environ.get('FAST_CONTROL') == '1' else []) + (['-DREGISTER_EMPTY'] if os.environ.get('REGISTER_EMPTY') == '1' else []),
        sim_build=str(ROOT/('build/physical_pipeline_upstream' if os.environ.get('PHYSICAL_PIPELINE') == '1' else 'build/registered_upstream' if registered else 'build/closure_upstream' if closure else 'build/banked_upstream')))
