-- an ethernet MAC that connects to a PHY using RMII
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.cpu2j0_pack.all;
use work.util_pack.all;
use work.attr_pack.all;
use work.emac_pack.all;
use work.data_bus_pack.all;

entity eth_mac_rmii is
  generic (
    c_addr_width   : integer  := 11;
    c_buswidth     : integer  := 32;
    DEFAULT_MAC_ADDR : std_logic_vector (47 downto 0) := (others => '0');
    ASYNC_BUS_BRIDGE   : boolean := false;
    ASYNC_BRIDGE_IMPL2 : boolean := true;
    INSERT_WRITE_DELAY_ETHRX : boolean := false;
    INSERT_READ_DELAY_ETHRX : boolean := false);
  port (
    reset : in std_logic;
    clk_bus : in std_logic;
    clk_emac : in std_logic;
--    clk_25 : in std_logic;
    db_i : in cpu_data_o_t;
    db_o : out cpu_data_i_t;
    eth_intr  : out std_logic;

    rtc_sec_i : in std_logic_vector(63 downto 0);
    rtc_nsec_i : in std_logic_vector(31 downto 0);

    phy_txen    : out std_logic;
    phy_txd     : out std_logic_vector(1 downto 0);
    phy_rxerr   : in  std_logic;
    phy_rxd     : in  std_logic_vector(1 downto 0);
    phy_crs_dv  : in  std_logic;
    phy_clk     : out std_logic);

-- synopsys translate_off
  group local_sigs : local_ports(
    phy_txen,
    phy_txd,
    phy_rxerr,
    phy_rxd,
    phy_crs_dv,
    phy_clk);
-- synopsys translate_on
  attribute soc_port_clock of phy_clk : signal is true;
  attribute soc_port_irq of eth_intr : signal is true;
  attribute soc_port_global_name of rtc_sec_i : signal is "rtc_sec";
  attribute soc_port_global_name of rtc_nsec_i : signal is "rtc_nsec";
--  attribute soc_port_global_name of clk_25 : signal is "clk_25";
end eth_mac_rmii;

architecture rtl of eth_mac_rmii is
begin
    db_o.ack    <= db_i.en;
    db_o.d      <= (others => '0');
    eth_intr    <= '0';

    phy_txen    <= '0';
    phy_txd     <= (others => '0');
    phy_clk     <= clk_emac;

end architecture rtl;
