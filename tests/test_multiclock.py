from pathlib import Path
import itertools
import os
import sys
import cocotb
from cocotb.triggers import Timer
from cocotbext.eth import GmiiFrame
from cocotb_test.simulator import run

ROOT = Path(__file__).resolve().parents[1]
UP = ROOT / 'vendor/verilog-ethernet'
FIFO_DEPTH = int(os.environ.get('TEST_FIFO_DEPTH', '2048'))
OVERSIZE_LENGTH = FIFO_DEPTH + 952
sys.path.insert(0, str(UP / 'tb/eth_mac_1g_fifo'))
import test_eth_mac_1g_fifo as upstream

real_clock = upstream.Clock
def unequal_clock(signal, period, **kwargs):
    return real_clock(signal, {'logic_clk': 6400, 'tx_clk': 8000, 'rx_clk': 8008}[signal._name], units='ps')
upstream.Clock = unequal_clock

@cocotb.test(timeout_time=1000, timeout_unit='us')
async def unequal_clocks(dut):
    await upstream.run_test_tx(dut, payload_lengths=lambda: [60, 61, 512, 1514]*3,
                               payload_data=upstream.incrementing_payload)

@cocotb.test(timeout_time=1000, timeout_unit='us')
async def receive_and_bad_fcs(dut):
    tb = upstream.TB(dut)
    await tb.reset()
    tb.axis_sink.set_pause_generator(itertools.cycle([1, 1, 1, 0]))
    dut.cfg_rx_enable.value = 1
    for length in [60, 61, 512, 1514]:
        payload = upstream.incrementing_payload(length)
        await tb.gmii_source.send(GmiiFrame.from_payload(payload))
        frame = await tb.axis_sink.recv()
        assert bytes(frame.tdata) == payload
        assert not frame.tuser
    bad = GmiiFrame.from_payload(bytes(range(60)))
    bad.data[-1] ^= 1
    await tb.gmii_source.send(bad)
    await Timer(3000, units='ns')
    assert tb.axis_sink.empty(), 'corrupt FCS frame escaped drop policy'
    await tb.gmii_source.send(GmiiFrame.from_payload(bytes([0x5a])*OVERSIZE_LENGTH))
    await Timer((OVERSIZE_LENGTH+32)*8008+1000000, units='ps')
    assert tb.axis_sink.empty(), 'oversized frame escaped RX FIFO drop policy'
    recovery = bytes(range(60))
    await tb.gmii_source.send(GmiiFrame.from_payload(recovery))
    assert bytes((await tb.axis_sink.recv()).tdata) == recovery

@cocotb.test(timeout_time=1000, timeout_unit='us')
async def oversized_tx_recovers(dut):
    tb = upstream.TB(dut)
    await tb.reset()
    dut.cfg_tx_enable.value = 1
    dut.cfg_ifg.value = 12
    await tb.axis_source.send(bytes([0xa5])*OVERSIZE_LENGTH)
    recovery = bytes(range(60))
    await tb.axis_source.send(recovery)
    frame = await tb.gmii_sink.recv()
    assert frame.get_payload() == recovery
    assert frame.check_fcs()
    assert frame.error is None

@cocotb.test(timeout_time=1000, timeout_unit='us')
async def exact_capacity_frame(dut):
    tb = upstream.TB(dut)
    await tb.reset()
    dut.cfg_tx_enable.value = 1
    dut.cfg_rx_enable.value = 1
    dut.cfg_ifg.value = 12
    payload = bytes(index % 256 for index in range(FIFO_DEPTH))
    await tb.axis_source.send(payload)
    tx_frame = await tb.gmii_sink.recv()
    assert tx_frame.get_payload() == payload
    assert tx_frame.check_fcs()
    recovery = bytes(range(60))
    await tb.axis_source.send(recovery)
    assert (await tb.gmii_sink.recv()).get_payload() == recovery
    await tb.gmii_source.send(GmiiFrame.from_payload(payload))
    rx_frame = await tb.axis_sink.recv()
    assert bytes(rx_frame.tdata) == payload
    assert not rx_frame.tuser

def test_multiclock():
    rtl = UP / 'rtl'
    axis = UP / 'lib/axis/rtl'
    sources = [rtl / (x+'.v') for x in ['eth_mac_1g_fifo','eth_mac_1g','axis_gmii_rx','axis_gmii_tx','lfsr']]
    sources += [axis / (x+'.v') for x in ['axis_adapter','axis_async_fifo','axis_async_fifo_adapter']]
    parameters = {'TX_FIFO_DEPTH':FIFO_DEPTH,'RX_FIFO_DEPTH':FIFO_DEPTH}
    banked = os.environ.get('BANKED_FIFO') == '1'
    if banked:
        sources = [ROOT/'rtl/axis_async_fifo_banked.v' if x.name == 'axis_async_fifo.v' else x for x in sources]
        read_pipeline = int(os.environ.get('FIFO_RAM_PIPELINE', '2'))
        parameters.update(TX_FIFO_RAM_PIPELINE=read_pipeline, RX_FIFO_RAM_PIPELINE=read_pipeline)
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
        sources = [ROOT/'rtl/axis_gmii_rx_lookahead.v' if x.name == 'axis_gmii_rx.v' else x for x in sources]
    simulator_args = ['--Wno-fatal'] if os.environ.get('SIM') == 'verilator' else []
    run(verilog_sources=[str(x) for x in sources], toplevel='eth_mac_1g_fifo',
        module='test_multiclock', python_search=[str(ROOT/'tests')],
        parameters=parameters,
            compile_args=simulator_args + lookahead_args + (['-DONEHOT_WRITE'] if closure else []) + (['-DREGISTER_FULL_FLAGS'] if registered else []) + (['-DELASTIC_READ'] if os.environ.get('ELASTIC_READ') == '1' else []) + (['-DFAST_CONTROL'] if os.environ.get('FAST_CONTROL') == '1' else []) + (['-DREGISTER_EMPTY'] if os.environ.get('REGISTER_EMPTY') == '1' else []),
        sim_build=str(ROOT/(f'build/multiclock_physical_pipeline_{FIFO_DEPTH}' if os.environ.get('PHYSICAL_PIPELINE') == '1' else f'build/multiclock_registered_{FIFO_DEPTH}' if registered else f'build/multiclock_closure_{FIFO_DEPTH}' if closure else f'build/multiclock_banked_{FIFO_DEPTH}' if banked else 'build/multiclock')))
