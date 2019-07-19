"""
==========================================================================
BpRefMemFL
==========================================================================
Reference model for BP memory.

Author : Yanghui Ou
  Date : July 19, 2019
"""
from __future__ import absolute_import, division, print_function

from pymtl3 import *
from pymtl3.stdlib.fl.MemoryFL import MemoryFL
from pymtl3.stdlib.cl.queues import BypassQueueCL 
from pymtl3.stdlib.ifcs import MemMsgType, mk_mem_msg

from .bp_cce_test import BpMemMsg, BpMemMsgType


class BpRefMemCL( Component ):

  def construct( s, qsize=1, mem_nbytes=64*1024 ):

    s.mem = MemoryFL( mem_nbytes=mem_nbytes )
    s.resp_q = BypassQueueCL( num_entries=qsize )

    # Bind the constraints to top level method just to be safe.
    s.add_constraints(
      M( s.req  ) == M( s.resp_q.enq ),
      M( s.resp ) == M( s.resp_q.deq ),
    )

  @non_blocking( lambda s: s.resp_q.enq.rdy() )
  def req( s, msg ):
    if msg.type_ == BpMemMsgType.LD8:
      data = s.mem.read( b39(msg.addr), nbytes=8 )
      resp = BpMemMsg( BpMemMsgType.LD8, b39(0), b64(data) )
      s.resp_q.enq( resp )
    elif msg.type_ == BpMemMsgType.ST8:
      s.mem.write( b39(msg.addr), b64(msg.data), nbytes=8 )
      resp = BpMemMsg( BpMemMsgType.LD8, b39(0), b64(data) )
      s.resp_q.enq( resp )
    else:
      raise AssertionError("Unsupported msg type!")

  @non_blocking( lambda s: s.resp_q.deq.rdy() )
  def resp( s ):
    msg = s.resp_q.deq()

  def line_trace( s ):
    return "{}(){}".format( s.req, s.resp )
  
  def bp_init( s ):
    s.reset  = b1(1)
    s.tick()
    s.reset = b1(0)
    s.tick()
