-- A version of the uartlite that uses the CPU's databus. This is intended to be
-- a temporary entity used by soc_top prior to connecting devices to the ring bus

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uart_pack.all;
use work.cpu2j0_pack.all;
use work.attr_pack.all;

entity uartlitedb is
  generic (
    intcfg : integer := 1;
    fclk   : real := 31.25e6;
    bps    : real := 115.2e3);
  port (
    rst    : in  std_logic;
    clk    : in  std_logic;
    db_i   : in cpu_data_o_t;
    db_o   : out cpu_data_i_t;
    int    : out std_logic;
    -- The actual serial signals
    rx     : in  std_logic;
    tx     : out std_logic);
-- synopsys translate_off
  group local_sigs : local_ports(rx,tx);
-- synopsys translate_on
  attribute sei_port_irq of int : signal is true;
end;

architecture arch of uartlitedb is
  function to_uart_i(d : cpu_data_o_t)
  return uart_i_t is
    variable r : uart_i_t;
  begin
    if d.a(3) = '0' then
      r.dc := DATA;
    else
      r.dc := CTRL;
    end if;
    r.d  := d.d(7 downto 0);
    r.en := d.en;
    r.we := d.wr;
    return r;
  end function to_uart_i;

  function to_data_i(u : uart_o_t)
  return cpu_data_i_t is
    variable r : cpu_data_i_t;
  begin
    r.ack := u.ack;
    r.d(31 downto 8) := (others => '0');
    r.d( 7 downto 0) := u.d;
    return r;
  end function to_data_i;

  signal uart_o : uart_o_t;
begin

  uart : uartlite
    generic map (
      intcfg => intcfg, fclk => fclk, bps => bps)
    port map (
      clk => clk,
      rst => rst,
      a => to_uart_i(db_i),
      y => uart_o,
      rx => rx,
      tx => tx);

  db_o <= to_data_i(uart_o);
  int <= uart_o.int;
end;

