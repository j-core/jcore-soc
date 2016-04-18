-- Cross a wide unsigned signal across a clock domain using gray encoding. The
-- input signal 'a' should only change by +1 or-1 so that at most one bit
-- changes in the gray encoded representation each cycle.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity syncgray is
  generic (
    WIDTH : natural);
  port (
    clkA : in  std_logic;
    clkB : in  std_logic;
    rst : in  std_logic;
    a   : in  unsigned(WIDTH-1 downto 0);
    y   : out unsigned(WIDTH-1 downto 0));
end;

use work.gray_pack.all;

architecture arch of syncgray is
  signal gray  : gray_vector(WIDTH-1 downto 0);
  signal sync  : gray_vector(WIDTH-1 downto 0);
  signal guard : gray_vector(WIDTH-1 downto 0);
begin
  process(clkA, rst)
  begin
    if rst = '1' then
      gray  <= (others => '0');
    elsif rising_edge(clkA) then
      -- Convert input to gray encoding and register in source clk domain.
      -- This is so there's no combo logic between output of registered gray
      -- encoding in clk domain A and registering in clk domain B
      gray <= to_gray_vector(std_logic_vector(a));
    end if;
  end process;

  process(clkB, rst)
  begin
    if rst = '1' then
      sync  <= (others => '0');
      guard <= (others => '0');
    elsif rising_edge(clkB) then
      sync  <= gray; -- first synch register
      guard <= sync; -- second synch register for meta stable protection
    end if;
  end process;

  y <= unsigned(to_std_logic_vector(guard));
end;
