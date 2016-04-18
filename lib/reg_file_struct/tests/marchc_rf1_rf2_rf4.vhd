library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.bist_pack.all;
use work.rf_pack.all;
use work.bist_tb_pack.all;
use work.test_pkg.all;

entity marchc_rf1_rf2_rf4 is
end marchc_rf1_rf2_rf4;

architecture tb of marchc_rf1_rf2_rf4 is

constant clk_period : time := 8 ns;
constant DEPTH : integer := 32;

signal clk : std_logic;
signal rst : std_logic;

signal bi  : bist_scan_t := BIST_SCAN_NOP;
signal bo  : bist_scan_t;

signal b1  : bist_scan_t;
signal b2  : bist_scan_t;

shared variable ENDSIM : boolean := false;

for rfa : bist_rf1
  use configuration work.bist_rf1_artisan;

for rfb : bist_rf2
  use configuration work.bist_rf2_artisan;

for rfc : bist_rf4
  use configuration work.bist_rf4_artisan;

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

   rfa : bist_rf1 generic map( sync => false, lhqd => false,
                              WIDTH => 16, DEPTH => DEPTH )
                     port map( clk => clk, rst => rst,
                               we => '0', wa => 0, d => (others => '0'),
                               ra0 => 0, q0 => open,
                               bi => bi, bo => b1);
   rfb : bist_rf2 generic map( sync => false, lhqd => false,
                              WIDTH => 16, DEPTH => DEPTH )
                     port map( clk => clk, rst => rst,
                               we => '0', wa => 0, d => (others => '0'),
                               ra0 => 0, q0 => open,
                               ra1 => 0, q1 => open,
                               bi => b1, bo => b2);
   rfc : bist_rf4 generic map( sync => false, lhqd => false,
                              WIDTH => 16, DEPTH => DEPTH )
                     port map( clk => clk, rst => rst,
                               we => '0', wa => 0, d => (others => '0'),
                               ra0 => 0, q0 => open,
                               ra1 => 0, q1 => open,
                               ra2 => 0, q2 => open,
                               ra3 => 0, q3 => open,
                               bi => b2, bo => bo);

   t0 : process
     variable result : boolean;
   begin
      test_plan(4, "march c on an rf1, rf2, and rf4 chained together");

      bist_march_c16(clk, bi, bo, result, (0 => 0, 1 => 0, 2 => 0), DEPTH);
      test_ok(result, "march c ports 0, 0, 0");

      bist_march_c16(clk, bi, bo, result, (0 => 0, 1 => 1, 2 => 1), DEPTH);
      test_ok(result, "march c ports 0, 1, 1");

      bist_march_c16(clk, bi, bo, result, (0 => 0, 1 => 1, 2 => 2), DEPTH);
      test_ok(result, "march c ports 0, 1, 2");

      bist_march_c16(clk, bi, bo, result, (0 => 0, 1 => 1, 2 => 3), DEPTH);
      test_ok(result, "march c ports 0, 1, 3");
      
      test_finished("done");
      ENDSIM := true;
      wait;
   end process;
end tb;
