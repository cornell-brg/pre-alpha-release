/**
 *
 * bp_top.v
 *
 */
 
`include "bsg_noc_links.vh"

module bp_top
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   , localparam cce_mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

   // Used to enable trace replay outputs for testbench
   , parameter calc_trace_p = 0
   , parameter cce_trace_p  = 0

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1
   
   // Tile parameters
   , localparam num_tiles_lp = num_core_p
   , localparam num_routers_lp = num_tiles_lp+1
   
   // Other parameters
   , localparam lce_cce_req_network_width_lp = lce_cce_req_width_lp+x_cord_width_p+1
   , localparam lce_cce_resp_network_width_lp = lce_cce_resp_width_lp+x_cord_width_p+1
   , localparam cce_lce_cmd_network_width_lp = cce_lce_cmd_width_lp+x_cord_width_p+1

   , localparam lce_cce_data_resp_num_flits_lp = bp_data_resp_num_flit_gp
   , localparam lce_cce_data_resp_len_width_lp = `BSG_SAFE_CLOG2(lce_cce_data_resp_num_flits_lp)
   , localparam lce_cce_data_resp_packet_width_lp = 
       lce_cce_data_resp_width_lp+x_cord_width_p+y_cord_width_p+lce_cce_data_resp_len_width_lp
   , localparam lce_cce_data_resp_router_width_lp = 
       (lce_cce_data_resp_packet_width_lp/lce_cce_data_resp_num_flits_lp) 
       + ((lce_cce_data_resp_packet_width_lp%lce_cce_data_resp_num_flits_lp) == 0 ? 0 : 1)
   , localparam lce_cce_data_resp_payload_offset_lp = 
       (x_cord_width_p+y_cord_width_p+lce_cce_data_resp_len_width_lp)

   , localparam lce_data_cmd_num_flits_lp = bp_data_cmd_num_flit_gp
   , localparam lce_data_cmd_len_width_lp = `BSG_SAFE_CLOG2(lce_data_cmd_num_flits_lp)
   , localparam lce_data_cmd_packet_width_lp = 
       lce_data_cmd_width_lp+x_cord_width_p+y_cord_width_p+lce_data_cmd_len_width_lp
   , localparam lce_data_cmd_router_width_lp = 
       (lce_data_cmd_packet_width_lp/lce_data_cmd_num_flits_lp) 
       + ((lce_data_cmd_packet_width_lp%lce_data_cmd_num_flits_lp) == 0 ? 0 : 1)
   , localparam lce_data_cmd_payload_offset_lp = (x_cord_width_p+y_cord_width_p+lce_data_cmd_len_width_lp)
   
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)

   // Arbitrarily set, should be set based on PD constraints
   , localparam reset_pipe_depth_lp = 10

   // TODO: This is hardcoded, should be set based on topology
   , localparam int repeater_depth_lp [15:0] = '{0, 0, 0, 0
                                                ,2, 0, 0, 0
                                                ,2, 0, 0, 0
                                                ,2, 0, 0, 0
                                                }
   )
  (input                                                       clk_i
   , input                                                     reset_i

   // Config channel
   , input [num_core_p-1:0]                                    cfg_w_v_i
   , input [num_core_p-1:0][cfg_addr_width_p-1:0]              cfg_addr_i
   , input [num_core_p-1:0][cfg_data_width_p-1:0]              cfg_data_i

   // Interrupts
   , input [num_core_p-1:0]                                    timer_irq_i
   , input [num_core_p-1:0]                                    soft_irq_i
   , input [num_core_p-1:0]                                    external_irq_i

   // Memory side connection
   , input [num_core_p-1:0][noc_cord_width_p-1:0]                 tile_cord_i
   , input [noc_cord_width_p-1:0]                                 dram_cord_i
   , input [noc_cord_width_p-1:0]                                 clint_cord_i

   , input [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  cmd_link_i
   , output [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
   , output [num_core_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] resp_link_o

  );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)

logic [num_core_p:0][E:W][2+lce_cce_req_network_width_lp-1:0] lce_req_link_stitch_lo, lce_req_link_stitch_li;
logic [num_core_p:0][E:W][2+lce_cce_resp_network_width_lp-1:0] lce_resp_link_stitch_lo, lce_resp_link_stitch_li;
logic [num_core_p:0][E:W][2+lce_cce_data_resp_router_width_lp-1:0] lce_data_resp_link_stitch_lo, lce_data_resp_link_stitch_li;
logic [num_core_p:0][E:W][2+cce_lce_cmd_network_width_lp-1:0] lce_cmd_link_stitch_lo, lce_cmd_link_stitch_li;
logic [num_core_p:0][E:W][2+lce_data_cmd_router_width_lp-1:0] lce_data_cmd_link_stitch_lo, lce_data_cmd_link_stitch_li;

/************************* BP Tiles *************************/
assign lce_req_link_stitch_lo[0][W]                = '0;
assign lce_resp_link_stitch_lo[0][W]               = '0;
assign lce_data_resp_link_stitch_lo[0][W]          = '0;
assign lce_cmd_link_stitch_lo[0][W]                = '0;
assign lce_data_cmd_link_stitch_lo[0][W]           = '0;

assign lce_req_link_stitch_li[num_core_p][W]       = '0;
assign lce_resp_link_stitch_li[num_core_p][W]      = '0;
assign lce_data_resp_link_stitch_li[num_core_p][W] = '0;
assign lce_cmd_link_stitch_li[num_core_p][W]       = '0;
assign lce_data_cmd_link_stitch_li[num_core_p][W]  = '0;

for(genvar i = 0; i < num_core_p; i++) 
  begin : rof1
    localparam core_id   = i;
    localparam cce_id    = i;
    localparam icache_id = (i * 2 + 0);
    localparam dcache_id = (i * 2 + 1);

    localparam core_id_width_lp = `BSG_SAFE_CLOG2(num_core_p);
    localparam cce_id_width_lp  = `BSG_SAFE_CLOG2(num_cce_p);
    localparam lce_id_width_lp  = `BSG_SAFE_CLOG2(num_lce_p);

    bp_proc_cfg_s proc_cfg;
    assign proc_cfg.core_id   = core_id[0+:core_id_width_lp];
    assign proc_cfg.cce_id    = cce_id[0+:cce_id_width_lp];
    assign proc_cfg.icache_id = icache_id[0+:lce_id_width_lp];
    assign proc_cfg.dcache_id = dcache_id[0+:lce_id_width_lp];

    bsg_noc_repeater_node
     #(.width_p(lce_cce_req_network_width_lp)
       ,.num_nodes_p(repeater_depth_lp[i])
       )
     lce_req_repeater
      (.clk_i(clk_i)
       ,.side_A_reset_i(reset_i)

       ,.side_A_links_i(lce_req_link_stitch_li[i][E])
       ,.side_A_links_o(lce_req_link_stitch_lo[i][E])

       ,.side_B_links_i(lce_req_link_stitch_li[i+1][W])
       ,.side_B_links_o(lce_req_link_stitch_lo[i+1][W])
       );

    bsg_noc_repeater_node
     #(.width_p(cce_lce_cmd_network_width_lp)
       ,.num_nodes_p(repeater_depth_lp[i])
       )
     lce_cmd_repeater
      (.clk_i(clk_i)
       ,.side_A_reset_i(reset_i)

       ,.side_A_links_i(lce_cmd_link_stitch_li[i][E])
       ,.side_A_links_o(lce_cmd_link_stitch_lo[i][E])

       ,.side_B_links_i(lce_cmd_link_stitch_li[i+1][W])
       ,.side_B_links_o(lce_cmd_link_stitch_lo[i+1][W])
       );

    bsg_noc_repeater_node
     #(.width_p(lce_data_cmd_router_width_lp)
       ,.num_nodes_p(repeater_depth_lp[i])
       )
     lce_data_cmd_repeater
      (.clk_i(clk_i)
       ,.side_A_reset_i(reset_i)

       ,.side_A_links_i(lce_data_cmd_link_stitch_li[i][E])
       ,.side_A_links_o(lce_data_cmd_link_stitch_lo[i][E])

       ,.side_B_links_i(lce_data_cmd_link_stitch_li[i+1][W])
       ,.side_B_links_o(lce_data_cmd_link_stitch_lo[i+1][W])
       );

    bsg_noc_repeater_node
     #(.width_p(lce_cce_resp_network_width_lp)
       ,.num_nodes_p(repeater_depth_lp[i])
       )
     lce_resp_repeater
      (.clk_i(clk_i)
       ,.side_A_reset_i(reset_i)

       ,.side_A_links_i(lce_resp_link_stitch_li[i][E])
       ,.side_A_links_o(lce_resp_link_stitch_lo[i][E])

       ,.side_B_links_i(lce_resp_link_stitch_li[i+1][W])
       ,.side_B_links_o(lce_resp_link_stitch_lo[i+1][W])
       );

    bsg_noc_repeater_node
     #(.width_p(lce_cce_data_resp_router_width_lp)
       ,.num_nodes_p(repeater_depth_lp[i])
       )
     lce_data_resp_repeater
      (.clk_i(clk_i)
       ,.side_A_reset_i(reset_i)

       ,.side_A_links_i(lce_data_resp_link_stitch_li[i][E])
       ,.side_A_links_o(lce_data_resp_link_stitch_lo[i][E])

       ,.side_B_links_i(lce_data_resp_link_stitch_li[i+1][W])
       ,.side_B_links_o(lce_data_resp_link_stitch_lo[i+1][W])
       );

    bp_tile
     #(.cfg_p(cfg_p)
       ,.calc_trace_p(calc_trace_p)
       ,.cce_trace_p(cce_trace_p)
       )
     tile
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.proc_cfg_i(proc_cfg)

       ,.my_x_i(x_cord_width_p'(i))
       ,.my_y_i(y_cord_width_p'(0))

       ,.cfg_w_v_i(cfg_w_v_i[i])
       ,.cfg_addr_i(cfg_addr_i[i])
       ,.cfg_data_i(cfg_data_i[i])

       // Router inputs
       ,.lce_req_link_i(lce_req_link_stitch_lo[i])
       ,.lce_resp_link_i(lce_resp_link_stitch_lo[i])
       ,.lce_data_resp_link_i(lce_data_resp_link_stitch_lo[i])
       ,.lce_cmd_link_i(lce_cmd_link_stitch_lo[i])
       ,.lce_data_cmd_link_i(lce_data_cmd_link_stitch_lo[i])

       // Router outputs
       ,.lce_req_link_o(lce_req_link_stitch_li[i])
       ,.lce_resp_link_o(lce_resp_link_stitch_li[i])
       ,.lce_data_resp_link_o(lce_data_resp_link_stitch_li[i])
       ,.lce_cmd_link_o(lce_cmd_link_stitch_li[i])
       ,.lce_data_cmd_link_o(lce_data_cmd_link_stitch_li[i])

       // CCE-MEM IF
       ,.my_cord_i(tile_cord_i[i])
       ,.dram_cord_i(dram_cord_i)
       ,.clint_cord_i(clint_cord_i)

       ,.cmd_link_i(cmd_link_i[i])
       ,.cmd_link_o(cmd_link_o[i])
       ,.resp_link_i(resp_link_i[i])
       ,.resp_link_o(resp_link_o[i])

       ,.timer_int_i(timer_irq_i[i])
       ,.software_int_i(soft_irq_i[i])
       ,.external_int_i(external_irq_i[i])
       );
  end

endmodule : bp_top

