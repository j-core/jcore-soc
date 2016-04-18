library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.cpu2j0_pack.all;
use work.aic2_pack.all;
use work.misc_pack.all;

entity aic_tb is
end aic_tb;

architecture tb of aic_tb is

-- signal start
        signal clk_sys : std_logic;
        signal rst_i : std_logic;

        signal bstb_i : std_logic;  -- bus stb use for breakpoint only
        signal back_i : std_logic;  -- bus ack: use for breakpoint only
        signal db_i : cpu_data_o_t := NULL_DATA_O ;
        signal db_iv1 : cpu_data_o_t; -- set by tb, automatic after reset
        signal db_iv2 : cpu_data_o_t; -- set by tb, test num specific
        signal db_o_aic1 : cpu_data_i_t;
        signal db_o_aic2 : cpu_data_i_t;
        signal diff0_chk_event_req : std_logic;
        signal diff0_chk_db_o      : std_logic;
        signal equiv_chk_event_req : std_logic;
        signal equiv_chk_db_o      : std_logic;
        signal event_req_aic1 : std_logic_vector(2 downto 0);
        signal event_req_aic2 : std_logic_vector(2 downto 0);
        signal event_info_aic1 : std_logic_vector(11 downto 0);
        signal event_info_aic2 : std_logic_vector(11 downto 0);
        signal event_i : cpu_event_o_t;
        signal event_o_aic1 : cpu_event_i_t;
        signal event_o_aic2 : cpu_event_i_t;
        signal enmi_i : std_logic;
        signal event_ack_i : std_logic;
        signal irq_i : std_logic_vector(7 downto 0) := (others => '0');
        signal irq_grp_i   : irq_a_t;
        signal irq_o_glue : irq_t;
        signal irq_s_i     : std_logic_vector(7 downto 0);
        signal irq_en_accumu_foraic2   : std_logic;
        signal rtc_sec_aic1 : std_logic_vector(63 downto 0);    -- clk_sys d
        signal rtc_sec_aic2 : std_logic_vector(63 downto 0);    -- clk_sys d
        signal rtc_nsec_aic1 : std_logic_vector(31 downto 0);
        signal rtc_nsec_aic2 : std_logic_vector(31 downto 0);

        signal aic_tb_test_number : integer;

-- signal end
-- constant begin
        constant clk_period_clk_sys : time := 20 ns;
-- constant end

begin

  clk_sys <= '0' after    (    clk_period_clk_sys ) / 2 when clk_sys = '1'
        else '1' after    (    clk_period_clk_sys ) / 2;

  -- remove aic instance when registered in master (this aic port is old)
--  dut : entity work.aic(behav)
--  generic map (c_busperiod => 10)
--  port map ( 
--        clk_bus => clk_sys ,
--        rst_i => rst_i ,
--        db_i => db_i ,
--        db_o => db_o_aic1 ,
--        bstb_i => bstb_i ,
--        back_i => back_i ,
--        rtc_sec => rtc_sec_aic1 ,
--        rtc_nsec => rtc_nsec_aic1 ,
--        irq_i => irq_i ,
--        enmi_i => enmi_i ,
--        event_req => event_req_aic1 ,
--        event_info => event_info_aic1 ,
--        event_ack_i => event_ack_i 
--  );
  -- end of remove aic instance when registered in master

  dut2 : entity work.aic2(behav)
  generic map
        (c_busperiod => 10,
        IRQ_SI0_NUM =>      96,
        IRQ_SI1_NUM =>      92,
        IRQ_SI2_NUM => (78 + 2),
        IRQ_SI3_NUM => (78 + 3),
        IRQ_SI4_NUM => (78 + 4),
        IRQ_SI5_NUM => (78 + 5),
        IRQ_SI6_NUM => (78 + 6),
        IRQ_SI7_NUM =>      93,
        IRQ_II0_NUM =>  76
        )
   port map (
        --             in    out
        --             |     | (named "_aic2)
        -- ------------+-----+---------------------
        clk_sys     => clk_sys     ,
        rst_i       => rst_i       ,
        db_i        => db_i        ,
        db_o        =>       db_o_aic2        ,
        rtc_sec     =>       rtc_sec_aic2     ,
        rtc_nsec    =>       rtc_nsec_aic2    ,
        irq_grp_i   => irq_grp_i   ,
        irq_s_i     => irq_s_i     ,
        enmi_i      => enmi_i      ,
        event_i     => event_i     ,
        event_o     =>       event_o_aic2 
--      event_req   =>       event_req_aic2   ,
--      event_info  =>       event_info_aic2  ,
--      event_ack_i => event_ack_i 
        );

  bstb_i      <= '0';
  back_i      <= '0';
  enmi_i      <= '1';
  event_i.ack  <= event_ack_i;

  irq_en_accumu_foraic2 <=
    irq_grp_i(0).en or irq_grp_i(1).en or irq_grp_i(2).en or
    irq_grp_i(3).en or irq_grp_i(4).en or irq_grp_i(5).en or
    irq_grp_i(6).en or irq_grp_i(7).en or irq_grp_i(8).en or
    irq_grp_i(9).en or 
    irq_s_i(0) or irq_s_i(1) or irq_s_i(2) or irq_s_i(3) or
    irq_s_i(4) or irq_s_i(5) or irq_s_i(6) or irq_s_i(7) ;

  dut_glue : entity work.aic2_tglue(behav)
    port map (
        clk_sys => clk_sys,
        rst_i   => rst_i,
        irqs    => irq_i(4 downto 0),
        irq_o   => irq_o_glue
    );

  -- cpu -> aic access pattern ------------------------------------------------
  -- process (1) --------------------------------------------------------------
  cpu2aic : process
  begin
  -- ------------------------------
  db_iv1                <= NULL_DATA_O;
             wait until (rst_i'event and rst_i = '0');
  -- ------------------------------
  db_iv1                <= NULL_DATA_O;
  -- ------------------------------
             wait for    60 ns;
  -- ------------------------------
  db_iv1.a(7 downto 0)  <= x"08";
  db_iv1.d              <= x"89abcdef";
  db_iv1.en             <= '1';
  db_iv1.wr             <= '1';
  db_iv1.we             <= x"f";
  -- ------------------------------
             wait for    20 ns;
  -- ------------------------------
  db_iv1                <= NULL_DATA_O;
  -- ------------------------------
  end process;

  -- db_i mixer (from db_iv1, db_iv2) -----------------------------------------
  -- process (2) --------------------------------------------------------------
  db_i_mixer : process (db_iv1, db_iv2)
  begin
  if(db_iv2.en = '1') then db_i <= db_iv2;
  else                     db_i <= db_iv1; end if;
  end process;

  -- equivalence check between aic1 aic2 --------------------------------------
  -- process (3) --------------------------------------------------------------
  equiv_check : process ( event_req_aic1, event_o_aic2, db_o_aic1, db_o_aic2 )
  begin
  if to_event_i(event_req_aic1, event_info_aic1).cmd = event_o_aic2.cmd  then
                                           equiv_chk_event_req <= '1'; 
  else                                     equiv_chk_event_req <= '0'; 
  end if;

  -- db_o check direction 
  --   ack match -- must condition 
  --   d   match -- check as long as wr=0 
  if(db_o_aic1.ack = db_o_aic2.ack) and
    ((db_o_aic1.d  = db_o_aic2.d  ) or (db_i.wr = '1')) then
                                           equiv_chk_db_o      <= '1'; 
  else                                     equiv_chk_db_o      <= '0'; 
  end if;

  end process;
  diff0_chk_event_req <= not equiv_chk_event_req;
  diff0_chk_db_o      <= not equiv_chk_db_o;

  -- irq input pattern --------------------------------------------------------
  -- process (4) --------------------------------------------------------------
  irq_vector : process 
  begin
  -- ------------------------------
     aic_tb_test_number <= 00;
  -- ------------------------------
  db_iv2                <= NULL_DATA_O;
  event_ack_i <= '0';
  rst_i <= '1';
  irq_i        <= (others => '0');
  irq_grp_i(0) <= NULL_IRQ;
  irq_grp_i(1) <= NULL_IRQ;
  irq_grp_i(2) <= NULL_IRQ;
  irq_grp_i(3) <= NULL_IRQ;
  irq_grp_i(4) <= NULL_IRQ;
  irq_grp_i(5) <= NULL_IRQ;
  irq_grp_i(6) <= NULL_IRQ;
  irq_grp_i(7) <= NULL_IRQ;
  irq_grp_i(8) <= NULL_IRQ;
  irq_grp_i(9) <= NULL_IRQ;
  irq_s_i <= (others => '0');                        wait for     30 ns;
  -- ------------------------------
  rst_i <= '0';                                      wait for    180 ns;
  -- ------------------------------
  -- ##################################################
  -- ### test              01
  -- ### req three time with prio up, prio down
     aic_tb_test_number <= 01;
    irq_i          <= "00001000";
                   --      * IRQS(3)
    irq_grp_i(5)   <= (en => '1' , num => "110000"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    200 ns;
    -- ------------------------------
    irq_i          <= "00000100";
                   --       * IRQS(2)
    irq_grp_i(5)   <= (en => '1' , num => "110111"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    200 ns;
    -- ------------------------------
    irq_i          <= "00010000";
                   --     *   IRQS(4)
    irq_grp_i(5)   <= (en => '1' , num => "101000"); wait for     20 ns;
    -- ------------------------------
    irq_i               <= (others => '0');
    irq_grp_i(5)        <= NULL_IRQ;                 wait for    200 ns;
  -- ### test 01 end
  -- ------------------------------

  -- ##################################################
  -- ### test              02
  -- ###   req three time with prio up, prio down (with cpu ack)
     aic_tb_test_number <= 02;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- ------------------------------
    irq_i          <= "00001000";
                   --      * IRQS(3)
    irq_grp_i(5)   <= (en => '1' , num => "110000"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    -- ------------------------------
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_i          <= "00000100";
                   --       * IRQS(2)
    irq_grp_i(5)   <= (en => '1' , num => "110111"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    -- ------------------------------
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_i          <= "00010000";
                   --     *   IRQS(4)
    irq_grp_i(5)   <= (en => '1' , num => "101000"); wait for     20 ns;
    -- ------------------------------
    irq_i               <= (others => '0');
    irq_grp_i(5)        <= NULL_IRQ;                 wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    -- ------------------------------
    event_ack_i    <= '0';                           wait for     80 ns;
  -- ### test 02 end
  -- ------------------------------

  -- ##################################################
  -- ### test              03 
  -- ###   req three time req req ack ack (higher to lower switch)
     aic_tb_test_number <= 03;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- ------------------------------
    irq_i          <= "00001000";
                   --      * IRQS(3)
    irq_grp_i(5)   <= (en => '1' , num => "110000"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    200 ns;
    -- ------------------------------
    irq_i          <= "00000100";
                   --       * IRQS(2)
    irq_grp_i(5)   <= (en => '1' , num => "110111"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    -- ------------------------------
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    -- ------------------------------
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_i          <= "00010000";
                   --     *   IRQS(4)
    irq_grp_i(5)   <= (en => '1' , num => "101000"); wait for     20 ns;
    -- ------------------------------
    irq_i               <= (others => '0');
    irq_grp_i(5)        <= NULL_IRQ;                 wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    -- ------------------------------
    event_ack_i    <= '0';                           wait for     80 ns;
  -- ### test 03 end

  -- ##################################################
  -- ### test              04 
  -- ###   round robin (4ch) test
     aic_tb_test_number <= 04;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "101100"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "101101"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "101100"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "101101"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "101110"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "101111"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    200 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    event_ack_i    <= '0';                           wait for    200 ns;
    -- ------------------------------
  -- ### test 04 end
  -- ------------------------------

  -- ##################################################
  -- ### test              05 
  -- ###   round robin (8ch) test
     aic_tb_test_number <= 05;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "000000"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "000001"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------ set 6 5 4 2 1 0
    irq_grp_i(6)   <= (en => '1' , num => "000110"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "000101"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "000100"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "000010"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "000001"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    irq_grp_i(6)   <= (en => '1' , num => "000000"); wait for     20 ns;
    irq_grp_i(6)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------ event info output order 
    -- ------------------------------ 2 -> 4 -> 5 -> 6 -> 0 -> 1
    -- ------------------------------ skip 3, 7
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    event_ack_i    <= '0';                           wait for    200 ns;
    -- ------------------------------
    -- ------------------------------
  -- ### test 05 end
  -- ------------------------------

  -- ##################################################
  -- ### test              06 
  -- ###   pit_related write with pit_enable = 0/1
     aic_tb_test_number <= 06;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- -------------------------------- pit_en 0->0
     db_iv2.en <= '1';
     db_iv2.a(7 downto 0)  <= x"00";
     db_iv2.d              <= x"02021aaa";
     db_iv2.wr <= '1';
     db_iv2.we <= b"1111";                           wait for     40 ns;
  -- ------------------------------
     db_iv2 <= NULL_DATA_O;                          wait for     60 ns;
    -- ------------------------------
     db_iv2.en <= '1';
     db_iv2.a( 7 downto 0) <= x"14";
     db_iv2.a(27 downto 24) <= x"1";
     db_iv2.rd <= '1';                               wait for     60 ns;
    -- ------------------------------ pit_en 0->1
     db_iv2.en <= '1';
     db_iv2.a( 7 downto 0) <= x"00";
     db_iv2.d              <= x"0402e123";
     db_iv2.wr <= '1';
     db_iv2.we <= b"1111";                           wait for     40 ns;
  -- ------------------------------
     db_iv2 <= NULL_DATA_O;                          wait for     60 ns;
    -- ------------------------------
     db_iv2.en <= '1';
     db_iv2.a( 7 downto 0) <= x"14";
     db_iv2.a(27 downto 24) <= x"2";
     db_iv2.rd <= '1';                               wait for     60 ns;
    -- ------------------------------
     db_iv2 <= NULL_DATA_O;                          wait for     20 ns;
    -- ------------------------------ pit_en 1->1
     db_iv2.en <= '1';
     db_iv2.a( 7 downto 0) <= x"00";
     db_iv2.d              <= x"04022eee";
     db_iv2.wr <= '1';
     db_iv2.we <= b"1111";                           wait for     40 ns;
  -- ------------------------------
     db_iv2 <= NULL_DATA_O;                          wait for     60 ns;
    -- ------------------------------
     db_iv2.en <= '1';
     db_iv2.a( 7 downto 0) <= x"14";
     db_iv2.a(27 downto 24) <= x"3";
     db_iv2.rd <= '1';                               wait for     60 ns;
    -- ------------------------------
     db_iv2 <= NULL_DATA_O;                          wait for     60 ns;
    -- ------------------------------ pit_en 1->0
     db_iv2.en <= '1';
     db_iv2.a( 7 downto 0) <= x"00";
     db_iv2.d              <= x"0002d234";
     db_iv2.wr <= '1';
     db_iv2.we <= b"1111";                           wait for     40 ns;
  -- ------------------------------
     db_iv2 <= NULL_DATA_O;                          wait for     60 ns;
    -- ------------------------------
     db_iv2.en <= '1';
     db_iv2.a( 7 downto 0) <= x"14";
     db_iv2.a(27 downto 24) <= x"4";
     db_iv2.rd <= '1';                               wait for     60 ns;
    -- ------------------------------
     db_iv2 <= NULL_DATA_O;                          wait for     60 ns;
    -- ------------------------------
  -- ### test 06 end
  -- ------------------------------


  -- ##################################################
  -- ### test              07 
  -- ###   pit interrupt
     aic_tb_test_number <= 07;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- --------------------------------  set pit throt low
    db_iv2.en <= '1';
    db_iv2.a(11 downto 0) <= x"010";
    db_iv2.d              <= x"00000020";
    db_iv2.wr <= '1';
    db_iv2.we <= b"1111";                           wait for     40 ns;
  -- --------------------------------  set pit_en = 1
    db_iv2.en <= '1';
    db_iv2.a(11 downto 0) <= x"000";
    db_iv2.d              <= x"04249000";
    db_iv2.wr <= '1';
    db_iv2.we <= b"1111";                           wait for     40 ns;
  -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for     20 ns;
  -- ------------------------------
    db_iv2.en <= '1';
    db_iv2.a(11 downto 0) <= x"014";
    db_iv2.a(27 downto 24) <= x"4";
    db_iv2.rd <= '1';                               wait for     400 ns;
    -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for      20 ns;
    db_iv2.a(11 downto 0) <= x"014";                wait for     480 ns;
  -- ------------------------------
    event_ack_i    <= '1';                          wait for     20 ns;
    event_ack_i    <= '0';                          wait for     80 ns;
  -- ------------------------------
    irq_i          <= "00001000";
                   --      * IRQS(3)
    irq_grp_i(5)   <= (en => '1' , num => "110000"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    360 ns;
    -- ------------------------------
    event_ack_i    <= '1';                          wait for     20 ns;
    event_ack_i    <= '0';                          wait for     80 ns;
                                                    wait for    400 ns;
  -- ------------------------------

  -- ##################################################
  -- ### test              08 
  -- ###   pit interrupt  (pit pri > irq pri)
     aic_tb_test_number <= 08;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- --------------------------------  set pit throt low
    db_iv2.en <= '1';
    db_iv2.a(11 downto 0) <= x"010";
    db_iv2.d              <= x"00000020";
    db_iv2.wr <= '1';
    db_iv2.we <= b"1111";                           wait for     40 ns;
  -- --------------------------------  set pit_en = 1
    db_iv2.en <= '1';
    db_iv2.a(11 downto 0) <= x"000";
    db_iv2.d              <= x"04240000";
    db_iv2.wr <= '1';
    db_iv2.we <= b"1111";                           wait for     40 ns;
  -- ------------------------------
    db_iv2.en <= '1';
    db_iv2.a(7 downto 0)  <= x"08";
    db_iv2.d              <= x"89ab1def"; -- IRQ(3) prio 1 (for aic1)
    db_iv2.wr             <= '1';
    db_iv2.we             <= b"1111";               wait for     40 ns;
  -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for     20 ns;
  -- ------------------------------
    db_iv2.en <= '1';
    db_iv2.a(11 downto 0) <= x"014";
    db_iv2.a(27 downto 24) <= x"4";
    db_iv2.rd <= '1';                               wait for     400 ns;
    -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for      20 ns;
    db_iv2.a(11 downto 0) <= x"014";                wait for     480 ns;
  -- ------------------------------
    event_ack_i    <= '1';                          wait for     20 ns;
    event_ack_i    <= '0';                          wait for     80 ns;
  -- ------------------------------
    irq_i          <= "00001000";
                   --      * IRQS(3)
    irq_grp_i(5)   <= (en => '1' , num => "000011"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    360 ns;
    -- ------------------------------
    event_ack_i    <= '1';                          wait for     20 ns;
    event_ack_i    <= '0';                          wait for     80 ns;
  -- ------------------------------

    -- ------------------------------
  -- ### test 08 end
  -- ------------------------------

  -- ##################################################
  -- ### test              09
  -- ### single wire
     aic_tb_test_number <= 09;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- -------------------------------- 
    db_iv2.en <= '1';
    db_iv2.a(7 downto 0)  <= x"08";
    db_iv2.d              <= x"79abcd78"; -- IRQ(0) prio 8
                                          -- IRQ(1,7) prio 7
    db_iv2.wr             <= '1';
    db_iv2.we             <= b"1111";               wait for     40 ns;
  -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for     20 ns;
  -- ------------------------------
    irq_i          <= "00000001";
                      --      * IRQS(0)
    irq_s_i        <= "00000001";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_i          <= "00000010";
                      --     * IRQS(1)
    irq_s_i        <= "00000010";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_i          <= "10000000";
               --      * IRQS(7)
    irq_s_i        <= "10000000";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_i          <= "00000001";
                      --      * IRQS(0)
    irq_s_i        <= "00000001";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_i          <= "00000010";
                      --     * IRQS(1)
    irq_s_i        <= "00000010";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_i          <= "10000000";
               --      * IRQS(7)
    irq_s_i        <= "10000000";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------

  -- ### test 09 end
  -- ------------------------------

  -- ##################################################
  -- ### test              10
  -- ### single wire
     aic_tb_test_number <= 10;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- -------------------------------- 
    db_iv2.en <= '1';
    db_iv2.a(7 downto 0)  <= x"08";
    db_iv2.d              <= x"79abcd78"; -- IRQ(0) prio 8
                                          -- IRQ(1,7) prio 7
    db_iv2.wr             <= '1';
    db_iv2.we             <= b"1111";               wait for     40 ns;
  -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for     20 ns;
  -- ------------------------------
    irq_i          <= "00000001";
                      --      * IRQS(0)
    irq_s_i        <= "00000001";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    irq_i          <= "00000010";
                      --     * IRQS(1)
    irq_s_i        <= "00000010";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    irq_i          <= "10000000";
               --      * IRQS(7)
    irq_s_i        <= "10000000";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    event_ack_i    <= '0';                           wait for    200 ns;
    -- ------------------------------

  -- ### test 10 end
  -- ------------------------------

  -- ##################################################
  -- ### test              11
  -- ### single wire
     aic_tb_test_number <= 11;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- -------------------------------- 
    db_iv2.en <= '1';
    db_iv2.a(7 downto 0)  <= x"08";
    db_iv2.d              <= x"79abcd78"; -- IRQ(0) prio 8
                                          -- IRQ(1,7) prio 7
    db_iv2.wr             <= '1';
    db_iv2.we             <= b"1111";               wait for     40 ns;
  -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for     20 ns;
  -- ------------------------------
    irq_i          <= "10000000";
               --      * IRQS(7)
    irq_s_i        <= "10000000";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    irq_i          <= "00000010";
                      --     * IRQS(1)
    irq_s_i        <= "00000010";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    irq_i          <= "00000001";
                      --      * IRQS(0)
    irq_s_i        <= "00000001";                    wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    event_ack_i    <= '0';                           wait for    200 ns;
    -- ------------------------------

  -- ### test 11 end
  -- ------------------------------

  -- ##################################################
  -- ### test              12
  -- ### 12bit counter interrupt
     aic_tb_test_number <= 12;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- -------------------------------- 
    db_iv2.en <= '1';
    db_iv2.a(7 downto 0)  <= x"00";
    db_iv2.d              <= x"0200001f"; -- count-enable
    db_iv2.wr             <= '1';
    db_iv2.we             <= b"1111";               wait for     40 ns;
  -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for   1100 ns;
  -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    db_iv2.en <= '1';
    db_iv2.a(7 downto 0)  <= x"00";
    db_iv2.d              <= x"00000999"; -- count-disable
    db_iv2.wr             <= '1';
    db_iv2.we             <= b"1111";               wait for     40 ns;
  -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for    200 ns;
  -- ------------------------------
  -- ### test 12 end
  -- ------------------------------

  -- ##################################################
  -- ### test              13
  -- ### single wire
     aic_tb_test_number <= 13;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- -------------------------------- 
    db_iv2.en <= '1';
    db_iv2.a(7 downto 0)  <= x"08";
    db_iv2.d              <= x"79abcd78"; -- IRQ(0) prio 8
                                          -- IRQ(1,7) prio 7
    db_iv2.wr             <= '1';
    db_iv2.we             <= b"1111";               wait for     40 ns;
  -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for     20 ns;
  -- ------------------------------
    irq_i          <= "10000011";
               --      * IRQS(7)
    irq_s_i        <= "10000011";                    wait for    200 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_s_i        <= (others => '0');               wait for    100 ns;
    -- ------------------------------

  -- ### test 13 end
  -- ------------------------------

  -- ##################################################
  -- ### test              14 
  -- ###   req three time req req ack ack (higher to lower switch)
     aic_tb_test_number <= 14;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- ------------------------------
    irq_i          <= "00001000";
                   --      * IRQS(3)
    irq_grp_i(5)   <= (en => '1' , num => "110001"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    200 ns;
    -- ------------------------------
    irq_i          <= "00000100";
                   --       * IRQS(2)
    irq_grp_i(5)   <= (en => '1' , num => "110000"); wait for     20 ns;
    -- ------------------------------
    irq_i          <= (others => '0');
    irq_grp_i(5)   <= NULL_IRQ;                      wait for    100 ns;
    -- ------------------------------
    irq_i          <= "00010000";
                   --     *   IRQS(4)
    irq_grp_i(5)   <= (en => '1' , num => "110010"); wait for     20 ns;
    -- ------------------------------
    irq_i               <= (others => '0');
    irq_grp_i(5)        <= NULL_IRQ;                 wait for    100 ns;
    -- ------------------------------
    db_iv2.en <= '1';
    db_iv2.a( 7 downto 0) <= x"0c";
    db_iv2.rd <= '1';                               wait for      40 ns;
    -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for      20 ns;
    -- ------------------------------
    db_iv2.en <= '1';
    db_iv2.a(7 downto 0)  <= x"0c";
    db_iv2.d              <= x"ffff6fff"; -- grp = b"110"
    db_iv2.wr             <= '1';
    db_iv2.we             <= b"1111";               wait for     40 ns;
  -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for     20 ns;
  -- ------------------------------
    db_iv2.en <= '1';
    db_iv2.a( 7 downto 0) <= x"0c";
    db_iv2.rd <= '1';                               wait for      40 ns;
    -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for      20 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
  -- ------------------------------
    db_iv2.en <= '1';
    db_iv2.a( 7 downto 0) <= x"0c";
    db_iv2.rd <= '1';                               wait for      40 ns;
    -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for      20 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
    -- ------------------------------
    event_ack_i    <= '1';                           wait for     20 ns;
    event_ack_i    <= '0';                           wait for     80 ns;
  -- ------------------------------
    db_iv2.en <= '1';
    db_iv2.a( 7 downto 0) <= x"0c";
    db_iv2.rd <= '1';                               wait for      40 ns;
    -- ------------------------------
    db_iv2 <= NULL_DATA_O;                          wait for      20 ns;
    -- ------------------------------
                                                    wait for     140 ns;
  -- ### test 14 end

  -- ##################################################
  -- ### test              15 
  -- ###   aic tglue test
     aic_tb_test_number <= 15;
  -- ------------------------------
  rst_i <= '1' ;                                     wait for     40 ns;
  rst_i <= '0' ;                                     wait for    160 ns;
  -- ------------------------------
    irq_i          <= "00011111";                    wait for    140 ns;
    irq_i          <= (others => '0');               wait for     80 ns;
  -- ### test 15 end

  -- test terminates ------------------------------  . . . . . . . . . .
     aic_tb_test_number <= 00;
                                                     wait for 999999 ns;
  -- ------------------------------
  end process;

end tb;

