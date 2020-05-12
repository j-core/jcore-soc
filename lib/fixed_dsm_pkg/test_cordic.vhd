library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.fixed_float_types.all;
use work.fixed_pkg.all;

use work.fixed_dsm_pack.all;

entity cordic_tb is
end cordic_tb;

architecture tb of cordic_tb is

procedure pr( x,y,z : in sfixed) is
begin
   report "step : x=" & real'image(to_real(x)) & " y=" & real'image(to_real(y)) & " z=" & real'image(to_real(z));
   report "     : angle=" & real'image(360.0 * arctan(to_real(y), to_real(x)) / MATH_2_PI) & " residual=" & real'image(90.0 * to_real(z));
   report "       x=" & to_string(x) & "       y=" & to_string(y);
-- & "       z=0x" & to_string(z);
end pr;

begin

   t0 : process
   variable x0, y0 : sfixed(1 downto  0);
   variable x1, y1 : sfixed(1 downto  0);
   variable x2, y2 : sfixed(1 downto -1);
   variable x3, y3 : sfixed(1 downto -3);
   variable x4, y4 : sfixed(1 downto -6);
   variable x5, y5 : sfixed(1 downto -10);
   variable x6, y6 : sfixed(1 downto -15);
   variable x7, y7 : sfixed(1 downto -16); -- -21);
   variable x8, y8 : sfixed(1 downto -17); -- -28);
   variable x9, y9 : sfixed(1 downto -18); -- -37);
   variable x10, y10 : sfixed(1 downto -19); -- -37);
   variable x11, y11 : sfixed(1 downto -20); -- -37);
   variable x12, y12 : sfixed(1 downto -21); -- -37);
   variable x13, y13 : sfixed(1 downto -22); -- -37);
   variable x14, y14 : sfixed(1 downto -23); -- -37);
   variable x15, y15 : sfixed(1 downto -24); -- -37);
   variable x16, y16 : sfixed(1 downto -25); -- -37);
   variable z0, z1, z2, z3, z4, z5, z6, z7, z8, z9, z10, z11, z12, z13, z14, z15, z16 : sfixed(1 downto -20);
   begin
      -- Rotate mode, 60 deg.
      report "";
      report "----> forward 60deg";
      x0 := to_sfixed(1.0         , x0);
      y0 := to_sfixed(0.0         , y0);
      z0 := to_sfixed(+60.0 / 90.0, z0);

      pr(x0, y0, z0);
      cordic_step(0, ROTATE, x0, y0, z0, x1, y1, z1);
      pr(x1, y1, z1);
      cordic_step(1, ROTATE, x1, y1, z1, x2, y2, z2);
      pr(x2, y2, z2);
      cordic_step(2, ROTATE, x2, y2, z2, x3, y3, z3);
      pr(x3, y3, z3);
      cordic_step(3, ROTATE, x3, y3, z3, x4, y4, z4);
      pr(x4, y4, z4);
      cordic_step(4, ROTATE, x4, y4, z4, x5, y5, z5);
      pr(x5, y5, z5);
      cordic_step(5, ROTATE, x5, y5, z5, x6, y6, z6);
      pr(x6, y6, z6);
      cordic_step(6, ROTATE, x6, y6, z6, x7, y7, z7);
      pr(x7, y7, z7);
      cordic_step(7, ROTATE, x7, y7, z7, x8, y8, z8);
      pr(x8, y8, z8);
      cordic_step(8, ROTATE, x8, y8, z8, x9, y9, z9);
      pr(x9, y9, z9);

      report "";
      report "<---- backward 60deg";
      x0 := to_sfixed(1.0         , x0);
      y0 := to_sfixed(0.0         , y0);
      z0 := to_sfixed(-60.0 / 90.0, z0);

      pr(x0, y0, z0);
      cordic_step(0, ROTATE, x0, y0, z0, x1, y1, z1);
      pr(x1, y1, z1);
      cordic_step(1, ROTATE, x1, y1, z1, x2, y2, z2);
      pr(x2, y2, z2);
      cordic_step(2, ROTATE, x2, y2, z2, x3, y3, z3);
      pr(x3, y3, z3);
      cordic_step(3, ROTATE, x3, y3, z3, x4, y4, z4);
      pr(x4, y4, z4);
      cordic_step(4, ROTATE, x4, y4, z4, x5, y5, z5);
      pr(x5, y5, z5);
      cordic_step(5, ROTATE, x5, y5, z5, x6, y6, z6);
      pr(x6, y6, z6);
      cordic_step(6, ROTATE, x6, y6, z6, x7, y7, z7);
      pr(x7, y7, z7);
      cordic_step(7, ROTATE, x7, y7, z7, x8, y8, z8);
      pr(x8, y8, z8);
      cordic_step(8, ROTATE, x8, y8, z8, x9, y9, z9);
      pr(x9, y9, z9);

      -- Rotate mode, 1.2345 deg tests.
      report "";
      report "----> forward 89.765deg";
      x0 := to_sfixed(1.0         , x0);
      y0 := to_sfixed(0.0         , y0);
      z0 := to_sfixed(+89.765 / 90.0, z0);

      pr(x0, y0, z0);
      cordic_step(0, ROTATE, x0, y0, z0, x1, y1, z1);
      pr(x1, y1, z1);
      cordic_step(1, ROTATE, x1, y1, z1, x2, y2, z2);
      pr(x2, y2, z2);
      cordic_step(2, ROTATE, x2, y2, z2, x3, y3, z3);
      pr(x3, y3, z3);
      cordic_step(3, ROTATE, x3, y3, z3, x4, y4, z4);
      pr(x4, y4, z4);
      cordic_step(4, ROTATE, x4, y4, z4, x5, y5, z5);
      pr(x5, y5, z5);
      cordic_step(5, ROTATE, x5, y5, z5, x6, y6, z6);
      pr(x6, y6, z6);
      cordic_step(6, ROTATE, x6, y6, z6, x7, y7, z7);
      pr(x7, y7, z7);
      cordic_step(7, ROTATE, x7, y7, z7, x8, y8, z8);
      pr(x8, y8, z8);
      cordic_step(8, ROTATE, x8, y8, z8, x9, y9, z9);
      pr(x9, y9, z9);
      cordic_step(9, ROTATE, x9, y9, z9, x10, y10, z10);
      pr(x10, y10, z10);
      cordic_step(10, ROTATE, x10, y10, z10, x11, y11, z11);
      pr(x11, y11, z11);
      cordic_step(11, ROTATE, x11, y11, z11, x12, y12, z12);
      pr(x12, y12, z12);
      cordic_step(12, ROTATE, x12, y12, z12, x13, y13, z13);
      pr(x13, y13, z13);
      cordic_step(13, ROTATE, x13, y13, z13, x14, y14, z14);
      pr(x14, y14, z14);
      cordic_step(14, ROTATE, x14, y14, z14, x15, y15, z15);
      pr(x15, y15, z15);
      cordic_step(15, ROTATE, x15, y15, z15, x16, y16, z16);
      pr(x16, y16, z16);

      wait;
   end process;
end tb;
