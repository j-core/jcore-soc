library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

use work.ring_bus_pack.all;

entity rbus_device is port (
  clk : in std_logic;
  rst : in std_logic;
  a : in  rbus_dev_i_8b;
  y : out rbus_dev_o_8b);
end;
architecture x of rbus_device is
begin
  y.word <= IDLE_8B;
  y.mode <=  RECEIVE when a.en = '1' and a.word.fr = '1'
                     and to_cmd(a.word.d) = READ and to_hops(a.word.d) = 0
             else FORWARD;
end;

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

use work.ring_bus_pack.all;

entity ring_bus_tb is
end ring_bus_tb;

architecture tb of ring_bus_tb is
  signal clk : std_logic;
  signal rst : std_logic;

  signal cmd : rbus_cmd;
  signal hops : cmd_hops;

  type bus_wires_t is array(integer range <>) of rbus_8b;

  type dev_i_wires_t is array(integer range <>) of rbus_dev_i_8b;
  type dev_o_wires_t is array(integer range <>) of rbus_dev_o_8b;

  signal bus_wires : bus_wires_t(0 to 4);
  signal dev_i_wires : dev_i_wires_t(0 to 3);
  signal dev_o_wires : dev_o_wires_t(0 to 3);

begin
  rst  <= '1', '0' after 20 ns;
  clk  <= '0' after 10 ns when clk = '1' else '1' after 10 ns;

  nodes: for i in bus_wires'low to bus_wires'high - 1 generate
    node: rbus_node_8b port map(
      clk => clk, rst => rst,
      bus_i => bus_wires(i).word, stall_o => bus_wires(i).stall,
      bus_o => bus_wires(i+1).word, stall_i => bus_wires(i+1).stall,
      dev_o => dev_i_wires(i), dev_i => dev_o_wires(i));
  end generate;

  devs: for i in dev_i_wires'low to dev_i_wires'high generate
    rec: entity work.rbus_device port map(
      clk => clk, rst => rst,
      a => dev_i_wires(i), y => dev_o_wires(i));
  end generate;

  s : process
  begin

    cmd <= to_cmd("01111010");
    hops <= to_hops("00001010");

    bus_wires(bus_wires'high).stall <= '0';
    bus_wires(bus_wires'low).word <= cmd_word_8b(IDLE, 0);

    wait until falling_edge(rst);
    wait until rising_edge(clk);
    bus_wires(bus_wires'low).word <= cmd_word_8b(READ, 3);
    wait until rising_edge(clk);
    bus_wires(bus_wires'low).word <= data_word_8b(x"01");
    wait until rising_edge(clk);
    bus_wires(bus_wires'low).word <= data_word_8b(x"02");
    wait until rising_edge(clk);
    bus_wires(bus_wires'low).word <= data_word_8b(x"03");
    wait until rising_edge(clk);
    bus_wires(bus_wires'low).word <= cmd_word_8b(IDLE, 0);
    wait for 20 ns;
    wait;
  end process;
end;
