library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.test_pkg.all;
use work.cpu2j0_pack.all;
use work.ring_bus_pack.all;
use work.examples_pack.all;

entity rbus_data_master_tap is
end;

architecture tb of rbus_data_master_tap is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal bus_start : rbus_word_8b := IDLE_8B;
  signal stall_start : std_logic := '0';

  signal bus_end : rbus_word_8b := IDLE_8B;
  signal stall_end : std_logic := '0';

  signal master_data_o : cpu_data_o_t := NULL_DATA_O;
  signal master_data_i : cpu_data_i_t := (ack => '0', d => (others => '0'));

  signal slave_data_o : cpu_data_o_t := NULL_DATA_O;
  signal slave_data_i : cpu_data_i_t := (ack => '0', d => (others => '0'));

  signal irq : std_logic := '0';

  shared variable ENDSIM : boolean := false;

  procedure test_equal(actual, expected : rbus_word_8b; desc : string := ""; directive : string := "") is
    variable ok : boolean;
  begin
    ok := (actual.fr = expected.fr) and (actual.d = expected.d);
    test_ok(ok, desc, directive);
  end procedure;
begin

  clk_gen : process
  begin
    if ENDSIM = false then
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    else
      wait;
    end if;
  end process;

  m : rbus_data_master port map (
    clk => clk,
    rst => rst,
    data_i => master_data_o,
    data_o => master_data_i,
    bus_o => bus_start,
    stall_i => stall_start,
    bus_i => bus_end,
    stall_o => stall_end
  );

  n : data_bus_adapter port map (
    clk => clk,
    rst => rst,
    bus_i => bus_start,
    stall_o => stall_start,
    bus_o => bus_end,
    stall_i => stall_end,
    data_o => slave_data_o,
    data_i => slave_data_i,
    irq => irq
  );

  process
  begin
    slave_data_i.ack <= '0';
    slave_data_i.d <= x"00000000";
    wait until rising_edge(slave_data_o.en);
    if slave_data_o.rd = '1' then
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      slave_data_i.d <= x"1a2b3c4d";
      slave_data_i.ack <= '1';
      wait until rising_edge(clk);
    elsif slave_data_o.wr = '1' then
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      slave_data_i.ack <= '1';
      wait until rising_edge(clk);
    end if;
  end process;

  process
  begin
    test_plan(9, "rbus_data_master_tap");
    wait for 10 ns;
    rst <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    test_comment("READ");
    master_data_o.en <= '1';
    master_data_o.rd <= '1';
    master_data_o.a <= x"12345678";

    wait until rising_edge(slave_data_o.en);
    test_equal(slave_data_o.rd, '1', "is read");
    test_equal(slave_data_o.wr, '0', "is not write");
    test_equal(slave_data_o.a, x"12345678", "read address");

    wait until rising_edge(master_data_i.ack);
    test_equal(master_data_i.d, x"1a2b3c4d", "read data");

    master_data_o.en <= '0';
    master_data_o.rd <= '0';

    wait until rising_edge(clk);
    wait until rising_edge(clk);

    test_comment("WRITE");
    master_data_o.en <= '1';
    master_data_o.wr <= '1';
    master_data_o.a <= x"12345678";
    master_data_o.d <= x"8090a0b0";

    wait until rising_edge(master_data_i.ack);
    master_data_o.en <= '0';
    master_data_o.wr <= '0';

    wait until rising_edge(slave_data_o.en);
    test_equal(slave_data_o.wr, '1', "is write");
    test_equal(slave_data_o.rd, '0', "is not read");
    test_equal(slave_data_o.a, x"12345678", "write address");
    test_equal(slave_data_o.d, x"8090a0b0", "write data");
    test_equal(slave_data_o.we, "1111", "write enable");

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    test_finished("done");
    wait for 40 ns;
    ENDSIM := true;
    wait;
    end process;
end tb;
