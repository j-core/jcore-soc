-- For SGM Spartan 6, it is DCM_SP
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library unisim;
use unisim.vcomponents.all;

entity ddr_clkgen is
    Port ( clk_i    : in  std_logic;
           clk0_o   : out std_logic;
           clk90_o  : out std_logic;
           clk180_o : out std_logic;
           clk2x_o  : out std_logic;
           clk125_o : out std_logic;
	   reset_i  : in  std_logic;
           locked   : out std_logic);
end ddr_clkgen;

architecture interface of ddr_clkgen is

signal dll_loop, dll_loop_buf : std_logic;
signal dll_90 : std_logic;
signal dll_180 : std_logic;
signal dll_2x : std_logic;
signal dll_125 : std_logic;
signal z, clk_b : std_logic;
signal w_dcmrsti, w_locked : std_logic;
signal status : std_Logic_vector(7 downto 0);

attribute keep : string;
attribute keep of w_locked : signal is "true";
begin
	-- Xilinx HDL Libraries Guide Version 8.1i
	DCM_inst : DCM_SP
	generic map (
	CLKDV_DIVIDE => 2.0, -- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
	-- 7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
	CLKFX_DIVIDE => 1, -- Can be any interger from 1 to 32
	CLKFX_MULTIPLY => 4, -- Can be any Integer from 1 to 32
	CLKIN_DIVIDE_BY_2 => FALSE, -- TRUE/FALSE to enable CLKIN divide by two feature
	CLKIN_PERIOD => 32.0, -- Specify period of input clock
	CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift of NONE, FIXED or VARIABLE
	CLK_FEEDBACK => "1X", -- Specify clock feedback of NONE, 1X or 2X
	DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or
	-- an Integer from 0 to 15
	DFS_FREQUENCY_MODE => "LOW", -- HIGH or LOW frequency mode for frequency synthesis
	DLL_FREQUENCY_MODE => "LOW", -- HIGH or LOW frequency mode for DLL
	DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
	PHASE_SHIFT => 0, -- Amount of fixed phase shift from -255 to 255
	STARTUP_WAIT => FALSE) -- Delay configuration DONE until DCM_SP LOCK, TRUE/FALSE
	port map (
	CLK0 => dll_loop, -- 0 degree DCM_SP CLK ouptput
	CLK90 => dll_90, -- 90 degree DCM_SP CLK output
	CLK180 => dll_180, -- 180 degree DCM_SP CLK output
	CLK270 => open, -- 270 degree DCM_SP CLK output
	CLK2X => dll_2x, -- 2X DCM_SP CLK output
	CLK2X180 => open, -- 2X, 180 degree DCM_SP CLK out
	CLKDV => open, -- Divided DCM_SP CLK out (CLKDV_DIVIDE)
	CLKFX => dll_125, -- DCM_SP CLK synthesis out (M/D)
	CLKFX180 => open, -- 180 degree CLK synthesis out
	LOCKED => w_locked, -- DCM_SP LOCK status output
	PSDONE => open, -- Dynamic phase adjust done output
	STATUS => status, -- 8-bit DCM_SP status bits output
	CLKFB => dll_loop_buf, -- DCM_SP clock feedback
	CLKIN => clk_b, -- Clock input (from IBUFG, BUFG or DCM_SP)
	PSCLK => z, -- Dynamic phase adjust clock input
	PSEN => z, -- Dynamic phase adjust enable input
	PSINCDEC => z, -- Dynamic phase adjust increment/decrement
	RST => w_dcmrsti -- DCM_SP asynchronous reset input
	);
	z <= '0';
	w_dcmrsti <= ((not w_locked) and status(2)) or reset_i;
        clk0_o  <= dll_loop_buf;

        clk_b <= clk_i;
	--u_ibuf : IBUF port map (O => clk_b, I => clk_i);
	u_0buf   : BUFG port map(O => dll_loop_buf, I => dll_loop);
	u_90buf  : BUFG port map(O => clk90_o, I => dll_90);
	u_180buf : BUFG port map(O => clk180_o, I => dll_180);
	u_2xbuf  : BUFG port map(O=> clk2x_o, I => dll_2x);
	u_125buf : BUFG port map(O=> clk125_o, I => dll_125);
	
        locked <= w_locked;

end interface;

