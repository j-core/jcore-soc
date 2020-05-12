library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.cpu2j0_pack.all;
use ieee.numeric_std.all;
use work.misc_pack.all;
use work.cache_pack.all;
use work.data_bus_pack.all;

package aic2_pack is

type v_irq_t is array(0 to 7) of std_logic_vector(7 downto 0);

type irq_t is record
  en  : std_logic;
  num : std_logic_vector (5 downto 0);
end record; 


constant NULL_IRQ : irq_t := (en => '0', num => (others => '0'));

constant c_event_nmi  : std_logic_vector(2 downto 0) := "001";
constant c_event_irq  : std_logic_vector(2 downto 0) := "000";
constant c_event_cer  : std_logic_vector(2 downto 0) := "010";
constant c_event_der  : std_logic_vector(2 downto 0) := "011";
constant c_event_mres : std_logic_vector(2 downto 0) := "110";
constant c_event_nevt : std_logic_vector(2 downto 0) := "111";

type irq_a_t is array(0 to 9) of irq_t;
type sbu_regf_t is array (0 to 9) of std_logic_vector(31 downto 0);

type db2_state_t is ( DB_INIT, DB_INT );
type wakeup_state_t is ( RESET, WAKE1, WAKE2, IDLE );

-- type cop_o_t is record
--   d    : std_logic_vector(31 downto 0);
--   rna  : std_logic_vector( 3 downto 0);
--   rnb  : std_logic_vector( 3 downto 0);
--   op   : std_logic_vector( 4 downto 0);
--  opcc : std_logic_vector( 1 downto 0);
--   en   : std_logic;
--   stallcp : std_logic;
-- end record;

-- constant NULL_COPR_O : cop_o_t := (
--   d    => (others => '0'),
--   rna  => (others => '0'),
--   rnb  => (others => '0'),
--   op   => (others => '0'),
-- opcc => (others => '0'),
--   en   =>            '0' ,
--   stallcp =>         '0'   );

-- type cop_i_t is record
--   d   : std_logic_vector(31 downto 0);
--   ack : std_logic;
--   t   : std_logic;
--   exc : std_logic;
-- end record;

type aiccom_io_t is record
  icinv         : std_logic;
  dcinv         : std_logic;
  ic_enable_ot  : std_logic;
  ic_disable_ot : std_logic;
  dc_enable_ot  : std_logic;
  dc_disable_ot : std_logic;
  ipi           : std_logic;
end record;
constant NULL_AICCOM : aiccom_io_t := (
  icinv         => '0', dcinv         => '0',
  ic_enable_ot  => '0', ic_disable_ot => '0',
  dc_enable_ot  => '0', dc_disable_ot => '0',
  ipi           => '0'  );

type aictwo_reg_t is record
   db_state       : db2_state_t;
   wakeup_state   : wakeup_state_t;
   cbcdcinv       : std_logic;
   cbcicinv       : std_logic;
   cpu1eni        : std_logic;
   irq_bynum      : std_logic_vector(63 downto 0); -- area save for cpuid/=0
   irqsiedge0     : std_logic_vector( 7 downto 0);
   irqsiedge1     : std_logic_vector( 7 downto 0);
   irq_peout      : std_logic_vector( 6 downto 0);
-- r_cpuerr       : std_logic;
-- r_dmaerr       : std_logic;
-- r_irq1         : std_logic;
-- r_irq10        : std_logic;
   r_mrst         : std_logic;
   r_nmi          : std_logic;
   reg_event      : std_logic_vector(15 downto 0);
   reg_rtc_nsec   : std_logic_vector(31 downto 0); -- area save for cpuid/=0
   reg_rtc_sec    : std_logic_vector(63 downto 0); -- area save for cpuid/=0
   roundrobin_ptr : std_logic_vector(30 downto 0); -- area save for cpuid/=0
   w_ack          : std_logic;
   sbu_regfile    : sbu_regf_t;
   sbu_num_ex     : std_logic_vector(4 downto 0);
   sbu_wnum_ma     : std_logic_vector(4 downto 0);
   sbu_rnum_ma     : std_logic_vector(4 downto 0);
   sbu_oplds_ma   : std_logic;
   reboot         : std_logic;
   busni_numer_cnt : integer range 0 to 31;
end record;

constant AIC2_REG_RESET : aictwo_reg_t := (
    DB_INIT       ,   -- db_state       : db2_state_t;
    RESET         ,   -- wakeup_state   : wakeup_state_t;
              '0' ,   -- cbcdcinv
              '0' ,   -- cbcicinv
              '0' ,   -- cpu1eni
   (others => '0'),   -- irq_bynum      (63 downto 0);
   (others => '0'),   -- irqsiedge0     ( 7 downto 0);
   (others => '0'),   -- irqsiedge1     ( 7 downto 0);
   (others => '0'),   -- irq_peout      ( 6 downto 0);
--            '0' ,   -- r_cpuerr
--            '0' ,   -- r_dmaerr
--            '0' ,   -- r_irq1
--            '0' ,   -- r_irq10
              '0' ,   -- r_mrst
              '0' ,   -- r_nmi
   b"0111111100011000" ,
--    <-><--><--><-->
--   1....1....0....0
--   5....0....5....0
                      -- reg_event      (15 downto 0);
                      -- (15) = 0, (14:12) = b"111", (11:0) = x"F18"
   (others => '0'),   -- reg_rtc_nsec   (31 downto 0);
   (others => '0'),   -- reg_rtc_sec    (63 downto 0);
   (others => '0'),   -- roundrobin_ptr (30 downto 0);
              '0' ,   -- w_ack
  ( x"00000fff"   ,   (others => '0'),    x"000fffff"   , -- nonzero SBR0 & 2
   (others => '0'),   (others => '0'),   (others => '0'),
    x"80000000",      (others => '0'),   (others => '0'), -- nonzero SBR6
    (others => '0')),
                      -- isbu_regfile    : sbu_regf_t;
   (others => '0'),   -- sbu_num_ex     : std_logic_vector(3 downto 0);
   (others => '0'),   -- sbu_wnum_ma     : std_logic_vector(3 downto 0);
   (others => '0'),   -- sbu_wnum_ma     : std_logic_vector(3 downto 0);
              '0',    -- sbu_oplds_ma
              '0',    -- reboot
               0      -- busni_numer_cnt : integer
    );
-- todo init pit_throttle change from x"00000018" 
--      to std_logic_vector(to_unsigned(1e9 / 100 / c_busperiod,
--                                      pit_throttle'length)

component aic2 is
        generic (c_busperiod : integer := 40;
        c_cpuid : integer := 0;
        busperiod_integer_ns : boolean := true;
        busperiodni_numer : integer := 80;
        busperiodni_denom : integer :=  7;
        IRQ_SI0_NUM : integer :=  78;
        IRQ_SI1_NUM : integer := (78 + 1);
        IRQ_SI2_NUM : integer := (78 + 2);
        IRQ_SI3_NUM : integer := (78 + 3);
        IRQ_SI4_NUM : integer := (78 + 4);
        IRQ_SI5_NUM : integer := (78 + 5);
        IRQ_SI6_NUM : integer := (78 + 6);
        IRQ_SI7_NUM : integer := (78 + 7);
        IRQ_II0_NUM : integer :=  76
        );
        port (
        clk_sys   : in  std_logic;
        rst_i     : in  std_logic;
        db_i      : in  cpu_data_o_t;
        db_o      : out cpu_data_i_t;
        rtc_sec   : out std_logic_vector(63 downto 0);    -- clk_sys domain
        rtc_nsec  : out std_logic_vector(31 downto 0);
        irq_grp_i : in  irq_a_t;
        irq_s_i   : in  std_logic_vector(7 downto 0) := (others => '0');
        enmi_i    : in  std_logic;
        event_i   : in  cpu_event_o_t;
        event_o   : out cpu_event_i_t;
        cpa       : in  cop_o_t;
        cpy       : out cop_i_t;
        cacheb_ctrl_ic : out cache_ctrl_t;
        cacheb_ctrl_dc : out cache_ctrl_t;
        aic_com_o : out aiccom_io_t;
        aic_com_i : in  aiccom_io_t;
        db_cctrans_o : in tracpu_data_o_t; -- to snoop cache_modereg, temporary
        cpu1eni   : out std_logic
        );
end component;

end package;

package body aic2_pack is

end aic2_pack;

