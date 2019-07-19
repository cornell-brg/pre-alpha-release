"""
==========================================================================
bp_cce_test.py
==========================================================================
Test cases for black parrot memory system.

Author : Yanghui Ou, Peitian Pan
  Date : July 18, 2019
"""
import hypothesis
from hypothesis import strategies as st

from pymtl3 import *
from pymtl3.datatypes import strategies as pst
from pymtl3.passes import GenDAGPass, OpenLoopCLPass as AutoTickSimPass
from pymtl3.passes.sverilog import ImportPass
from pymtl3.stdlib.test.pyh2.stateful_bp import run_pyh2_bp

from .bp_cce import WrappedBox
from .BpMemMsg import BpMsg, BpMemMsgType
from .BpMemCLWrapper import BpMemCLWrapper
from .BpRefMemFL import BpRefMemFL

#-------------------------------------------------------------------------
# Ad-hoc test
#-------------------------------------------------------------------------

def test_bp_mem_adhoc():
  mem = WrappedBox( BpMsg, BpMsg )
  mem.elaborate()
  mem = ImportPass()( mem )
  mem.elaborate()
  mem.apply( SimulationPass )

  # Reset and freeze
  mem.bp_init()
  assert mem.req.rdy
  mem.req.msg = BpMsg( BpMemMsgType.ST8, b39(0x1000), b64(0xfaceb00c) ) 
  mem.req.en  = b1(1)
  print( mem.line_trace() )
  mem.tick()
  mem.req.en  = b1(0)
  while not mem.resp.rdy:
    print( mem.line_trace() )
    mem.tick()
  assert mem.resp.rdy
  mem.resp.en = b1(1)
  print( "resp:", str(mem.resp.msg) )
  mem.tick()
  mem.resp.en = b1(0)
  mem.tick()
  mem.req.msg = BpMsg( BpMemMsgType.LD8, b39(0x1000), b64(0xfaceb00c) ) 
  mem.req.en  = b1(1)
  print( mem.line_trace() )
  mem.tick()
  mem.req.en = b1(0)
  while not mem.resp.rdy:
    print( mem.line_trace() )
    mem.tick()
  assert mem.resp.rdy
  mem.resp.en = b1(1)
  print( "resp:", str(mem.resp.msg) )
  assert mem.resp.msg.data == 0xfaceb00c
  mem.tick()
  mem.resp.en = b1(0)
  mem.tick()
  mem.tick()
  mem.tick()
  mem.tick()

#-------------------------------------------------------------------------
# Auto-tick test
#-------------------------------------------------------------------------

def test_auto_tick():
  # Create an auto-tick simulator
  mem = BpMemCLWrapper( WrappedBox( BpMsg, BpMsg ) )
  mem.elaborate()
  mem = ImportPass()( mem )
  mem.apply( GenDAGPass() )
  mem.apply( AutoTickSimPass() )
  mem.lock_in_simulation()
  mem.bp_init()
  
  # Send a store request
  assert mem.req.rdy()
  mem.req( BpMsg( BpMemMsgType.ST8, b39(0x1000), b64(0xdeadface) ) )

  # Send a back to back load request
  assert mem.req.rdy()
  mem.req( BpMsg( BpMemMsgType.LD8, b39(0x1000), b64(0)          ) )
  
  # Get store response
  while not mem.resp.rdy(): pass
  assert mem.resp.rdy()
  mem.resp()
  
  # Check load response
  while not mem.resp.rdy(): pass
  assert mem.resp.rdy()
  assert mem.resp().data == 0xdeadface

#-------------------------------------------------------------------------
# Auto-tick test
#-------------------------------------------------------------------------

@st.composite
def bp_mem_msg_strat( draw ):
  type_ = draw( st.sampled_from([ BpMsgType.ST8, BpMsgType.LD8 ]) )
  addr  = draw( st.integers(100, 120) )
  addr  = b39( addr << 2 )
  data  = draw( st.sampled_from([ b64(0xfaceb00c), b64(0xdeadface), b64(0xdeafbabe) ]) )
  return BpMemMsg( type_, addr, data )

def test_pyh2():
  run_pyh2_bp(
    WrappedBox( BpMsg, BpMsg ),
    BpRefMemFL(),
    BpMemCLWrapper,
    { 'req.msg' : bp_mem_msg_strat() },
  )
