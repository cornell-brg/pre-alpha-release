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

    # Interface
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
    s.dump_vcd = True

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

    s.req_wire = Wire( Bits107 )
    s.resp_wire = Wire( Bits107 )

    s.connect( s.req.msg.type_, s.req_wire[103:107] )
    s.connect( s.req.msg.addr,  s.req_wire[64 :103] )
    s.connect( s.req.msg.data,  s.req_wire[0  :64 ] )

    s.connect( s.resp.msg.type_, s.resp_wire[103:107] )
    s.connect( s.resp.msg.addr,  s.resp_wire[64 :103] )
    s.connect( s.resp.msg.data,  s.resp_wire[0  :64 ] )

    # Components
    s.me_box = testbench()(
      freeze_i       = s.freeze,
      tr_pkt_v_i     = s.req.rdy,
      tr_pkt_i       = s.req_wire,
      tr_pkt_yumi_o  = s.req.en,
      tr_pkt_v_o     = s.resp.val,
      tr_pkt_o       = s.resp_wire,
      tr_pkt_ready_i = s.resp.rdy,
    )

  def line_trace( s ):
    return "f:{},v_i:{},m_i:{},y_i:{},v_o:{},m_o:{},r_o:{}".format(
      s.me_box.freeze_i, 
      s.me_box.tr_pkt_v_i,
      s.me_box.tr_pkt_i,
      s.me_box.tr_pkt_yumi_o,
      s.me_box.tr_pkt_v_o,
      s.me_box.tr_pkt_o,
      s.me_box.tr_pkt_ready_i,
    )
    #  return "{}||{}".format(
    #    s.me_box.line_trace(),
    #    s.me_box.internal_line_trace(),
    #  )

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

    s.connect( s.req, s.req_q.enq )
    s.connect( s.req_q.deq, s.dut.req )
    s.connect( s.dut.resp, s.adapter.in_ )
    s.connect( s.adapter.out, s.resp_q.enq )
    s.connect( s.resp_q.deq, s.resp )
    s.connect( s.freeze, s.dut.freeze )

  def line_trace( s ):
    return "{}({}){}".format( s.req, s.dut.line_trace(), s.resp )

  def bp_init( s ):
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
    print( "init finished" )

