-- On FPGAs, a signal can be explicitly connected to a global net to which is
-- used for high fanout signals like clocks. In simulation or ASIC synthesis,
-- this is a simple signal assignment.

library ieee;
use ieee.std_logic_1164.all;

entity global_buffer is
  port (
    i : in  std_logic;
    o : out std_logic);
end entity;

architecture simple of global_buffer is
begin
  o <= i;
end architecture;
