library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cpu2j0_pack.all;
-- use work.cache_pack.all;
use work.dma_pack.all;

entity spi3_tb is
end spi3_tb;

architecture tb of spi3_tb is

  constant  NUM_CS          : integer   := 2;
  constant  CLK_FREQ        : real      := 50.0e6;
  constant  CLK_PERIOD      : time      := 20.0 ns; -- 50MHz
  constant  CPOL            : std_logic := '1';
  constant  CPHA            : std_logic := '1';
  constant  LOW_SPEED_FREQ  : real := 400.0e3;
  constant  HIGH_SPEED_FREQ : real := 12.5e6;

  signal  clk     :     std_logic;
  signal  clk_half_pre :     std_logic;
  signal  clk_half_sync :     std_logic;
  signal  rst     :     std_logic;
  signal  actp_i  :     actp_i_t;
  signal  actp_o  :     actp_o_t;
  ---- 
  signal  actp_o_t_end_12del : std_logic_vector(6 downto 0);
  signal  actp_o_t_end_84del : std_logic_vector(6 downto 0) := (others => '0');
  signal  actp_o_t_end_12del_i : std_logic_vector(6 downto 0);
  signal  actp_o_t_end_84del_i : std_logic_vector(6 downto 0);
  ---- 
  --  minus 6 cycle (read timing of tb)
  signal  actp_o_t_end_06del : std_logic_vector(6 downto 0);
  signal  actp_o_t_end_78del : std_logic_vector(6 downto 0) := (others => '0');
  ---- 
  signal  db_i    :     cpu_data_o_t;
  signal  db_ifx  :     cpu_data_o_t; -- fixed cycle patten
                                      -- (dependent to dma.ack))
  signal  db_o    :     cpu_data_i_t;
  signal  spi_clk :     std_logic;
  signal  cs      :     std_logic_vector(NUM_CS - 1 downto 0);
  signal  miso    :     std_logic;
  signal  miso_cycle :   std_logic;
  signal  miso_loopb4ck : std_logic;
  signal  mosi    :     std_logic;
  signal  cpu0_ddr_ibus_o     :     cpu_instruction_o_t;
--  signal  ddrdb_o :     mem_o_t;
--  signal  ddrdb_o_1delay : mem_o_t;
--  signal  ddrdb_i :     mem_i_t;
  signal  rtc_nsec :    std_logic_vector(31 downto 0);
  signal  thisr_cycle_tb :    std_logic_vector (19 downto 0);
  signal  thisc_cycle_tb :    std_logic_vector (19 downto 0);
  signal  thisr_rdata :    std_logic_vector ( 7 downto 0);
  signal  thisc_rdata :    std_logic_vector ( 7 downto 0);
  signal  thisr_wdcount_tb :    std_logic_vector ( 5 downto 0);
  signal  thisc_wdcount_tb :    std_logic_vector ( 5 downto 0);
  ---- 
  signal   thisr_spi_clkstate0 : std_logic;
  signal   thisr_spi_clkstate1 : std_logic;
  signal   thisr_spi_clkstate2 : std_logic;
  signal   thisc_spi_clkstate0 : std_logic;
  signal   thisc_spi_clkstate1 : std_logic;
  signal   thisc_spi_clkstate2 : std_logic;
  signal   thisr_spi_data : std_logic_vector(11 downto 0) ;
  signal   thisc_spi_data : std_logic_vector(11 downto 0) ;
  signal   thisr_spi_data2: std_logic_vector( 7 downto 0) ;
  signal   thisc_spi_data2: std_logic_vector( 7 downto 0) ;
  ---- 

begin
  u_spi3 : entity work.spi3(arch)
  generic map (
    NUM_CS           => NUM_CS  ,
    CLK_FREQ         => CLK_FREQ,
    CPOL             => CPOL    ,
    CPHA             => CPHA    ,
    LOW_SPEED_FREQ   => LOW_SPEED_FREQ  ,
    HIGH_SPEED_FREQ  => HIGH_SPEED_FREQ
  )
  port map (
  clk     => clk     ,
  rst     => rst     ,
--  cpu0_ddr_ibus_o => cpu0_ddr_ibus_o ,
  db_i    => db_i    ,
  db_o    => db_o    ,
  spi_clk => spi_clk ,
  cs      => cs      ,
  miso    => miso    ,
  mosi    => mosi    ,
  actp_i  => actp_i  ,
  actp_o  => actp_o
--  ddrdb_o => ddrdb_o ,
--  ddrdb_i => ddrdb_i ,
--  rtc_nsec => rtc_nsec );
  );

  actp_o.ack   <= (others => '0');
  rst          <= '1', '0' after 15 ns;
  clk          <= '0' after CLK_PERIOD/2  when clk = '1' else
                  '1' after CLK_PERIOD/2 ;
  clk_half_pre <= '0' after CLK_PERIOD    when clk_half_pre = '1' else
                  '1' after CLK_PERIOD   ;
  clk_half_sync     <= clk_half_pre after CLK_PERIOD/2;


  acklat_actp : process (thisr_cycle_tb, actp_i.req )
  begin
  if(thisr_cycle_tb(7) = '0') then
       actp_o_t_end_12del_i <= actp_i.req;
       actp_o_t_end_84del_i <= (others => '0') ;
  else actp_o_t_end_84del_i <= actp_i.req;
       actp_o_t_end_12del_i <= (others => '0') ; end if;
  end process;
  
  actp_o_t_end_12del <= transport actp_o_t_end_12del_i after CLK_PERIOD * 12;
  actp_o_t_end_84del <= transport actp_o_t_end_84del_i after CLK_PERIOD * 84;
  actp_o_t_end_06del <= transport actp_o_t_end_12del_i after CLK_PERIOD * 06;
  actp_o_t_end_78del <= transport actp_o_t_end_84del_i after CLK_PERIOD * 78;
  actp_o.t_end <= actp_o_t_end_12del or actp_o_t_end_84del;

  miso_loopb4ck <=         mosi after CLK_PERIOD * 4;
--  ddrdb_i.d   <= (others => '0');
  rtc_nsec    <= x"abcd2345";

  genmiso : process( miso_loopb4ck, thisr_cycle_tb , miso_cycle)
  begin
         miso <= miso_cycle ;
  end process;

  gen_miso_cycle : process ( thisr_cycle_tb )
  begin
    if(thisr_cycle_tb(4 downto 2) = "010") or
      (thisr_cycle_tb(4 downto 2) = "101") or
      (thisr_cycle_tb(4 downto 2) = "111") then
         miso_cycle <= '1';
    else miso_cycle <= '0'; end if;
  end process;

  gen_db_i : process ( actp_o_t_end_06del, actp_o_t_end_78del, db_ifx, thisr_wdcount_tb)
  begin
    -- initial value start
    thisc_wdcount_tb <= thisr_wdcount_tb;
    -- initial value end
    if   (actp_o_t_end_06del = "100" & x"7") or
         (actp_o_t_end_78del = "100" & x"7") then
      db_i.a    <= x"abcd005c";
      db_i.en   <=  '1';
      db_i.wr <=  '0'; db_i.rd <=  '1';
      db_i.we <=  "0000";
      db_i.d  <= x"00000000";
    elsif(actp_o_t_end_06del = "100" & x"9") or
         (actp_o_t_end_78del = "100" & x"9") then 
      db_i.a    <= x"abcd005c";
      db_i.en   <=  '1';
      db_i.wr <=  '1'; db_i.rd <=  '0';
      db_i.we <=  "1111";
      db_i.d  <= x"33333333";
      db_i.a( 1 downto  0) <= thisr_wdcount_tb( 1 downto  0);
      case thisr_wdcount_tb( 1 downto  0) is
        when "00"   => db_i.d(31 downto 24) <=  "11" & thisr_wdcount_tb;
        when "01"   => db_i.d(23 downto 16) <=  "11" & thisr_wdcount_tb;
        when "10"   => db_i.d(15 downto  8) <=  "11" & thisr_wdcount_tb;
        when others => db_i.d( 7 downto  0) <=  "11" & thisr_wdcount_tb;
      end case;
      thisc_wdcount_tb <= std_logic_vector(unsigned(thisr_wdcount_tb) + 1);
    else 
      db_i    <= db_ifx;
    end if;
  end process;

--signal  thisr_wdcount_tb :    std_logic_vector ( 5 downto 0);
--signal  thisc_wdcount_tb :    std_logic_vector ( 5 downto 0);

--   ddrdb_o_1delay <= ddrdb_o after CLK_PERIOD ;
--   -- ---------------------------------------------------
--   gen_ready_1wait : process (ddrdb_o, ddrdb_o_1delay)
--     variable mem_rdy_1wait : std_logic;
--   begin
--     if (ddrdb_o_1delay.en = '1') and
--        (ddrdb_o.en        = '1') and
--        (ddrdb_o_1delay.a = ddrdb_o.a) then mem_rdy_1wait := '1';
--      else                                  mem_rdy_1wait := '0';
--      end if;
--      ddrdb_i.ack <=     mem_rdy_1wait;
--   end process;
  -- ---------------------------------------------------
--  retired ack
--  ddrdb_i.ack <= ddrdb_o.en after CLK_PERIOD ;
  -- ---------------------------------------------------

  instr_vector : process begin
    cpu0_ddr_ibus_o.en <= '1';
    cpu0_ddr_ibus_o.a <= "000" & x"fffd7d7"; 
                                                    wait for CLK_PERIOD * 1;
    cpu0_ddr_ibus_o.en <= '0';
    cpu0_ddr_ibus_o.a <= "000" & x"0000010"; 
                                                    wait for CLK_PERIOD * 4;
  end process;
 
--signal  thisr_cycle_tb :    std_logic (15 downto 0);
--signal  thisc_cycle_tb :    std_logic (15 downto 0);
  -- cycle count
  process ( thisr_cycle_tb, thisr_rdata, db_i, db_o )
  begin
    thisc_cycle_tb <= std_logic_vector(unsigned(thisr_cycle_tb) + 1);
    if(db_i.en = '1') and (db_o.ack = '1') then
         thisc_rdata <= db_o.d( 7 downto  0);
    else thisc_rdata <= thisr_rdata; end if;
  end process;

  spi_clkp: process ( spi_clk, thisr_spi_clkstate0, thisr_spi_clkstate1, 
    thisr_spi_clkstate2)
  begin
    thisc_spi_clkstate1 <= thisr_spi_clkstate0;
    thisc_spi_clkstate2 <= thisr_spi_clkstate1;
    if(thisr_spi_clkstate0 = '0') and
      (thisr_spi_clkstate1 = '1') then
      thisc_spi_data <= thisr_spi_data(10 downto 0) & mosi;
    else 
      thisc_spi_data <= thisr_spi_data; end if;

    if(spi_clk             = '1') and
      (thisr_spi_clkstate0 = '1') and
      (thisr_spi_clkstate1 = '1') and
      (thisr_spi_clkstate2 = '0') then
         thisc_spi_data2 <= thisr_spi_data(7 downto 0);
    else thisc_spi_data2 <= thisr_spi_data2;
    end if;
  end process;

  tb_flip_flop : process (clk, rst)
  begin
     if rst = '1' then
        thisr_cycle_tb    <= (others => '0');
        thisr_rdata       <= (others => '0');
        thisr_wdcount_tb  <= (others => '0');
     elsif clk = '1' and clk'event then
        thisr_cycle_tb    <= thisc_cycle_tb;
        thisr_rdata       <= thisc_rdata;
        thisr_wdcount_tb  <= thisc_wdcount_tb ;
     end if;
  end process;

  tb_flip_flop_half_pre : process (clk_half_pre, rst)
  begin
     if rst = '1' then
        thisr_spi_data    <= (others => '0');
        thisr_spi_data2   <= (others => '0');
     elsif clk_half_pre = '1' and clk_half_pre'event then
        thisr_spi_data    <= thisc_spi_data ;
        thisr_spi_data2   <= thisc_spi_data2;
     end if;
  end process;

  tb_flip_flop_half : process (clk_half_sync, rst)
  begin
     if rst = '1' then
        thisr_spi_clkstate0 <= '0';
        thisr_spi_clkstate1 <= '0';
        thisr_spi_clkstate2 <= '0';
     elsif clk_half_sync = '1' and clk_half_sync'event then
        thisr_spi_clkstate0 <= spi_clk;
        thisr_spi_clkstate1 <= thisc_spi_clkstate1;
        thisr_spi_clkstate2 <= thisc_spi_clkstate2;
     end if;
  end process;


  spi_vector : process begin
    -- ------------------------------------------------------------------------
    db_ifx    <= NULL_DATA_O;                       wait for CLK_PERIOD * 0.5;
    db_ifx    <= NULL_DATA_O;                       wait for CLK_PERIOD * 10;
    -- ------------------------------------------------------------------------
    -- *** test 1  one block read                   ***************************
    --                        spi -> ddr
    -- ------------------------------------------------------------------------
    db_ifx.en <= '1'; db_ifx.wr <= '1'; db_ifx.we <= "1111";
    db_ifx.a(7 downto 0) <= x"64"; db_ifx.d(15 downto 0) <= x"0907";
                                                    wait until db_o.ack = '1';
                                                    wait for CLK_PERIOD * 1;
    -- ------------------------------------------------------------------------
    db_ifx    <= NULL_DATA_O;                       wait for CLK_PERIOD * 4;
    -- ------------------------------------------------------------------------
    db_ifx.en <= '1'; db_ifx.wr <= '1'; db_ifx.we <= "1111";
    db_ifx.a(7 downto 0) <= x"58"; db_ifx.d(15 downto 0) <= x"0010";
                                                    wait until db_o.ack = '1';
                                                    wait for CLK_PERIOD * 1;
    -- ------------------------------------------------------------------------
    db_ifx    <= NULL_DATA_O;                       wait for CLK_PERIOD * 5;
    -- ------------------------------------------------------------------------
    db_ifx.en <= '1'; db_ifx.wr <= '1'; db_ifx.we <= "1111";
    db_ifx.a(7 downto 0) <= x"50"; db_ifx.d(15 downto 0) <= x"0001";
                                                    wait until db_o.ack = '1';
                                                    wait for CLK_PERIOD * 1;
    -- ------------------------------------------------------------------------
    db_ifx    <= NULL_DATA_O;                       wait for CLK_PERIOD * 10;
                                                  wait for CLK_PERIOD * 2000;
    -- ------------------------------------------------------------------------
    db_ifx.en <= '1'; db_ifx.wr <= '1'; db_ifx.we <= "1111";
    db_ifx.a(7 downto 0) <= x"58"; db_ifx.d(15 downto 0) <= x"0010";
                                                    wait until db_o.ack = '1';
                                                    wait for CLK_PERIOD * 1;
    -- ------------------------------------------------------------------------
    db_ifx    <= NULL_DATA_O;                       wait for CLK_PERIOD * 5;
    -- ------------------------------------------------------------------------
    db_ifx.en <= '1'; db_ifx.wr <= '1'; db_ifx.we <= "1111";
    db_ifx.a(7 downto 0) <= x"50"; db_ifx.d(15 downto 0) <= x"0002";
                                                    wait until db_o.ack = '1';
                                                    wait for CLK_PERIOD * 1;
    -- ------------------------------------------------------------------------
    db_ifx    <= NULL_DATA_O;                       wait for CLK_PERIOD * 10;
                                              wait for CLK_PERIOD * 999999;
    -- ------------------------------------------------------------------------

  end process;
  
end architecture;
