-- Outputs the 18.432 MHz clk used by UART16550

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

entity dds_18432 is 
	generic (cin_freq : real);
	port (
	cin : in std_logic;
	rst : in std_logic;
	cout_18432: out std_logic
);
end entity dds_18432;

architecture behaviour of dds_18432 is
	constant TARGET_FREQ : real := 18432000.0;
	-- Desired frequency of edges in cout
	constant TARGET_EDGE_FREQ : real := TARGET_FREQ * 2.0;
	-- Output the Nth bit of the counter to divide count by 2**N
	constant DIVISOR_EXP : integer := 10;

	constant STEP : integer := integer(round(TARGET_EDGE_FREQ * (2.0**DIVISOR_EXP) / cin_freq));

	signal dds_count : std_logic_vector(DIVISOR_EXP downto 0);
begin
	process(cin, rst)
	begin
		if rst = '1' then
			dds_count <= (others => '0');
		elsif rising_edge(cin) then
			dds_count <= dds_count + STEP;
		end if;
	end process;
	cout_18432 <= dds_count(DIVISOR_EXP);
end behaviour;
