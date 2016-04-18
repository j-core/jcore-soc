-- A ROM with instruction and data bus ports.
library ieee;
use ieee.std_logic_1164.all;

use work.cpu2j0_pack.all;
use work.bus_mux_pkg.all;
use work.memory_pack.all;
use work.data_bus_pack.all;

entity cpu_rom is
  generic (
    ADDR_WIDTH : natural);
  port (
    clk : in std_logic;
    rst : in std_logic;
    dbus_o : in  cpu_data_o_t;
    dbus_i : out cpu_data_i_t;
    ibus_o : in  cpu_instruction_o_t;
    ibus_i : out cpu_instruction_i_t);
end entity;

architecture arch of cpu_rom is
  signal instr_dbus_o : cpu_data_o_t;
  signal instr_dbus_i : cpu_data_i_t;
  signal rom_bus_o : cpu_data_o_t;
  signal rom_bus_i : cpu_data_i_t;

  signal clkn : std_logic;
begin
  splice_instr_data_bus(ibus_o, ibus_i, instr_dbus_o, instr_dbus_i);

  -- The underlying memory has only 1 read port, so use external mux to combine
  -- them
  u_bmux : multi_master_bus_mux port map(
    rst => rst,
    clk => clk,
    m1_i => dbus_i, m1_o => dbus_o,
    m2_i => instr_dbus_i, m2_o => instr_dbus_o,
    slave_i => rom_bus_i, slave_o => rom_bus_o);

  -- TODO: Need some way to initialize the ROM
  clkn <= not clk;

  rom : rom_1r
    generic map (
      DATA_WIDTH => 32,
      -- -2 because lower 2 bits specify byte within the word
      ADDR_WIDTH => ADDR_WIDTH - 2)
    port map (
      clk => clkn,
      -- treats writes as reads, but that's ok
      en => rom_bus_o.en,
      a => rom_bus_o.a(ADDR_WIDTH - 1 downto 2),
      d => rom_bus_i.d,
      -- TODO: Expose margin
      margin => '0');

  rom_bus_i.ack <= rom_bus_o.en;
end architecture;
