/**
 *
 * Name:
 *   bp_cce_reg.v
 *
 * Description:
 *
 */

module bp_cce_reg
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_lce_p                     = "inv"
    , parameter num_cce_p                   = "inv"
    , parameter paddr_width_p                = "inv"
    , parameter lce_assoc_p                 = "inv"
    , parameter lce_sets_p                  = "inv"
    , parameter block_size_in_bytes_p       = "inv"
    , parameter lce_req_data_width_p        = "inv"

    // Derived parameters
    , localparam lg_num_lce_lp              = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp              = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam block_size_in_bits_lp      = (block_size_in_bytes_p*8)
    , localparam lg_block_size_in_bytes_lp  = `BSG_SAFE_CLOG2(block_size_in_bytes_p)
    , localparam lg_lce_assoc_lp            = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp             = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam tag_width_lp               =
      (paddr_width_p-lg_lce_sets_lp-lg_block_size_in_bytes_lp)
    , localparam entry_width_lp             = (tag_width_lp+`bp_cce_coh_bits)
    , localparam tag_set_width_lp           = (entry_width_lp*lce_assoc_p)

    , localparam bp_lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p)
    , localparam bp_lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam bp_lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, block_size_in_bits_lp)
    , localparam bp_mem_cce_resp_width_lp=
      `bp_mem_cce_resp_width(paddr_width_p, num_lce_p, lce_assoc_p)
    , localparam bp_mem_cce_data_resp_width_lp=
      `bp_mem_cce_data_resp_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)
  )
  (input                                                                   clk_i
   , input                                                                 reset_i

   , input bp_cce_inst_decoded_s                                           decoded_inst_i

   , input [bp_lce_cce_req_width_lp-1:0]                                   lce_req_i
   , input [bp_lce_cce_data_resp_width_lp-1:0]                             lce_data_resp_i
   , input [bp_lce_cce_resp_width_lp-1:0]                                  lce_resp_i

   , input [bp_mem_cce_resp_width_lp-1:0]                                  mem_resp_i
   , input [bp_mem_cce_data_resp_width_lp-1:0]                             mem_data_resp_i

   , input [`bp_cce_inst_gpr_width-1:0]                                    alu_res_i
   , input [`bp_cce_inst_gpr_width-1:0]                                    mov_src_i

   , input                                                                 dir_pending_o_i
   , input                                                                 dir_pending_v_o_i

   , input                                                                 dir_sharers_v_i
   , input [num_lce_p-1:0]                                                 dir_sharers_hits_i
   , input [num_lce_p-1:0][lg_lce_assoc_lp-1:0]                            dir_sharers_ways_i
   , input [num_lce_p-1:0][`bp_cce_coh_bits-1:0]                           dir_sharers_coh_states_i

   , input                                                                 dir_lru_v_i
   , input                                                                 dir_lru_cached_excl_i
   , input [tag_width_lp-1:0]                                              dir_lru_tag_i

   , input [lg_lce_assoc_lp-1:0]                                           gad_req_addr_way_i
   , input [lg_num_lce_lp-1:0]                                             gad_transfer_lce_i
   , input [lg_lce_assoc_lp-1:0]                                           gad_transfer_lce_way_i
   , input                                                                 gad_transfer_flag_i
   , input                                                                 gad_replacement_flag_i
   , input                                                                 gad_upgrade_flag_i
   , input                                                                 gad_invalidate_flag_i
   , input                                                                 gad_exclusive_flag_i
   , input                                                                 gad_cached_flag_i

   // Register value outputs

   , output logic [lg_num_lce_lp-1:0]                                      req_lce_o
   , output logic [paddr_width_p-1:0]                                      req_addr_o
   , output logic [tag_width_lp-1:0]                                       req_tag_o


   , output logic [lg_lce_assoc_lp-1:0]                                    req_addr_way_o

   , output logic [lg_lce_assoc_lp-1:0]                                    lru_way_o
   , output logic [paddr_width_p-1:0]                                      lru_addr_o

   , output logic [lg_num_lce_lp-1:0]                                      transfer_lce_o
   , output logic [lg_lce_assoc_lp-1:0]                                    transfer_lce_way_o

   , output logic [`bp_cce_coh_bits-1:0]                                   next_coh_state_o

   , output logic [`bp_cce_inst_num_flags-1:0]                             flags_o

   , output logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0]   gpr_o

   , output logic [`bp_lce_cce_ack_type_width-1:0]                         ack_type_o

   , output logic [num_lce_p-1:0]                                          sharers_hits_o
   , output logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0]                     sharers_ways_o
   , output logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0]                    sharers_coh_states_o

   , output logic [`bp_lce_cce_nc_req_size_width-1:0]                      nc_req_size_o
   , output logic [lce_req_data_width_p-1:0]                               nc_data_o

   , output logic                                                          lru_cached_excl_o
  );

  wire unused = dir_pending_v_o_i;

  // Define structure variables for input queues
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, block_size_in_bits_lp);


  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p);

  bp_lce_cce_req_s lce_req_s_i;
  bp_lce_cce_resp_s lce_resp_s_i;
  bp_lce_cce_data_resp_s lce_data_resp_s_i;
  bp_mem_cce_resp_s mem_resp_s_i;
  bp_mem_cce_data_resp_s mem_data_resp_s_i;

  // assign input and output queues to/from structure variables
  always_comb
  begin
    lce_req_s_i = lce_req_i;
    lce_resp_s_i = lce_resp_i;
    lce_data_resp_s_i = lce_data_resp_i;
    mem_resp_s_i = mem_resp_i;
    mem_data_resp_s_i = mem_data_resp_i;
  end

  // Registers

  logic [lg_num_lce_lp-1:0] req_lce_r, req_lce_n;
  logic [paddr_width_p-1:0] req_addr_r, req_addr_n;
  logic [lg_lce_assoc_lp-1:0] req_addr_way_r, req_addr_way_n;

  logic [lg_lce_assoc_lp-1:0] lru_way_r, lru_way_n;
  logic [paddr_width_p-1:0] lru_addr_r, lru_addr_n;

  logic [lg_num_lce_lp-1:0] transfer_lce_r, transfer_lce_n;
  logic [lg_lce_assoc_lp-1:0] transfer_lce_way_r, transfer_lce_way_n;

  logic [`bp_cce_coh_bits-1:0] next_coh_state_r, next_coh_state_n;

  logic [`bp_cce_inst_num_flags-1:0] flags_r, flags_n;

  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_r, gpr_n;

  logic [`bp_lce_cce_ack_type_width-1:0] ack_type_r, ack_type_n;

  logic [num_lce_p-1:0] sharers_hits_r, sharers_hits_n;
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] sharers_ways_r, sharers_ways_n;
  logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0] sharers_coh_states_r, sharers_coh_states_n;

  logic [`bp_lce_cce_nc_req_size_width-1:0] nc_req_size_r, nc_req_size_n;
  logic [lce_req_data_width_p-1:0] nc_data_r, nc_data_n;

  logic lru_cached_excl_r, lru_cached_excl_n;

  always_comb
  begin
    req_lce_o = req_lce_r;
    req_addr_o = req_addr_r;
    req_tag_o = req_addr_r[paddr_width_p-1 -: tag_width_lp];
    req_addr_way_o = req_addr_way_r;

    lru_way_o = lru_way_r;
    lru_addr_o = lru_addr_r;

    transfer_lce_o = transfer_lce_r;
    transfer_lce_way_o = transfer_lce_way_r;

    next_coh_state_o = next_coh_state_r;

    flags_o = flags_r;

    gpr_o = gpr_r;

    ack_type_o = ack_type_r;

    // Bypass sharers information being written to registers when it is being written.
    // TODO: can eliminate if critical path-y
    // This allows a one cycle reduction of the directory read operation latency
    // If bypassing is removed, need to set busy signal in FINISH_READ in directory
    if (dir_sharers_v_i) begin
      sharers_hits_o = dir_sharers_hits_i;
      sharers_ways_o = dir_sharers_ways_i;
      sharers_coh_states_o = dir_sharers_coh_states_i;
    end else begin
      sharers_hits_o = sharers_hits_r;
      sharers_ways_o = sharers_ways_r;
      sharers_coh_states_o = sharers_coh_states_r;
    end

    nc_req_size_o = nc_req_size_r;
    nc_data_o = nc_data_r;

    lru_cached_excl_o = lru_cached_excl_r;
  end

  int j;
  always_comb
  begin
    // Request LCE, address, tag
    case (decoded_inst_i.req_sel)
      e_req_sel_lce_req: begin
        req_lce_n = lce_req_s_i.src_id;
        req_addr_n = lce_req_s_i.addr;
      end
      e_req_sel_mem_resp: begin
        req_lce_n = mem_resp_s_i.payload.lce_id;
        req_addr_n = mem_resp_s_i.payload.req_addr;
      end
      e_req_sel_mem_data_resp: begin
        req_lce_n = mem_data_resp_s_i.payload.lce_id;
        req_addr_n = mem_data_resp_s_i.addr;
      end
      e_req_sel_pending: begin // TODO: v2
        req_lce_n = '0;
        req_addr_n = '0;
      end
      default: begin
        req_lce_n = '0;
        req_addr_n = '0;
      end
    endcase

    // Request Address Way
    case (decoded_inst_i.req_addr_way_sel)
      e_req_addr_way_sel_logic: begin
        req_addr_way_n = gad_req_addr_way_i;
      end
      e_req_addr_way_sel_mem_resp: begin
        req_addr_way_n = mem_resp_s_i.payload.way_id;
      end
      e_req_addr_way_sel_mem_data_resp: begin
        req_addr_way_n = mem_data_resp_s_i.payload.way_id;
      end
      default: begin
        req_addr_way_n = '0;
      end
    endcase

    // LRU Way
    case (decoded_inst_i.lru_way_sel)
      e_lru_way_sel_lce_req: begin
        lru_way_n = lce_req_s_i.lru_way_id;
      end
      e_lru_way_sel_mem_resp: begin
        lru_way_n = mem_resp_s_i.payload.way_id;
      end
      e_lru_way_sel_mem_data_resp: begin
        lru_way_n = mem_data_resp_s_i.payload.way_id;
      end
      e_lru_way_sel_pending: begin
        lru_way_n = '0; // TODO: v2
      end
      default: begin
        lru_way_n = '0;
      end
    endcase

    // Transfer LCE and Transfer LCE Way
    case (decoded_inst_i.transfer_lce_sel)
      e_tr_lce_sel_logic: begin
        transfer_lce_n = gad_transfer_lce_i;
        transfer_lce_way_n = gad_transfer_lce_way_i;
      end
      e_tr_lce_sel_mem_resp: begin
        transfer_lce_n = mem_resp_s_i.payload.tr_lce_id;
        transfer_lce_way_n = mem_resp_s_i.payload.tr_way_id;
      end
      default: begin
        transfer_lce_n = '0;
        transfer_lce_way_n = '0;
      end
    endcase

    // ACK Type
    ack_type_n = lce_resp_s_i.msg_type;

    // Flags
    flags_n[e_flag_sel_pcf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];

    case (decoded_inst_i.rqf_sel)
      e_rqf_lce_req: begin
        flags_n[e_flag_sel_rqf] = lce_req_s_i.msg_type;
        flags_n[e_flag_sel_ucf] = lce_req_s_i.non_cacheable;
        nc_req_size_n           = lce_req_s_i.nc_size;
      end
      e_rqf_mem_resp: begin
        flags_n[e_flag_sel_rqf] = mem_resp_s_i.msg_type;
        flags_n[e_flag_sel_ucf] = mem_resp_s_i.non_cacheable;
        nc_req_size_n           = mem_resp_s_i.nc_size;
      end
      e_rqf_mem_data_resp: begin
        flags_n[e_flag_sel_rqf] = mem_data_resp_s_i.msg_type;
        flags_n[e_flag_sel_ucf] = mem_data_resp_s_i.non_cacheable;
        nc_req_size_n           = mem_data_resp_s_i.nc_size;
      end
      e_rqf_pending: begin
        flags_n[e_flag_sel_rqf] = '0; // TODO: v2
        flags_n[e_flag_sel_ucf] = '0;
        nc_req_size_n           = '0;
      end
      e_rqf_imm0: begin
        flags_n[e_flag_sel_rqf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        flags_n[e_flag_sel_ucf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        nc_req_size_n           = '0;
      end
      default: begin
        flags_n[e_flag_sel_rqf] = '0;
        flags_n[e_flag_sel_ucf] = '0;
        nc_req_size_n           = '0;
      end
    endcase

    case (decoded_inst_i.nerldf_sel)
      e_nerldf_lce_req: begin
        flags_n[e_flag_sel_nerf] = lce_req_s_i.non_exclusive;
        flags_n[e_flag_sel_ldf] = lce_req_s_i.lru_dirty;
      end
      e_nerldf_pending: begin
        flags_n[e_flag_sel_nerf] = '0; // TODO: v2
        flags_n[e_flag_sel_ldf] = '0; // TODO: v2
      end
      e_nerldf_imm0: begin
        flags_n[e_flag_sel_nerf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        flags_n[e_flag_sel_ldf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
      end
      default: begin
        flags_n[e_flag_sel_nerf] = '0;
        flags_n[e_flag_sel_ldf] = '0;
      end
    endcase

    case (decoded_inst_i.nwbf_sel)
      e_nwbf_lce_data_resp: begin
        if (lce_data_resp_s_i.msg_type == e_lce_resp_null_wb) begin
          flags_n[e_flag_sel_nwbf] = 1'b1;
        end else begin
          flags_n[e_flag_sel_nwbf] = '0;
        end
      end
      e_nwbf_imm0: begin
        flags_n[e_flag_sel_nwbf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
      end
      default: begin
        flags_n[e_flag_sel_nwbf] = '0;
      end
    endcase

    case (decoded_inst_i.tf_sel)
      e_tf_logic: flags_n[e_flag_sel_tf] = gad_transfer_flag_i;
      e_tf_mem_resp: flags_n[e_flag_sel_tf] = mem_resp_s_i.payload.transfer;
      e_tf_imm0: flags_n[e_flag_sel_tf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
      default: flags_n[e_flag_sel_tf] = '0;
    endcase

    case (decoded_inst_i.pruief_sel)
      e_pruief_logic: begin
        flags_n[e_flag_sel_pf] = dir_pending_o_i; // RDP instruction
        flags_n[e_flag_sel_rf] = gad_replacement_flag_i;
        flags_n[e_flag_sel_uf] = gad_upgrade_flag_i;
        flags_n[e_flag_sel_if] = gad_invalidate_flag_i;
        flags_n[e_flag_sel_ef] = gad_exclusive_flag_i;
        flags_n[e_flag_sel_cf] = gad_cached_flag_i;
      end
      e_pruief_imm0: begin
        flags_n[e_flag_sel_pf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        flags_n[e_flag_sel_rf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        flags_n[e_flag_sel_uf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        flags_n[e_flag_sel_if] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        flags_n[e_flag_sel_ef] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        flags_n[e_flag_sel_cf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
      end
      default: begin
        flags_n[e_flag_sel_pf] = '0;
        flags_n[e_flag_sel_rf] = '0;
        flags_n[e_flag_sel_uf] = '0;
        flags_n[e_flag_sel_if] = '0;
        flags_n[e_flag_sel_ef] = '0;
        flags_n[e_flag_sel_cf] = '0;
      end
    endcase

    case (decoded_inst_i.rwbf_sel)
      e_rwbf_mem_resp: flags_n[e_flag_sel_rwbf] = mem_resp_s_i.payload.replacement;
      e_rwbf_imm0: flags_n[e_flag_sel_rwbf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
      default: flags_n[e_flag_sel_rwbf] = '0;
    endcase

    // GPR
    for (j = 0; j < `bp_cce_inst_num_gpr; j=j+1) begin
      if (decoded_inst_i.alu_dst_w_v & decoded_inst_i.gpr_w_mask[j]) begin
        gpr_n[j] = alu_res_i;
      end else if (decoded_inst_i.mov_dst_w_v & decoded_inst_i.gpr_w_mask[j]) begin
        gpr_n[j] = mov_src_i;
      end else begin
        gpr_n[j] = '0;
      end
    end

    // Next Coh State
    next_coh_state_n = decoded_inst_i.imm[`bp_cce_coh_bits-1:0];

    // Sharers stuff - comes from directory
    sharers_hits_n = dir_sharers_hits_i;
    sharers_ways_n = dir_sharers_ways_i;
    sharers_coh_states_n = dir_sharers_coh_states_i;

    lru_cached_excl_n = dir_lru_cached_excl_i;
    // LRU Addr
    lru_addr_n = {dir_lru_tag_i, req_addr_r[lg_block_size_in_bytes_lp +: lg_lce_sets_lp],
                  {lg_block_size_in_bytes_lp{1'b0}}};

    // Uncached data
    if (decoded_inst_i.nc_data_lce_req) begin
      nc_data_n = lce_req_s_i.data;
    end else if (decoded_inst_i.nc_data_mem_data_resp) begin
      nc_data_n = mem_data_resp_s_i.data[0+:lce_req_data_width_p];
    end else begin
      nc_data_n = '0;
    end
  end


  int i;
  always_ff @(posedge clk_i)
  begin
    if (reset_i) begin
      req_lce_r <= '0;
      req_addr_r <= '0;
      req_addr_way_r <= '0;
      lru_way_r <= '0;
      lru_addr_r <= '0;
      transfer_lce_r <= '0;
      transfer_lce_way_r <= '0;
      next_coh_state_r <= '0;
      flags_r <= '0;
      gpr_r <= '0;
      ack_type_r <= '0;
      sharers_hits_r <= '0;
      sharers_ways_r <= '0;
      sharers_coh_states_r <= '0;
    end else begin
      if (decoded_inst_i.req_w_v) begin
        req_lce_r <= req_lce_n;
        req_addr_r <= req_addr_n;
      end
      if (decoded_inst_i.req_addr_way_w_v) begin
        req_addr_way_r <= req_addr_way_n;
      end
      if (decoded_inst_i.lru_way_w_v) begin
        lru_way_r <= lru_way_n;
      end
      if (decoded_inst_i.transfer_lce_w_v) begin
        transfer_lce_r <= transfer_lce_n;
        transfer_lce_way_r <= transfer_lce_way_n;
      end
      if (decoded_inst_i.ack_type_w_v) begin
        ack_type_r <= ack_type_n;
      end

      // Flags
      for (i = 0; i < `bp_cce_inst_num_flags; i=i+1) begin
        if (decoded_inst_i.flag_mask_w_v[i]) begin
          flags_r[i] <= flags_n[i];
        end
      end

      // GPR
      for (i = 0; i < `bp_cce_inst_num_gpr; i=i+1) begin
        if (decoded_inst_i.gpr_w_mask[i]) begin
          gpr_r[i] <= gpr_n[i];
        end
      end

      // Next Coh State
      if (decoded_inst_i.mov_dst_w_v && decoded_inst_i.dst == e_dst_next_coh_state) begin
        next_coh_state_r <= next_coh_state_n;
      end

      // Sharers Info
      if (dir_sharers_v_i) begin
        sharers_hits_r <= sharers_hits_n;
        sharers_ways_r <= sharers_ways_n;
        sharers_coh_states_r <= sharers_coh_states_n;
      end

      if (dir_lru_v_i) begin
        lru_cached_excl_r <= lru_cached_excl_n;
        lru_addr_r <= lru_addr_n;
      end

      // Uncached data and request size
      if (decoded_inst_i.nc_data_w_v) begin
        nc_data_r <= nc_data_n;
      end

      if (decoded_inst_i.nc_req_size_w_v) begin
        nc_req_size_r <= nc_req_size_n;
      end

    end // else
  end // always_ff

endmodule
