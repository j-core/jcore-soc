library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.test_pkg.all;
use work.ring_bus_pack.all;

entity node_tap is
end;

architecture tb  of node_tap is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal bus_i : rbus_word_8b := IDLE_8B;
  signal stall_o : std_logic := '0';

  signal bus_o : rbus_word_8b := IDLE_8B;
  signal stall_i : std_logic := '0';

  signal dev_i : rbus_dev_i_8b := (word => IDLE_8B, en => '0', ack => '0');
  signal dev_o : rbus_dev_o_8b := (mode => FORWARD, word => IDLE_8B);

  shared variable ENDSIM : boolean := false;

  procedure test_equal(actual, expected : rbus_word_8b; desc : string := ""; directive : string := "") is
    variable ok : boolean;
  begin
    ok := (actual.fr = expected.fr) and (actual.d = expected.d);
    test_ok(ok, desc, directive);
  end procedure;

  procedure step_bus(
    signal dev_o : out rbus_dev_o_8b;
    output : rbus_word_8b;

    dev_out : rbus_word_8b;
    dev_en : std_logic := '1';
    dev_in : rbus_word_8b := IDLE_8B;
    dev_ack : std_logic := 'U';
    mode : rbus_node_mode;

    desc : string := "";
    directive : string := ""
  ) is
    variable ok_dev_en : boolean;
    variable ok_dev_d : boolean;
    variable ok_bus_o : boolean;
    variable ok_ack : boolean;
  begin
    wait until falling_edge(clk);
    ok_dev_en := dev_i.en = dev_en;
    ok_dev_d := dev_i.word = dev_out;
    ok_bus_o := bus_o = output;

    dev_o.word <= dev_in;
    dev_o.mode <= mode;
    wait until rising_edge(clk);

    if dev_ack = 'U' then
      ok_ack := true;
    else
      ok_ack := dev_i.ack = dev_ack;
    end if;

    test_ok(ok_dev_en and ok_dev_d and ok_bus_o and ok_ack, desc, directive);
    if not ok_dev_en then
      test_comment("dev_i.en mismatch " & time'image(now));
    end if;
    if not ok_dev_d then
      test_comment("dev_i.word mismatch " & time'image(now));
    end if;
    if not ok_ack then
      test_comment("dev_i.ack mismatch " & time'image(now));
    end if;
    if not ok_bus_o then
      test_comment("bus output mismatch " & time'image(now));
    end if;
  end procedure;

  procedure step_bus(
    signal dev_o : out rbus_dev_o_8b;
    output : rbus_word_8b;

    desc : string := "";
    directive : string := ""
  ) is
    variable ok_dev_en : boolean;
    variable ok_bus_o : boolean;
    variable ok_ack : boolean;
  begin
    wait until falling_edge(clk);
    ok_dev_en := dev_i.en = '0';
    ok_ack := dev_i.ack = '0';
    ok_bus_o := bus_o = output;
    dev_o <= (mode => FORWARD, word => IDLE_8B);
    wait until rising_edge(clk);

    test_ok(ok_dev_en and ok_bus_o and ok_ack, desc, directive);
    if not ok_dev_en then
      test_comment("dev_i.en not 0 " & time'image(now));
    end if;
    if not ok_ack then
      test_comment("dev_i.ack not 0 " & time'image(now));
    end if;
    if not ok_bus_o then
      test_comment("bus output mismatch " & time'image(now));
    end if;
  end procedure;

  procedure step_bus_idle(
    signal dev_o : out rbus_dev_o_8b
  ) is
  begin
    wait until falling_edge(clk);
    dev_o <= (mode => FORWARD, word => IDLE_8B);
    wait until rising_edge(clk);
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

  n : rbus_node_8b port map (
    clk => clk,
    rst => rst,
    bus_i => bus_i,
    stall_o => stall_o,
    bus_o => bus_o,
    stall_i => stall_i,
    dev_o => dev_i,
    dev_i => dev_o
  );

  process
  begin
    test_plan(62, "node8b");
    wait for 10 ns;
    rst <= '0';
    wait until rising_edge(clk);

    test_comment("FORWARD a read command");
    bus_i <= cmd_word_8b(READ, 2) after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => FORWARD,
      dev_out => cmd_word_8b(READ, 1),
      dev_ack => '0',
      desc    => "forward read cmd in");

    bus_i <= cmd_word_8b(TSEQ, 3) after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(READ, 1),
      desc    => "forward TSEQ without passing to device");
    bus_i <= cmd_word_8b(TSTAMP, 3) after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(TSEQ, 3),
      desc    => "forward TSTAMP without passing to device - TSEQ hops unchanged");
    bus_i <= data_word_8b(x"11") after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(TSTAMP, 3),
      desc    => "forward read data 1 in - TSTAMP hops unchanged");
    bus_i <= cmd_word_8b(BUSY, 5) after 1 ns;
    step_bus(
      dev_o,
      output  => data_word_8b(x"11"),
      desc    => "forward BUSY without passing to device");
    bus_i <= data_word_8b(x"22") after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(BUSY, 5),
      desc    => "forward read data 2 in - BUSY hops unchanged");
    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => data_word_8b(x"22"),
      mode    => FORWARD,
      dev_out => IDLE_8B,
      dev_ack => '0',
      desc    => "forward read data 2 out");
    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => FORWARD,
      dev_out => IDLE_8B,
      desc    => "after forward read idle out");

    step_bus_idle(dev_o);

    test_comment("RECEIVE a read command outputting IDLE");
    bus_i <= cmd_word_8b(READ, 2) after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => RECEIVE,
      dev_out => cmd_word_8b(READ, 1),
      desc    => "receive read cmd in");
    --bus_i <= cmd_word_8b(BUSY, 0) after 1 ns;
    --step_bus(
    --  dev_o,
    --  output  => IDLE_8B,
    --  desc    => "BUSY cmd not passed to device");
    bus_i <= data_word_8b(x"11") after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => RECEIVE,
      dev_out => data_word_8b(x"11"),
      desc    => "receive read data 1 in");
    bus_i <= data_word_8b(x"22") after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => RECEIVE,
      dev_out => data_word_8b(x"22"),
      desc    => "receive read data 2 in");
    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => FORWARD,
      dev_out => IDLE_8B,
      desc    => "receive read data 2 out");
    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => FORWARD,
      dev_out => IDLE_8B,
      desc    => "after receive read idle out");

    step_bus_idle(dev_o);

    test_comment("RECEIVE a read command outputting WRITE");
    bus_i <= cmd_word_8b(READ, 1) after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => RECEIVE,
      dev_out => cmd_word_8b(READ, 0),
      dev_in  => cmd_word_8b(WRITE, 15),
      dev_ack => '1',
      desc    => "receive read cmd in");
    bus_i <= data_word_8b(x"11") after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(WRITE, 15),
      mode    => RECEIVE,
      dev_out => data_word_8b(x"11"),
      dev_in  => data_word_8b(x"01"),
      dev_ack => '1',
      desc    => "receive read data 1 in");
    bus_i <= data_word_8b(x"22") after 1 ns;
    step_bus(
      dev_o,
      output  => data_word_8b(x"01"),
      mode    => RECEIVE,
      dev_out => data_word_8b(x"22"),
      dev_in  => data_word_8b(x"02"),
      dev_ack => '1',
      desc    => "receive read data 2 in");
    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => data_word_8b(x"02"),
      mode    => FORWARD,
      dev_out => IDLE_8B,
      dev_ack => '0',
      desc    => "receive read data 2 out");
    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => FORWARD,
      dev_out => IDLE_8B,
      dev_ack => '0',
      desc    => "after receive read idle out");

    test_comment("External stall node");
    bus_i <= cmd_word_8b(REG, 2) after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => FORWARD,
      dev_out => cmd_word_8b(REG, 1),
      desc    => "receive read cmd in");
    bus_i <= cmd_word_8b(READ, 1) after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(REG, 1),
      mode    => FORWARD,
      dev_out => cmd_word_8b(READ, 0),
      desc    => "receive read cmd in");
    stall_i <= '1' after 1 ns;
    bus_i <= cmd_word_8b(OFFSET, 10) after 1 ns;
    -- READ 10 should be queued inside node
    step_bus(
      dev_o,
      output  => cmd_word_8b(READ, 0),
      desc    => "word to device stalled");
    stall_i <= '0' after 1 ns;
    bus_i <= cmd_word_8b(BROADCAST, 5) after 1 ns;
    wait for 1 ns;
    test_equal(stall_o, '1', "stall signal passed through");
    -- dropping stall_i should allow stalled READ 10 to go through
    step_bus(
      dev_o,
      output  => cmd_word_8b(READ, 0),
      mode    => FORWARD,
      dev_out => cmd_word_8b(OFFSET, 9),
      desc    => "stalled device passed through");

    wait for 1 ns;
    test_equal(stall_o, '0', "stopped stalling");
    step_bus(
      dev_o,
      output  => cmd_word_8b(OFFSET, 9),
      mode    => FORWARD,
      dev_out => cmd_word_8b(BROADCAST, 4),
      desc    => "after stall");

    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(BROADCAST, 4),
      mode    => FORWARD,
      dev_out => IDLE_8B,
      desc    => "held input goes through once");

    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => FORWARD,
      dev_out => IDLE_8B,
      desc    => "held input goes through only once");

    step_bus_idle(dev_o);
    step_bus_idle(dev_o);


    test_comment("Stall drops IDLE and BUSY");
    bus_i <= cmd_word_8b(REG, 2) after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => FORWARD,
      dev_out => cmd_word_8b(REG, 1),
      desc    => "Start by sending REG");
    stall_i <= '1' after 1 ns;
    bus_i <= cmd_word_8b(BUSY, 0) after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(REG, 1),
      desc    => "stalled REG - sending BUSY");

    wait for 1 ns;
    test_equal(stall_o, '0', "stall_o stays low because BUSY sent");

    bus_i <= cmd_word_8b(IDLE, 0) after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(REG, 1),
      desc    => "stalled REG - IDLE");

    wait for 1 ns;
    test_equal(stall_o, '0', "stall_o stays low because IDLE sent");


    bus_i <= cmd_word_8b(READ, 3) after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(REG, 1),
      desc    => "stalled REG - READ");

    wait for 1 ns;
    test_equal(stall_o, '1', "stall_o goes high to queue READ msg");

    stall_i <= '0' after 1 ns;

    -- dropping stall_i should allow stalled READ 10 to go through
    step_bus(
      dev_o,
      output  => cmd_word_8b(REG, 1),
      mode    => FORWARD,
      dev_out => cmd_word_8b(READ, 2),
      desc    => "stalled cmd passed through");

    wait for 1 ns;
    test_equal(stall_o, '0', "stopped stalling");

    bus_i <= IDLE_8B after 1 ns;

    step_bus(
      dev_o,
      output  => cmd_word_8b(READ, 2),
      mode    => FORWARD,
      dev_out => IDLE_8B,
      desc    => "stalled device passed through");

    step_bus_idle(dev_o);
    step_bus_idle(dev_o);


    test_comment("test SNOOP mode");
    bus_i <= cmd_word_8b(READ, 2) after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => SNOOP,
      dev_out => cmd_word_8b(READ, 1),
      dev_ack => '0',
      desc    => "snoop read cmd in");

    bus_i <= cmd_word_8b(TSEQ, 3) after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(READ, 1),
      mode    => FORWARD, -- mode change should be ignored
      dev_out => cmd_word_8b(TSEQ, 3),
      dev_ack => '0',
      desc    => "snoop TSEQ with snoop");
    bus_i <= data_word_8b(x"11") after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(TSEQ, 3),
      mode    => FORWARD, -- mode change should be ignored
      dev_out => data_word_8b(x"11"),
      dev_ack => '0',
      desc    => "snoop data 1 in - TSEQ hops unchanged");
    bus_i <= cmd_word_8b(BUSY, 5) after 1 ns;
    step_bus(
      dev_o,
      output  => data_word_8b(x"11"),
      mode    => FORWARD, -- mode change should be ignored
      dev_out => cmd_word_8b(BUSY, 5),
      dev_ack => '0',
      desc    => "snoop BUSY");
    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(BUSY, 5),
      mode    => FORWARD, -- mode change should be ignored
      dev_out => IDLE_8B,
      dev_ack => '0',
      desc    => "snoop data 2 out");
    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => RECEIVE,
      dev_out => IDLE_8B,
      dev_ack => '1',
      desc    => "after snoop read idle out");

    step_bus_idle(dev_o);
    step_bus_idle(dev_o);

    test_comment("Test TRANSMIT");
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => TRANSMIT,
      dev_out => IDLE_8B,
      dev_ack => '1',
      desc    => "start transmit");
    wait for 1 ns;
    test_equal(stall_o, '0', "stalling remains low with idle inputs");
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => TRANSMIT,
      dev_out => IDLE_8B,
      dev_in  => cmd_word_8b(READ, 3),
      dev_ack => '1',
      desc    => "transmit with idle input");
    wait for 1 ns;
    test_equal(stall_o, '0', "stalling remains low with idle inputs");
    step_bus(
      dev_o,
      output  => cmd_word_8b(READ, 3),
      mode    => TRANSMIT,
      dev_out => IDLE_8B,
      dev_in  => data_word_8b(x"01"),
      dev_ack => '1',
      desc    => "transmit with idle input again");
    bus_i <= cmd_word_8b(WRITE,4) after 1 ns;
    wait for 1 ns;
    test_equal(stall_o, '0', "stalling remains low with idle inputs");
    step_bus(
      dev_o,
      output  => data_word_8b(x"01"),
      mode    => TRANSMIT,
      dev_out => cmd_word_8b(WRITE, 3),
      dev_in  => data_word_8b(x"02"),
      dev_ack => '1',
      desc    => "start transmit");
    wait for 1 ns;
    test_equal(stall_o, '1', "stalling goes high with non-idle input during trasmit");
    step_bus(
      dev_o,
      output  => data_word_8b(x"02"),
      mode    => RECEIVE,
      dev_out => cmd_word_8b(WRITE, 3),
      dev_in  => data_word_8b(x"03"),
      dev_ack => '1',
      desc    => "switch to RECEIVE");
    wait for 1 ns;
    test_equal(stall_o, '0', "switching to receive dropped stall_o");

    bus_i <= IDLE_8B after 1 ns;
    step_bus_idle(dev_o);
    step_bus_idle(dev_o);
    step_bus_idle(dev_o);

    test_comment("Switch from RECEIVE to TRANSMIT");
    bus_i <= cmd_word_8b(READ, 1) after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => RECEIVE,
      dev_out => cmd_word_8b(READ, 0),
      dev_in  => cmd_word_8b(WRITE, 15),
      dev_ack => '1',
      desc    => "receive read cmd in");
    bus_i <= data_word_8b(x"11") after 1 ns;
    step_bus(
      dev_o,
      output  => cmd_word_8b(WRITE, 15),
      mode    => RECEIVE,
      dev_out => data_word_8b(x"11"),
      dev_in  => data_word_8b(x"01"),
      dev_ack => '1',
      desc    => "receive read data 1 in");
    bus_i <= data_word_8b(x"22") after 1 ns;
    step_bus(
      dev_o,
      output  => data_word_8b(x"01"),
      mode    => TRANSMIT,
      dev_out => data_word_8b(x"22"),
      dev_in  => data_word_8b(x"02"),
      dev_ack => '1',
      desc    => "switch to transmit");
    bus_i <= data_word_8b(x"33") after 1 ns;
    wait for 1 ns;
    test_equal(stall_o, '1', "stalling goes high with non-idle input during trasmit");
    step_bus(
      dev_o,
      output  => data_word_8b(x"02"),
      mode    => TRANSMIT,
      dev_out => data_word_8b(x"22"),
      dev_in  => data_word_8b(x"03"),
      dev_ack => '1',
      desc    => "receive stalled data during transmit");
    step_bus(
      dev_o,
      output  => data_word_8b(x"03"),
      mode    => RECEIVE,
      dev_out => data_word_8b(x"22"),
      dev_in  => data_word_8b(x"04"),
      dev_ack => '1',
      desc    => "switch to receive");
    wait for 1 ns;
    test_equal(stall_o, '0', "stall_o drops after switching back to RECEIVE");
    step_bus(
      dev_o,
      output  => data_word_8b(x"04"),
      mode    => FORWARD,
      dev_out => data_word_8b(x"33"),
      dev_ack => '1',
      desc    => "after receive read idle out");
    bus_i <= IDLE_8B after 1 ns;
    step_bus(
      dev_o,
      output  => IDLE_8B,
      mode    => FORWARD,
      dev_out => IDLE_8B,
      dev_ack => '0',
      desc    => "after receive read idle out");

    step_bus_idle(dev_o);

    test_finished("done");
    wait for 40 ns;
    ENDSIM := true;
    wait;
    end process;
end tb;
