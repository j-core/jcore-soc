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
  r.d := std_logic_vector(to_unsigned(rbus_cmd'pos(cmd), 4))
        & std_logic_vector(to_unsigned(hops, 4));
  return r;
end function;
function data_word_8b(d : std_logic_vector(7 downto 0))
  return rbus_word_8b is
  variable r : rbus_word_8b;
begin
  r.fr := '0';
  r.d := d;
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
  r.d := std_logic_vector(to_unsigned(rbus_cmd'pos(cmd), 4))
        & std_logic_vector(to_unsigned(hops, 4))
        & '0';
  return r;
end function;
function data_word_9b(d : std_logic_vector(8 downto 0))
  return rbus_word_9b is
  variable r : rbus_word_9b;
begin
  r.fr := '0';
  r.d := d;
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
-- This file is included by ring_bus_pkg_body.vhmh in order to create 8b and 9b
-- versions of the bus helper procedures
function is_idle(word : rbus_word_9b)
  return boolean is
begin
  return is_cmd(word.fr, word.d, IDLE);
end;
function is_cmd(word : rbus_word_9b; cmd : rbus_cmd)
  return boolean is
begin
  return is_cmd(word.fr, word.d, cmd);
end;
function can_discard(word : rbus_word_9b)
  return boolean is
  variable cmd : rbus_cmd;
begin
  return can_discard(word.fr, word.d);
end;
function cmd_starts_msg(word : rbus_word_9b)
  return boolean is
  variable cmd : rbus_cmd;
begin
  return cmd_starts_msg(word.fr, word.d);
end;
procedure rbus_node_inputs(
  this : inout rbus_node_reg_9b;
  bus_i : in rbus_word_9b;
  stall_i : in std_logic;
  scratch : out rbus_scratch_9b;
  inputs : out rbus_inputs_9b)
is
  variable cmd : rbus_cmd;
  variable hops : cmd_hops;
  variable next_word : rbus_word_9b;
begin
  if stall_i = '1' then
    -- this node is being stalled by the next node in the bus so we must not
    -- change this.bus_o
    -- don't pass anything new to the device this cycle
    inputs.en := '0';
    inputs.word := IDLE_9b;
    -- queue the next incoming bus word if not queueing a useful word yet
    if can_discard(this.stalled) then
      this.stalled := bus_i;
    end if;
    scratch.next_in := IDLE_9b;
    scratch.next_out := IDLE_9b;
  else
    -- determine next incoming word which is either from the bus or is the
    -- word queued during a stall
    if can_discard(this.stalled) then
      -- next word comes from the bus
      next_word := bus_i;
    else
      -- next word comes from the queued word
      next_word := this.stalled;
      this.stalled := IDLE_9b;
    end if;
    -- inform device whether it should pay attention to the d output
    if this.mode = FORWARD then
      inputs.en := '0';
    -- even in FORWARD, later logic will set '1' if it is the start of a
    -- new message
    else
      inputs.en := '1';
    end if;
    scratch.next_in := next_word;
    -- treat command words that start messages specially
    if cmd_starts_msg(next_word) then
      cmd := to_cmd(next_word.d);
      -- tell device to pay attention to new message
      inputs.en := '1';
      -- update hop count. decrement to zero
      hops := to_hops(next_word.d);
      if hops /= 0 then
        hops := hops - 1;
        next_word := cmd_word_9b(cmd, hops);
      end if;
    end if;
    -- send input or stalled word to device
    inputs.word := next_word;
    scratch.next_out := next_word;
  end if;
end;
procedure rbus_node_outputs(
  this : inout rbus_node_reg_9b;
  stall_i : in std_logic;
  scratch : in rbus_scratch_9b;
  outputs : in rbus_outputs_9b;
  ack : out std_logic)
is
begin
  if stall_i = '1' then
    -- and tell device what it sends this cycle won't be used
    ack := '0';
  else
    -- allow switching between RECEIVE and TRANSMIT modes to support
    -- replacing messages on the bus with larger messages. For example, when
    -- responding to a READ command, the device replace it with a WRITE, but
    -- the data might take additional cycles to fetch so the WRITE could
    -- contain BUSY commands.
    if cmd_starts_msg(scratch.next_out)
      or (this.mode = RECEIVE and outputs.mode = TRANSMIT)
      or (this.mode = TRANSMIT and outputs.mode = RECEIVE)
      -- allow switching from SNOOP to FORWARD to let nodes decide part way
      -- through a message to no longer pay attention to it
      -- TODO: Should this be allowed?
      --or (this.mode = SNOOP and outputs.mode = FORWARD)
    then
      this.mode := outputs.mode;
    end if;
    -- send to bus
    if this.mode = FORWARD or this.mode = SNOOP then
      -- send word from bus input
      this.bus_o.word := scratch.next_out;
      ack := '0';
    else
      -- send word from device
      this.bus_o.word := outputs.word;
      ack := '1';
    end if;
    if this.mode = TRANSMIT then
      this.stalled := scratch.next_in;
    end if;
  end if;
  -- Determine when to stall based on when command from the bus is queued.
  -- This can_discard check avoids queueing some words by not stalling the
  -- previous node. This drops IDLE and BUSY commands during stalls.
  if can_discard(this.stalled) then
    this.bus_o.stall := '0';
  else
    this.bus_o.stall := '1';
  end if;
end;
-- This file is included by ring_bus_pkg_body.vhmh in order to create 8b and 9b
-- versions of the bus helper procedures
function is_idle(word : rbus_word_8b)
  return boolean is
begin
  return is_cmd(word.fr, word.d, IDLE);
end;
function is_cmd(word : rbus_word_8b; cmd : rbus_cmd)
  return boolean is
begin
  return is_cmd(word.fr, word.d, cmd);
end;
function can_discard(word : rbus_word_8b)
  return boolean is
  variable cmd : rbus_cmd;
begin
  return can_discard(word.fr, word.d);
end;
function cmd_starts_msg(word : rbus_word_8b)
  return boolean is
  variable cmd : rbus_cmd;
begin
  return cmd_starts_msg(word.fr, word.d);
end;
procedure rbus_node_inputs(
  this : inout rbus_node_reg_8b;
  bus_i : in rbus_word_8b;
  stall_i : in std_logic;
  scratch : out rbus_scratch_8b;
  inputs : out rbus_inputs_8b)
is
  variable cmd : rbus_cmd;
  variable hops : cmd_hops;
  variable next_word : rbus_word_8b;
begin
  if stall_i = '1' then
    -- this node is being stalled by the next node in the bus so we must not
    -- change this.bus_o
    -- don't pass anything new to the device this cycle
    inputs.en := '0';
    inputs.word := IDLE_8b;
    -- queue the next incoming bus word if not queueing a useful word yet
    if can_discard(this.stalled) then
      this.stalled := bus_i;
    end if;
    scratch.next_in := IDLE_8b;
    scratch.next_out := IDLE_8b;
  else
    -- determine next incoming word which is either from the bus or is the
    -- word queued during a stall
    if can_discard(this.stalled) then
      -- next word comes from the bus
      next_word := bus_i;
    else
      -- next word comes from the queued word
      next_word := this.stalled;
      this.stalled := IDLE_8b;
    end if;
    -- inform device whether it should pay attention to the d output
    if this.mode = FORWARD then
      inputs.en := '0';
    -- even in FORWARD, later logic will set '1' if it is the start of a
    -- new message
    else
      inputs.en := '1';
    end if;
    scratch.next_in := next_word;
    -- treat command words that start messages specially
    if cmd_starts_msg(next_word) then
      cmd := to_cmd(next_word.d);
      -- tell device to pay attention to new message
      inputs.en := '1';
      -- update hop count. decrement to zero
      hops := to_hops(next_word.d);
      if hops /= 0 then
        hops := hops - 1;
        next_word := cmd_word_8b(cmd, hops);
      end if;
    end if;
    -- send input or stalled word to device
    inputs.word := next_word;
    scratch.next_out := next_word;
  end if;
end;
procedure rbus_node_outputs(
  this : inout rbus_node_reg_8b;
  stall_i : in std_logic;
  scratch : in rbus_scratch_8b;
  outputs : in rbus_outputs_8b;
  ack : out std_logic)
is
begin
  if stall_i = '1' then
    -- and tell device what it sends this cycle won't be used
    ack := '0';
  else
    -- allow switching between RECEIVE and TRANSMIT modes to support
    -- replacing messages on the bus with larger messages. For example, when
    -- responding to a READ command, the device replace it with a WRITE, but
    -- the data might take additional cycles to fetch so the WRITE could
    -- contain BUSY commands.
    if cmd_starts_msg(scratch.next_out)
      or (this.mode = RECEIVE and outputs.mode = TRANSMIT)
      or (this.mode = TRANSMIT and outputs.mode = RECEIVE)
      -- allow switching from SNOOP to FORWARD to let nodes decide part way
      -- through a message to no longer pay attention to it
      -- TODO: Should this be allowed?
      --or (this.mode = SNOOP and outputs.mode = FORWARD)
    then
      this.mode := outputs.mode;
    end if;
    -- send to bus
    if this.mode = FORWARD or this.mode = SNOOP then
      -- send word from bus input
      this.bus_o.word := scratch.next_out;
      ack := '0';
    else
      -- send word from device
      this.bus_o.word := outputs.word;
      ack := '1';
    end if;
    if this.mode = TRANSMIT then
      this.stalled := scratch.next_in;
    end if;
  end if;
  -- Determine when to stall based on when command from the bus is queued.
  -- This can_discard check avoids queueing some words by not stalling the
  -- previous node. This drops IDLE and BUSY commands during stalls.
  if can_discard(this.stalled) then
    this.bus_o.stall := '0';
  else
    this.bus_o.stall := '1';
  end if;
end;
end ring_bus_pack;
