"""
==========================================================================
bp_cce_test.py
==========================================================================
Test cases for black parrot memory system.

Author : Yanghui Ou, Peitian Pan
  Date : July 18, 2019
"""
from pymtl3 import *


class BpMemMsgType( object ):
  # TODO: add other types here
  LD8  = b4(0b0011)
  ST8  = b4(0b1011)

BpMsg = mk_bit_struct( "BpMemMsg",[
  ( 'type_', Bits4  ),
  ( 'addr',  Bits39 ),
  ( 'data',  Bits64 ),
])

