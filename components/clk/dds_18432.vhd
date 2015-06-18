-- dds_18432 is 18.432 MHz used  UART16550
-- The input is 50 MHz 

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.attr_pack.all;

entity dds_18432 is 
	generic (c_busperiod : integer := 40);
	port (
	cin_50mhz : in std_logic;
	rst_i : in std_logic;
	cout_18432: out std_logic
);
  attribute sei_port_global_name of cin_50mhz : signal is "clk_sys";
  attribute sei_port_global_name of rst_i : signal is "reset";
  attribute sei_port_global_name of cout_18432 : signal is "uart_ref_clk";
end entity dds_18432;

architecture behaviour of dds_18432 is
	function f_getddsval return integer is
	begin
		if c_busperiod = 32 then
			return 604;
		else
			return 755;
		end if;
	end function f_getddsval;
	constant ddsv : integer := f_getddsval;
	signal dds_count : std_logic_vector(10 downto 0);
begin
	-- assume cin_50mhz is 50 MHz we need 18.432 MHz clk for Baud rate generater
	process(cin_50mhz, rst_i)
	begin
		if rst_i = '1' then 
			dds_count <= (others => '0');
		elsif rising_edge(cin_50mhz) then
			dds_count <= dds_count + ddsv;
		end if;
	end process;
	cout_18432 <= dds_count(10);
end behaviour;
