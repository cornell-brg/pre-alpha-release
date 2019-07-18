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

from pymtl3.dsl import Placeholder
from pymtl3.stdlib.ifcs import DeqIfcRTL, GiveIfcRTL, OutValRdyIfc

#-------------------------------------------------------------------------
# testbench
#-------------------------------------------------------------------------
# TODO:rename testbench into something meaningful.

class testbench( Placeholder, Component ):
  def construct( s, import_params ):

    # FIXME: calculate ReqType from import params.
    ReqType  = mk_bits( 64 )
    RespType = mk_bits( 64 )

    # Interface
    s.clk_i          = Inport ( Bits1    )
    s.reset_i        = InPort ( Bits1    )
    s.freeze_i       = InPort ( Bits1    )

    # Req side - equivalent to a deq interface
    s.tr_pkt_v_i     = Inport ( Bits1    )
    s.tr_pkt_i       = Inport ( ReqType  )
    s.tr_pkt_yumi_o  = OutPort( Bits1    )

    # Resp side - equivalent to a val/rdy
    s.tr_pkt_v_o     = OutPort( Bits1    )
    s.tr_pkt_o       = OutPort( RespType )
    s.tr_pkt_ready_i = InPort ( Bits1    )

#-------------------------------------------------------------------------
# BpMeBlackBox
#-------------------------------------------------------------------------

class BpMeBlackBox( Component ):

  # TODO: add parameters.
  def construct( s, ReqType, RespType ):

    # Interface
    s.freeze = Inport      ( Bits1    )
    s.req    = GetIfcRTL   ( ReqType  )
    s.resp   = OutValRdyIfc( RespType )

    # Components
    s.me_box = testbench({
      # TODO: parameters
    })(
      clk_i          = s.clk,
      reset_i        = s.reset,
      freeze_i       = s.freeze,
      tr_pkt_v_i     = s.req.rdy,
      tr_pkt_i       = s.req.msg,
      tr_pkt_yumi_o  = s.req.en,
      tr_pkt_v_o     = s.resp.val,
      tr_pkt_o       = s.resp.msg,
      tr_pkt_ready_i = s.resp.rdy,
    )

    # Metadata for verilog import
    s.me_box.sverilog_import = True