library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ring_bus_pack is

-- A ring bus for connecting multiple devices. Words of data are sent one step
-- along the bus in only one direction each clock cycle. Messages on the bus
-- are comprised of one or more words and each message has command type. 
  
-- Here are the possible command types
type rbus_cmd is (
  -- bus commands
  IDLE, -- indicates the bus is idle and any device can insert a message
  BUSY, -- indicates the bus is busy and the message being sent is not complete
        -- but the next word in the command is not yet available

  REG,
  OFFSET,
  READ,
  WRITE,
  INTERRUPT,
  BROADCAST,

  -- tag commands are used to add information to other commands
  TSEQ, -- a time relative to a seq number
  TSTAMP -- a time in seconds and nanoseconds
  );

-- A ring bus command word contains both the command type and a hop count which
-- is incremented as a command travels around a ring. The hop count can be used
-- to determine either the sender or receiver depending on it's initial value.
subtype cmd_hops is integer range 0 TO 15;

-- Two bus widths are supported: 8bit and 9 bit. 9 bit is meant to be used for
-- transmitting 2.16 fixed point data in two cycles. Smaller bit widths can be
-- supported by inserting entities between ring bus nodes to serialize to the
-- smaller width, deserialize back to 8 or 9 bits, and use the stall and busy
-- commands to communicate when data is not yet ready.

type rbus_word_8b is record
  fr : std_logic;
  d  : std_logic_vector(7 downto 0);
end record;

type rbus_word_9b is record
  fr : std_logic;
  d  : std_logic_vector(8 downto 0);
end record;

-- Helper functions for interacting with ring bus words

function cmd_word_8b(cmd : rbus_cmd; hops : cmd_hops)
  return rbus_word_8b;

function data_word_8b(d : std_logic_vector(7 downto 0))
  return rbus_word_8b;

function data_word_8b(d : integer)
  return rbus_word_8b;

function cmd_word_9b(cmd : rbus_cmd; hops : cmd_hops)
  return rbus_word_9b;

function data_word_9b(d : std_logic_vector(8 downto 0))
  return rbus_word_9b;

function data_word_9b(d : integer)
  return rbus_word_9b;

function to_cmd(d : std_logic_vector)
  return rbus_cmd;

function to_hops(d : std_logic_vector)
  return cmd_hops;

function is_idle(word : rbus_word_8b)
  return boolean;

function is_idle(word : rbus_word_9b)
  return boolean;

function is_cmd(word : rbus_word_8b; cmd : rbus_cmd)
  return boolean;

function is_cmd(word : rbus_word_9b; cmd : rbus_cmd)
  return boolean;

function can_discard(word : rbus_word_8b)
  return boolean;

function can_discard(word : rbus_word_9b)
  return boolean;

function cmd_starts_msg(word : rbus_word_8b)
  return boolean;

function cmd_starts_msg(word : rbus_word_9b)
  return boolean;

-- The bus itself is a word going in one direction, and a stall line going in
-- the other direction
type rbus_8b is record
  word : rbus_word_8b;
  stall : std_logic;
end record;

type rbus_9b is record
  word : rbus_word_9b;
  stall : std_logic;
end record;

type rbus_8b_array is array(integer range <>) of rbus_8b;
type rbus_9b_array is array(integer range <>) of rbus_9b;

-- The mode determines what a node does with commands received from the bus.
type rbus_node_mode is (
  FORWARD, -- pass command along the bus
  SNOOP,   -- pass command to both the device and along the bus
  RECEIVE, -- pass command to the attached device and send from device
  TRANSMIT -- stall bus commands and send from device
);

constant IDLE_8B : rbus_word_8b := cmd_word_8b(IDLE, 0);
constant IDLE_9B : rbus_word_9b := cmd_word_9b(IDLE, 0);

constant RBUS_IDLE_8B : rbus_8b := (IDLE_8B, '0');
constant RBUS_IDLE_9B : rbus_9b := (IDLE_9B, '0');

type rbus_dev_i_8b is record
  -- en and d are a bus word coming from the bus
  -- if en='0' then d is not valid
  en   : std_logic;
  -- holds the incoming word from the bus. This may be a word stalled from a
  -- previous cycle's input under some conditions.
  word : rbus_word_8b;

  -- acknowledges the word in the rbus_dev_o was sent
  -- on the bus output. Can only go high in the RECEIVE and TRANSMIT states.
  ack  : std_logic;
end record;

type rbus_dev_o_8b is record
  -- the requested mode to change the node to. Mode changes can usually only
  -- occur at the start of a message. Changes between RECEIVE and TRASMIT are
  -- allowed any cycle
  mode : rbus_node_mode;
  -- word to send on the bus. This is only used in the RECEIVE and
  -- TRANSMIT states
  word : rbus_word_8b;
end record;

type rbus_dev_i_9b is record
  -- en and word are a bus word coming from the bus
  -- if en='0' then word is not valid
  en   : std_logic;
  word : rbus_word_9b;

  -- acknowledges the word in the rbus_dev_o was sent
  -- on the bus output
  ack  : std_logic;
end record;

type rbus_dev_o_9b is record
  mode : rbus_node_mode;
  word : rbus_word_9b;
end record;

-- Ring bus nodes can be implemented either with a separate instantiated
-- component connected to the bus or with the
-- rbus_node_inputs/rbus_node_outputs procedures. The later seems to integrate
-- better with the 2-process method.

component rbus_node_8b is port (
  clk : in std_logic;
  rst : in std_logic;

  -- connections to predesessor in ring bus
  bus_i : in rbus_word_8b;
  stall_o : out std_logic;

  -- connections to successor in ring bus
  bus_o : out rbus_word_8b;
  stall_i : in std_logic;

  -- connections to peripheral device
  dev_o : out rbus_dev_i_8b;
  dev_i : in  rbus_dev_o_8b);
end component;

component rbus_node_9b is port (
  clk : in std_logic;
  rst : in std_logic;

  -- connections to predesessor in ring bus
  bus_i : in rbus_word_9b;
  stall_o : out std_logic;

  -- connections to successor in ring bus
  bus_o : out rbus_word_9b;
  stall_i : in std_logic;

  -- connections to peripheral device
  dev_o : out rbus_dev_i_9b;
  dev_i : in  rbus_dev_o_9b);
end component;


-- These register types are used by the rbus_node_inputs/rbus_node_outputs
-- procedures. Add one of these registers into the register record of a vhm
-- entity and then call rbus_node_inputs and rbus_node_outputs to connect the
-- entity to the ring bus.

type rbus_node_reg_8b is record
  stalled : rbus_word_8b;
  bus_o   : rbus_8b;
  --bus_o   : rbus_word_8b;
  --stall_o : std_logic;
  mode    : rbus_node_mode;
  dev_o   : rbus_dev_i_8b;
end record;

constant RBUS_NODE_RESET_8B : rbus_node_reg_8b := (
  stalled => IDLE_8B,
  bus_o   => (IDLE_8B, '0'),
  mode    => FORWARD,
  dev_o   => (word => IDLE_8B, en => '0', ack => '0')
);

type rbus_node_reg_9b is record
  stalled : rbus_word_9b;
  bus_o   : rbus_9b;
  --bus_o   : rbus_word_9b;
  --stall_o : std_logic;
  mode    : rbus_node_mode;
  dev_o   : rbus_dev_i_9b;
end record;

constant RBUS_NODE_RESET_9B : rbus_node_reg_9b := (
  stalled => IDLE_9B,
  bus_o   => (IDLE_9B, '0'),
  mode    => FORWARD,
  dev_o   => (word => IDLE_9B, en => '0', ack => '0')
);

-- scratch storage set by rbus_node_inputs to share state with rbus_node_outputs
type rbus_scratch_8b is record
  next_in  : rbus_word_8b;
  next_out : rbus_word_8b;
end record;

type rbus_scratch_9b is record
  next_in  : rbus_word_9b;
  next_out : rbus_word_9b;
end record;


-- rbus_inputs_* hold input from the ring bus that is set by the
-- rbus_node_inputs procedure
type rbus_inputs_8b is record
  en   : std_logic;
  word : rbus_word_8b;
end record;

type rbus_inputs_9b is record
  en   : std_logic;
  word : rbus_word_9b;
end record;

-- rbus_outputs_* hold output to the ring bus that is read by the
-- rbus_node_outputs procedure
type rbus_outputs_8b is record
  mode : rbus_node_mode;
  word : rbus_word_8b;
end record;

type rbus_outputs_9b is record
  mode : rbus_node_mode;
  word : rbus_word_9b;
end record;

constant RBUS_OUTPUTS_FORWARD_8B : rbus_outputs_8b := (FORWARD, IDLE_8B);
constant RBUS_OUTPUTS_FORWARD_9B : rbus_outputs_9b := (FORWARD, IDLE_9B);

-- These are procedures for the logic common to all ring bus nodes
procedure rbus_node_inputs(
  this    : inout rbus_node_reg_9b;
  bus_i   : in    rbus_word_9b;
  stall_i : in    std_logic;
  scratch : out   rbus_scratch_9b;
  inputs  : out   rbus_inputs_9b);
procedure rbus_node_outputs(
  this    : inout rbus_node_reg_9b;
  stall_i : in    std_logic;
  scratch : in    rbus_scratch_9b;
  outputs : in    rbus_outputs_9b;
  ack     : out   std_logic);
procedure rbus_node_inputs(
  this    : inout rbus_node_reg_8b;
  bus_i   : in    rbus_word_8b;
  stall_i : in    std_logic;
  scratch : out   rbus_scratch_8b;
  inputs  : out   rbus_inputs_8b);
procedure rbus_node_outputs(
  this    : inout rbus_node_reg_8b;
  stall_i : in    std_logic;
  scratch : in    rbus_scratch_8b;
  outputs : in    rbus_outputs_8b;
  ack     : out   std_logic);

end package;
