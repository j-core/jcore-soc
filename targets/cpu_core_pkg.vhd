library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.data_bus_pack.all;
use work.cpu2j0_pack.all;

package cpu_core_pack is
  type core_data_bus_device_t is (
    DEV_NONE,
    DEV_DDR,
    DEV_SRAM,
    DEV_PERIPH,
    DEV_CPU);
  type core_data_bus_i_t is array(core_data_bus_device_t'left to core_data_bus_device_t'right)
    of cpu_data_i_t;
  type core_data_bus_o_t is array(core_data_bus_device_t'left to core_data_bus_device_t'right)
    of cpu_data_o_t;

  type core_instr_bus_device_t is (
    DEV_NONE,
    DEV_DDR,
    DEV_SRAM);
  type core_instr_bus_i_t is array(core_instr_bus_device_t'left to core_instr_bus_device_t'right)
    of cpu_instruction_i_t;
  type core_instr_bus_o_t is array(core_instr_bus_device_t'left to core_instr_bus_device_t'right)
    of cpu_instruction_o_t;

  type cpumreg_state_t is ( IDLE, LOCK0, LOCK1 );

  type ram_arb_o_t is record
    en : std_logic;
    wr : std_logic;
    lock : std_logic;
  end record;

  type cpumreg_reg_t is record
    cpu1en : std_logic;
    state_ramarb : cpumreg_state_t;
  end record;

  constant CPUMREG_REG_RESET : cpumreg_reg_t := (
    '0' , IDLE );

  function decode_core_data_addr(addr : std_logic_vector(31 downto 0))
    return core_data_bus_device_t;

  procedure core_data_bus_mux(
    signal master_i : out cpu_data_i_t;
    signal master_o : in  cpu_data_o_t;
    selected        : in  core_data_bus_device_t;
    signal slaves_i : in  core_data_bus_i_t;
    signal slaves_o : out core_data_bus_o_t);

  function decode_core_instr_addr(addr : std_logic_vector(31 downto 1))
    return core_instr_bus_device_t;

  procedure core_instr_bus_mux(
    signal master_i : out cpu_instruction_i_t;
    signal master_o : in  cpu_instruction_o_t;
    selected        : in  core_instr_bus_device_t;
    signal slaves_i : in  core_instr_bus_i_t;
    signal slaves_o : out core_instr_bus_o_t);

  component cpumreg is port (
    clk : in std_logic;
    rst : in std_logic;
    -- cpu target port
    db0_i : in cpu_data_o_t;
    db1_i : in cpu_data_o_t;
    -- ram arbitration control
    ram0_arb_o : in ram_arb_o_t;
    ram1_arb_o : in ram_arb_o_t;
    -- cpu target port
    db0_o : out cpu_data_i_t;
    db1_o : out cpu_data_i_t;
    cpu0ram_a_en : out std_logic;
    cpu1ram_a_en : out std_logic);
  end component;

  component cpu_core is
    port (
      clk : in std_logic;
      rst : in std_logic;

      instr_bus_o : out instr_bus_o_t;
      instr_bus_i : in  instr_bus_i_t;

      data_bus_lock : out std_logic;
      data_bus_o    : out data_bus_o_t;
      data_bus_i    : in  data_bus_i_t;

      debug_o : out cpu_debug_o_t;
      debug_i : in  cpu_debug_i_t;

      event_o : out cpu_event_o_t;
      event_i : in  cpu_event_i_t;

      data_master_en : out std_logic;
      data_master_ack : out std_logic);
  end component;
end package;

package body cpu_core_pack is
  function is_prefix(addr : std_logic_vector;
                     prefix : std_logic_vector)
  return boolean is
  begin
    return addr(addr'left downto (addr'left - prefix'high + prefix'low)) = prefix;
  end function;

  -- determine device from data address
  function decode_core_data_addr(addr : std_logic_vector(31 downto 0))
  return core_data_bus_device_t is
  begin
    case addr(31 downto 28) is
      when x"0" =>
        -- TODO: Should this be more selective and avoid mirroring the SRAM?
        -- Keep in synch with decode_core_instr_addr()
        return DEV_SRAM;
      when x"1" =>
        return DEV_DDR;
      when x"a" =>
        case addr(27 downto 8) is
          -- This address, 0xabcd0600-0xabcd06ff, is hard-coded in soc_gen as an already
          -- used address range. If you change this, change soc_gen too.
          when x"bcd06" =>
            return DEV_CPU;
          when others =>
            -- The restriction that peripheral addresses start with 0xa is
            -- hard-coded in soc_gen. If you change this, change soc_gen too.
            return DEV_PERIPH;
        end case;
      when others =>
        return DEV_NONE;
    end case;
  end function;

  -- connect master and slave data buses
  procedure core_data_bus_mux(
    signal master_i : out cpu_data_i_t;
    signal master_o : in  cpu_data_o_t;
    selected        : in  core_data_bus_device_t;
    signal slaves_i : in  core_data_bus_i_t;
    signal slaves_o : out core_data_bus_o_t) is
  begin
    master_i <= slaves_i(selected);

    -- split outgoing data bus, masked by device
    for dev in core_data_bus_device_t'left to core_data_bus_device_t'right loop
      slaves_o(dev) <= mask_data_o(master_o, to_bit(dev = selected));
    end loop;
  end;

  -- determine device from instruction address
  function decode_core_instr_addr(addr : std_logic_vector(31 downto 1))
  return core_instr_bus_device_t is
  begin
    case addr(31 downto 28) is
      when x"0" =>
        -- TODO: Should this be more restrictive and avoid mirroring SRAM?
        -- Keep in synch with decode_core_data_addr()
        return DEV_SRAM;
      when x"1" =>
        return DEV_DDR;
      when others =>
        return DEV_NONE;
    end case;
  end function;

  -- connect master and slave instruction buses
  procedure core_instr_bus_mux(
    signal master_i : out cpu_instruction_i_t;
    signal master_o : in  cpu_instruction_o_t;
    selected        : in  core_instr_bus_device_t;
    signal slaves_i : in  core_instr_bus_i_t;
    signal slaves_o : out core_instr_bus_o_t) is
  begin
    -- select incoming bus
    master_i <= slaves_i(selected);

    -- split outgoing bus, masked by device
    for dev in core_instr_bus_device_t'left to core_instr_bus_device_t'right loop
      slaves_o(dev) <= master_o;
      slaves_o(dev).en <= master_o.en and to_bit(dev = selected);
    end loop;
  end;
end package body;
