library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package gray_pack is

type gray_vector is array (natural range <>) of std_logic;

function gr_inc (V: std_logic_vector) return std_logic_vector;
function "+" (L: gray_vector; R: integer) return gray_vector;
function to_gray_vector (V, S: integer) return gray_vector;
function to_gray_vector (V: std_logic_vector) return gray_vector;
function to_integer(V: gray_vector) return integer;
function to_std_logic_vector(V: gray_vector) return std_logic_vector;

end package;

package body gray_pack is

function to_std_logic_vector(V: gray_vector) return std_logic_vector is
variable vec : std_logic_vector(V'range);
begin
   vec(V'left) := V(V'left);

   for i in V'left-1 downto V'right loop
      vec(i) := vec(i+1) xor V(i);
   end loop;

   return vec;
end to_std_logic_vector;

function to_integer(V: gray_vector) return integer is
variable vec : std_logic_vector(V'range);
variable ret : integer;
begin
   vec(V'left) := V(V'left);

   for i in V'left-1 downto V'right loop
      vec(i) := vec(i+1) xor V(i);
   end loop;

   ret := to_integer(unsigned(vec));
   return ret;
end to_integer;

function to_gray_vector (V, S: integer) return gray_vector is
variable vec : std_logic_vector(S-1 downto 0);
variable ret : gray_vector(S-1 downto 0);
begin
   vec := std_logic_vector(to_unsigned(V,S));

   for i in vec'left-1 downto vec'right loop
      ret(i) := vec(i+1) xor vec(i);
   end loop;
   ret(vec'left) := vec(vec'left);

   return ret;
end to_gray_vector;

function to_gray_vector (V: std_logic_vector) return gray_vector is
variable vec : std_logic_vector(V'range);
variable ret : gray_vector(V'range);
begin
   vec := V;

   for i in vec'left-1 downto vec'right loop
      ret(i) := vec(i+1) xor vec(i);
   end loop;
   ret(vec'left) := vec(vec'left);

   return ret;
end to_gray_vector;

function gr_inc (V: std_logic_vector) return std_logic_vector is
variable grv : std_logic_vector(V'left downto V'right);
variable tog : std_logic_vector(V'left downto V'right);
variable ors : std_logic_vector(V'left+1 downto V'right);
begin
   grv := V;

   -- Calculate parity;
   ors(V'right) := '1';
   for i in grv'range loop
      ors(V'right) := ors(V'right) xor grv(i);
   end loop;

   -- propegate the first 1 bit
   for i in V'right to V'left loop
      ors(i+1) := ors(i) or grv(i);
   end loop;

   -- but only 1 bit flips
   tog(V'right) := ors(V'right);
   for i in V'right to V'left-1 loop
      tog(i+1) := ors(i+1) and not ors(i);
   end loop;

   -- now flip that correct bit
   grv := grv xor tog;

   return grv;
end gr_inc;

function "+" (L: gray_vector; R: integer) return gray_vector is
variable res : gray_vector(L'range);
begin
   assert R = 1 report "Gray adder tried to add value other than 1" severity failure;
   res := gray_vector(gr_inc(std_logic_vector(L)));
   return res;
end "+";

end gray_pack;
