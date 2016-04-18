library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu2j0_pack.all;
use work.data_bus_pack.all;
use work.cpu_core_pack.all;
use work.misc_pack.all;
use work.config.all;

entity cpu_core is
  port (
    clk : in std_logic;
    rst : in std_logic;

    instr_bus_o : out instr_bus_o_t;
    instr_bus_i : in instr_bus_i_t;

    data_bus_lock : out std_logic;
    data_bus_o : out data_bus_o_t;
    data_bus_i : in data_bus_i_t;

    debug_o : out cpu_debug_o_t;
    debug_i : in  cpu_debug_i_t;

    event_o : out cpu_event_o_t;
    event_i : in  cpu_event_i_t;

    data_master_en : out std_logic;
    data_master_ack : out std_logic
    );
end entity;

architecture arch of cpu_core is
  signal data_master_i : cpu_data_i_t;
  signal data_master_o : cpu_data_o_t;
  signal data_slaves_i : core_data_bus_i_t;
  signal data_slaves_o : core_data_bus_o_t;

  signal instr_master_o : cpu_instruction_o_t;
  signal instr_master_i : cpu_instruction_i_t;
  signal instr_slaves_i : core_instr_bus_i_t;
  signal instr_slaves_o : core_instr_bus_o_t;

begin
  u_cpu : cpu
    port map (
      clk => clk,
      rst => rst,
      db_lock => data_bus_lock,
      db_o => data_master_o,
      db_i => data_master_i,
      inst_o => instr_master_o,
      inst_i => instr_master_i,
      debug_o => debug_o,
      debug_i => debug_i,
      event_o => event_o,
      event_i => event_i
    );

  -- select instruction bus device based on instruction address
  core_instr_bus_mux(
    master_i => instr_master_i, master_o => instr_master_o,
    selected => decode_core_instr_addr(instr_master_o.a),
    slaves_i => instr_slaves_i, slaves_o => instr_slaves_o);

  -- select data bus device based on data address.
  core_data_bus_mux(
    master_i => data_master_i, master_o => data_master_o,
    selected => decode_core_data_addr(data_master_o.a),
    slaves_i => data_slaves_i, slaves_o => data_slaves_o);

  -- connect buses to ports
  data_bus_o(DEV_SRAM) <= data_slaves_o(DEV_SRAM);
  data_slaves_i(DEV_SRAM) <= data_bus_i(DEV_SRAM);

  data_bus_o(DEV_DDR) <= data_slaves_o(DEV_DDR);
  data_slaves_i(DEV_DDR) <= data_bus_i(DEV_DDR);

  data_bus_o(DEV_PERIPH) <= data_slaves_o(DEV_PERIPH);
  data_slaves_i(DEV_PERIPH) <= data_bus_i(DEV_PERIPH);

  data_bus_o(DEV_CPU) <= data_slaves_o(DEV_CPU);
  data_slaves_i(DEV_CPU) <= data_bus_i(DEV_CPU);

  instr_bus_o(DEV_SRAM) <= instr_slaves_o(DEV_SRAM);
  instr_slaves_i(DEV_SRAM) <= instr_bus_i(DEV_SRAM);

  instr_bus_o(DEV_DDR) <= instr_slaves_o(DEV_DDR);
  instr_slaves_i(DEV_DDR) <= instr_bus_i(DEV_DDR);

  -- terminate NONE buses. TODO: Generate bus error events?
  instr_slaves_i(DEV_NONE) <= loopback_bus(instr_slaves_o(DEV_NONE));
  data_slaves_i(DEV_NONE) <= loopback_bus(data_slaves_o(DEV_NONE));

  data_master_en <= data_master_o.en;
  data_master_ack <= data_master_i.ack;

end architecture;
