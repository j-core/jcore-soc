library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity syncff is
	port (clk : in std_logic;
		reset : in std_logic;
		sin : in std_logic;
		sout : out std_logic);
end syncff;

architecture rtl of syncff is 
	signal wire : std_logic;
begin
	process(clk, reset)
	begin
		if reset = '1' then
			sout <= '0';
			wire <= '0';
		elsif rising_edge(clk) then
			wire <= sin;
			sout <= wire;
		end if;
	end process;
end architecture rtl;

