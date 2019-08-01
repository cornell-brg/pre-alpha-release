"""
==========================================================================
bp_cce.py
==========================================================================
Lightweight python wrapper to bring the cache coherence engine into PyMTL
framework.

Author : Yanghui Ou, Peitian Pan
  Date : July 18, 2019
"""

from pymtl3 import *

from pymtl3.passes.sverilog import ImportPass, ImportConfigs
from pymtl3.dsl import Placeholder
from pymtl3.stdlib.ifcs import DeqIfcRTL, GiveIfcRTL, OutValRdyIfc, \
                               EnqIfcRTL, GetIfcRTL, InValRdyIfc, \
                               SendIfcRTL
from pymtl3.stdlib.rtl.queues import BypassQueueRTL


#-------------------------------------------------------------------------
# testbench
#-------------------------------------------------------------------------
# TODO:rename testbench into something meaningful.

class testbench( Placeholder, Component ):
  # def construct( s, import_params ):
  def construct( s ):

    # FIXME: calculate ReqType from import params.
    ReqType  = mk_bits( 107 )
    RespType = mk_bits( 107 )

    # Interface
    s.freeze       = InPort ( Bits1    )

    # Req side - equivalent to a deq interface
    s.req_rdy  = InPort ( Bits1    )
    s.req_wire = InPort ( ReqType  )
    s.req_en   = OutPort( Bits1    )

    # Resp side - equivalent to a val/rdy
    s.resp_val  = OutPort( Bits1    )
    s.resp_wire = OutPort( RespType )
    s.resp_rdy  = InPort ( Bits1    )

    # Metadata for verilog import
    s.sverilog_import = ImportConfigs(
        # verbose = True,
        top_module = "testbench",
        vl_flist = "flist.verilator",
        # Warning control
        vl_W_lint = False,
        vl_W_style = False,
        vl_W_fatal = False,
        vl_Wno_list = [ 'UNOPTFLAT', 'WIDTHCONCAT' ],
        # Enable vcd dump
        vl_trace = True,
        # flags passed to C compiler
        c_flags = "-std=c++11",
        c_include_path = [ "$BP_EXTERNAL_DIR/DRAMSim2" ],
        c_srcs = [ "$BP_ME_DIR/test/common/dramsim2_wrapper.cpp" ],
        ld_flags = '-L$BP_EXTERNAL_DIR/lib -Wl,-rpath=$BP_EXTERNAL_DIR/lib',
        ld_libs = "-ldramsim",
        # Map port names of `testbench` component to Verilog port names
        port_map = {
          # clk and reset are implicit pymtl ports
          "clk" : "clk_i",
          "reset" : "reset_i",
          "freeze" : "freeze_i",
          "req_rdy" : "tr_pkt_v_i",
          "req_wire" : "tr_pkt_i",
          "req_en" : "tr_pkt_yumi_o",
          "resp_val" : "tr_pkt_v_o",
          "resp_wire" : "tr_pkt_o",
          "resp_rdy" : "tr_pkt_ready_i",
        }
    )

#-------------------------------------------------------------------------
# BpMeBlackBox
#-------------------------------------------------------------------------

class BpMeBlackBox( Component ):

  def construct( s, ReqType, RespType ):

    # Interface
    s.freeze = InPort      ( Bits1    )
    s.req    = GetIfcRTL   ( ReqType  )
    s.resp   = OutValRdyIfc( RespType )

    s.req_wire = Wire( Bits107 )
    s.resp_wire = Wire( Bits107 )

    connect( s.req.msg.type_, s.req_wire[103:107] )
    connect( s.req.msg.addr,  s.req_wire[64 :103] )
    connect( s.req.msg.data,  s.req_wire[0  :64 ] )

    connect( s.resp.msg.type_, s.resp_wire[103:107] )
    connect( s.resp.msg.addr,  s.resp_wire[64 :103] )
    connect( s.resp.msg.data,  s.resp_wire[0  :64 ] )

    # Components
    s.me_box = testbench()(
      freeze          = s.freeze,
      req_rdy         = s.req.rdy,
      req_wire        = s.req_wire,
      req_en          = s.req.en,
      resp_val        = s.resp.val,
      resp_wire       = s.resp_wire,
      resp_rdy        = s.resp.rdy,
      # freeze_i       = s.freeze,
      # tr_pkt_v_i     = s.req.rdy,
      # tr_pkt_i       = s.req_wire,
      # tr_pkt_yumi_o  = s.req.en,
      # tr_pkt_v_o     = s.resp.val,
      # tr_pkt_o       = s.resp_wire,
      # tr_pkt_ready_i = s.resp.rdy,
      # reset = s.reset,
    )

  def line_trace( s ):
    return "f:{},v_i:{},m_i:{},y_i:{},v_o:{},m_o:{},r_o:{}".format(
      s.me_box.freeze,
      s.me_box.req_rdy,
      s.me_box.req_wire,
      s.me_box.req_en,
      s.me_box.resp_val,
      s.me_box.resp_wire,
      s.me_box.resp_rdy,
    )

#-------------------------------------------------------------------------
# ValRdy2EnRdy
#-------------------------------------------------------------------------
# A val/rdy to send adapter.

class ValRdy2EnRdy( Component ):

  def construct( s, MsgType ):

    s.in_ = InValRdyIfc( MsgType )
    s.out = SendIfcRTL( MsgType )

    @s.update
    def comb_logic0():
      s.in_.rdy = s.out.rdy

    @s.update
    def comb_logic1():
      s.out.en  = s.out.rdy & s.in_.val

    @s.update
    def comb_logic2():
      s.out.msg = s.in_.msg

  def line_trace( s ):
    return "{}(){}".format( s.in_, s.out )

#-------------------------------------------------------------------------
# WrappedBpBox
#-------------------------------------------------------------------------
# A wrapper that adds queues to req and resp side to create callee
# interfaces.

class WrappedBox( Component ):

  def construct( s, ReqType, RespType ):

    # Interface
    s.req  = EnqIfcRTL( ReqType  )
    s.resp = DeqIfcRTL( RespType )

    s.freeze = InPort( Bits1 )

    s.req_q   = BypassQueueRTL( ReqType, num_entries=1 )
    s.resp_q  = BypassQueueRTL( ReqType, num_entries=1 )
    s.dut     = BpMeBlackBox( ReqType, RespType )
    s.adapter = ValRdy2EnRdy( RespType )

    connect( s.dut.reset, s.reset )
    connect( s.req, s.req_q.enq )
    connect( s.req_q.deq, s.dut.req )
    connect( s.dut.resp, s.adapter.in_ )
    connect( s.adapter.out, s.resp_q.enq )
    connect( s.resp_q.deq, s.resp )
    connect( s.freeze, s.dut.freeze )

  def line_trace( s ):
    return "{}({}){}".format( s.req, s.dut.line_trace(), s.resp )

  def bp_init( s ):
    # Disable assertions during reset
    s.dut.me_box.assert_en(False)
    s.reset  = b1(1)
    s.freeze = b1(1)
    s.tick()
    s.tick()
    s.tick()
    s.reset = b1(0)
    s.tick()
    s.tick()
    s.tick()
    s.freeze = b1(0)
    for _ in range( 5000 ):
      s.tick()
    s.tick()
    # Re-enable assertions
    s.dut.me_box.assert_en(True)

if __name__ == "__main__":
  dut = testbench()
  dut.elaborate()
  _dut = ImportPass()( dut )
  _dut.elaborate()
