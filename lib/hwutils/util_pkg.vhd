-- Common utilities
-- (c) Smart Energy Instruments, Inc. 2013

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package util_pack is

  component syncff port (
    clk : in std_logic;
    reset : in std_logic;
    sin : in std_logic;
    sout : out std_logic);
  end component;

  function log2_fcn (a : in natural) return natural;
  function v2i_fcn (v  : in std_logic_vector) return integer;
  function i2v_fcn (i,n  : in natural) return std_logic_vector;
  function or_reduce_fcn  (a : in std_logic_vector) return std_logic;
  function enc_fcn     (a : in std_logic_vector) return std_logic_vector;
  function reverse_slv (data : std_logic_vector) return std_logic_vector;

end util_pack;

package body util_pack is

function log2_fcn (a : in natural) return natural is
variable temp    : natural := a;
variable y : natural := 0;
begin
   while temp > 1 loop
      y := y + 1;
      temp    := temp / 2;
   end loop;
   if (a mod 2**y) /= 0 then
      y := y + 1;
   end if;
   return y;
end log2_fcn;

function v2i_fcn (v  : in std_logic_vector) return integer is
begin
   return to_integer(unsigned(v));
end v2i_fcn;

function i2v_fcn (i,n  : in natural) return std_logic_vector is
begin
   return std_logic_vector(to_unsigned(i,n));
end i2v_fcn;

function or_reduce_fcn  (a : in std_logic_vector) return std_logic is
variable m  : natural := a'length;
variable y  : std_logic := '0';
begin
   for i in 0 to m-1 loop
      y := a(i) or y;
   end loop;
   return y;
end or_reduce_fcn;

function enc_fcn (a : in std_logic_vector) return std_logic_vector is
variable m : natural := a'length;
variable n : natural := log2_fcn(m);
variable y : std_logic_vector(n-1 downto 0);
begin
   y := (others => '0');
   for i in 0 to m-1 loop
      if a(i) = '1' then
         y:= i2v_fcn(i, n);
      end if;
   end loop;
   return y;
end enc_fcn;

function reverse_slv (data : std_logic_vector) return std_logic_vector is
variable tmp : std_logic_vector(data'length-1 downto 0);
begin
   for i in 0 to integer(data'length)-1 loop
      tmp(i) := data(data'high-i);
   end loop;
   return tmp;

end reverse_slv;

end util_pack;

