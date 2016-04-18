-- Simple test bench for async read / sync write reg file

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.bist_pack.all;
use work.rf_pack.all;
use work.bist_tb_pack.all;
use work.test_pkg.all;

entity bist_rf_tb is
end bist_rf_tb;

architecture tb of bist_rf_tb is

constant clk_period : time := 8 ns;
constant WIDTH : natural := 16;
constant DEPTH   : natural := 32;

signal clk : std_logic;
signal rst : std_logic;
signal we  : std_logic;

signal wa  : integer range 0 to DEPTH-1;
signal ra0 : integer range 0 to DEPTH-1;
signal ra1 : integer range 0 to DEPTH-1;

signal d   : std_logic_vector(WIDTH-1 downto 0);
signal q0  : std_logic_vector(WIDTH-1 downto 0);
signal q1  : std_logic_vector(WIDTH-1 downto 0);

signal bi  : bist_scan_t;
signal bid : bist_scan_t;
signal bo  : bist_scan_t;

signal v   : std_logic_vector(WIDTH-1 downto 0);

shared variable ENDSIM : boolean := false;

for rf_dut : bist_rf2
  use configuration work.bist_rf2_artisan;

begin
   rst <= '1', '0' after 15 ns;

   clk_gen : process
   begin
     if ENDSIM = false then
       clk <= '0';
       wait for clk_period/2;
       clk <= '1';
       wait for clk_period/2;
     else
       wait;
     end if;
   end process;

   rf_dut : bist_rf2 generic map( sync => false, lhqd => false,
                                  WIDTH => WIDTH, DEPTH => DEPTH )
                     port map( clk => clk, rst => rst,
                               we => we, wa => wa, d => d,
                               ra0 => ra0, q0 => q0,
                               ra1 => ra1, q1 => q1,
                               bi => bi, bo => bo);

   rd : process(clk, rst, bi, bid, bo, v)
   begin
      if rst = '1' then
          v   <= (others => '0');
          bid <= BIST_SCAN_NOP;
      elsif clk'event and clk = '1' then
          bid <= bi;
          if bid.bist = '1' and bid.en = '1' and to_bist_cmd(bid.cmd) = SHIFT_DATA then
             v <= bo.d & v(WIDTH-1 downto 1);
          end if;
      end if;
   end process;

   t0 : process
     variable output : std_logic_vector(15 downto 0);
     variable result : boolean;
   begin
      test_plan(22, "bist rf");
      test_comment("test normal usage of RF through bist collar");
      we  <= '0';
      wa  <=  0;
      ra0 <=  0;
      ra1 <=  0;
      d   <= (others => '0');
      bi  <= BIST_SCAN_NOP;
      wait until rst = '0';
      wait until clk'event and clk = '1';

      ra0 <=  6;
      wa  <=  6; d <= x"55aa"; we <= '1';
      wait until clk'event and clk = '1';
      we  <= '0';
      wait until clk'event and clk = '0';
      test_equal(q0, x"55aa", "wr r6 and read through port 0");

      ra1 <=  6;

      wait until clk'event and clk = '1';
      wa  <=  5; d <= x"a5a5"; we <= '1';
      wait until clk'event and clk = '0';
      test_equal(q1, x"55aa", "wr r6 and read through port 1 same cycle to read old value");

      ra0 <=  5; ra1 <= 0;
      wait until clk'event and clk = '1';
      wa  <=  5; d <= x"c0ff"; we <= '1';
      wait until clk'event and clk = '0';
      test_equal(q0, x"a5a5", "read r5 after 2 writes, expecting to see first value");

      wait until clk'event and clk = '1';
      we  <= '0';
      wait until clk'event and clk = '0';
      test_equal(q0, x"c0ff", "read r5 again after same 2 writes, expecting to see second value");

      ra1 <= 5;

      wait until clk'event and clk = '1';
      wait until clk'event and clk = '0';
      test_equal(q1, x"c0ff", "read r5 through port 2 also");

      ra0 <= 6;
      wait until clk'event and clk = '1';
      wait until clk'event and clk = '0';
      test_equal(q0, x"55aa", "change port 0 to read r6 again");
      test_equal(q1, x"c0ff", "port 1 still reading r5");

      test_comment("test BIST control of register file");
      -- Some BIST signals
      bi.bist <= '1';
      bi.cmd  <= to_slv(NOP);
      wait until clk'event and clk = '1';
      bi.d    <= '1';
      bi.cmd  <= to_slv(SHIFT_CTRL);
      wait until clk'event and clk = '1';

      -- WE, rd port 1, addr 6
      bist_ctrl(clk, bi, '1', 6, (0 => 1));

      bi.cmd  <= to_slv(NOP);
      wait until clk'event and clk = '1';

      bist_data(clk, bi, bo, x"FEED", output);
      test_equal(output, x"55aa", "Read r6  port 1 using bist data commands");
      wait until clk'event and clk = '1';

      bi.cmd  <= to_slv(NOP);
      wait until clk'event and clk = '1';
      bi.en   <= '0';
      wait until clk'event and clk = '1';
      bi.bist <= '0';

      test_equal(q0, x"FEED", "Check value written through bist commands");

      test_comment("test is_repeated()");
      test_ok(is_repeated("1", "1"), "repeat 1 1");
      test_ok(is_repeated("0", "0"), "repeat 0 0");
      test_ok(not is_repeated("1", "0"), "repeat 1 0");
      test_ok(is_repeated("11111", "1"), "repeat 11111 1");
      test_ok(not is_repeated("11111", "0"), "repeat 11111 0");
      test_ok(not is_repeated("11011", "1"), "repeat 11011 1");
      test_ok(not is_repeated("11011", "0"), "repeat 11011 0");

      test_ok(not is_repeated("11111", "11"), "repeat size mismatch");
      test_ok(is_repeated("111111", "11"), "repeat 111111 11");
      test_ok(not is_repeated("111111", "10"), "repeat 111111 10");

      test_ok(is_repeated("101010", "10"), "repeat 101010 10");

      test_ok(is_repeated(x"e2e2e2e2", x"e2"), "repeat 0xe2e2e2e2 0xe2");
      test_ok(not is_repeated(x"e2e3e2e2", x"e2"), "repeat 0xe2e3e2e2 0xe2");

      test_finished("done");
      ENDSIM := true;
      wait;
   end process;      
end tb;
