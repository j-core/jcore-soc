library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cpu2j0_pack.all;
use work.bus_mux_pkg.all;
use work.test_pkg.all;

entity multi_master_bus_mux_tap is
end multi_master_bus_mux_tap;

architecture tb of multi_master_bus_mux_tap is
  constant NULL_DATA_I : cpu_data_i_t := (d => (others => '0'), ack => '0');
  constant NULL_DATA_O : cpu_data_o_t := ('0', (others => '0'), '0', '0', "0000", (others => '0'));

  signal clk, rst : std_logic;
  signal m1_i, m2_i : cpu_data_i_t;
  -- registered versions of above to represent masters view of data bus
  signal m1_ir, m2_ir : cpu_data_i_t;
  signal slave_i : cpu_data_i_t;
  signal slave_same_cycle_i : cpu_data_i_t := NULL_DATA_I;
  signal slave_delayed_i    : cpu_data_i_t := NULL_DATA_I;
  signal m1_o, m2_o, slave_o : cpu_data_o_t;

  shared variable slave_delay : time := 4 ns;
  shared variable slave_cycle_delay : integer := 0;
  shared variable slave_ack_drop_delay : time := 3 ns;

  shared variable same_cycle_slave : boolean := false;

  shared variable STOPSLAVE : boolean := false;
  shared variable STOPCLK : boolean := false;
begin
  u_bmux : multi_master_bus_mux port map(
    rst => rst, clk => clk,
    m1_i => m1_i, m1_o => m1_o,
    m2_i => m2_i, m2_o => m2_o,
    slave_i => slave_i, slave_o => slave_o);

  slave_i <= slave_same_cycle_i when same_cycle_slave else
             slave_delayed_i;

  clk_gen : process
  begin
    if STOPCLK then
      wait;
    end if;
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  -- Have two difference bus slaves. One that delays ACKing and one that ACKs
  -- immediately.

  -- This process simulates the single data bus slave responding to read and
  -- write requests from the two masters.
  slave: process
  begin
    if STOPSLAVE then
      STOPCLK := true;
      wait;
    end if;
    slave_delayed_i <= NULL_DATA_I;
    wait until clk'event and clk = '1' and slave_o.en = '1';
    -- slave_delay adds additional cycles to the delay between the slave noticing
    -- EN high at a rising clock edge until it raises ACK. Note that the slave
    -- always waits to see EN at a rising edge above, so this slave doesn't ACK
    -- within the same cycle that EN was raised.
    for I in 1 to slave_cycle_delay loop
      wait until clk'event and clk = '1';
    end loop;
    wait for slave_delay;
    slave_delayed_i.ack <= '1';
    if slave_o.rd = '1' then
      slave_delayed_i.d <= x"aaaa" & slave_o.a(15 downto 0);
    end if;
    -- hold ack high until after the next clock edge
    wait until clk'event and clk = '1';
    wait for slave_ack_drop_delay;
  end process;

  -- an alternative slave ACKs immediately for testing zero wait state requests
  slave_same_cycle_i.ack <= slave_o.en;
  slave_same_cycle_i.d <= x"bbbb" & slave_o.a(15 downto 0) when slave_o.rd = '1' else
                          (others => '0');

  -- Register the inputs from the bus to the two masters because masters should
  -- only sample the bus at the clock edge. These registers are what the tests
  -- examine.
  reg_inputs: process (clk, m1_i, m2_i)
  begin
    if clk'event and clk ='1' then
      m1_ir <= m1_i;
      m2_ir <= m2_i;
    end if;
  end process;

  process
    -- wait for a given number of rising clock edges (+ a little bit to let
    -- signals "settle")
    procedure wait_clk(constant cycles : in integer) is
    begin
      for I in 1 to cycles loop
        wait until clk'event and clk = '1';
      end loop;
      -- wait a little bit past the clock edge to ensure all simulation events
      -- scheduled at the clock edge have run
      wait for 1 ns;
    end;
    function read(addr : std_logic_vector(31 downto 0)) return cpu_data_o_t is
      variable r : cpu_data_o_t := NULL_DATA_O;
    begin
      r.en := '1';
      r.rd := '1';
      r.a := addr;
      return r;
    end;
    function write(addr : std_logic_vector(31 downto 0);
                    data : std_logic_vector(31 downto 0);
                    we : std_logic_vector(3 downto 0) := "1111") return cpu_data_o_t is
      variable w : cpu_data_o_t := NULL_DATA_O;
    begin
      w.en := '1';
      w.wr := '1';
      w.a := addr;
      w.d := data;
      w.we := we;
      return w;
    end;
  begin
    test_plan(42, "multi_master_bus_mux");
    rst <= '1';
    m1_o <= NULL_DATA_O;
    m2_o <= NULL_DATA_O;

    wait_clk(2);
    rst <= '0';

    slave_delay := 4 ns;
    slave_cycle_delay := 0;
    wait_clk(1);

    test_comment("READ M1 - 1 cycle delay");
    m1_o <= read(x"00000001");
    wait_clk(2);
    test_ok(m1_ir.ack = '1' and m1_ir.d = x"aaaa0001", "Read M1 - 1 cycle delay");
    test_equal(m2_ir.ack, '0', "M2 not acked by above read");
    m1_o <= NULL_DATA_O;

    test_comment("READ M1 - 2 cycle delay");
    slave_cycle_delay := 2;
    m1_o <= read(x"00000002");
    wait_clk(2);
    test_equal(m1_ir.ack, '0', "M1 read delay 1");
    wait_clk(1);
    test_equal(m1_ir.ack, '0', "M2 read delay 2");
    wait_clk(1);
    test_ok(m1_ir.ack = '1' and m1_ir.d = x"aaaa0002", "Read M1 - read after delay");
    test_equal(m2_ir.ack, '0', "M2 not acked by above read");
    m1_o <= NULL_DATA_O;

    test_comment("READ M1 and M2 together, 1 cycle delay");
    slave_cycle_delay := 0;
    -- even start the M2 read earlier. it should still go second
    m2_o <= read(x"00000004");
    wait for 1 ns;
    m1_o <= read(x"00000003");
    wait_clk(2);
    test_ok(m1_ir.ack = '1' and m1_ir.d = x"aaaa0003", "Read M1 has priority");
    test_equal(m2_ir.ack, '0', "M2 read waiting");
    m1_o <= NULL_DATA_O;
    wait_clk(2);
    test_ok(m2_ir.ack = '1' and m2_ir.d = x"aaaa0004", "Waiting M2 read completes");
    test_equal(m1_ir.ack, '0', "M1 no ack");
    m2_o <= NULL_DATA_O;
    wait_clk(1);
    test_ok(m1_ir.ack = '0' and m2_ir.ack = '0', "all ACKs zero");

    test_comment("READ M1 and M2 together, with delay, and start a new M1 WRITE immediately to further delay M2 READ");
    slave_cycle_delay := 1;
    m1_o <= read(x"00000005");
    m2_o <= read(x"00000006");
    wait_clk(3);
    test_ok(m1_ir.ack = '1' and m1_ir.d = x"aaaa0005", "Read M1 has priority");
    test_equal(m2_ir.ack, '0', "M2 read waiting");
    -- start new read on M1
    m1_o <= write(x"00000007", x"10101010");
    wait_clk(3);
    test_ok(m1_ir.ack = '1', "Following M1 write still has priority");
    test_equal(m2_ir.ack, '0', "M2 read still waiting");
    m1_o <= NULL_DATA_O;
    wait_clk(3);
    test_ok(m2_ir.ack = '1' and m2_ir.d = x"aaaa0006", "Waiting M2 read completes");
    test_equal(m1_ir.ack, '0', "M1 no ack");
    m2_o <= NULL_DATA_O;
    wait_clk(1);
    test_ok(m1_ir.ack = '0' and m2_ir.ack = '0', "all ACKs zero");

    test_comment("Start M1 READ and while it's processing, start an M2 READ. Ensure both reads complete");
    slave_cycle_delay := 0;
    m1_o <= read(x"00000008");
    wait_clk(1);
    m2_o <= read(x"00000009");
    wait_clk(1);
    test_ok(m1_ir.ack = '1' and m1_ir.d = x"aaaa0008", "Read M1 not interrupted");
    test_equal(m2_ir.ack, '0', "M2 read waiting");
    m1_o <= NULL_DATA_O;
    wait_clk(2);
    test_ok(m2_ir.ack = '1' and m2_ir.d = x"aaaa0009", "Following M2 READ completed");
    test_equal(m1_ir.ack, '0', "M1 ACK still zero");
    m2_o <= NULL_DATA_O;
    wait_clk(1);
    test_ok(m1_ir.ack = '0' and m2_ir.ack = '0', "all ACKs zero");

    test_comment("Start M2 READ and while it's processing, start an M1 READ. Ensure both reads complete");
    slave_cycle_delay := 0;
    m2_o <= read(x"00000009");
    wait_clk(1);
    m1_o <= read(x"0000000a");
    wait_clk(1);
    test_ok(m2_ir.ack = '1' and m2_ir.d = x"aaaa0009", "Read M2 not interrupted");
    test_equal(m1_ir.ack, '0', "M1 read waiting");
    m2_o <= NULL_DATA_O;
    wait_clk(2);
    test_ok(m1_ir.ack = '1' and m1_ir.d = x"aaaa000a", "Following M1 READ completed");
    test_equal(m2_ir.ack, '0', "M2 ACK still zero");
    m1_o <= NULL_DATA_O;
    wait_clk(1);
    test_ok(m1_ir.ack = '0' and m2_ir.ack = '0', "all ACKs zero");

    test_comment("Back-to-back M2 READs should be interleaved with a late-arriving M1 READ");
    slave_cycle_delay := 0;
    m2_o <= read(x"0000000b");
    wait_clk(1);
    m1_o <= read(x"0000000c");
    wait_clk(1);
    test_ok(m2_ir.ack = '1' and m2_ir.d = x"aaaa000b", "First M2 read complete");
    test_equal(m1_ir.ack, '0', "M1 read waiting");
    m2_o <= read(x"0000000d"); -- try to start another M2 read immediately
    wait_clk(2);
    test_ok(m1_ir.ack = '1' and m1_ir.d = x"aaaa000c", "M1 READ between back-to-back M2 READs");
    test_equal(m2_ir.ack, '0', "M2 ACK zero");
    m1_o <= NULL_DATA_O;
    wait_clk(2);
    test_ok(m2_ir.ack = '1' and m2_ir.d = x"aaaa000d", "Second M2 READ completes");
    test_equal(m1_ir.ack, '0', "M1 ACK still zero");
    m2_o <= NULL_DATA_O;
    wait_clk(1);
    test_ok(m1_ir.ack = '0' and m2_ir.ack = '0', "all ACKs zero");

    test_comment("");
    test_comment("Test zero-wait-state operation with a bus slave that ACKs immediately");
    test_comment("");
    same_cycle_slave := true;
    wait_clk(1);
    m1_o <= read(x"0000000e");
    m2_o <= read(x"0000000f");
    wait_clk(1);
    test_ok(m1_ir.ack = '1' and m1_ir.d = x"bbbb000e", "M1 immediate READ has priority");
    test_equal(m2_ir.ack, '0', "M2 ACK zero");
    m1_o <= NULL_DATA_O;
    wait_clk(1);
    test_ok(m2_ir.ack = '1' and m2_ir.d = x"bbbb000f", "M2 immediate READ complete");
    test_equal(m1_ir.ack, '0', "M1 ACK zero");
    m1_o <= read(x"00000010");
    m2_o <= NULL_DATA_O;
    wait_clk(1);
    test_ok(m1_ir.ack = '1' and m1_ir.d = x"bbbb0010", "Second M1 immediate READ complete");
    test_equal(m2_ir.ack, '0', "M2 ACK zero");
    m1_o <= NULL_DATA_O;
    wait_clk(1);
    test_ok(m1_ir.ack = '0' and m2_ir.ack = '0', "all ACKs zero");

    test_finished("done");
    STOPSLAVE := true;
    m1_o <= read(x"ffffffff"); -- ensure slave process will wake up and stop clk
    wait;
  end process;
end tb;
