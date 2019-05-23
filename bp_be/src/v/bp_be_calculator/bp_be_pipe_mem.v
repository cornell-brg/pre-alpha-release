/**
 *
 * Name:
 *   bp_be_pipe_mem.v
 * 
 * Description:
 *   Pipeline for RISC-V memory instructions. This includes both int + float loads + stores.
 *
 * Parameters:
 *   vaddr_width_p    -
 *
 * Inputs:
 *   clk_i            -
 *   reset_i          -
 *
 *   decode_i         - All of the pipeline control information needed for a dispatched instruction
 *   pc_i             - PC of the dispatched instruction
 *   rs1_i            - Source register data for the dispatched instruction
 *   rs2_i            - Source register data for the dispatched instruction
 *   imm_i            - Immediate data for the dispatched instruction
 *   exc_i            - Exception information for a dispatched instruction
 *
 *   mem_resp_i       - Load / store response from the MMU.
 *   mem_resp_v_i     - 'ready-then-valid' interface
 *   mem_resp_ready_o   - 

 *
 * Outputs:
 *   mmu_cmd_o        -  Load / store command to the MMU
 *   mmu_cmd_v_o      -  'ready-then-valid' interface
 *   mmu_cmd_ready_i  - 
 * 
 *   data_o         - The calculated result of a load 
 *   cache_miss_o     - Goes high when the result of the load or store is a cache miss 
 *   
 * Keywords:
 *   calculator, mem, mmu, load, store, rv64i, rv64f
 *
 * Notes:
 *   
 */

module bp_be_pipe_mem 
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p               = "inv"
   , parameter lce_sets_p                = "inv"
   , parameter cce_block_size_in_bytes_p = "inv"
   // Generated parameters
   , localparam decode_width_lp        = `bp_be_decode_width
   , localparam exception_width_lp     = `bp_be_exception_width
   , localparam mmu_cmd_width_lp       = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam csr_cmd_width_lp       = `bp_be_csr_cmd_width
   , localparam mem_resp_width_lp      = `bp_be_mem_resp_width(vaddr_width_p)
   , localparam mem_exception_width_lp = `bp_be_mem_exception_width

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                                  clk_i
   , input                                reset_i

   , input                                kill_ex1_i
   , input                                kill_ex2_i
   , input                                kill_ex3_i

   , input                                mem3_itlb_fill_v_i
   , input                                mem3_store_not_load_i
   , input [vaddr_width_p-1:0]            mem3_pc_i

   , input [decode_width_lp-1:0]          decode_i
   , input [rv64_instr_width_gp-1:0]      instr_i
   , input [reg_data_width_lp-1:0]        rs1_i
   , input [reg_data_width_lp-1:0]        rs2_i
   , input [reg_data_width_lp-1:0]        imm_i

   , output [mmu_cmd_width_lp-1:0]        mmu_cmd_o
   , output                               mmu_cmd_v_o
   , input                                mmu_cmd_ready_i

   , output [csr_cmd_width_lp-1:0]        csr_cmd_o
   , output                               csr_cmd_v_o
   , input                                csr_cmd_ready_i

   , input  [mem_resp_width_lp-1:0]       mem_resp_i
   , input                                mem_resp_v_i
   , output                               mem_resp_ready_o

   , output logic                              v_o
   , output logic [reg_data_width_lp-1:0]      data_o
   , output logic [mem_exception_width_lp-1:0] mem_exception_o
   , output logic [vaddr_width_p-1:0]          mem3_vaddr_o
   );

// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)

// Cast input and output ports 
bp_be_decode_s    decode;
bp_be_mmu_cmd_s   mem1_cmd, mem3_cmd_li, mem3_cmd_lo, mem3_cmd;
bp_be_csr_cmd_s   csr_cmd_li, csr_cmd_lo;
bp_be_mem_resp_s  mem_resp;
rv64_instr_s      instr;

assign decode = decode_i;
assign mem_resp = mem_resp_i;
assign csr_cmd_o = csr_cmd_lo;
assign instr = instr_i;

// Suppress unused signal warnings
wire unused0 = kill_ex2_i;

logic csr_cmd_v_lo, mem3_cmd_v_li, mem3_cmd_v_lo, mem3_cmd_v, mem1_cmd_v;

// Suppress unused signal warnings
wire unused2 = mmu_cmd_ready_i;
wire unused3 = csr_cmd_ready_i;

assign data_o = mem_resp.data;

bsg_shift_reg
 #(.width_p(csr_cmd_width_lp)
   ,.stages_p(2)
   )
 csr_shift_reg
  (.clk(clk_i)
   ,.reset_i(reset_i)

   ,.valid_i(decode.csr_instr_v)
   ,.data_i(csr_cmd_li)

   ,.valid_o(csr_cmd_v_lo)
   ,.data_o(csr_cmd_lo)
   );

// TODO: we are using extra bits for this.
// Can add this information to the calculator pipeline
// And share them between CSR and MEM3 cmds
bsg_shift_reg
 #(.width_p(mmu_cmd_width_lp)
   ,.stages_p(2)
   )
 mem3_shift_reg
  (.clk(clk_i)
   ,.reset_i(reset_i)

   ,.valid_i(mem3_cmd_v_li)
   ,.data_i(mem3_cmd_li)

   ,.valid_o(mem3_cmd_v_lo)
   ,.data_o(mem3_cmd_lo)
   );

logic [reg_data_width_lp-1:0] offset;

assign offset = decode.offset_sel ? '0 : imm_i[0+:vaddr_width_p];

assign mem1_cmd_v = (decode.dcache_r_v | decode.dcache_w_v) & ~kill_ex1_i;
always_comb 
  begin
    mem1_cmd.mem_op = decode.fu_op;
    mem1_cmd.data   = rs2_i;
    mem1_cmd.vaddr  = (rs1_i + offset);
  end

assign mem3_cmd_v_li = decode.fence_instr_v & ~kill_ex1_i;
assign mem3_cmd_v    = (mem3_cmd_v_lo | mem_resp.exception.dtlb_miss | mem3_itlb_fill_v_i) & ~kill_ex3_i;
always_comb
  begin
    mem3_cmd_li.mem_op = decode.fu_op;

    if(mem3_itlb_fill_v_i) begin
      mem3_cmd.mem_op = e_ptw_i;
    end
    else if(mem_resp.exception.dtlb_miss) begin
      mem3_cmd.mem_op = mem3_store_not_load_i ? e_ptw_s : e_ptw_l;
    end
    else begin
      mem3_cmd.mem_op = mem3_cmd_lo.mem_op;
    end
    mem3_cmd.vaddr = mem3_itlb_fill_v_i ? mem3_pc_i : mem_resp.vaddr;
    mem3_cmd.data  = mem3_pc_i;
  end

assign csr_cmd_v_o = csr_cmd_v_lo & ~kill_ex3_i;
wire csr_imm_op = (decode.fu_op == e_csrrwi) 
                  | (decode.fu_op == e_csrrsi) 
                  | (decode.fu_op == e_csrrci);
always_comb
  begin
    csr_cmd_li.csr_op   = decode.fu_op;
    csr_cmd_li.csr_addr = instr.fields.itype.imm12;
    csr_cmd_li.data     = csr_imm_op ? imm_i : rs1_i;
  end

// Output results of memory op
assign v_o                = mem_resp_v_i;
assign mem_resp_ready_o   = 1'b1;
assign mem_exception_o    = mem_resp.exception;
assign mem3_vaddr_o       = mem_resp.vaddr;

// Set MMU cmd signal
assign mmu_cmd_v_o = mem1_cmd_v | mem3_cmd_v;
assign mmu_cmd_o = mem3_cmd_v ? mem3_cmd : mem1_cmd;

endmodule : bp_be_pipe_mem

