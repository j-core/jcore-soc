library ieee;
use ieee.std_logic_1164.all;
use work.attr_pack.all;

-- A simple entity to set reset. Made this entity so soc_gen tool can easily
-- create the reset. Likely this should be either replaced by a procedure or
-- function (requires extending the tool to understand procedures and
-- functions).
entity reset_gen is
  port (
    reset         : out std_logic;
    clock_locked0 : in  std_logic;
    clock_locked1 : in  std_logic);
  -- synopsys translate_off
  group global_sigs : global_ports(
    reset,
    clock_locked0,
    clock_locked1);
-- synopsys translate_on
end entity;

architecture arch of reset_gen is
  --function and_reduce(bits : in std_logic_vector) return std_logic is
  --  variable r : std_logic := '1';
  --begin
  --  for i in bits'range loop
  --    r := r and bits(i);
  --  end loop;
  --  return r;
  --end function;
begin
  reset <= not (clock_locked0 and clock_locked1);
end architecture;
