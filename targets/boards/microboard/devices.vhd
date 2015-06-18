-- Copyright (c) 2015, Smart Energy Instruments Inc.
-- All rights reserved.  For details, see COPYING in the top level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config.all;
use work.cpu2j0_pack.all;
use work.data_bus_pack.all;
entity devices is
    port (
        clk_sys : in std_logic;
        cpu0_periph_dbus_i : out cpu_data_i_t;
        cpu0_periph_dbus_o : in cpu_data_o_t;
        cpu1_periph_dbus_i : out cpu_data_i_t;
        cpu1_periph_dbus_o : in cpu_data_o_t;
        irqs : out std_logic_vector(7 downto 0);
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
architecture impl of devices is
    type device_t is (NONE, DEV_GPIO, DEV_SPI, DEV_UART);
    signal active_dev : device_t;
    type data_bus_i_t is array (device_t'left to device_t'right) of cpu_data_i_t;
    type data_bus_o_t is array (device_t'left to device_t'right) of cpu_data_o_t;
    signal devs_bus_i : data_bus_i_t;
    signal devs_bus_o : data_bus_o_t;
    function decode_address (addr : std_logic_vector(31 downto 0)) return device_t is
    begin
        -- Assumes addr(31 downto 28) = x"a".
        -- Address decoding closer to CPU checks those bits.
        if addr(27 downto 9) = "1011110011010000000" then
            if addr(8 downto 7) = "00" then
                if addr(6) = '0' then
                    return DEV_GPIO;
                else
                    return DEV_SPI;
                end if;
            elsif addr(8) = '1' then
                return DEV_UART;
            end if;
        end if;
        return NONE;
    end;
begin
    -- multiplex data bus to and from devices
    active_dev <= decode_address(cpu0_periph_dbus_o.a);
    cpu0_periph_dbus_i <= devs_bus_i(active_dev);
    bus_split : for dev in device_t'left to device_t'right generate
        devs_bus_o(dev) <= mask_data_o(cpu0_periph_dbus_o, to_bit(dev = active_dev));
    end generate;
    -- second CPU's bus is not used currently
    cpu1_periph_dbus_i <= loopback_bus(cpu1_periph_dbus_o);
    devs_bus_i(NONE) <= loopback_bus(devs_bus_o(NONE));
    -- Instantiate devices
    gpio : entity work.pio(beh)
        port map (
            clk_bus => clk_sys,
            db_i => devs_bus_o(DEV_GPIO),
            db_o => devs_bus_i(DEV_GPIO),
            irq => irqs(4),
            p_i => pi,
            p_o => po,
            reset => reset
        );
    spi : entity work.spi(beh)
        generic map (
            c_csnum => 2,
            fclk => 3.125E7
        )
        port map (
            clk_bus => clk_sys,
            db_i => devs_bus_o(DEV_SPI),
            db_o => devs_bus_i(DEV_SPI),
            reset => reset,
            spi_clk => spi_clk,
            spi_flashcs_o => spi_cs,
            spi_miso => spi_miso,
            spi_mosi => spi_mosi
        );
    uart : entity work.uartlitedb(arch)
        generic map (
            bps => 115200.0,
            fclk => 3.125E7,
            intcfg => 1
        )
        port map (
            clk => clk_sys,
            db_i => devs_bus_o(DEV_UART),
            db_o => devs_bus_i(DEV_UART),
            int => irqs(1),
            rst => reset,
            rx => uart_rx,
            tx => uart_tx
        );
    -- Ununsed irqs
    irqs(0) <= '0';
    irqs(2) <= '0';
    irqs(3) <= '0';
    irqs(5) <= '0';
    irqs(6) <= '0';
    irqs(7) <= '0';
end;
