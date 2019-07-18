"""
==========================================================================
bp_cce_test.py
==========================================================================
Test cases for black parrot memory system.

Author : Yanghui Ou, Peitian Pan
  Date : July 18, 2019
"""

from pymtl3 import *

from .bp_cce import WrappedBox

class BpMemMsg( object ):
  # TODO: add other types here
  RD8  = b4(0b0011)
  LD8  = b4(0b1011)

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
  mem.reset()
  mem.tick()
  mem.tick()
  mem.tick()