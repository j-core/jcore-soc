library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.fixed_float_types.all;
use work.fixed_pkg.all;

use work.fixed_dsm_pack.all;

entity fdm_tb is
end fdm_tb;

architecture tb of fdm_tb is

signal a    : sfixed(1 downto 0);
signal ar   : real;

signal b    : sfixed(1 downto 0);
signal br   : real;

signal acc  : sfixed(1 downto -4);
signal accr : real;

signal y    : sfixed(1 downto -4);
signal yr   : real;

signal yi   : sfixed(3 downto -6);
signal yir  : real;

signal in_data : std_logic;
signal sr      : std_logic_vector(15 downto 0);

signal q    : std_logic;
signal uql  : sfixed (3 downto -2);
signal uqlr : real;
signal uqr  : sfixed (3 downto -2);
signal uqrr : real;

signal big  : sfixed(3 downto -6);
signal sml  : sfixed(1 downto -2);

signal cao  : sfixed(1 downto -18);

begin
   ar   <= to_real(a);
   br   <= to_real(b);
   yr   <= to_real(y);
   yir  <= to_real(yi);
   accr <= to_real(acc);
   uqlr <= to_real(uql);
   uqrr <= to_real(uqr);
   big  <= to_sfixed(1.5, big);
   sml  <= resize(big, sml);

   -- input and delayed
   a    <= to_sfixed(in_data);
   b    <= to_sfixed(sr(15));
   -- The output multiplier
   y   <= acc * sr(7);
   -- Quantizer
   q   <= quantize(y);
   -- Un-quanzise (bit to fixed point)
   uql <= to_sfixed(q, uql,  2);
   uqr <= to_sfixed(q, uql, -2);

   t0 : process
   begin
      -- reset everything
      in_data <= '0';                -- +1
      acc     <= (others => '0');
      sr      <= "0101010101010101"; -- DSM 0.0
      yi      <= (others => '0');
      wait for 1 us;

      report "Test script";
      report "resize test: big=" & real'image(to_real(big)) & " small=" & real'image(to_real(sml));

      -- Now just run it...

      report "starting MAF output " & real'image(accr);

      -- 32 iterations
      for i in 0 to 31 loop
         acc <= diff_int(acc, a, b, 4);    -- moving average over 16 interations
         sr  <= sr(14 downto 0) & in_data;

         yi  <= int(yi, y, 2);           -- integrate over 4 interations
         wait for 1 us;
      end loop;

      report "Settled with input +1 MAF output " & real'image(accr);

      in_data <= '1';               -- -1

      -- 32 iterations
      for i in 0 to 31 loop
         acc <= diff_int(acc, a, b, 4);    -- moving average over 16 interations
         sr  <= sr(14 downto 0) & in_data;

         yi  <= int(yi, y, 2);           -- integrate over 4 interations
         wait for 1 us;
      end loop;

      report "Settled with input -1 MAF output " & real'image(accr);

      for i in 0 to 16 loop
         cao <= to_sfixed(cordic_angle(i), cao);
         wait for 1 ns;
         report "0x" & to_hstring(cao) & " = " & real'image(cordic_angle(i));
         report "err " & real'image(cordic_angle(i) - to_real(cao));
      end loop;

      wait;
   end process;
end tb;
