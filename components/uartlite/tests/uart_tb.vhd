-- simple UART test bench.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.uart_pack.all;

entity uart_tb is
end uart_tb;

architecture tb of uart_tb is

   signal clk   : std_logic;
   signal rst   : std_logic;
   signal a     : uart_i_t;
   signal y     : uart_o_t;
   signal rx    : std_logic;
   signal tx    : std_logic;

begin
   rst   <= '1', '0' after 10 ns;
   clk   <= '1' after 16 ns when clk = '0' else '0' after 16 ns;

   rx    <= tx;

   tst : process
   begin
      a.en <= '0';
      a.we <= '0';
      a.d  <= x"5a";
      a.dc <= DATA;

      wait for 1 uS;

      a.we <= '1';
      a.en <= '1';

      for i in 0 to 17 loop
        wait until y.ack = '1';
        a.d  <= std_logic_vector(to_unsigned(i,8));
        a.en <= '0';

        wait for 1 uS;
        a.en <= '1';
      end loop;

      wait until y.ack = '1';
      a.en <= '0';

      a.we <= '0';
      wait for 325 uS;

      a.en <= '1';
      for i in 0 to 17 loop
        wait until y.ack = '1';
        a.en <= '0';

        wait for 1 uS;
        a.en <= '1';
      end loop;

      wait until y.ack = '1';
      a.en <= '0';

      wait for 10 uS;

      a.d  <= x"10";
      a.dc <= CTRL;
      a.we <= '1';
      a.en <= '1';

      wait until y.ack = '1';
      a.en <= '0';

      wait for 10 uS;

      a.d  <= x"22";
      a.dc <= DATA;
      a.we <= '1';
      a.en <= '1';

      --wait until y.ack = '1';
      --a.en <= '0';

      for i in 0 to 17 loop
        wait until y.ack = '1';
        a.d  <= std_logic_vector(to_unsigned(i,8));
        a.en <= '0';

        wait for 1 uS;
        a.en <= '1';
      end loop;

      wait until y.ack = '1';
      a.en <= '0';
      ---------------------------
      wait for 350 uS;


      a.dc <= DATA;
      a.we <= '0';
      a.en <= '1';

      for i in 0 to 17 loop
        wait until y.ack = '1';
        a.en <= '0';

        wait for 10 uS;

        a.dc <= CTRL;
      --a.we <= '0';
        a.en <= '1';

        wait until y.ack = '1';
        a.en <= '0';

        wait for 10 us;
        a.dc <= DATA;
        a.en <= '1';

        
      end loop;

       wait until y.ack = '1';
        a.en <= '0';
      
      wait for 50 uS;

      a.d  <= x"33";
      a.dc <= DATA;
      a.we <= '1';
      a.en <= '1';

      wait until y.ack = '1';
      a.en <= '0';
      
      wait;
   end process;

   u0 : uartlite generic map (intcfg => 0, fclk => 31.25e6, bps => 500.0e3 )
                port    map ( clk => clk, rst => rst, a => a, y => y, rx => rx, tx => tx );
end tb;
