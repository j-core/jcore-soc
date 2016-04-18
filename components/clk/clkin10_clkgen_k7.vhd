library unisim;
use unisim.vcomponents.all;

architecture k7 of clkin10_clkgen is
  -- Input clock buffering / unused connectors
  signal clkdcm           : std_logic;
  signal clkpll           : std_logic;
  -- Output clock buffering / unused connectors
  signal clkfbout         : std_logic;
  signal clkout0          : std_logic;
  signal clkout1          : std_logic;
  signal mmcm_feedback_in : std_logic;
  signal mmcm_feedback_out: std_logic;
  -- status signals
  signal lockeddcm        : std_logic;
  signal status_internal  : std_logic_vector(7 downto 0);
  signal resetpll         : std_logic;
  signal lockedpll        : std_logic;

begin
  clkin1_buf : IBUFG
  port map (
    O => clkdcm,
    I => clk_in);

  mmcm_adv_inst : MMCME2_ADV
  generic map (
    BANDWIDTH            => "OPTIMIZED",
    CLKOUT4_CASCADE      => FALSE,
    COMPENSATION         => "ZHOLD",
    STARTUP_WAIT         => FALSE,
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT_F      => 64.000,
    CLKFBOUT_PHASE       => 0.000,
    CLKFBOUT_USE_FINE_PS => FALSE,
    CLKOUT0_DIVIDE_F     => 32.000,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    CLKOUT0_USE_FINE_PS  => FALSE,
    CLKIN1_PERIOD        => 100.000,
    REF_JITTER1          => 0.010)
  port map (
    -- Output clocks
    CLKFBOUT            => mmcm_feedback_out,
    CLKOUT0             => clkpll,
    -- Input clock control
    CLKFBIN             => mmcm_feedback_in,
    CLKIN1              => clkdcm,
    CLKIN2              => '0',
    -- Tied to always select the primary input clock
    CLKINSEL            => '1',
    -- Ports for dynamic reconfiguration
    DADDR               => (others => '0'),
    DCLK                => '0',
    DEN                 => '0',
    DI                  => (others => '0'),
    DO                  => open,--do_unused,
    DRDY                => open,--drdy_unused,
    DWE                 => '0',
    -- Ports for dynamic phase shift
    PSCLK               => '0',
    PSEN                => '0',
    PSINCDEC            => '0',
    PSDONE              => open,--psdone_unused,
    -- Other control and status signals
    LOCKED              => lockeddcm,--LOCKED,
    CLKINSTOPPED        => open,--clkinstopped_unused,
    CLKFBSTOPPED        => open,--clkfbstopped_unused,
    PWRDWN              => '0',
    RST                 => rst);

  resetpll <= rst or (not lockeddcm);

  plle2_adv_inst : PLLE2_ADV
  generic map (
    BANDWIDTH            => "OPTIMIZED",
    COMPENSATION         => "INTERNAL",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT        => 50,
    CLKFBOUT_PHASE       => 0.000,
    -- clk_bitlink
    CLKOUT0_DIVIDE       => 8,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    -- clk_bitlink_2x
    CLKOUT1_DIVIDE       => 4,
    CLKOUT1_PHASE        => 0.000,
    CLKOUT1_DUTY_CYCLE   => 0.500,
    -- unused
    CLKOUT2_DIVIDE       => 8,
    CLKOUT2_PHASE        => 0.000,
    CLKOUT2_DUTY_CYCLE   => 0.500,
    CLKOUT3_DIVIDE       => 8,
    CLKOUT3_PHASE        => 0.000,
    CLKOUT3_DUTY_CYCLE   => 0.500,
    CLKOUT4_DIVIDE       => 8,
    CLKOUT4_PHASE        => 0.000,
    CLKOUT4_DUTY_CYCLE   => 0.500,
    CLKOUT5_DIVIDE       => 8,
    CLKOUT5_PHASE        => 0.000,
    CLKOUT5_DUTY_CYCLE   => 0.500,
    CLKIN1_PERIOD        => 50.000,
    REF_JITTER1          => 0.001)
  port map (
    -- Output clocks
    CLKFBOUT            => clkfbout,
    CLKOUT0             => clkout0,
    CLKOUT1             => clkout1,
    -- Input clock control
    CLKFBIN             => clkfbout,
    CLKIN1              => clkpll,
    CLKIN2              => '0',
    -- Tied to always select the primary input clock
    CLKINSEL            => '1',
    -- Ports for dynamic reconfiguration
    DADDR               => (others => '0'),
    DCLK                => '0',
    DEN                 => '0',
    DI                  => (others => '0'),
    DO                  => open,--do_unused,
    DRDY                => open,--drdy_unused,
    DWE                 => '0',
    -- Other control and status signals
    LOCKED              => lockedpll,
    PWRDWN              => '0',
    RST                 => resetpll);

  lock <= lockeddcm and lockedpll;

  MMCM_FEEDBACK_buf : BUFG port map (O => mmcm_feedback_in, I => mmcm_feedback_out);

  -- Output buffering
  -------------------------------------
  clkout0_buf : BUFG port map (O => clk_bitlink,    I => clkout0);
  clkout1_buf : BUFG port map (O => clk_bitlink_2x, I => clkout1);

end architecture;
