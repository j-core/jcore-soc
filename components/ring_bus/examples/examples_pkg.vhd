library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cpu2j0_pack.all;
use work.ring_bus_pack.all;

package examples_pack is

type data_bus_adapter_state is (
  IGNORE,
  ADDRESS,
  READ_ISSUE,
  READ_REPLY,
  WRITE_RECEIVE,
  WRITE_ISSUE,
  INTERRUPT
  );

subtype state_count is integer range 0 TO 4;
  
type data_bus_adapter_reg is record
  node_this : rbus_node_reg_8b;

  state : data_bus_adapter_state;
  state_count : state_count;
  data_o : cpu_data_o_t;

  a : std_logic_vector(31 downto 0);
  d : std_logic_vector(31 downto 0);

  irq : std_logic;
  prev_irq : std_logic;
end record;

constant DATA_BUS_ADAPTER_RESET : data_bus_adapter_reg := (
  node_this => RBUS_NODE_RESET_8B,
  state => IGNORE,
  state_count => 0,
  data_o => NULL_DATA_O,
  a => (others => '0'),
  d => (others => '0'),
  irq => '0',
  prev_irq => '0'
);

component data_bus_adapter is port (
  clk : in std_logic;
  rst : in std_logic;

  -- connections to predesessor in ring bus
  bus_i : in rbus_word_8b;
  stall_o : out std_logic;

  -- connections to successor in ring bus
  bus_o : out rbus_word_8b;
  stall_i : in std_logic;

  data_o : out cpu_data_o_t;
  data_i : in cpu_data_i_t;
  irq : in std_logic);
end component;

type rbus_data_master_send_state is (
  IDLE,
  SEND_OFFSET,
  SEND_READ,
  SEND_WRITE
);

type rbus_data_master_recv_state is (
  IDLE,
  RECV_WRITE
);

subtype data_word is std_logic_vector(31 downto 0);

type rbus_master_request is record
  active : boolean;
  hops : cmd_hops;
  send_data : data_word;
  recv_data : data_word;
  cmd : rbus_cmd;
end record;

constant MASTER_REQUEST_RESET : rbus_master_request := (
  active => false,
  hops => 0,
  send_data => (others => '0'),
  recv_data => (others => '0'),
  cmd => IDLE
);

type rbus_data_master_reg is record
  send_state : rbus_data_master_send_state;
  send_count : state_count;
  recv_state : rbus_data_master_recv_state;
  recv_count : state_count;
  send_node : rbus_node_reg_8b;
  recv_node : rbus_node_reg_8b;
  data_o : cpu_data_i_t;
  request : rbus_master_request;
end record;

constant RBUS_DATA_MASTER_RESET : rbus_data_master_reg := (
  send_state => IDLE,
  send_count => 0,
  recv_state => IDLE,
  recv_count => 0,
  send_node => RBUS_NODE_RESET_8B,
  recv_node => RBUS_NODE_RESET_8B,
  data_o => (ack => '0', d => x"00000000"),
  request => MASTER_REQUEST_RESET
);

component rbus_data_master is port (
  clk : in std_logic;
  rst : in std_logic;

  -- ports to data bus master
  data_i : in cpu_data_o_t;
  data_o : out cpu_data_i_t;

  -- ports to start of ring
  bus_o : out rbus_word_8b;
  stall_i : in std_logic;

  -- ports to end of ring
  bus_i : in rbus_word_8b;
  stall_o : out std_logic);
end component;

function shift_in_right(dest : std_logic_vector; new_data : std_logic_vector)
  return std_logic_vector;

function shift_out_left(bits : std_logic_vector; num_bits : natural)
  return std_logic_vector;

end package;

package body examples_pack is

function shift_in_right(dest : std_logic_vector; new_data : std_logic_vector)
  return std_logic_vector is
  alias destv : std_logic_vector(dest'length - 1 downto 0) is dest;
  alias new_datav : std_logic_vector(new_data'length - 1 downto 0) is new_data;

begin
  assert dest'length >= new_data'length
    report "shifted in data must be shorted than destination"
    severity failure;
  return destv(destv'left - new_datav'length downto 0) & new_datav;
end;

function shift_out_left(bits : std_logic_vector; num_bits : natural)
  return std_logic_vector is
  alias bitsv : std_logic_vector(bits'length - 1 downto 0) is bits;
  variable z : std_logic_vector(num_bits - 1 downto 0);
begin
  assert num_bits <= bits'length
    report "num_bits must be <= available bits"
                     severity failure;
  z := (others => '0');
  return bits(bits'left - num_bits downto 0) & z;
end;

end examples_pack;
