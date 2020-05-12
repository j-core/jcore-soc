library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.cpu2j0_pack.all;
use work.util_pack.all;
use work.attr_pack.all;

entity eth_mac is
    
    generic ( c_addr_width   : integer  := 11;
             c_buswidth        : integer  := 32;
             DEFAULT_MAC_ADDR : std_logic_vector (47 downto 0) := (others => '0');
             ASYNC_BRIDGE_IMPL2 : boolean := false);
    
    port (reset : in std_logic;
          clk_bus : in std_logic;
          clk_sys : in std_logic;
    	  db_i : in cpu_data_o_t;  -- clk_bus
    	  db_o : out cpu_data_i_t;  -- clk_bus
          --   mismatch to generation tool
    	  dbsys_i_en  : in std_logic;
    	  dbsys_i_a   : in std_logic_vector(31 downto 0);
    	  dbsys_i_d   : in std_logic_vector(31 downto 0);
    	  dbsys_i_wr  : in std_logic;
    	  dbsys_i_we  : in std_logic_vector(3 downto 0);
    	  dbsys_o_ack : out std_logic;
    	  dbsys_o_d  : out std_logic_vector(31 downto 0);
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

-- synopsys translate_off
    group local_sigs : local_ports(
      phy_resetn,
      phy_rxd,
      phy_rx_dv,
      phy_rx_er,
      phy_rx_col,
      phy_rx_crs,
      phy_txd,
      phy_tx_en,
      phy_tx_er);
-- synopsys translate_on
  attribute soc_port_irq of eth_intr : signal is true;
  attribute soc_port_global_name of rtc_sec_i : signal is "rtc_sec";
  attribute soc_port_global_name of rtc_nsec_i : signal is "rtc_nsec";
  attribute soc_port_global_name of phy_tx_clk : signal is "eth_tx_clk";
  attribute soc_port_global_name of phy_rx_clk : signal is "eth_rx_clk";
end eth_mac;

architecture rtl of eth_mac is
begin  -- rtl
    	  dbsys_o_ack <= dbsys_i_en;
    	  dbsys_o_d   <= (others => '0');
          eth_intr    <= '0';
          idle        <= '1';

	  phy_resetn  <= not reset;
	  phy_txd     <= (others => '0');
          phy_tx_en   <= '0';
          phy_tx_er   <= '0';
    
end architecture rtl;

