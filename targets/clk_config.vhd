use work.config.all;

package clk_config is

  -- calculate clock frequencies from the periods set in the generated config package
  constant CFG_CLK_CPU_FREQ_HZ : real := 1.0e9 / real(CFG_CLK_CPU_PERIOD_NS);
  constant CFG_CLK_MEM_FREQ_HZ : real := 1.0e9 / real(CFG_CLK_MEM_PERIOD_NS);
  constant CFG_CLK_BITLINK_FREQ_HZ : real := 1.0e9 / real(CFG_CLK_BITLINK_PERIOD_NS);
end;
