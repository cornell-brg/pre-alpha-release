"""
==========================================================================
BpMemCLWrapper
==========================================================================
Wrapper that wraps RTL model into CL.

Author : Yanghui Ou
  Date : July 19, 2019
"""
from __future__ import absolute_import, division, print_function

from pymtl3 import *


class BpMemCLWrapper( Component ):

  def __init__( s, rtl_model ):
    super( BpMemCLWrapper, s ).__init__()

    s.model_name = type( rtl_model ).__name__

  def construct( s, rtl_model ):

    s.freeze = InPort( Bits1 )
    s.req  = NonBlockingCalleeIfc()
    s.resp = NonBlockingCalleeIfc()

    s.model = rtl_model

    connect( s.freeze, s.model.freeze )
    connect( s.req,    s.model.req    )
    connect( s.resp,   s.model.resp   )

  def line_trace( s ):
    return s.model.line_trace()
  
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
