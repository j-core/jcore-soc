------------------------------------------------------------------------------
-- Output     Output      Phase    Duty Cycle   Pk-to-Pk     Phase
-- Clock     Freq (MHz)  (degrees)    (%)     Jitter (ps)  Error (ps)
------------------------------------------------------------------------------
-- clk250      250.000      0.000      50.0      212.631    235.448
-- clk125_0    125.000      0.000      50.0      172.776    235.448
-- clk125_90   125.000     90.000      50.0      172.776    235.448
-- clk125_180  125.000    180.000      50.0      172.776    235.448
-- clk125_270  125.000    270.000      50.0      172.776    235.448
-- clk_cpu 1000/CLK_CPU_DIVIDE  0.000      50.0      254.951    235.448
--
------------------------------------------------------------------------------
-- Input Clock   Input Freq (MHz)   Input Jitter (UI)
------------------------------------------------------------------------------
-- primary         100.000             0.05

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity pll_250 is
generic (
  CLK_CPU_DIVIDE : natural := 32);
port
 (-- Clock in ports
  clk        : in  std_logic;
  -- Clock out ports
  clk250     : out std_logic;
  clk125_0   : out std_logic;
  clk125_90  : out std_logic;
  clk125_180 : out std_logic;
  clk125_270 : out std_logic;
  clk_cpu    : out std_logic;
  -- Status and control signals
  reset_o    : out std_logic;
  locked     : out std_logic
 );
end pll_250;

architecture xilinx of pll_250 is
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of xilinx : architecture is "pll_250,clk_wiz_v3_1,{component_name=pll_250,use_phase_alignment=true,use_min_o_jitter=true,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,feedback_source=FDBK_AUTO,primtype_sel=PLL_BASE,num_out_clk=6,clkin1_period=10.0,clkin2_period=10.0,use_power_down=false,use_reset=false,use_locked=true,use_inclk_stopped=false,use_status=false,use_freeze=false,use_clk_valid=false,feedback_type=SINGLE,clock_mgr_type=AUTO,manual_override=true}";
  -- Input clock buffering / unused connectors
  signal clkin1      : std_logic;
  -- Output clock buffering / unused connectors
  signal clkfbout         : std_logic;
  signal clkfbout_buf     : std_logic;
  signal clkout0          : std_logic;
  signal clkout1          : std_logic;
  signal clkout2          : std_logic;
  signal clkout3          : std_logic;
  signal clkout4          : std_logic;
  signal clkout5          : std_logic;
  signal w_locked         : std_logic;
  -- Unused status signals

begin


  -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFG
  port map
   (O => clkin1,
    I => clk);


  -- Clocking primitive
  --------------------------------------
  -- Instantiation of the PLL primitive
  --    * Unused inputs are tied off
  --    * Unused outputs are labeled unused

  pll_base_inst : PLL_BASE
  generic map
   (BANDWIDTH            => "LOW",
    CLK_FEEDBACK         => "CLKFBOUT",
    COMPENSATION         => "SYSTEM_SYNCHRONOUS",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT        => 10,
    CLKFBOUT_PHASE       => 0.000,
    --CLKOUT0_DIVIDE       => 16,--62.5M gen --yk changed
    CLKOUT0_DIVIDE       => 4,--250M gen--yk changed
    CLKOUT0_PHASE        => 180.000,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    CLKOUT1_DIVIDE       => 8,
    CLKOUT1_PHASE        => 0.000,
    CLKOUT1_DUTY_CYCLE   => 0.500,
    CLKOUT2_DIVIDE       => 8,
    CLKOUT2_PHASE        => 90.000,
    CLKOUT2_DUTY_CYCLE   => 0.500,
    CLKOUT3_DIVIDE       => 8,
    CLKOUT3_PHASE        => 180.000,
    CLKOUT3_DUTY_CYCLE   => 0.500,
    CLKOUT4_DIVIDE       => 8,
    CLKOUT4_PHASE        => 270.000,
    CLKOUT4_DUTY_CYCLE   => 0.500,
    CLKOUT5_DIVIDE       => CLK_CPU_DIVIDE,
    CLKOUT5_PHASE        => 0.000,
    CLKOUT5_DUTY_CYCLE   => 0.500,
    CLKIN_PERIOD         => 10.0,
    REF_JITTER           => 0.050)
  port map
    -- Output clocks
   (CLKFBOUT            => clkfbout,
    CLKOUT0             => clkout0,
    CLKOUT1             => clkout1,
    CLKOUT2             => clkout2,
    CLKOUT3             => clkout3,
    CLKOUT4             => clkout4,
    CLKOUT5             => clkout5,
    -- Status and control signals
    LOCKED              => w_locked,
    RST                 => '0',
    -- Input clock control
    CLKFBIN             => clkfbout_buf,
    CLKIN               => clkin1);

  -- Output buffering
  -------------------------------------
  clkf_buf : BUFG
  port map
   (O => clkfbout_buf,
    I => clkfbout);

  clkout1_buf : BUFG
  port map
   (O   => clk250,
    I   => clkout0);

  clkout2_buf : BUFG
  port map
   (O   => clk125_0,
    I   => clkout1);

  clkout3_buf : BUFG
  port map
   (O   => clk125_90,
    I   => clkout2);

  clkout4_buf : BUFG
  port map
   (O   => clk125_180,
    I   => clkout3);

  clkout5_buf : BUFG
  port map
   (O   => clk125_270,
    I   => clkout4);

  clkout6_buf : BUFG
  port map
   (O   => clk_cpu,
    I   => clkout5);

  process (clkfbout_buf)
  begin
     if rising_edge(clkfbout_buf) then
        reset_o <= not w_locked;
     end if;
  end process;

  locked <= w_locked;
end xilinx;
