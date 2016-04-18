library ieee;
use ieee.std_logic_1164.all;

use work.cpu2j0_pack.all;

package misc_pack is
  component i2c is
    generic (c_busclk_period : integer := 40);
    port (
      clk_bus : in std_logic;
      reset   : in std_logic;
      db_i    : in cpu_data_o_t;
      db_o    : out cpu_data_i_t;
      twi_clk : inout std_logic;
      twi_dat : inout std_logic;
      irq     : out std_logic);
  end component i2c;

  component spi is
    generic (c_csnum : integer range 2 to 5 := 2;
             fclk    : real range 25.0e6 to 50.0e6 := 31.25e6);
    port (
      clk_bus       : in std_logic;
      reset         : in std_logic;
      db_i          : in cpu_data_o_t;
      db_o          : out cpu_data_i_t;
      spi_clk       : out std_logic;
      spi_flashcs_o : out std_logic_vector(c_csnum -1 downto 0);
      spi_miso      : in std_logic;
      spi_mosi      : out std_logic);
  end component spi;

  component pio is
    port (
      clk_bus : in std_logic;
      reset   : in std_logic;
      db_i    : in cpu_data_o_t;
      db_o    : out cpu_data_i_t;
      irq     : out std_logic;
      p_i     : in std_logic_vector(31 downto 0);
      p_o     : out std_logic_vector(31 downto 0));
  end component pio;

  component d2a is
    generic (c_bits : integer := 24);
    port (
      sck     : in std_logic;
      ws      : in std_logic;
      sd      : out std_logic_vector(3 downto 0);
      clk_bus : in std_logic;
      reset   : in std_logic;
      db_i    : in cpu_data_o_t;
      db_o    : out cpu_data_i_t);
  end component d2a;

  component i2sctrl is
    port (
      clk_i  : in std_logic;
      sclk_o : out std_logic;
      ws     : out std_logic);
  end component i2sctrl;

  component aic is
    generic (c_busperiod : integer := 40);
    port (
      clk_bus : in std_logic;
      rst_i : in std_logic;
      db_i : in cpu_data_o_t;
      db_o : out cpu_data_i_t;
      bstb_i : in std_logic;
      back_i : in std_logic;

      irq_i : in std_logic_vector(7 downto 0) := (others => '0');
      rtc_sec : out std_logic_vector(63 downto 0);
      rtc_nsec : out std_logic_vector(31 downto 0);
      enmi_i : in std_logic;
      event_req : out std_logic_vector(2 downto 0);
      event_info : out std_logic_vector(11 downto 0);
      event_ack_i : in std_logic);
  end component aic;

  function to_event_i(event_req : std_logic_vector(2 downto 0);
                      event_info : std_logic_vector(11 downto 0))
    return cpu_event_i_t;

end misc_pack;

package body misc_pack is
  function to_event_i(event_req : std_logic_vector(2 downto 0);
                      event_info : std_logic_vector(11 downto 0))
  return cpu_event_i_t is
    variable event_i : cpu_event_i_t;
  begin
    if event_req = "111" then
      event_i.en := '0';
    else
      event_i.en := '1';
    end if;
    case event_req is
      when "000" | "001" =>
        event_i.cmd := INTERRUPT;
      when "010" | "011" =>
        event_i.cmd := ERROR;
      when "100" =>
        event_i.cmd := BREAK;
      when others =>
        event_i.cmd := RESET_CPU;
    end case;
    if event_req = "000" then
      event_i.msk := '0';
    else
      event_i.msk := '1';
    end if;
    event_i.lvl := event_info(11 downto 8);
    event_i.vec := event_info( 7 downto 0);
    return event_i;
  end function;
end;
