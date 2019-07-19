"""
==========================================================================
bp_cce_test.py
==========================================================================
Test cases for black parrot memory system.

Author : Yanghui Ou, Peitian Pan
  Date : July 18, 2019
"""

from pymtl3 import *
from pymtl3.passes import GenDAGPass, OpenLoopCLPass as AutoTickSimPass
from pymtl3.passes.sverilog import ImportPass

from .bp_cce import WrappedBox
from .BpMemCLWrapper import BpMemCLWrapper


class BpMemMsgType( object ):
  # TODO: add other types here
  LD8  = b4(0b0011)
  ST8  = b4(0b1011)

BpMsg = mk_bit_struct( "BpMemMsg",[
  ( 'type_', Bits4  ),
  ( 'addr',  Bits39 ),
  ( 'data',  Bits64 ),
])

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

