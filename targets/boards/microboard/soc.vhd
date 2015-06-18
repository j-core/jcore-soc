-- Copyright (c) 2015, Smart Energy Instruments Inc.
-- All rights reserved.  For details, see COPYING in the top level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config.all;
use work.cpu2j0_pack.all;
use work.data_bus_pack.all;
use work.ddr_pack.all;
entity soc is
    port (
        clk_sys : in std_logic;
        clk_sys2x : in std_logic;
        clk_sys_90 : in std_logic;
        clock_locked : in std_logic;
        ddr_sd_ctrl : out sd_ctrl_t;
        ddr_sd_data_i : out sd_data_i_t;
        ddr_sd_data_o : in sd_data_o_t;
        pi : in std_logic_vector(31 downto 0);
        po : out std_logic_vector(31 downto 0);
        reset : in std_logic;
        spi_clk : out std_logic;
        spi_cs : out std_logic_vector(1 downto 0);
        spi_miso : in std_logic;
        spi_mosi : out std_logic;
        uart_rx : in std_logic;
        uart_tx : out std_logic
    );
end;
architecture impl of soc is
    signal cache01sel_ctrl_temp : std_logic;
    signal cpu0_ddr_dbus_i : cpu_data_i_t;
    signal cpu0_ddr_dbus_o : cpu_data_o_t;
    signal cpu0_ddr_ibus_i : cpu_instruction_i_t;
    signal cpu0_ddr_ibus_o : cpu_instruction_o_t;
    signal cpu0_mem_lock : std_logic;
    signal cpu0_periph_dbus_i : cpu_data_i_t;
    signal cpu0_periph_dbus_o : cpu_data_o_t;
    signal cpu1_ddr_dbus_i : cpu_data_i_t;
    signal cpu1_ddr_dbus_o : cpu_data_o_t;
    signal cpu1_ddr_ibus_i : cpu_instruction_i_t;
    signal cpu1_ddr_ibus_o : cpu_instruction_o_t;
    signal cpu1_mem_lock : std_logic;
    signal cpu1_periph_dbus_i : cpu_data_i_t;
    signal cpu1_periph_dbus_o : cpu_data_o_t;
    signal dcache_ctrl : cache_ctrl_t;
    signal ddr_bus_i : cpu_data_i_t;
    signal ddr_bus_o : cpu_data_o_t;
    signal debug_i : cpu_debug_i_t;
    signal icache0_ctrl : cache_ctrl_t;
    signal icache1_ctrl : cache_ctrl_t;
    signal irqs : std_logic_vector(7 downto 0);
begin
    ddr_ctrl : entity work.ddr_ctrl(logic)
        generic map (
            c_data_width => CFG_DDRDQ_WIDTH,
            c_dll_enable => 2,
            c_period_clkbus => CFG_BUS_PERIOD,
            c_sa_width => CFG_SA_WIDTH
        )
        port map (
            clk_2x => clk_sys2x,
            db_i => ddr_bus_o,
            db_o => ddr_bus_i,
            ddr_clk0 => clk_sys,
            ddr_clk90 => clk_sys_90,
            reset_in => reset,
            sd_ctrl => ddr_sd_ctrl,
            sd_data_i => ddr_sd_data_o,
            sd_data_o => ddr_sd_data_i
        );
    ddr_ram_mux : entity work.ddr_ram_mux(one_cpu_direct)
        port map (
            cache01sel_ctrl_temp => cache01sel_ctrl_temp,
            clk => clk_sys,
            clk_ddr => clock_locked,
            cpu0_dbus_i => cpu0_ddr_dbus_i,
            cpu0_dbus_o => cpu0_ddr_dbus_o,
            cpu0_ibus_i => cpu0_ddr_ibus_i,
            cpu0_ibus_o => cpu0_ddr_ibus_o,
            cpu0_mem_lock => cpu0_mem_lock,
            cpu1_dbus_i => cpu1_ddr_dbus_i,
            cpu1_dbus_o => cpu1_ddr_dbus_o,
            cpu1_ibus_i => cpu1_ddr_ibus_i,
            cpu1_ibus_o => cpu1_ddr_ibus_o,
            cpu1_mem_lock => cpu1_mem_lock,
            dcache_ctrl => dcache_ctrl,
            ddr_bus_i => ddr_bus_i,
            ddr_bus_o => ddr_bus_o,
            icache0_ctrl => icache0_ctrl,
            icache1_ctrl => icache1_ctrl,
            rst => reset
        );
    cpus : entity work.cpus(one_cpu)
        port map (
            clk => clk_sys,
            cpu0_ddr_dbus_i => cpu0_ddr_dbus_i,
            cpu0_ddr_dbus_o => cpu0_ddr_dbus_o,
            cpu0_ddr_ibus_i => cpu0_ddr_ibus_i,
            cpu0_ddr_ibus_o => cpu0_ddr_ibus_o,
            cpu0_mem_lock => cpu0_mem_lock,
            cpu0_periph_dbus_i => cpu0_periph_dbus_i,
            cpu0_periph_dbus_o => cpu0_periph_dbus_o,
            cpu1_ddr_dbus_i => cpu1_ddr_dbus_i,
            cpu1_ddr_dbus_o => cpu1_ddr_dbus_o,
            cpu1_ddr_ibus_i => cpu1_ddr_ibus_i,
            cpu1_ddr_ibus_o => cpu1_ddr_ibus_o,
            cpu1_mem_lock => cpu1_mem_lock,
            cpu1_periph_dbus_i => cpu1_periph_dbus_i,
            cpu1_periph_dbus_o => cpu1_periph_dbus_o,
            debug_i => debug_i,
            debug_o => open,
            irqs => irqs,
            rst => reset,
            rtc_nsec => open,
            rtc_sec => open
        );
    devices : entity work.devices(impl)
        port map (
            clk_sys => clk_sys,
            cpu0_periph_dbus_i => cpu0_periph_dbus_i,
            cpu0_periph_dbus_o => cpu0_periph_dbus_o,
            cpu1_periph_dbus_i => cpu1_periph_dbus_i,
            cpu1_periph_dbus_o => cpu1_periph_dbus_o,
            irqs => irqs,
            pi => pi,
            po => po,
            reset => reset,
            spi_clk => spi_clk,
            spi_cs => spi_cs,
            spi_miso => spi_miso,
            spi_mosi => spi_mosi,
            uart_rx => uart_rx,
            uart_tx => uart_tx
        );
    -- Zero out unused signals
    icache0_ctrl <= (en => '0', inv => '0');
    cache01sel_ctrl_temp <= '0';
    debug_i <= (en => '0', cmd => BREAK, ir => (others => '0'), d => (others => '0'), d_en => '0');
    dcache_ctrl <= (en => '0', inv => '0');
    icache1_ctrl <= (en => '0', inv => '0');
end;
