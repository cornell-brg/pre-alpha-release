#include <stdlib.h>
#include <systemc.h>
#include <verilated_vcd_sc.h>
#include <verilated_cov.h>

#include "Vtestbench.h"
#include "Vtestbench__Dpi.h"

#define CLK_TIME 10

int sc_main(int argc, char **argv)
{
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(VM_TRACE);

  Vtestbench *tb = new Vtestbench("testbench");

  svSetScope(svGetScopeFromName("testbench.testbench.rof1[0].mem"));
  // Use me to find the correct scope of your DPI functions
  //Verilated::scopesDump();

  sc_clock clock("clk", sc_time(CLK_TIME, SC_NS));
  sc_signal <bool> reset("reset");

  tb->clk_i(clock);
  tb->reset_i(reset);

#if VM_TRACE
  VerilatedVcdSc* wf = new VerilatedVcdSc;
  tb->trace(wf, 10);
  wf->open("vcdplus.vpd");
  std::cout << "TESTTESTTEST" << std::endl;
#endif

  reset = 1;

  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);

  reset = 0;

  while (!Verilated::gotFinish()) {
    sc_start(CLK_TIME, SC_NS);
  }

#if VM_COVERAGE
  VerilatedCov::write(argv[1]);
#endif

  exit(EXIT_SUCCESS);
}
