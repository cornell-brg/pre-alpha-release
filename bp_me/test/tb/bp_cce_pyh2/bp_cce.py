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

from pymtl3.passes.sverilog import ImportPass
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

    # Delete default clk/reset
    # del( s.clk   )
    # del( s.reset )

    # Interface
    # s.clk_i          = InPort ( Bits1    )
    # s.reset_i        = InPort ( Bits1    )
    s.freeze_i       = InPort ( Bits1    )

    # Req side - equivalent to a deq interface
    s.tr_pkt_v_i     = InPort ( Bits1    )
    s.tr_pkt_i       = InPort ( ReqType  )
    s.tr_pkt_yumi_o  = OutPort( Bits1    )

    # Resp side - equivalent to a val/rdy
    s.tr_pkt_v_o     = OutPort( Bits1    )
    s.tr_pkt_o       = OutPort( RespType )
    s.tr_pkt_ready_i = InPort ( Bits1    )

    # Metadata for verilog import
    s.sverilog_import = True
    s.bp_import = True
    # s.sverilog_import_path = "../testbench.v"
    s.sverilog_import_path = "testbench.sv"

#-------------------------------------------------------------------------
# BpMeBlackBox
#-------------------------------------------------------------------------

class BpMeBlackBox( Component ):

  # TODO: add parameters.
  def construct( s, ReqType, RespType ):

    # Interface
    s.freeze = InPort      ( Bits1    )
    s.req    = GetIfcRTL   ( ReqType  )
    s.resp   = OutValRdyIfc( RespType )

    # Components
    # s.me_box = testbench({
      # # TODO: parameters
    # })(
    s.me_box = testbench()(
      # clk_i          = s.clk,
      # reset_i        = s.reset,
      freeze_i       = s.freeze,
      tr_pkt_v_i     = s.req.rdy,
      tr_pkt_i       = s.req.msg,
      tr_pkt_yumi_o  = s.req.en,
      tr_pkt_v_o     = s.resp.val,
      tr_pkt_o       = s.resp.msg,
      tr_pkt_ready_i = s.resp.rdy,
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

    s.req_q  = BypassQueueRTL( ReqType, num_entries=1 )
    s.resp_q = BypassQueueRTL( ReqType, num_entries=1 )
    s.dut = BpMeBlackBox( ReqType, RespType )
    s.adapter = ValRdy2EnRdy( RespType )

    s.connect( s.req, s.req_q.enq )
    s.connect( s.req_q.deq, s.dut.req )
    s.connect( s.dut.resp, s.adapter.in_ )
    s.connect( s.adapter.out, s.resp_q.enq )
    s.connect( s.resp_q.deq, s.resp )
    s.connect( s.freeze, s.dut.freeze )

  def line_trace( s ):
    return "{}(){}".format( s.req, s.resp )

if __name__ == "__main__":
  tb = WrappedBox( Bits107, Bits107 )
  tb.elaborate()
  # del( s.clk   )
  # del( s.reset )
  tb = ImportPass()( tb )
  tb.elaborate()
  tb.apply( SimulationPass )
  tb.reset()
  tb.tick()
  tb.tick()
  tb.tick()
