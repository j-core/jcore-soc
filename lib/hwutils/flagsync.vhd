-- Pass a 1-cycle pulse between clock domains
-- Inspired by http://www.fpga4fun.com/CrossClockDomain2.html
-- If inA pulses are too close together and frequency of clkA is higher than
-- clkB, then not every pulse will be replicated in outB
library ieee;
use ieee.std_logic_1164.all;

entity flagsync is
  port (rst  : in  std_logic;
        clkA : in  std_logic;
        inA  : in  std_logic;
        clkB : in  std_logic;
        outB : out std_logic);
end;

architecture rtl of flagsync is
  -- clock domain A
  signal toggleA : std_logic;

  -- clock domain B
  signal toggleB : std_logic;
  signal old_toggleB : std_logic;
begin

  -- change pulse to a level toggle
  process(clkA, rst, inA, toggleA)
  begin
    if rst = '1' then
      toggleA <= '0';
    elsif rising_edge(clkA) then
      toggleA <= toggleA xor inA;
    end if;
  end process;

  -- move toggle signal to domain B
  sync : entity work.sync2ff(rtl)
    port map (
      clk => clkB,
      reset => rst,
      sin => toggleA,
      sout => toggleB
    );

  -- change toggle back to a pulse
  process(clkB, rst, toggleB, old_toggleB)
  begin
    if rst = '1' then
      old_toggleB <= '0';
      outB <= '0';
    elsif rising_edge(clkB) then
      old_toggleB <= toggleB;
      outB <= toggleB xor old_toggleB;
    end if;
  end process;
end;
