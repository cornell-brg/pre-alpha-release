"""
==========================================================================
AluVRTL_test.py
==========================================================================
Imported ALU from Verilog.

Author : Cheng Tan
  Date : July 18, 2019
"""
from copy import deepcopy

# import hypothesis
from hypothesis import strategies as st
from hypothesis import given, settings

from pymtl3 import *
from pymtl3.datatypes import strategies as pst
from pymtl3.passes import GenDAGPass, OpenLoopCLPass as AutoTickSimPass
from pymtl3.passes.sverilog import ImportPass
# from pymtl3.stdlib.test.pyh2.stateful import run_pyh2
# from pymtl3.stdlib.test.pyh2.RTL2CLWrapper import RTL2CLWrapper

from .AluVRTL import Alu, AluVRTL
from .AluFL   import AluFL

def mk_alu_req( nbits ):
  DataType = mk_bits( nbits )
  new_name = 'AluReq_{}'.format( nbits )
  def str_func( self ):
    op_str = (
      '+ ' if self.op == 0 else
      '- ' if self.op == 1 else
      '<<' if self.op == 2 else
      '>>' if self.op == 3 else
      '& ' if self.op == 4 else
      '| ' if self.op == 5 else
      '^ ' if self.op == 6 else
      '~ '
    )
    return "{}{}{}".format( self.in1, op_str, self.in2 )

  msg_cls = mk_bit_struct( new_name,[
      ( 'in1', DataType ),
      ( 'in2', DataType ),
      ( 'op',  Bits3    ),
    ], str_func )
  msg_cls.data_nbits = nbits
  return msg_cls

def mk_alu_resp( nbits ):
  DataType = mk_bits( nbits )
  new_name = 'AluResp_{}'.format( nbits )

  msg_cls = mk_bit_struct( new_name,[
      ( 'result', DataType ),
      ( 'branch', Bits1    ),
    ] )
  msg_cls.data_nbits = nbits
  return msg_cls

#-------------------------------------------------------------------------
# Ad-hoc test
#-------------------------------------------------------------------------

ops = {
  'add' : b3(0),
  'sub' : b3(1),
}

def test_adhoc():
  ReqType  = mk_alu_req (16)
  RespType = mk_alu_resp(16)
  dut = AluVRTL( ReqType, RespType )
  dut.elaborate()
  dut = ImportPass()( dut )
  dut.apply( SimulationPass )

  print()
  print( dut.line_trace() )
  # Write a message
  dut.enq.en = b1(1)
  dut.enq.msg = ReqType( b16(0x0003), b16(0x0002), ops['add'] )
  dut.tick()
  assert dut.deq.rdy
  dut.deq.en = b1(1)

  print( dut.line_trace() )

  # Read a message
  assert dut.deq.msg.result == b16(0x0005)

  # Note that we need to finalize the imported DUT here to avoid
  # interference with the hypothesis test
  dut.alu.finalize()

#-------------------------------------------------------------------------
# Hypothesis test
#-------------------------------------------------------------------------

@st.composite
def alu_req_strat( draw, nbits ):
  in1 = draw( pst.bits(nbits), label="in1" )
  in2 = draw( pst.bits(nbits), label="in2" )
  op  = draw( pst.bits(3),     label='op'  )
  ReqType = mk_alu_req( nbits )
  return ReqType( in1, in2, op )

_cached_alu = None
_p_width = None

def import_alu( p_width ):
  """Import ALU with caching.
  
  We plan to cache arbitrary Verilog module inside the import pass so this will
  no longer be necessary.
  """
  global _cached_alu, _p_width
  if not _cached_alu or _p_width != p_width:
    ReqType, RespType = mk_alu_req(p_width), mk_alu_resp(p_width)
    dut = AluVRTL( ReqType, RespType )
    dut.elaborate()
    dut = ImportPass()( dut )
    dut.apply( SimulationPass )
    _cached_alu, _p_width = dut, p_width
  return _cached_alu

@given( alu_req_strat(32) )
@settings( deadline = None )
def test_hypothesis_32( req ):
  alu = import_alu(32)
  # Uncomment to see the generated request message
  # print(req.__dict__)
  ref = AluFL(mk_alu_resp(32))
  ref.elaborate()
  ref.apply( SimulationPass )

  # Feed request to DUT
  alu.enq.en = b1(1)
  alu.enq.msg = deepcopy(req)
  alu.tick()

  # Feed request to reference model
  ref.enq( req )
  result = ref.deq()

  # Check if results are the same
  assert alu.deq.rdy == b1(1)
  assert alu.deq.msg == result

  # We do not finalize the imported model because it will be reused by
  # the next hypothesis test run.

#-------------------------------------------------------------------------
# PyH2 test
#-------------------------------------------------------------------------

# @hypothesis.settings( deadline=None )
# @hypothesis.given( nbits = st.integers(1, 16) )
# def test_pyh2( nbits ):
  # print( "nbits = {}".format( nbits ) )
  # Req  = mk_alu_req( nbits )
  # Resp = mk_alu_resp( nbits )
  # run_pyh2( AluVRTL( Req, Resp ), AluFL( Resp ), arg_strat_mapping={
    # 'enq.msg' : alu_req_strat( nbits )
  # } )
