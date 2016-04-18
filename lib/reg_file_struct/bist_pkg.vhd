-- async / sync 1,2,4R sync 1W register file, using Artisan transparent latch 0.18um.
-- modeled from datasheet parameters

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package bist_pack is

type bist_cmd_t is ( NOP, SHIFT_CTRL, SHIFT_DATA );

function to_bist_cmd (I : std_logic_vector) return bist_cmd_t;
function to_slv      (I : bist_cmd_t)       return std_logic_vector;

type bist_scan_t is record
   bist : std_logic;
   en   : std_logic;
   cmd  : std_logic_vector(1 downto 0);
   d    : std_logic;
   ctrl : std_logic;
end record;

constant BIST_SCAN_NOP : bist_scan_t := ( '0', '0', (others => '0'), '0', '0' );

type bist_scan_array_t is array (natural range <>) of bist_scan_t;

end package;

package body bist_pack is

function to_bist_cmd (I : std_logic_vector) return bist_cmd_t is
begin
   return bist_cmd_t'val(to_integer(unsigned(I)));
end to_bist_cmd;

function to_slv      (I : bist_cmd_t)       return std_logic_vector is
begin
   return std_logic_vector(to_unsigned(bist_cmd_t'pos(I),2));
end to_slv;

end bist_pack;
