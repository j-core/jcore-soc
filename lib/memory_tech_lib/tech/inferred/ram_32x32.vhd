library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.memory_pack.all;

entity ram_32x32 is
   generic (
   read : ram_read_type_t := ASYNC);
   port (
   clk : in  std_logic;
   w   : in  ram_32x32_w_t;
   r   : in  ram_32x32_r_t;
   d   : out ram_32x32_d_t);
end ram_32x32;

architecture beh of ram_32x32 is

type ma_t is array (0 to 31) of std_logic_vector(31 downto 0);
signal mem : ma_t := (others => (others => '0') );
signal rc  : ram_32x32_r_t;

begin
   c0 : process(clk,w,r)
   begin
      if clk'event and clk = '1' and w.wr = '1' and w.we(3) = '1' then mem(w.a)(31 downto 24) <= w.d(31 downto 24); end if;
      if clk'event and clk = '1' and w.wr = '1' and w.we(2) = '1' then mem(w.a)(23 downto 16) <= w.d(23 downto 16); end if;
      if clk'event and clk = '1' and w.wr = '1' and w.we(1) = '1' then mem(w.a)(15 downto  8) <= w.d(15 downto  8); end if;
      if clk'event and clk = '1' and w.wr = '1' and w.we(0) = '1' then mem(w.a)( 7 downto  0) <= w.d( 7 downto  0); end if;

      if    read = SYNC0 and clk'event and clk = '0' then rc <= r;
      elsif read = SYNC1 and clk'event and clk = '1' then rc <= r;
      else                                                rc <= r; end if;
   end process;
   d <= mem(rc.a);
end beh;
