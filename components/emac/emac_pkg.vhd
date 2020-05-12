library ieee;
use ieee.std_logic_1164.all;

use work.config.all;
use work.cpu2j0_pack.all;

package emac_pack is
  constant c_emac_period : integer := 20; -- 50MHz fixed, for RTC

  component eth_mac is
    generic (
      c_addr_width   : integer  := 11;
      c_buswidth     : integer  := 32;
      DEFAULT_MAC_ADDR : std_logic_vector (47 downto 0) := (others => '0');
      ASYNC_BRIDGE_IMPL2 : boolean := false ) ;
    port (
      reset : in std_logic;
      clk_bus : in std_logic;
      db_i : in cpu_data_o_t;   -- clk_bus
      db_o : out cpu_data_i_t;  -- clk_bus
      clk_sys : in std_logic;
      dbsys_i_en : in std_logic;
      dbsys_i_a  : in std_logic_vector(31 downto 0);
      dbsys_i_d  : in std_logic_vector(31 downto 0);
      dbsys_i_wr : in std_logic;
      dbsys_i_we : in std_logic_vector( 3 downto 0);
      dbsys_o_ack : out std_logic;
      dbsys_o_d : out std_logic_vector(31 downto 0);
      eth_intr  : out std_logic;
      idle      : out std_logic;

      rtc_sec_i : in std_logic_vector(63 downto 0);
      rtc_nsec_i : in std_logic_vector(31 downto 0);
      -- PHY Interface signals
      phy_resetn : out   std_logic;
      phy_tx_clk : in    std_logic;
      phy_rx_clk : in    std_logic;
      phy_rxd    : in    std_logic_vector(3 downto 0);
      phy_rx_dv  : in    std_logic;
      phy_rx_er  : in    std_logic;
      phy_rx_col : in    std_logic;
      phy_rx_crs : in    std_logic;
      phy_txd    : out   std_logic_vector(3 downto 0);
      phy_tx_en  : out   std_logic;
      phy_tx_er  : out   std_logic);
  end component eth_mac;

  component eth_mac_rmii is
    generic (
      c_addr_width   : integer  := 11;
      c_buswidth     : integer  := 32;
      DEFAULT_MAC_ADDR : std_logic_vector (47 downto 0) := (others => '0'));
    port (
      reset : in std_logic;
      clk_bus : in std_logic;
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
  end component;
end emac_pack;
