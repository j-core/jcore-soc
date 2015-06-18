#include "config.h"

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu2j0_pack.all;
use work.data_bus_pack.all;
use work.cpu_core_pack.all;
use work.misc_pack.all;

entity cpu_core is
  generic (
    bus_period : integer
  );
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

    -- external event interface
    -- AIC should multiplex events from these ports and events from old-style
    -- interrupts lines. Currently these ports are not used, but eventually they
    -- will supplant the irqs port.
    --event_o : out cpu_event_o_t;
    --event_i : in  cpu_event_i_t;
    -- legacy irq lines
    irq_i : in std_logic_vector(7 downto 0);

    -- Currently the time comes from the AIC so these ports need to be here.
    -- This will change.
    rtc_sec : out std_logic_vector(63 downto 0);
    rtc_nsec : out std_logic_vector(31 downto 0)
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

  signal internal_event_o : cpu_event_o_t;
  signal internal_event_i : cpu_event_i_t;
#if CONFIG_AIC == 1
  signal event_req : std_logic_vector(2 downto 0);
  signal event_info : std_logic_vector(11 downto 0);
#endif

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
      event_o => internal_event_o,
      event_i => internal_event_i
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

  instr_bus_o(DEV_SRAM) <= instr_slaves_o(DEV_SRAM);
  instr_slaves_i(DEV_SRAM) <= instr_bus_i(DEV_SRAM);

  instr_bus_o(DEV_DDR) <= instr_slaves_o(DEV_DDR);
  instr_slaves_i(DEV_DDR) <= instr_bus_i(DEV_DDR);

  -- terminate NONE buses. TODO: Generate bus error events?
  instr_slaves_i(DEV_NONE) <= loopback_bus(instr_slaves_o(DEV_NONE));
  data_slaves_i(DEV_NONE) <= loopback_bus(data_slaves_o(DEV_NONE));

#if CONFIG_AIC == 1
  u_aic : aic
    generic map (c_busperiod => bus_period)
    port map(
      clk_bus => clk, rst_i => rst,
      db_i => data_slaves_o(DEV_AIC), db_o => data_slaves_i(DEV_AIC),
      bstb_i => data_master_o.en, back_i => data_master_i.ack, 
      rtc_sec => rtc_sec, rtc_nsec => rtc_nsec, irq_i => irq_i,
      event_req => event_req, event_info => event_info,
      enmi_i => '1', event_ack_i => internal_event_o.ack);
  internal_event_i <= to_event_i(event_req, event_info);
#else
  data_slaves_i(DEV_AIC) <= loopback_bus(data_slaves_o(DEV_AIC));
  internal_event_i <= NULL_CPU_EVENT_I;
#endif

end architecture;
