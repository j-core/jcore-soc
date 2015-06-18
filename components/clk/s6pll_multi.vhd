-- Clock generator.  Uses PLL to generate base signals, bitlink clock divider is in fabric.
--
------------------------------------------------------------------------------
-- Output     Output      Phase    Duty Cycle   Pk-to-Pk     Phase
-- Clock     Freq (MHz)  (degrees)    (%)     Jitter (ps)  Error (ps)
------------------------------------------------------------------------------
-- CLK_OUT1   250.000      0.000      50.0      174.869    261.639
-- CLK_OUT2   250.000     90.000      50.0      174.869    261.639
-- CLK_OUT3    62.500      0.000      50.0      217.482    261.639
-- CLK_OUT4    31.250      0.000      50.0      243.254    261.639
-- CLK_OUT5    31.250     90.000      50.0      243.254    261.639
-- CLK_OUT6   125.000      0.000      50.0      194.912    261.639
--
-- DCM uses 250MHz and creates:
-- 125 MHz, 0, 90, 180, 270 deg.
--
------------------------------------------------------------------------------
-- Input Clock   Input Freq (MHz)   Input Jitter (UI)
------------------------------------------------------------------------------
-- CLK                 25           0.00125

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity s6_clk is
port
 (-- Clock in ports
  CLK              : in     std_logic;
  -- Clock out ports
  CLK_125_0        : out    std_logic;
  CLK_125_90       : out    std_logic;
  CLK_125_180      : out    std_logic;
  CLK_125_270      : out    std_logic;
  CLK_125          : out    std_logic;
  CLK_62           : out    std_logic;
  CLK_31_0         : out    std_logic;
  CLK_31_90        : out    std_logic;
  -- Status and control signals
  RST              : in     std_logic;
  LOCK             : out    std_logic
 );
end s6_clk;

architecture struct of s6_clk is
  -- Input clock buffering / unused connectors
  signal clkin1           : std_logic;
  -- Output clock buffering / unused connectors
  signal pll_clkfb        : std_logic;
  signal clkout0          : std_logic;
  signal clkout1          : std_logic;
  signal clkout2          : std_logic;
  signal clkout3          : std_logic;
  signal clkout4          : std_logic;
  signal clkout5          : std_logic;
  signal pll_locked       : std_logic;
  signal clk_125_b        : std_logic;

  signal dcm_reset        : std_logic;
  signal dcm_clkfb        : std_logic;
  signal clk0             : std_logic;
  signal clk0b            : std_logic;
  signal clk90            : std_logic;
  signal clk180           : std_logic;
  signal clk270           : std_logic;
  signal dcm_locked       : std_logic;
  signal dcm_status       : std_logic_vector(7 downto 0);

begin

  -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFG
  port map
   (O => clkin1,
    I => CLK);

  -- Clock synthesis
  --------------------------------------

  pll_base_inst : PLL_BASE
  generic map
   (BANDWIDTH            => "HIGH",
    CLK_FEEDBACK         => "CLKFBOUT",
    COMPENSATION         => "PLL2DCM",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT        => 40,
    CLKFBOUT_PHASE       => 0.000,
    CLKOUT0_DIVIDE       => 4,
    CLKOUT0_PHASE        => 0.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    CLKOUT1_DIVIDE       => 4,
    CLKOUT1_PHASE        => 90.000,
    CLKOUT1_DUTY_CYCLE   => 0.500,
    CLKOUT2_DIVIDE       => 10,
    CLKOUT2_PHASE        => 0.000,
    CLKOUT2_DUTY_CYCLE   => 0.500,
    CLKOUT3_DIVIDE       => 20,
    CLKOUT3_PHASE        => 0.000,
    CLKOUT3_DUTY_CYCLE   => 0.500,
    CLKOUT4_DIVIDE       => 20,
    CLKOUT4_PHASE        => 90.000,
    CLKOUT4_DUTY_CYCLE   => 0.500,
    CLKOUT5_DIVIDE       => 8,
    CLKOUT5_PHASE        => 0.000,
    CLKOUT5_DUTY_CYCLE   => 0.500,
    CLKIN_PERIOD         => 40.0,
    REF_JITTER           => 0.001)
  port map
    -- Output clocks
   (CLKFBOUT            => pll_clkfb,
    CLKOUT0             => clkout0,
    CLKOUT1             => clkout1,
    CLKOUT2             => clkout2,
    CLKOUT3             => clkout3,
    CLKOUT4             => clkout4,
    CLKOUT5             => clkout5,
    -- Status and control signals
    LOCKED              => pll_locked,
    RST                 => RST,
    -- Input clock control
    CLKFBIN             => pll_clkfb,
    CLKIN               => clkin1);

  -- BitLink clock generation DLL
  --------------------------------------

  dcm_reset <= not pll_locked;

  dcm_sp_inst: DCM_SP
  generic map
   (CLKDV_DIVIDE          => 2.000,
    CLKFX_DIVIDE          => 1,
    CLKFX_MULTIPLY        => 4,
    CLKIN_DIVIDE_BY_2     => FALSE,
    CLKIN_PERIOD          => 8.0,
    CLKOUT_PHASE_SHIFT    => "NONE",
    CLK_FEEDBACK          => "1X",
    DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
    PHASE_SHIFT           => 0,
    STARTUP_WAIT          => FALSE)
  port map
   -- Input clock
   (CLKIN                 => clkout5,
    CLKFB                 => dcm_clkfb,
    -- Output clocks
    CLK0                  => clk0,
    CLK90                 => clk90,
    CLK180                => clk180,
    CLK270                => clk270,
    CLK2X                 => open,
    CLK2X180              => open,
    CLKFX                 => open,
    CLKFX180              => open,
    CLKDV                 => open,
   -- Ports for dynamic phase shift
    PSCLK                 => '0',
    PSEN                  => '0',
    PSINCDEC              => '0',
    PSDONE                => open,
   -- Other control and status signals
    LOCKED                => dcm_locked,
    STATUS                => dcm_status,
    RST                   => dcm_reset,
   -- Unused pin, tie low
    DSSEN                 => '0');

  LOCK <= ( dcm_locked and  ( not dcm_status(1) ) );

  -- Output buffering for PLL signals
  -------------------------------------

  clkout62_buf    : BUFG port map (O   => CLK_62,    I   => clkout2);
  clkout31_0_buf  : BUFG port map (O   => CLK_31_0,  I   => clkout3);
  clkout31_90_buf : BUFG port map (O   => CLK_31_90, I   => clkout4);
  clkout125_buf   : BUFG port map (O   => CLK_125_b, I   => clkout5);
  clk_125_0 <= CLK_125_b;
  clk_125   <= CLK_125_b;

  -- Output buffering for DCM signals
  -------------------------------------

  clkout125_0_buf   : BUFG port map (O   => dcm_clkfb,   I   => clk0);
  clkout125_90_buf  : BUFG port map (O   => clk_125_90,  I   => clk90);
  clkout125_180_buf : BUFG port map (O   => clk_125_180, I   => clk180); 
  clkout125_270_buf : BUFG port map (O   => clk_125_270, I   => clk270);
--  clkout125_buf     : BUFG port map (O   => CLK_125,     I   => clk0);
--  clk_125_0 <= dcm_clkfb;

end struct;
