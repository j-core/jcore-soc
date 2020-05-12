use work.config.all;

package clk_config is

  -- calculate clock frequencies from the periods set in the generated config package
  constant CFG_CLK_CPU_FREQ_HZ : real := real(CFG_CLK_PLLE2_HZ) / real(CFG_CLK_CPU_PERIOD_NS);
  constant CFG_CLK_MEM_FREQ_HZ : real := real(CFG_CLK_PLLE2_HZ) / real(CFG_CLK_MEM_PERIOD_NS);
  constant CFG_CLK_PLLE2_MULT : natural := CFG_CLK_PLLE2_HZ / 25000000;
  constant CFG_CLK_BITLINK_FREQ_HZ : real := 1.0e9 / real(CFG_CLK_BITLINK_PERIOD_NS);
end;
