-- Creates a DDR input with implementations for different platforms.
--
-- TODO: Ensure Kintex7 and Spartan6 implementations behave the same for all
-- the supported generics.

-- These architectures are not in ddr_input.vhd so that that file can be
-- included in simulations without where unisim doesn't exist.

library unisim;
use unisim.vcomponents.all;
architecture spartan6 of ddr_input is
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
  i : IDDR2
    generic map (
      DDR_ALIGNMENT => convert_alignment(DDR_ALIGNMENT),
      INIT_Q0 => to_bit(INIT_Q1),
      INIT_Q1 => to_bit(INIT_Q2),
      SRTYPE => SRTYPE)
    port map (
      D  => d,
      C0 => clk,
      C1 => clkn,
      CE => '1',
      Q0 => q1,
      Q1 => q2,
      R  => rst,
      S  => '0');
end architecture;

library unisim;
use unisim.vcomponents.all;
architecture kintex7 of ddr_input is
begin
  i : IDDR
    generic map (
      DDR_CLK_EDGE => DDR_ALIGNMENT,
      INIT_Q1 => to_bit(INIT_Q1),
      INIT_Q2 => to_bit(INIT_Q2),
      SRTYPE => SRTYPE)
    port map (
      D  => d,
      C => clk,
      CE => '1',
      Q1 => q1,
      Q2 => q2,
      R  => rst,
      S  => '0');
end architecture;
