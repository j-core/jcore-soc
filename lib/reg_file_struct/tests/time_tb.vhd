-- Artisan buffer 0.18um.
-- modeled from datasheet parameters

library ieee;
use ieee.std_logic_1164.all;

use work.artisan_pack.all;

entity time_tb is
end time_tb;

architecture tb of time_tb is

signal d : std_logic;
signal g : std_logic;
signal o : std_logic;
signal n : std_logic;
signal r : std_logic;

begin
   d <= '0', '1' after 1 ns, '0' after 2 ns, '1' after 4 ns, '0' after 6 ns, '1' after 7 ns,     '0' after 9 ns;
   g <= '0',                     '1' after 3 ns,       '0' after 5 ns,                 '1' after 8 ns,     '0' after 10 ns;
   o <= '0', '1' after 0.5 ns,   '0' after 3.5 ns,     '1' after 5.5 ns;
   n <= not o;

   buf0 : buf    generic map ( drive => X1 ) port map ( A => d );
   dl01 : dly1   generic map ( drive => X1 ) port map ( A => d );
   dl02 : dly2   generic map ( drive => X1 ) port map ( A => d );
   dl03 : dly3   generic map ( drive => X1 ) port map ( A => d );
   cbf0 : clkbuf generic map ( drive => X1 ) port map ( A => d );
   tlt0 : tlat   generic map ( drive => X1 ) port map ( D => d, G => g );
   rf10 : rf1r1w generic map ( drive => X2 ) port map ( WB => d, WW => g,  RW => o, RWN => n, RB => r );
   rf20 : rf2r1w generic map ( drive => X2 ) port map ( WB => d, WW => g, R1W => o, R2W => n );
   rdr0 : rfrd   generic map ( drive => X1 ) port map ( RB => r );
   tbi0 : tbufi  generic map ( drive => X1 ) port map ( A => d, OE => g );
   oai0 : oai21  generic map ( drive => XL ) port map ( A0 => d, A1 => g, B0 => n );
end tb;
