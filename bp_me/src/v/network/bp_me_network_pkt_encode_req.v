/**
 *  Name:
 *    bp_me_network_pkt_encode_req.v
 *
 *  Description:
 *    It takes bp_lce_cce_req_s as a payload, parses, and forms it into a wormhole
 *    packet that goes into the adapter.
 *
 *    packet = {payload, length, y_cord, x_cord}
 *
 *  Notes:
 *    We could not send the data flit on a non-non-cacheable request.
 */


module bp_me_network_pkt_encode_req
  import bp_common_pkg::*;
  #(parameter num_lce_p="inv"
    , parameter num_cce_p="inv"
    , parameter lce_assoc_p="inv"
    , parameter paddr_width_p="inv"
    , parameter block_size_in_bits_p="inv"

    , parameter max_num_flit_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    
    , parameter dword_width_p=64

    , localparam lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p,num_lce_p,paddr_width_p,lce_assoc_p,dword_width_p)

    , localparam len_width_lp=`BSG_SAFE_CLOG2(max_num_flit_p)
    , localparam max_payload_width_lp=lce_cce_req_width_lp
    , localparam max_packet_width_lp=
      (x_cord_width_p+y_cord_width_p+len_width_lp+max_payload_width_lp)
    , localparam width_lp=
      (max_packet_width_lp/max_num_flit_p)+((max_packet_width_lp%max_num_flit_p) == 0 ? 0 : 1)

    , localparam req_len_lp =
      (max_packet_width_lp/width_lp)+(max_packet_width_lp%width_lp==0 ? 0 : 1)-1
  )
  (
    input [lce_cce_req_width_lp-1:0] payload_i
    , output logic [max_packet_width_lp-1:0] packet_o
  );


  `declare_bp_lce_cce_req_s(num_cce_p,num_lce_p,paddr_width_p,lce_assoc_p,dword_width_p);
  bp_lce_cce_req_s req;
  assign req = payload_i;

  logic [x_cord_width_p-1:0] x_cord;
  logic [y_cord_width_p-1:0] y_cord;
  logic [len_width_lp-1:0] length;

  always_comb begin
    y_cord = y_cord_width_p'(0);
    x_cord = x_cord_width_p'(req.dst_id << 1);

    length = req_len_lp;
  end

  assign packet_o = {req, length, y_cord, x_cord};

endmodule

