library unisim;
use unisim.vcomponents.all;

architecture s6 of clkin10_clkgen is
  -- Input clock buffering / unused connectors
  signal clkdcm          : std_logic;
  signal clkpll          : std_logic;
  -- Output clock buffering / unused connectors
  signal clkfbout        : std_logic;
  signal clkout0         : std_logic;
  signal clkout1         : std_logic;
  -- status signals
  signal lockeddcm       : std_logic;
  signal status_internal : std_logic_vector(7 downto 0);
  signal resetpll        : std_logic;
  signal lockedpll       : std_logic;

begin
  clkin1_buf : IBUFG
    port map (
      O => clkdcm,
      I => clk_in);

  dcm_sp_inst : DCM_SP
    generic map (
      CLKDV_DIVIDE       => 2.000,
      CLKFX_DIVIDE       => 1,
      CLKFX_MULTIPLY     => 4,
      CLKIN_DIVIDE_BY_2  => false,
      CLKIN_PERIOD       => 100.000,
      CLKOUT_PHASE_SHIFT => "NONE",
      CLK_FEEDBACK       => "2X",
      DESKEW_ADJUST      => "SYSTEM_SYNCHRONOUS",
      PHASE_SHIFT        => 0,
      STARTUP_WAIT       => false)
    port map (
      -- Input clock
      CLKIN    => clkdcm,
      CLKFB    => clkpll,
      -- Output clocks
      CLK0     => open,
      CLK90    => open,
      CLK180   => open,
      CLK270   => open,
      CLK2X    => clkpll,
      CLK2X180 => open,
      CLKFX    => open,
      CLKFX180 => open,
      CLKDV    => open,
      -- Ports for dynamic phase shift
      PSCLK    => '0',
      PSEN     => '0',
      PSINCDEC => '0',
      PSDONE   => open,
      -- Other control and status signals
      LOCKED   => lockeddcm,
      STATUS   => status_internal,
      RST      => RST,
      -- Unused pin, tie low
      DSSEN    => '0');

  resetpll <= RST or (not lockeddcm);

  pll_base_inst : PLL_BASE
    generic map (
      BANDWIDTH      => "LOW",
      CLK_FEEDBACK   => "CLKFBOUT",
      COMPENSATION   => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE  => 1,
      CLKFBOUT_MULT  => 50,
      CLKFBOUT_PHASE => 0.000,
      -- clk_bitlink
      CLKOUT0_DIVIDE     => 8,
      CLKOUT0_PHASE      => 0.000,
      CLKOUT0_DUTY_CYCLE => 0.500,
      -- clk_bitlink_2x
      CLKOUT1_DIVIDE     => 4,
      CLKOUT1_PHASE      => 0.000,
      CLKOUT1_DUTY_CYCLE => 0.500,
      -- unused
      CLKOUT2_DIVIDE     => 8,
      CLKOUT2_PHASE      => 0.000,
      CLKOUT2_DUTY_CYCLE => 0.500,
      CLKOUT3_DIVIDE     => 8,
      CLKOUT3_PHASE      => 0.000,
      CLKOUT3_DUTY_CYCLE => 0.500,
      CLKOUT4_DIVIDE     => 8,
      CLKOUT4_PHASE      => 0.000,
      CLKOUT4_DUTY_CYCLE => 0.500,
      CLKOUT5_DIVIDE     => 8,
      CLKOUT5_PHASE      => 0.000,
      CLKOUT5_DUTY_CYCLE => 0.500,
      CLKIN_PERIOD       => 50.0,
      REF_JITTER         => 0.005)
    port map (
      -- Output clocks
      CLKFBOUT => clkfbout,
      CLKOUT0  => clkout0,
      CLKOUT1  => clkout1,
      -- Status and control signals
      LOCKED   => lockedpll,
      RST      => resetpll,
      -- Input clock control
      CLKFBIN  => clkfbout,
      CLKIN    => clkpll);

  LOCK <= lockeddcm and lockedpll;

  -- Output buffering
  -------------------------------------
  clkout0_buf : BUFG port map (O => clk_bitlink,    I => clkout0);
  clkout1_buf : BUFG port map (O => clk_bitlink_2x, I => clkout1);

end architecture;
