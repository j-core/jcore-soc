
-- This file is included by ring_bus_pkg_body.vhmh in order to create 8b and 9b
-- versions of the bus helper procedures

#define RBUS_NODE_ENTITY ADD_SUFFIX(rbus_node_)
#define RBUS_WORD ADD_SUFFIX(rbus_word_)
#define RBUS_SCRATCH ADD_SUFFIX(rbus_scratch_)

function is_idle(word : RBUS_WORD)
  return boolean is
begin
  return is_cmd(word.fr, word.d, IDLE);
end;

function is_cmd(word : RBUS_WORD; cmd : rbus_cmd)
  return boolean is
begin
  return is_cmd(word.fr, word.d, cmd);
end;

function can_discard(word : RBUS_WORD)
  return boolean is
  variable cmd : rbus_cmd;
begin
  return can_discard(word.fr, word.d);
end;

function cmd_starts_msg(word : RBUS_WORD)
  return boolean is
  variable cmd : rbus_cmd;
begin
  return cmd_starts_msg(word.fr, word.d);
end;

procedure rbus_node_inputs(
  this    : inout ADD_SUFFIX(rbus_node_reg_);
  bus_i   : in    RBUS_WORD;
  stall_i : in    std_logic;
  scratch : out   RBUS_SCRATCH;
  inputs  : out   ADD_SUFFIX(rbus_inputs_))
is
  variable cmd : rbus_cmd;
  variable hops : cmd_hops;
  variable next_word : RBUS_WORD;
begin
  if stall_i = '1' then
    -- this node is being stalled by the next node in the bus so we must not
    -- change this.bus_o

    -- don't pass anything new to the device this cycle
    inputs.en   := '0';
    inputs.word := ADD_SUFFIX(IDLE_);
    -- queue the next incoming bus word if not queueing a useful word yet
    if can_discard(this.stalled) then
      this.stalled := bus_i;
    end if;
    scratch.next_in := ADD_SUFFIX(IDLE_);
    scratch.next_out := ADD_SUFFIX(IDLE_);
  else
    -- determine next incoming word which is either from the bus or is the
    -- word queued during a stall
    if can_discard(this.stalled) then
      -- next word comes from the bus
      next_word := bus_i;
    else
      -- next word comes from the queued word
      next_word := this.stalled;
      this.stalled := ADD_SUFFIX(IDLE_);
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
        next_word := ADD_SUFFIX(cmd_word_)(cmd, hops);
      end if;
    end if;
    -- send input or stalled word to device
    inputs.word := next_word;
    scratch.next_out := next_word;
  end if;
end;

procedure rbus_node_outputs(
  this    : inout ADD_SUFFIX(rbus_node_reg_);
  stall_i : in    std_logic;
  scratch : in    RBUS_SCRATCH;
  outputs : in    ADD_SUFFIX(rbus_outputs_);
  ack     : out   std_logic)
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
