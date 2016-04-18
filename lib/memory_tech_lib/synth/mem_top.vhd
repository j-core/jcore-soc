library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_test_pack.all;

entity mem_top is
  port (
    rst0 : in std_logic;
    clk0 : in std_logic;
    rst1 : in std_logic;
    clk1 : in std_logic;
    select_mem : in mem_type;
    p0 : in mem_port;
    p1 : in mem_port;
    dr0 : out data_array_t;
    dr1 : out data_array_t;
    dr2 : out data_array_t;
    dr3 : out data_array_t);
end entity;

architecture tb of mem_top is
  for m0 : memories use configuration work.memories_inferred;
  for m1 : memories use configuration work.memories_mems;
begin

  m0: memories
    port map (
      rst0 => rst0,
      clk0 => clk0,
      rst1 => rst1,
      clk1 => clk1,
      select_mem => select_mem,
      p0 => p0,
      p1 => p1,
      dr0 => dr0,
      dr1 => dr1);

  m1: memories
    port map (
      rst0 => rst0,
      clk0 => clk0,
      rst1 => rst1,
      clk1 => clk1,
      select_mem => select_mem,
      p0 => p0,
      p1 => p1,
      dr0 => dr2,
      dr1 => dr3);

end architecture;
