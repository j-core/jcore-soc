library unisim;
use unisim.vcomponents.all;

architecture s6 of clkin25_clkgen is
  -- Input clock buffering
  signal clkpll           : std_logic;
  -- Output clock buffering
  signal pll_clkfb        : std_logic;
  signal clkout0          : std_logic;
  signal clkout1          : std_logic;
  signal clkout2          : std_logic;
  signal clkout3          : std_logic;
begin

  -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFG
    port map (
      O => clkpll,
      I => clk_in);

  -- Clock synthesis
  --------------------------------------
  pll_base_inst : PLL_BASE
  generic map (
    BANDWIDTH            => "HIGH",
    CLK_FEEDBACK         => "CLKFBOUT",
    COMPENSATION         => "PLL2DCM",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT        => 40,
    CLKFBOUT_PHASE       => 0.000,
    -- clk_cpu
    CLKOUT0_DIVIDE       => CLK_CPU_DIVIDE,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    -- clk_mem
    CLKOUT1_DIVIDE       => 2*CLK_MEM_2X_DIVIDE,
    CLKOUT1_PHASE        => 0.000,
    CLKOUT1_DUTY_CYCLE   => 0.500,
    -- clk_mem_90
    CLKOUT2_DIVIDE       => 2*CLK_MEM_2X_DIVIDE,
    CLKOUT2_PHASE        => 90.000,
    CLKOUT2_DUTY_CYCLE   => 0.500,
    -- clk_mem_2x
    CLKOUT3_DIVIDE       => CLK_MEM_2X_DIVIDE,
    CLKOUT3_PHASE        => 0.000,
    CLKOUT3_DUTY_CYCLE   => 0.500,
    -- unused
    CLKOUT4_DIVIDE       => 40,
    CLKOUT4_PHASE        => 00.000,
    CLKOUT4_DUTY_CYCLE   => 0.500,
    -- unused
    CLKOUT5_DIVIDE       => 40,
    CLKOUT5_PHASE        => 0.000,
    CLKOUT5_DUTY_CYCLE   => 0.500,

    CLKIN_PERIOD         => 40.0,
    REF_JITTER           => 0.001)
  port map (
    -- Output clocks
    CLKFBOUT            => pll_clkfb,
    CLKOUT0             => clkout0,
    CLKOUT1             => clkout1,
    CLKOUT2             => clkout2,
    CLKOUT3             => clkout3,
    -- Status and control signals
    LOCKED              => lock,
    RST                 => RST,
    -- Input clock control
    CLKFBIN             => pll_clkfb,
    CLKIN               => clkpll);

  -- Output buffering for PLL signals
  -------------------------------------
  clkout0_buf : BUFG port map (O => clk_cpu,    I => clkout0);
  clkout1_buf : BUFG port map (O => clk_mem,    I => clkout1);
  clkout2_buf : BUFG port map (O => clk_mem_90, I => clkout2);
  clkout3_buf : BUFG port map (O => clk_mem_2x, I => clkout3);
end architecture;
