-- Simple test bench for async read / sync write reg file

library ieee;
use ieee.std_logic_1164.all;

use work.rf_pack.all;

entity rf_tb is
end rf_tb;

architecture tb of rf_tb is

constant clk_period : time := 8 ns;
constant WIDTH : natural := 16;
constant DEPTH   : natural := 32;

signal clk : std_logic;
signal rst : std_logic;
signal we  : std_logic;

signal wa  : integer range 0 to DEPTH-1;
signal ra0 : integer range 0 to DEPTH-1;
signal ra1 : integer range 0 to DEPTH-1;
signal ra2 : integer range 0 to DEPTH-1;
signal ra3 : integer range 0 to DEPTH-1;

signal d   : std_logic_vector(WIDTH-1 downto 0);

signal q10 : std_logic_vector(WIDTH-1 downto 0);

signal q20 : std_logic_vector(WIDTH-1 downto 0);
signal q21 : std_logic_vector(WIDTH-1 downto 0);

signal q40 : std_logic_vector(WIDTH-1 downto 0);
signal q41 : std_logic_vector(WIDTH-1 downto 0);
signal q42 : std_logic_vector(WIDTH-1 downto 0);
signal q43 : std_logic_vector(WIDTH-1 downto 0);

for all : rf2 use entity work.rf2(artisan);
begin
   rst <= '0', '1' after 5 ns, '0' after 15 ns;
   clk <= '0' after clk_period/2 when clk = '1' else '1' after clk_period/2;

    -- change sync to true for sync read, lhqd to true to use LHQD latch cells
   rf1dut : rf1 generic map( sync => false, lhqd => false,
                             WIDTH => WIDTH, DEPTH => DEPTH )
                   port map( clk => clk, rst => rst,
                             we => we, wa => wa, d => d,
                             ra0 => ra0, q0 => q10);

   rf2dut : rf2 generic map( sync => false, lhqd => false,
                             WIDTH => WIDTH, DEPTH => DEPTH )
                   port map( clk => clk, rst => rst,
                             we => we, wa => wa, d => d,
                             ra0 => ra0, q0 => q20,
                             ra1 => ra1, q1 => q21);

   rf4dut : rf4 generic map( sync => false, lhqd => false,
                             WIDTH => WIDTH, DEPTH => DEPTH )
                   port map( clk => clk, rst => rst,
                             we => we, wa => wa, d => d,
                             ra0 => ra0, q0 => q40,
                             ra1 => ra1, q1 => q41,
                             ra2 => ra2, q2 => q42,
                             ra3 => ra3, q3 => q43);

   t0 : process
   begin
      we  <= '0';
      wa  <=  0;
      ra0 <=  0;
      ra3 <=  0;
      d   <= (others => '0');
      wait until rst = '1';
      wait until rst = '0';
      wait until clk'event and clk = '1';

      ra2 <=  5;
      ra0 <=  6;
      wa  <=  6; d <= x"55aa"; we <= '1';
      wait until clk'event and clk = '1';
      we  <= '0';

      ra1 <=  6;
      wait until clk'event and clk = '1';

      ra0 <=  5; ra1 <= 0; ra3 <= 6;
      wa  <=  5; d <= x"a5a5"; we <= '1';
      wait until clk'event and clk = '1';

      wa  <=  5; d <= x"c0ff"; we <= '1';
      wait until clk'event and clk = '1';
      we  <= '0';

      ra1 <= 5;
      wait until clk'event and clk = '1';
      ra0 <= 6;
      wait;
   end process;      
end tb;
