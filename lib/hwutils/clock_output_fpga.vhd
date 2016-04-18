-- A clock output that uses a DDR output with hardcoded data inputs 1 and 0 to
-- output the clock edges.

-- These architectures are not in clock_output.vhd so that that file can be
-- included in simulations without where unisim doesn't exist.

library unisim;
use unisim.vcomponents.all;
architecture spartan6 of clock_output is
begin
  o : ODDR2
    generic map (
      DDR_ALIGNMENT => "NONE",
      SRTYPE => "ASYNC")
    port map (
      Q  => q,
      C0 => clk,
      C1 => not clk,
      CE => '1',
      D0 => '1',
      D1 => '0',
      R  => rst,
      S  => '0');
end architecture;

library unisim;
use unisim.vcomponents.all;
architecture kintex7 of clock_output is
begin
  o : ODDR
    generic map (
      DDR_CLK_EDGE => "OPPOSITE_EDGE",
      SRTYPE => "ASYNC")
    port map (
      Q  => q,
      C  => clk,
      CE => '1',
      D1 => '1',
      D2 => '0',
      R  => rst,
      S  => '0');
end architecture;
