library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity N_BUF is port (
      I  : in std_logic;
      O  : out std_logic);
end entity N_BUF;
architecture rtl of N_BUF is
begin
  p0 : process ( I )
  begin
    O <= I ;
  end process  ;
end rtl;

library IEEE;
use IEEE.std_logic_1164.all;

entity N_TBUF is port (
      OE  : in std_logic;
      I   : in std_logic;
      O   : out std_logic);
end entity N_TBUF;

architecture rtl of N_TBUF is
begin
  p1: process(OE, I )
  begin
   if ( OE ='1' ) then O <= 'Z'  ;
   else                O <= I ;
   end if;
   end process;
end rtl;



