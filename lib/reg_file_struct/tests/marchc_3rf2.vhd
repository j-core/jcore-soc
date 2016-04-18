
-- a configuration for a bist_rf2 whose RF file has a bit stuck high for a
-- particular read port and register
configuration bist_rf2_stuck_bit_r0_high_port_1 of bist_rf2 is
  for bist
    for rf : RF2
      use entity work.rf2_stuck_bits(arch)
        generic map(reg_addr => 0,
                    WIDTH => 16,
                    DEPTH => 32,
                    and_mask => x"FFFF",
                    or_mask => x"0001",
                    port_sel => "01");
      for arch
        for rf : RF2
          use entity work.RF2(artisan);
        end for;
      end for;
    end for;
  end for;
end configuration;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.bist_pack.all;
use work.rf_pack.all;
use work.bist_tb_pack.all;
use work.test_pkg.all;

entity marchc_3rf2 is
end marchc_3rf2;

architecture tb of marchc_3rf2 is

constant clk_period : time := 8 ns;
constant DEPTH : integer := 32;

signal clk : std_logic;
signal rst : std_logic;

signal bi  : bist_scan_t := BIST_SCAN_NOP;
signal bo  : bist_scan_t;

signal b1  : bist_scan_t;
signal b2  : bist_scan_t;

shared variable ENDSIM : boolean := false;

-- configure rf2 to have a stuck bit on a read port for r0
for rf2 : bist_rf2
  use configuration work.bist_rf2_stuck_bit_r0_high_port_1;

for rf1, rf3 : bist_rf2
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

   rf1 : bist_rf2 generic map( sync => false, lhqd => false,
                               WIDTH => 16, DEPTH => DEPTH )
                     port map( clk => clk, rst => rst,
                               we => '0', wa => 0, d => (others => '0'),
                               ra0 => 0, q0 => open,
                               ra1 => 0, q1 => open,
                               bi => bi, bo => b1);
   rf2 : bist_rf2 generic map( sync => false, lhqd => false,
                               WIDTH => 16, DEPTH => DEPTH )
                     port map( clk => clk, rst => rst,
                               we => '0', wa => 0, d => (others => '0'),
                               ra0 => 0, q0 => open,
                               ra1 => 0, q1 => open,
                               bi => b1, bo => b2);
   rf3 : bist_rf2 generic map( sync => false, lhqd => false,
                               WIDTH => 16, DEPTH => DEPTH )
                     port map( clk => clk, rst => rst,
                               we => '0', wa => 0, d => (others => '0'),
                               ra0 => 0, q0 => open,
                               ra1 => 0, q1 => open,
                               bi => b2, bo => bo);

   t0 : process
     variable result : boolean;
   begin
      test_plan(3, "march c on 3 rf2s chained together");

      bist_march_c16(clk, bi, bo, result, (0 => 0, 1 => 0, 2 => 0), DEPTH);
      test_ok(result, "march c port 0");

      bist_march_c16(clk, bi, bo, result, (0 => 1, 1 => 0, 2 => 1), DEPTH);
      test_ok(result, "march c port 1,0,1");

      bist_march_c16(clk, bi, bo, result, (0 => 1, 1 => 1, 2 => 1), DEPTH);
      test_ok(not result, "march c port 1,1,1");

      test_finished("done");
      ENDSIM := true;
      wait;
   end process;
end tb;
