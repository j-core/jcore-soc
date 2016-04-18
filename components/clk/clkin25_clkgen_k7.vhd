library unisim;
use unisim.vcomponents.all;

architecture k7 of clkin25_clkgen is
  -- Input clock buffering / unused connectors
  signal clkpll        : std_logic;
  -- Output clock buffering / unused connectors
  signal pll_clkfb     : std_logic;
  signal pll_clkfb_buf : std_logic;
  signal clkout0       : std_logic;
  signal clkout1       : std_logic;
  signal clkout2       : std_logic;
  signal clkout3       : std_logic;
  --signal clkout5          : std_logic;
  signal pll_locked    : std_logic;

begin

  -- Input buffering
  --------------------------------------
  clkpll_buf : IBUFG
    port map (
      O => clkpll,
      I => clk_in);

  -- Clock synthesis
  --------------------------------------

  plle2_adv_inst : PLLE2_ADV
    generic map (
      BANDWIDTH      => "OPTIMIZED",
      COMPENSATION   => "ZHOLD",
      DIVCLK_DIVIDE  => 1,
      CLKFBOUT_MULT  => 40,
      CLKFBOUT_PHASE => 0.000,
      -- clk_cpu
      CLKOUT0_DIVIDE     => CLK_CPU_DIVIDE,
      CLKOUT0_PHASE      => 0.000,
      CLKOUT0_DUTY_CYCLE => 0.500,
      -- clk_mem
      CLKOUT1_DIVIDE     => 2*CLK_MEM_2X_DIVIDE,
      CLKOUT1_PHASE      => 0.000,
      CLKOUT1_DUTY_CYCLE => 0.500,
      -- clk_mem_90
      CLKOUT2_DIVIDE     => 2*CLK_MEM_2X_DIVIDE,
      CLKOUT2_PHASE      => 90.000,
      CLKOUT2_DUTY_CYCLE => 0.500,
      -- clk_mem_2x
      CLKOUT3_DIVIDE     => CLK_MEM_2X_DIVIDE,
      CLKOUT3_PHASE      => 0.000,
      CLKOUT3_DUTY_CYCLE => 0.500,
      -- unused
      CLKOUT4_DIVIDE     => 20,
      CLKOUT4_PHASE      => 90.000,
      CLKOUT4_DUTY_CYCLE => 0.500,
      -- unused
      CLKOUT5_DIVIDE     => 8,
      CLKOUT5_PHASE      => 0.000,
      CLKOUT5_DUTY_CYCLE => 0.500,

      CLKIN1_PERIOD => 40.000,
      REF_JITTER1   => 0.001)
    port map (
      -- Output clocks
      CLKFBOUT => pll_clkfb,            --tbd
      CLKOUT0  => clkout0,
      CLKOUT1  => clkout1,
      CLKOUT2  => clkout2,
      CLKOUT3  => clkout3,
      -- Other control and status signals
      LOCKED   => pll_locked,
      PWRDWN   => '0',
      RST      => RST,
      -- Input clock control
      CLKFBIN  => pll_clkfb_buf,        --TBD
      CLKIN1   => clkpll,
      CLKIN2   => '0',
      -- Tied to always select the primary input clock
      CLKINSEL => '1',
      -- Ports for dynamic reconfiguration
      DADDR    => (others => '0'),
      DCLK     => '0',
      DEN      => '0',
      DI       => (others => '0'),
      DO       => open,                 --do_unused,
      DRDY     => open,                 --drdy_unused,
      DWE      => '0');
  pllfeedback_buf : BUFG port map (O => pll_clkfb_buf, I => pll_clkfb);

  -- BitLink clock generation DLL
  --------------------------------------

  lock <= pll_locked;

  -- Output buffering for PLL signals
  -------------------------------------
  clkout0_buf : BUFG port map (O => clk_cpu,    I => clkout0);
  clkout1_buf : BUFG port map (O => clk_mem,    I => clkout1);
  clkout2_buf : BUFG port map (O => clk_mem_90, I => clkout2);
  clkout3_buf : BUFG port map (O => clk_mem_2x, I => clkout3);

end architecture;
