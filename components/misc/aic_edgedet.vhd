-- This entity detect source of IRQ rising edge and latch it until clear signal assert

library ieee;
use ieee.std_logic_1164.all;

entity aic_edgedet is port (
	q : out std_logic := '0';
	clk : in std_logic;
	rst : in std_logic;
	irq : in std_logic;
	en_i : in std_logic;
	clr_i : in std_logic);
end entity aic_edgedet;

architecture beh of aic_edgedet is 
	signal reg0, reg1 : std_logic := '0';
	signal w_edge : std_logic := '0';
begin
	process(clk, rst)
	begin
		if rst = '1' then
			reg0 <= '0';
			reg1 <= '0';
			q <= '0';
		elsif rising_edge(clk) then
			reg0 <= irq;
			reg1 <= reg0;
			if w_edge = '1' then
				q <= en_i;
			elsif clr_i = '1' then
				q <= '0';
			end if;
		end if;
	end process;
	w_edge <= '1' when reg1 = '0' and reg0 = '1' else
		  '0';

end beh;
