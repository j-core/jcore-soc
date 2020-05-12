library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.fixed_float_types.all;
use work.fixed_pkg.all;

package fixed_dsm_pack is

function to_sfixed(I: std_logic) return sfixed;
function to_sfixed(I: std_logic; O: sfixed; S: integer) return sfixed;
function "*" (L: sfixed; R: std_logic) return sfixed;
function "*" (L: std_logic; R: sfixed) return sfixed;
function diff_int (A: sfixed; I: sfixed; D: sfixed; N: integer) return sfixed;
function int (A: sfixed; I: sfixed; N: integer) return sfixed;
function quantize(I: sfixed) return std_logic;

type cordic_mode_t is ( VECTOR, ROTATE );
function cordic_angle(N: in integer) return real;
procedure cordic_step(N: in integer; M: in cordic_mode_t; Xin: in sfixed; Yin: in sfixed; Zin: in sfixed; Xout: inout sfixed; Yout: inout sfixed; Zout: inout sfixed);

end fixed_dsm_pack;

package body fixed_dsm_pack is

function to_sfixed(I: std_logic) return sfixed is
variable ret : sfixed(1 downto 0);
begin
   ret := I & '1';
   return ret;
end to_sfixed;

function to_sfixed(I: std_logic; O: sfixed; S: integer) return sfixed is
variable ret : sfixed(O'range);
begin
   ret := resize(to_sfixed(I), O) sla S;
   return ret;
end to_sfixed;

function "*" (L: sfixed; R: std_logic) return sfixed is
begin
   if R = '1' then return resize(-L, L);
   else            return L;
   end if;
end "*";

function "*" (L: std_logic; R: sfixed) return sfixed is
begin
   if L = '1' then return resize(-R, R);
   else            return R;
   end if;
end "*";

function diff_int (A: sfixed; I: sfixed; D: sfixed; N: integer) return sfixed is
variable im : sfixed(I'left+1 downto I'right-N);
begin
   im := resize(I - D, im) sra N;
   return resize(A + im, A);
end diff_int;

function int (A: sfixed; I: sfixed; N: integer) return sfixed is
variable im : sfixed(I'left downto I'right-N);
begin
   im := resize(I, im) sra N;
   return resize(A + im, A);
end int;

function quantize(I: sfixed) return std_logic is
begin
   return I(I'left);
end quantize;

function cordic_angle(N: in integer) return real is
begin
   return arctan(2.0**(-real(N)))/MATH_PI_OVER_2;
end cordic_angle;

procedure cordic_step(N: in integer; M: in cordic_mode_t; Xin: in sfixed; Yin: in sfixed; Zin: in sfixed; Xout: inout sfixed; Yout: inout sfixed; Zout: inout sfixed) is
variable d : std_logic;
begin
   if M = VECTOR then d :=     Yin(Yin'left);
   else               d := not Zin(Zin'left); end if;

   Xout := resize(Xin + (resize(Yin, Xout) sra N) * d,       Xout);
   Yout := resize(Yin - (resize(Xin, Yout) sra N) * d,       Yout);
   Zout := resize(Zin + to_sfixed(cordic_angle(N), Zin) * d, Zout);
end cordic_step;

end fixed_dsm_pack;
