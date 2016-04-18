-- Creates a DDR output with implementations for different platforms.
--
-- TODO: Ensure Kintex7 and Spartan6 implementations behave the same for all
-- the supported generics.

-- These architectures are not in ddr_output.vhd so that that file can be
-- included in simulations without where unisim doesn't exist.

library unisim;
use unisim.vcomponents.all;
architecture spartan6 of ddr_output is
  function convert_alignment(align : string)
    return string is
  begin
    if align = "OPPOSITE_EDGE" then
      return "NONE";
    elsif align = "SAME_EDGE" then
      return "C0";
    else
      -- TODO: how to signal an error here?
      return "";
    end if;
  end;
  signal clkn : std_logic;
begin
  clkn <= not clk;
  o : ODDR2
    generic map (
      DDR_ALIGNMENT => convert_alignment(DDR_ALIGNMENT),
      INIT => to_bit(INIT),
      SRTYPE => SRTYPE)
    port map (
      Q  => q,
      C0 => clk,
      C1 => clkn,
      CE => '1',
      D0 => d1,
      D1 => d2,
      R  => rst,
      S  => '0');
end architecture;

library unisim;
use unisim.vcomponents.all;
architecture kintex7 of ddr_output is
begin
  o : ODDR
    generic map (
      DDR_CLK_EDGE => DDR_ALIGNMENT,
      INIT => to_bit(INIT),
      SRTYPE => SRTYPE)
    port map (
      Q  => q,
      C => clk,
      CE => '1',
      D1 => d1,
      D2 => d2,
      R  => rst,
      S  => '0');
end architecture;
