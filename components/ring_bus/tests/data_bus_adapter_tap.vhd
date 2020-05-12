library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.test_pkg.all;
use work.cpu2j0_pack.all;
use work.ring_bus_pack.all;
use work.examples_pack.all;

entity data_bus_adapter_tap is
end;

architecture tb  of data_bus_adapter_tap is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal bus_i : rbus_word_8b := IDLE_8B;
  signal stall_o : std_logic := '0';

  signal bus_o : rbus_word_8b := IDLE_8B;
  signal stall_i : std_logic := '0';

  signal data_o : cpu_data_o_t;
  signal data_i : cpu_data_i_t;

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

  n : data_bus_adapter port map (
    clk => clk,
    rst => rst,
    bus_i => bus_i,
    stall_o => stall_o,
    bus_o => bus_o,
    stall_i => stall_i,
    data_o => data_o,
    data_i => data_i,
    irq => irq
  );

  process
  begin
    data_i.ack <= '0';
    data_i.d <= x"00000000";
    wait until rising_edge(data_o.en);
    if data_o.rd = '1' then
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      data_i.d <= x"1a2b3c4d";
      data_i.ack <= '1';
      wait until rising_edge(clk);
    elsif data_o.wr = '1' then
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      data_i.ack <= '1';
      wait until rising_edge(clk);
    end if;
  end process;

  process
  begin
    test_plan(20, "data_bus_adapter_tap");
    wait for 10 ns;
    rst <= '0';
    wait until rising_edge(clk);

    test_comment("address command");
    wait until rising_edge(clk);
    bus_i <= cmd_word_8b(OFFSET, 1);
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"01");
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"02");
    irq <= '1';
    wait until rising_edge(clk);
    bus_i <= cmd_word_8b(BUSY, 0);
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"03");
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"04");
    wait until rising_edge(clk);
    --bus_i <= data_word_8b(x"05");
    --wait until rising_edge(clk);
    bus_i <= IDLE_8B;
    wait until rising_edge(clk);
    wait for 1 ns;
    test_equal(bus_o, cmd_word_8b(INTERRUPT, 15), "INTERRUPT sent");

    test_comment("READ command");
    test_ok(data_o.en = '0', "EN low before read");
    bus_i <= cmd_word_8b(READ, 1);
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"00");
    wait for 1 ns;
    test_equal(data_o.en, '1', "EN high after read");
    test_equal(data_o.a, x"01020304", "read address");
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"00");
    test_equal(bus_o, cmd_word_8b(WRITE, 15), "WRITE reply to READ");
    wait until rising_edge(clk);
    test_equal(stall_o, '1', "Stalling during read 1");
    wait until rising_edge(clk);
    test_equal(stall_o, '1', "Stalling during read 2");
    wait until rising_edge(clk);
    test_equal(stall_o, '0', "Stalling after read");
    bus_i <= data_word_8b(x"00");
    test_equal(bus_o, data_word_8b(x"1a"), "reply to READ data 1");
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"00");
    test_equal(bus_o, data_word_8b(x"2b"), "reply to READ data 2");
    wait until rising_edge(clk);
    
    bus_i <= cmd_word_8b(IDLE, 0);
    test_equal(bus_o, data_word_8b(x"3c"), "reply to READ data 3");
    wait until rising_edge(clk);

    bus_i <= cmd_word_8b(IDLE, 0);
    test_equal(bus_o, data_word_8b(x"4d"), "reply to READ data 4");
    wait until rising_edge(clk);

    wait until rising_edge(clk);
    wait until rising_edge(clk);

    test_comment("WRITE");
    test_equal(data_o.en, '0', "EN low before write");
    bus_i <= cmd_word_8b(WRITE, 1);
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"32");
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"ab");
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"cd");
    test_equal(data_o.en, '0', "EN low during write");
    wait until rising_edge(clk);
    bus_i <= cmd_word_8b(IDLE, 0);
    wait until rising_edge(clk);
    wait for 1 ns;
    test_equal(data_o.en, '1', "EN high when write issued");
    test_equal(data_o.d, x"0032abcd", "write data");
    test_equal(data_o.a, x"01020304", "write address");
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    bus_i <= cmd_word_8b(OFFSET, 1);
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"04");
    wait until rising_edge(clk);
    bus_i <= cmd_word_8b(IDLE, 0);

    bus_i <= cmd_word_8b(WRITE, 1);
    wait until rising_edge(clk);
    bus_i <= data_word_8b(x"42");
    wait until rising_edge(clk);
    bus_i <= cmd_word_8b(IDLE, 0);
    wait until rising_edge(clk);
    wait for 1 ns;
    test_equal(data_o.en, '1', "EN high when write issued");
    test_equal(data_o.d, x"00000042", "write data");
    test_equal(data_o.a, x"00000004", "write address");

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    irq <= '0';
    wait until rising_edge(clk);
    irq <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    test_finished("done");
    wait for 40 ns;
    ENDSIM := true;
    wait;
    end process;
end tb;
