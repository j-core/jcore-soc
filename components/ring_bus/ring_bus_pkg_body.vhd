library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ring_bus_pack.all;

package body ring_bus_pack is

function cmd_word_8b(cmd : rbus_cmd; hops : cmd_hops)
  return rbus_word_8b is
  variable r : rbus_word_8b;
begin
  r.fr := '1';
  r.d  := std_logic_vector(to_unsigned(rbus_cmd'pos(cmd), 4))
        & std_logic_vector(to_unsigned(hops, 4));
  return r;
end function;

function data_word_8b(d : std_logic_vector(7 downto 0))
  return rbus_word_8b is
  variable r : rbus_word_8b;
begin
  r.fr := '0';
  r.d  := d;
  return r;
end function;

function data_word_8b(d : integer)
  return rbus_word_8b is
begin
  return data_word_8b(std_logic_vector(to_unsigned(d, 8)));
end function;

function cmd_word_9b(cmd : rbus_cmd; hops : cmd_hops)
  return rbus_word_9b is
  variable r : rbus_word_9b;
begin
  r.fr := '1';
  r.d  := std_logic_vector(to_unsigned(rbus_cmd'pos(cmd), 4))
        & std_logic_vector(to_unsigned(hops, 4))
        & '0';
  return r;
end function;

function data_word_9b(d : std_logic_vector(8 downto 0))
  return rbus_word_9b is
  variable r : rbus_word_9b;
begin
  r.fr := '0';
  r.d  := d;
  return r;
end function;

function data_word_9b(d : integer)
  return rbus_word_9b is
begin
  return data_word_9b(std_logic_vector(to_unsigned(d, 9)));
end function;

function to_cmd(d : std_logic_vector)
  return rbus_cmd is
  alias da : std_logic_vector(d'length-1 downto 0) is d;
  variable dv : std_logic_vector(3 downto 0) := da(da'left downto da'left - 3);
begin
  return rbus_cmd'val(to_integer(unsigned(dv)));
end function;

function to_hops(d : std_logic_vector)
  return cmd_hops is
  alias da : std_logic_vector(d'length-1 downto 0) is d;
  variable dv : std_logic_vector(3 downto 0) := da(da'left - 4 downto da'left - 7);
begin
  return to_integer(unsigned(dv));
end function;

function is_cmd(fr : std_logic; d : std_logic_vector; cmd : rbus_cmd)
  return boolean is
begin
  if fr = '1' then
    return to_cmd(d) = cmd;
  else
    return false;
  end if;
end;

-- returns true for commands that can be safely dropped
function can_discard(fr : std_logic; d : std_logic_vector)
  return boolean is
  variable cmd : rbus_cmd;
begin
  if fr = '1' then
    cmd := to_cmd(d);
    return cmd = IDLE or cmd = BUSY;
  else
    return false;
  end if;
end;

-- returns true for words that are commands starting a message
function cmd_starts_msg(fr : std_logic; d : std_logic_vector)
  return boolean is
  variable cmd : rbus_cmd;
begin
  if fr = '1' then
    cmd := to_cmd(d);
    -- check if next word is the start of a new message
    return cmd /= BUSY and cmd /= TSEQ and cmd /= TSTAMP;
  else
    return false;
  end if;
end;

#define ADD_SUFFIX(x) x ## 9b
#include "ring_bus_pkg_body_generic.vhd"
#undef ADD_SUFFIX

#define ADD_SUFFIX(x) x ## 8b
#include "ring_bus_pkg_body_generic.vhd"

end ring_bus_pack;
