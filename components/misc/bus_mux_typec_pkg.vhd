library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu2j0_pack.all;
use work.dma_pack.all;

package bus_mux_typec_pack is

  type state_busarbc_t is ( M1, M1LOCK1, M1LOCK2, M12LOCKT, M2, M3, M3LOCK1, M3LOCK2, M34LOCKT, M4, M5, IDLE );

  type bus_mux_typec_reg_t is record
    state_busarbc       : state_busarbc_t;
    state_busarbc_woa   : state_busarbc_t;
    state_busarbc_round : state_busarbc_t;
    ddrburst           : std_logic ;
    dmaburst16         : std_logic ;
    dmaburst16at       : std_logic ;
    valid_accmem       : std_logic ;
    mem_o              : cpu_data_o_t;
    mem_ack            : std_logic ;
    count : std_logic_vector(2 downto 0);
  end record;

  constant BUS_MUX_TYPEC_REG_RESET :bus_mux_typec_reg_t := (
    M1 , M1, M1 ,
   '0', -- ddrburst
   '0', -- dmaburst16
   '0', -- dmaburst16at
   '0', -- valid_accmem
   ('0', (others => '0'), '0', '0', (others => '0'),
              (others => '0')),
   '0', -- mem_ack
   (others => '0') );

  component bus_mux_typec is port (
    clk           : in   std_logic;
    rst           : in   std_logic;
  
    m1_o          : out  cpu_data_i_t;
    m1_ddrburst   : in   std_logic;
    m1_lock       : in   std_logic;
    m1_i          : in   cpu_data_o_t;
  
    m2_o          : out  cpu_data_i_t;
    m2_ddrburst   : in   std_logic;
    m2_i          : in   cpu_data_o_t;
  
    m3_o          : out  cpu_data_i_t;
    m3_ddrburst   : in   std_logic;
    m3_lock       : in   std_logic;
    m3_i          : in   cpu_data_o_t;
  
    m4_o          : out  cpu_data_i_t;
    m4_ddrburst   : in   std_logic;
    m4_i          : in   cpu_data_o_t;
  
    m5_o          : out  bus_ddr_i_t;
    m5_i          : in   bus_ddr_o_t;
    mem_o         : out  cpu_data_o_t;
    mem_ddrburst  : out  std_logic;
    mem_i         : in   cpu_data_i_t
  );
  end component;

end package;

package body bus_mux_typec_pack is
end          bus_mux_typec_pack;
