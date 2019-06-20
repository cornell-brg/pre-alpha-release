/**
  *
  * testbench.v
  *
  */
  
`include "bsg_noc_links.vh"

module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(cfg_p)
   , localparam cce_mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp)

   // Number of elements in the fake BlackParrot memory
   , parameter clock_period_in_ps_p = 1000
   , parameter prog_name_p = "prog.mem"
   , parameter dram_cfg_p  = "dram_ch.ini"
   , parameter dram_sys_cfg_p = "dram_sys.ini"
   , parameter dram_capacity_p = 16384

   , localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

   // Trace replay parameters
   , parameter calc_trace_p                = 0
   , parameter cce_trace_p                 = 0
   , parameter trace_ring_width_p          = "inv"
   , parameter trace_rom_addr_width_p      = "inv"
   , localparam trace_rom_data_width_lp    = trace_ring_width_p + 4
   
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)
   
   , localparam noc_x_cord_width_lp = `BSG_SAFE_CLOG2(num_core_p+2)
   , localparam noc_y_cord_width_lp = 1
   
   // FIXME: not needed when IO complex is used
   , localparam link_width_lp = noc_width_p+2
   )
  (input clk_i
   , input reset_i
   );

// Wormhole router coordinate IDs
// FIXME: hardcoded router coordinates, should be replaced with bsg_tag_clients
localparam clint_x_cord_lp = `BSG_CDIV(num_core_p, 2);
localparam clint_y_cord_lp = 0;

localparam dram_x_cord_lp  = num_core_p+1;
localparam dram_y_cord_lp  = 0;
   
`declare_bsg_ready_and_link_sif_s(noc_width_p, bsg_ready_and_link_sif_s);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp)     

bsg_ready_and_link_sif_s [1:0] ct_link_li, ct_link_lo;

bsg_ready_and_link_sif_s cmd_link_li, cmd_link_lo;
bsg_ready_and_link_sif_s resp_link_li, resp_link_lo;
bsg_ready_and_link_sif_s mem_link_li, mem_link_lo;
bsg_ready_and_link_sif_s cfg_link_li, cfg_link_lo;

assign ct_link_li = {cmd_link_lo, resp_link_lo};
assign {cmd_link_li, resp_link_li} = ct_link_lo;

// Fix bug
assign mem_link_li.v = cmd_link_li.v;
assign mem_link_li.data = cmd_link_li.data;
assign mem_link_li.ready_and_rev = resp_link_li.ready_and_rev;

assign cfg_link_li.v = resp_link_li.v;
assign cfg_link_li.data = resp_link_li.data;
assign cfg_link_li.ready_and_rev = cmd_link_li.ready_and_rev;

assign resp_link_lo.v = mem_link_lo.v;
assign resp_link_lo.data = mem_link_lo.data;
assign resp_link_lo.ready_and_rev = cfg_link_lo.ready_and_rev;

assign cmd_link_lo.v = cfg_link_lo.v;
assign cmd_link_lo.data = cfg_link_lo.data;
assign cmd_link_lo.ready_and_rev = mem_link_lo.ready_and_rev;

   
logic [link_width_lp-1:0] multi_data_li, multi_data_lo;
logic multi_v_li, multi_v_lo;
logic multi_yumi_lo, multi_yumi_li;

logic [1:0] ct_fifo_valid_lo, ct_fifo_yumi_li;
logic [1:0] ct_fifo_valid_li, ct_fifo_yumi_lo;
logic [1:0][noc_width_p-1:0] ct_fifo_data_lo, ct_fifo_data_li;
     
bp_mem_cce_resp_s      mem_resp_li;
logic                  mem_resp_v_li, mem_resp_ready_lo;
bp_mem_cce_data_resp_s mem_data_resp_li;
logic                  mem_data_resp_v_li, mem_data_resp_ready_lo;
bp_cce_mem_cmd_s       mem_cmd_lo;
logic                  mem_cmd_v_lo, mem_cmd_yumi_li;
bp_cce_mem_data_cmd_s  mem_data_cmd_lo;
logic                  mem_data_cmd_v_lo, mem_data_cmd_yumi_li;

bp_mem_cce_resp_s      dram_resp_lo;
logic                  dram_resp_v_lo, dram_resp_ready_li;
bp_mem_cce_data_resp_s dram_data_resp_lo;
logic                  dram_data_resp_v_lo, dram_data_resp_ready_li;
bp_cce_mem_cmd_s       dram_cmd_li;
logic                  dram_cmd_v_li, dram_cmd_yumi_lo;
bp_cce_mem_data_cmd_s  dram_data_cmd_li;
logic                  dram_data_cmd_v_li, dram_data_cmd_yumi_lo;

bp_mem_cce_resp_s      host_resp_lo;
logic                  host_resp_v_lo, host_resp_ready_li;
bp_mem_cce_data_resp_s host_data_resp_lo;
logic                  host_data_resp_v_lo, host_data_resp_ready_li;
bp_cce_mem_cmd_s       host_cmd_li;
logic                  host_cmd_v_li, host_cmd_yumi_lo;
bp_cce_mem_data_cmd_s  host_data_cmd_li;
logic                  host_data_cmd_v_li, host_data_cmd_yumi_lo;

bp_cce_mem_data_cmd_s  cfg_data_cmd_lo;
logic                  cfg_data_cmd_v_lo, cfg_data_cmd_yumi_li;
bp_mem_cce_resp_s      cfg_resp_li;
logic                  cfg_resp_v_li, cfg_resp_ready_lo;

genvar i;

// Chip
wrapper
 #(.cfg_p(cfg_p)
   ,.calc_trace_p(calc_trace_p)
   ,.cce_trace_p(cce_trace_p)
   )
 wrapper
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.multi_data_i(multi_data_li)
   ,.multi_v_i(multi_v_li)
   ,.multi_yumi_o(multi_yumi_lo)

   ,.multi_data_o(multi_data_lo)
   ,.multi_v_o(multi_v_lo)
   ,.multi_yumi_i(multi_yumi_li)
   );

  bsg_channel_tunnel 
 #(.width_p                (noc_width_p)
  ,.num_in_p               (2)
  ,.remote_credits_p       (ct_remote_credits_p)
  ,.use_pseudo_large_fifo_p(1)
  ,.lg_credit_decimation_p (ct_lg_credit_decimation_p)
  )
  ct
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)

  // incoming multiplexed data
  ,.multi_data_i(multi_data_lo)
  ,.multi_v_i   (multi_v_lo)
  ,.multi_yumi_o(multi_yumi_li)

  // outgoing multiplexed data
  ,.multi_data_o(multi_data_li)
  ,.multi_v_o   (multi_v_li)
  ,.multi_yumi_i(multi_yumi_lo)

  // incoming demultiplexed data
  ,.data_i(ct_fifo_data_lo)
  ,.v_i   (ct_fifo_valid_lo)
  ,.yumi_o(ct_fifo_yumi_li)

  // outgoing demultiplexed data
  ,.data_o(ct_fifo_data_li)
  ,.v_o   (ct_fifo_valid_li)
  ,.yumi_i(ct_fifo_yumi_lo)
  );
  
  for (i = 0; i < 2; i++) 
  begin: rof0
    // Must add a fifo here, convert yumi_o to ready_o
    bsg_two_fifo
   #(.width_p(noc_width_p)
    ) ct_fifo
    (.clk_i  (clk_i  )
    ,.reset_i(reset_i)
    ,.ready_o(ct_link_lo[i].ready_and_rev)
    ,.data_i (ct_link_li[i].data         )
    ,.v_i    (ct_link_li[i].v            )
    ,.v_o    (ct_fifo_valid_lo[i])
    ,.data_o (ct_fifo_data_lo [i])
    ,.yumi_i (ct_fifo_yumi_li [i])
    );
    assign ct_link_lo     [i].v    = ct_fifo_valid_li[i];
    assign ct_link_lo     [i].data = ct_fifo_data_li [i];
    assign ct_fifo_yumi_lo[i]      = ct_link_lo[i].v & ct_link_li[i].ready_and_rev;
  end

bind bp_be_top
  bp_be_nonsynth_tracer
   #(.cfg_p(cfg_p))
   tracer
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mhartid_i(be_calculator.proc_cfg.core_id)

     ,.issue_pkt_i(be_calculator.issue_pkt)
     ,.issue_pkt_v_i(be_calculator.issue_pkt_v_i)

     ,.fe_nop_v_i(be_calculator.fe_nop_v)
     ,.be_nop_v_i(be_calculator.be_nop_v)
     ,.me_nop_v_i(be_calculator.me_nop_v)
     ,.dispatch_pkt_i(be_calculator.dispatch_pkt)

     ,.ex1_br_tgt_i(be_calculator.calc_status.int1_br_tgt)
     ,.ex1_btaken_i(be_calculator.calc_status.int1_btaken)
     ,.iwb_result_i(be_calculator.comp_stage_n[3])
     ,.fwb_result_i(be_calculator.comp_stage_n[4])

     ,.cmt_trace_exc_i(be_calculator.exc_stage_n[1+:5])

     ,.trap_v_i(be_mem.csr.trap_v_o)
     ,.mtvec_i(be_mem.csr.mtvec_n)
     ,.mtval_i(be_mem.csr.mtval_n)
     ,.ret_v_i(be_mem.csr.ret_v_o)
     ,.mepc_i(be_mem.csr.mepc_n)
     ,.mcause_i(be_mem.csr.mcause_n)

     ,.priv_mode_i(be_mem.csr.priv_mode_n)
     ,.mpp_i(be_mem.csr.mstatus_n.mpp)
     );

bind bp_be_top
  bp_be_nonsynth_perf
   #(.cfg_p(cfg_p))
   perf
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mhartid_i(be_calculator.proc_cfg.core_id)

     ,.fe_nop_i(be_calculator.exc_stage_r[2].fe_nop_v)
     ,.be_nop_i(be_calculator.exc_stage_r[2].be_nop_v)
     ,.me_nop_i(be_calculator.exc_stage_r[2].me_nop_v)
     ,.poison_i(be_calculator.exc_stage_r[2].poison_v)
     ,.roll_i(be_calculator.exc_stage_r[2].roll_v)
     ,.instr_cmt_i(be_calculator.calc_status.instr_cmt_v)

     ,.program_finish_i(testbench.program_finish)
     );

// DRAM + link 
bp_me_cce_to_wormhole_link_client
 #(.cfg_p(cfg_p)
  ,.x_cord_width_p(noc_x_cord_width_lp)
  ,.y_cord_width_p(noc_y_cord_width_lp)
  )
  client_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)
   
  ,.mem_cmd_o(mem_cmd_lo)
  ,.mem_cmd_v_o(mem_cmd_v_lo)
  ,.mem_cmd_yumi_i(mem_cmd_yumi_li)

  ,.mem_data_cmd_o(mem_data_cmd_lo)
  ,.mem_data_cmd_v_o(mem_data_cmd_v_lo)
  ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_li)

  ,.mem_resp_i(mem_resp_li)
  ,.mem_resp_v_i(mem_resp_v_li)
  ,.mem_resp_ready_o(mem_resp_ready_lo)

  ,.mem_data_resp_i(mem_data_resp_li)
  ,.mem_data_resp_v_i(mem_data_resp_v_li)
  ,.mem_data_resp_ready_o(mem_data_resp_ready_lo)
     
  ,.my_x_i(noc_x_cord_width_lp'(dram_x_cord_lp))
  ,.my_y_i(noc_y_cord_width_lp'(dram_y_cord_lp))
     
  ,.link_i(mem_link_li)
  ,.link_o(mem_link_lo)
  );

bp_mem_dramsim2
#(.mem_id_p(0)
   ,.clock_period_in_ps_p(clock_period_in_ps_p)
   ,.prog_name_p(prog_name_p)
   ,.dram_cfg_p(dram_cfg_p)
   ,.dram_sys_cfg_p(dram_sys_cfg_p)
   ,.dram_capacity_p(dram_capacity_p)
   ,.num_lce_p(num_lce_p)
   ,.num_cce_p(num_cce_p)
   ,.paddr_width_p(paddr_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.block_size_in_bytes_p(cce_block_width_p/8)
   ,.lce_sets_p(lce_sets_p)
   ,.lce_req_data_width_p(dword_width_p)
  )
mem
 (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i(dram_cmd_li)
  ,.mem_cmd_v_i(dram_cmd_v_li)
  ,.mem_cmd_yumi_o(dram_cmd_yumi_lo)

  ,.mem_data_cmd_i(dram_data_cmd_li)
  ,.mem_data_cmd_v_i(dram_data_cmd_v_li)
  ,.mem_data_cmd_yumi_o(dram_data_cmd_yumi_lo)

  ,.mem_resp_o(dram_resp_lo)
  ,.mem_resp_v_o(dram_resp_v_lo)
  ,.mem_resp_ready_i(dram_resp_ready_li)

  ,.mem_data_resp_o(dram_data_resp_lo)
  ,.mem_data_resp_v_o(dram_data_resp_v_lo)
  ,.mem_data_resp_ready_i(dram_data_resp_ready_li)
  );


assign host_cmd_yumi_o     = '0;
assign host_data_resp_o    = '0;
assign host_data_resp_v_lo = '0;
logic program_finish;
bp_nonsynth_host
 #(.cfg_p(cfg_p))
 host_mmio
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_data_cmd_i(host_data_cmd_li)
   ,.mem_data_cmd_v_i(host_data_cmd_v_li)
   ,.mem_data_cmd_yumi_o(host_data_cmd_yumi_lo)

   ,.mem_resp_o(host_resp_lo)
   ,.mem_resp_v_o(host_resp_v_lo)
   ,.mem_resp_ready_i(host_resp_ready_li)

   ,.program_finish_o(program_finish)
   );

// MMIO arbitration
wire host_data_cmd_not_dram = mem_data_cmd_v_lo & (mem_data_cmd_lo.addr < dram_base_addr_gp);
wire host_cmd_not_dram      = mem_cmd_v_lo & (mem_cmd_lo.addr < dram_base_addr_gp);

assign host_cmd_li          = mem_cmd_lo;
assign host_cmd_v_li        = mem_cmd_v_lo & host_cmd_not_dram;
assign dram_cmd_li          = mem_cmd_lo;
assign dram_cmd_v_li        = mem_cmd_v_lo & ~host_cmd_not_dram;
assign mem_cmd_yumi_li      = host_cmd_not_dram 
                              ? host_cmd_yumi_lo 
                              : dram_cmd_yumi_lo;

assign host_data_cmd_li     = mem_data_cmd_lo;
assign host_data_cmd_v_li   = mem_data_cmd_v_lo & host_data_cmd_not_dram;
assign dram_data_cmd_li     = mem_data_cmd_lo;
assign dram_data_cmd_v_li   = mem_data_cmd_v_lo & ~host_data_cmd_not_dram;
assign mem_data_cmd_yumi_li = host_data_cmd_not_dram 
                              ? host_data_cmd_yumi_lo 
                              : dram_data_cmd_yumi_lo;

assign mem_resp_li = host_resp_v_lo ? host_resp_lo : dram_resp_lo;
assign mem_resp_v_li = host_resp_v_lo | dram_resp_v_lo;
assign host_resp_ready_li = mem_resp_ready_lo;
assign dram_resp_ready_li = mem_resp_ready_lo;

assign mem_data_resp_li = host_data_resp_v_lo ? host_data_resp_lo : dram_data_resp_lo;
assign mem_data_resp_v_li = host_data_resp_v_lo | dram_data_resp_v_lo;
assign host_data_resp_ready_li = mem_data_resp_ready_lo;
assign dram_data_resp_ready_li = mem_data_resp_ready_lo;

// CFG loader + rom + link
bp_me_cce_to_wormhole_link_master
 #(.cfg_p(cfg_p)
  ,.x_cord_width_p(noc_x_cord_width_lp)
  ,.y_cord_width_p(noc_y_cord_width_lp)
  )
  master_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i('0)
  ,.mem_cmd_v_i('0)
  ,.mem_cmd_yumi_o()

  ,.mem_data_cmd_i(cfg_data_cmd_lo)
  ,.mem_data_cmd_v_i(cfg_data_cmd_v_lo)
  ,.mem_data_cmd_yumi_o(cfg_data_cmd_yumi_li)

  ,.mem_resp_o(cfg_resp_li)
  ,.mem_resp_v_o(cfg_resp_v_li)
  ,.mem_resp_ready_i(cfg_resp_ready_lo)

  ,.mem_data_resp_o()
  ,.mem_data_resp_v_o()
  ,.mem_data_resp_ready_i(1'b1)
  
  ,.my_x_i(noc_x_cord_width_lp'(dram_x_cord_lp))
  ,.my_y_i(noc_y_cord_width_lp'(dram_y_cord_lp))
  
  ,.mem_cmd_dest_x_i('0)
  ,.mem_cmd_dest_y_i('0)
  
  ,.mem_data_cmd_dest_x_i(noc_x_cord_width_lp'(clint_x_cord_lp))
  ,.mem_data_cmd_dest_y_i(noc_y_cord_width_lp'(clint_y_cord_lp))
  
  ,.link_i(cfg_link_li)
  ,.link_o(cfg_link_lo)
  );
  
logic reset_r;
bsg_dff_chain
 #(.width_p(1)
   ,.num_stages_p(10)
   )
 reset_pipe
  (.clk_i(clk_i)
   ,.data_i(reset_i)
   ,.data_o(reset_r)
   );

bp_cce_mmio_cfg_loader
  #(.cfg_p(cfg_p)
    ,.inst_width_p(`bp_cce_inst_width)
    ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
    ,.inst_ram_els_p(num_cce_instr_ram_els_p)
    ,.skip_ram_init_p('0)
  )
  cfg_loader
  (.clk_i(clk_i)
   ,.reset_i(reset_r)
   
   ,.mem_data_cmd_o(cfg_data_cmd_lo)
   ,.mem_data_cmd_v_o(cfg_data_cmd_v_lo)
   ,.mem_data_cmd_yumi_i(cfg_data_cmd_yumi_li)
   
   ,.mem_resp_i(cfg_resp_li)
   ,.mem_resp_v_i(cfg_resp_v_li)
   ,.mem_resp_ready_o(cfg_resp_ready_lo)
  );

endmodule : testbench

