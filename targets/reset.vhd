library ieee;
use ieee.std_logic_1164.all;

-- A simple entity to set reset. Made this entity so soc_gen tool can easily
-- create the reset. Likely this should be either replaced by a procedure or
-- function (requires extending the tool to understand procedures and
-- functions).
entity reset_gen is
  port (
    reset        : out std_logic;
    clock_locked : in std_logic);
  -- synopsys translate_off
  group global_sigs : global_ports(
    reset,
    clock_locked);
  -- synopsys translate_on
end entity;

architecture arch of reset_gen is
begin
  reset <= not clock_locked;
end architecture;
