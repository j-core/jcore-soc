library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bist_pack.all;
use work.cpu2j0_pack.all;

package dma_pack is

constant DMA_ADDR_WIDTH            : natural := 32; -- 4G Byte
constant DMA_DDR_BUS_WIDTH         : natural := 32;
constant DMA_M_RING_BUS_WIDTH      : natural := 32;
constant DMA_TARGET_BUS_WIDTH      : natural := 32;
constant DMA_ADDR_REG_WIDTH        : natural := 11; -- 512 regs -> 2kB
constant DMA_INT_NUM               : natural :=  2;
constant DMA_CHANNEL_NUM           : natural := 64;
constant DMA_CHANNEL_NUM_LOG       : natural :=  6;
constant DMA_INTERN_ADDR_WIDTH     : natural := 32;
constant DMA_BUSMUX_CLIMIT         : std_logic_vector := b"011";
constant DMA_CACHE_ADRUPPER0       : std_logic_vector := b"00000";
               -- H'0000_0000 - H'07FF_FFFF,
               -- to save DMA early days logic verification program
constant DMA_CACHE_ADRUPPER1       : std_logic_vector := b"0001";
               -- H'1000_0000 - H'1FFF_FFFF same start address data_bus_pkg.vhd
               -- and information CACHE REGION 28bit

  type dma_stater_t is  ( IDLE, SRDA, BRDA, BRDD, RLD1, RLD2, RLD3 );
  type dma_statew_t is  ( IDLE, SWTA, BWTA, BWTD, VWTA, PREPW );
  type dma_statetg_t is ( IDLE, TGR1, TGR2, TGRC, TGW1, TGWC );
  type dma_statebuf_t is ( IDLE, SRDA0, BRDA0, BRDD0, SWTA0, BWTA0, BWTD0, PWT00);
  type state_busarb_t is ( M1R, M1WA, M2, M1WB, IDLE );
  type bist_scanar_dm_t is array(0 to 22) of bist_scan_t;
  type dma_buf_t is array(0 to 7) of std_logic_vector(31 downto 0);

  type bus_ddr_o_t is record
    en       : std_logic;
    a        : std_logic_vector(DMA_ADDR_WIDTH-1         downto 0);
    d        : std_logic_vector(DMA_DDR_BUS_WIDTH-1   downto 0);
    wr       : std_logic;
    we       : std_logic_vector(DMA_DDR_BUS_WIDTH/8-1 downto 0);
    burst32  : std_logic;
    burst16  : std_logic;
    bgrp     : std_logic; -- burst (group transfer)
  end record;

  type bus_ddr_i_t is record
    d       : std_logic_vector(DMA_DDR_BUS_WIDTH-1    downto 0);
    ack     : std_logic;
  end record;

  type bus_m_ring_o_t is record
    en       : std_logic;
    a        : std_logic_vector(DMA_ADDR_WIDTH-1         downto 0);
    d        : std_logic_vector(DMA_M_RING_BUS_WIDTH-1   downto 0);
    wr       : std_logic;
    we       : std_logic_vector(DMA_M_RING_BUS_WIDTH/8-1 downto 0);
    size     : std_logic_vector(2 downto 0);
    en_syncg_ddr : std_logic; -- only for (not DMA_ASYNC) case, delay improve
    wr_syncg_ddr : std_logic; -- only for (not DMA_ASYNC) case, delay improve
    burst32  : std_logic;
    burst16  : std_logic;
  end record;

  type bus_m_ring_i_t is record
    d       : std_logic_vector(DMA_M_RING_BUS_WIDTH-1    downto 0);
    ack     : std_logic;
  end record;

  type target_o_t is record
    d       : std_logic_vector(DMA_TARGET_BUS_WIDTH-1    downto 0);
    ack     : std_logic;
  end record;

  type target_i_t is record
    en    : std_logic;
    a     : std_logic_vector(DMA_ADDR_REG_WIDTH-1        downto 0);
    d     : std_logic_vector(DMA_TARGET_BUS_WIDTH-1      downto 0);
    wr    : std_logic;
    we    : std_logic_vector(DMA_TARGET_BUS_WIDTH/8-1    downto 0);
  end record;

  type int_o_t is record
    req   : std_logic_vector(1 downto 0);
  end record;

  type actp_o_t is record
    ack : std_logic_vector(DMA_CHANNEL_NUM_LOG downto 0);
    t_end : std_logic_vector(DMA_CHANNEL_NUM_LOG downto 0);
  end record;

  type actp_i_t is record
    req : std_logic_vector(DMA_CHANNEL_NUM_LOG downto 0);
  end record;

  constant NULL_ACTP_I : actp_i_t := ( req => (others => '0') );

  type dsmrec_ctrl_t is record
    trig_mod   : std_logic;
    blenable   : std_logic_vector(5 downto 0);
    timep_intv : std_logic_vector(2 downto 0);
    en         : std_logic;
  end record;

  type dma_fconv_o_t is record
    den : std_logic_vector( 7 downto 0);
    aen : std_logic;
    d0  : std_logic_vector(31 downto 0);
    d1  : std_logic_vector(31 downto 0);
    a   : std_logic_vector(27 downto 0);
    wr  : std_logic;
    size : std_logic_vector( 2 downto 0);
    dddd : std_logic;
    abuf : std_logic_vector( 2 downto 0);
  end record;

  type dma_fconv_i_t is record
    aack : std_logic;
    en   : std_logic_vector( 7 downto 0);
    d    : std_logic_vector(31 downto 0);
  end record;

   type dsmlocal_cpudata_o_t is record
      en   : std_logic;
      a    : std_logic_vector(31 downto 0);
      rd   : std_logic;
      wr   : std_logic;
      we   : std_logic_vector(3 downto 0);
      d    : std_logic_vector(31 downto 0);
   end record;
   constant DSMLOCAL_NULL_DATA_O : dsmlocal_cpudata_o_t := ( en => '0', 
   a => (others => '0'), rd => '0', wr => '0', we => "0000",
   d => (others => '0'));

   type dsmlocal_cpudata_i_t is record
      d    : std_logic_vector(31 downto 0);
      ack  : std_logic;
   end record;

   constant DSMLOCAL_NULL_DATA_I : dsmlocal_cpudata_i_t := (ack => '0', 
    d => (others => '0'));

  component dma is
  -- generic to reduce area (the number of register file macro 55% (22 -> 12))
  -- DMA_NUMCH = {64, 32, 16}, if 32,16 then cut down
    generic ( DMA_NUMCH : integer := 64 ;
              DMA_ASYNC : boolean := false ;
              DMA_GRPT  : boolean := false );
    port (
	clk          : in std_logic;
	rst          : in std_logic;
	bi           : in bist_scan_t;
	bo           : out bist_scan_t;
	bus_m_ring_o : out bus_m_ring_o_t; 
	bus_m_ring_i : in  bus_m_ring_i_t;
	target_o     : out target_o_t; 
	target_i     : in  target_i_t; 
        dma_fconv_o  : out dma_fconv_o_t;
        dma_fconv_i  : in dma_fconv_i_t;
	int_o        : out int_o_t; 
        dsmrec_ctrl  : out dsmrec_ctrl_t;
	actp_o       : out actp_o_t; 
	actp_i       : in  actp_i_t);
  end component;

  component dmabuf is 
    generic ( CLK_RATIO_MEMSYS : integer range 1 to 3 := 1 ;
              DMA_GRPT  : boolean := false );
    port (
        clk200       : in  std_logic;
        rst          : in  std_logic;
        dma_fconv_o  : in  dma_fconv_o_t;
        dma_fconv_i  : out dma_fconv_i_t;
	bus_ddr_o    : out bus_ddr_o_t;
	bus_ddr_i    : in  bus_ddr_i_t);
  end component;

  component dma_db is
  -- generic to reduce area (the number of register file macro 55% (22 -> 12))
  -- DMA_NUMCH = {64, 32, 16}, if 32,16 then cut down
    generic ( DMA_NUMCH : integer := 64 ;
              DMA_ASYNC : boolean := false ;  -- repo false
              DMA_GRPT  : boolean := false ); -- repo false
    port (
        clk          : in  std_logic;
        clk200       : in  std_logic;
        rst          : in  std_logic;
        db_i         : in  cpu_data_o_t;
        db_o         : out cpu_data_i_t;
        db_peri_i    : in  cpu_data_i_t;
        db_peri_o    : out cpu_data_o_t;
        dbus_o       : out bus_ddr_o_t;
        dbus_i       : in  bus_ddr_i_t;
        int          : out std_logic;
	actp_o       : out actp_o_t; 
	actp_i       : in  actp_i_t;
        dsmrec_ctrl  : out dsmrec_ctrl_t;
        db_dsmreclocal_o : out dsmlocal_cpudata_o_t;
        db_dsmreclocal_i : in dsmlocal_cpudata_i_t;
        bi           : in  bist_scan_t;
        bo           : out bist_scan_t);
  end component;

  component bus_mux_typeb is port (
  clk    : in   std_logic;
  rst    : in   std_logic;
  m1_o   : out  cpu_data_i_t;
  m1_i   : in   cpu_data_o_t;
  m2_o   : out  bus_ddr_i_t;
  m2_i   : in   bus_ddr_o_t;
  mem_o  : out  cpu_data_o_t;
  mem_i  : in   cpu_data_i_t );
  end component;
-- -----------------------------

  -- functions for connecting bus_ddr and cpu_data buses
  function to_cpu_data(i : bus_ddr_o_t) return cpu_data_o_t;
  function to_bus_ddr(i : cpu_data_i_t) return bus_ddr_i_t;
  function chnum_to_depth(i : integer) return natural;

  function loopback_bus(i : bus_ddr_o_t) return bus_ddr_i_t;
end package;

package body dma_pack is

  function to_cpu_data(i : bus_ddr_o_t) return cpu_data_o_t is
    variable o : cpu_data_o_t;
  begin
    o.en := i.en;
    o.a  := i.a;
    o.d  := i.d;
    o.wr := i.wr;
    o.rd := i.en and (not i.wr);
    o.we := i.we;
    return o;
  end function;

  function to_bus_ddr(i : cpu_data_i_t) return bus_ddr_i_t is
    variable o : bus_ddr_i_t;
  begin
    o.d   := i.d;
    o.ack := i.ack;
    return o;
  end function;

  function chnum_to_depth(i : integer) return natural is
    variable o : natural;
  begin
    case i is
    when 16     => o := 16;
    when others => o := 32; end case;
    return o;
  end function;
  function loopback_bus(i : bus_ddr_o_t) return bus_ddr_i_t is
    variable o : bus_ddr_i_t;
  begin
    o.ack := i.en;
    o.d   := (others => '0');
    return o;
  end function;

end dma_pack;



