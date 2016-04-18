library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.cpu2j0_pack.all;
use ieee.numeric_std.all;
use work.misc_pack.all;

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

function itov(X, N : integer) return std_logic_vector;
function vtoi(X : std_logic_vector) return integer;

type irq_a_t is array(0 to 9) of irq_t;

type db2_state_t is ( DB_INIT, DB_INT );
type wakeup_state_t is ( RESET, WAKE1, WAKE2, IDLE );

type aictwo_reg_t is record
   db_state       : db2_state_t;
   wakeup_state   : wakeup_state_t;
   count          : std_logic_vector(11 downto 0);
   count_enable   : std_logic;
   db_count       : std_logic_vector( 3 downto 0);
   gsel           : std_logic_vector( 2 downto 0);
   irq_bynum      : std_logic_vector(63 downto 0); -- area save for cpuid/=0
   irqsample_i         : std_logic_vector( 7 downto 0);
   irqsiedge0     : std_logic_vector( 7 downto 0);
   irqsiedge1     : std_logic_vector( 7 downto 0);
   irq_peout      : std_logic_vector( 6 downto 0);
   pit_cntr       : std_logic_vector(31 downto 0);
   pit_enable     : std_logic;
   pit_flag       : std_logic;
   pit_throttle   : std_logic_vector(31 downto 0);
   q_irqs         : std_logic_vector( 7 downto 0);
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
   pit_irqnuma    : std_logic_vector( 5 downto 0);
   pit_irqnumb    : std_logic_vector( 3 downto 0);
   w_ack          : std_logic;
end record;

constant AIC2_REG_RESET : aictwo_reg_t := (
    DB_INIT       ,   -- db_state       : db2_state_t;
    RESET         ,   -- wakeup_state   : wakeup_state_t;
   (others => '1'),   -- count          (11 downto 0);
              '0' ,   -- count_enable
   (others => '0'),   -- db_count       (3 downto 0);
   (others => '0'),   -- gsel           ( 2 downto 0);
   (others => '0'),   -- irq_bynum      (63 downto 0);
   (others => '0'),   -- irqsample_i    ( 7 downto 0);
   (others => '0'),   -- irqsiedge0     ( 7 downto 0);
   (others => '0'),   -- irqsiedge1     ( 7 downto 0);
   (others => '0'),   -- irq_peout      ( 6 downto 0);
   (others => '0'),   -- pit_cntr       (31 downto 0);
              '0' ,   -- pit_enable
              '0' ,   -- pit_flag
   x"000fffff"    ,   -- pit_throttle   (31 downto 0);
   (others => '0'),   -- q_irqs         ( 7 downto 0);
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
   (others => '0'),   -- pit_irqnuma    ( 5 downto 0);
   (others => '0'),   -- pit_irqnumb    ( 3 downto 0);
              '0'     -- w_ack
   );
-- todo init pit_throttle change from x"00000018" 
--      to std_logic_vector(to_unsigned(1e9 / 100 / c_busperiod,
--                                      pit_throttle'length)

component aic2 is
        generic (c_busperiod : integer := 40;
        c_cpuid : integer := 0;
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
        event_o   : out cpu_event_i_t
        );
end component;

end package;

package body aic2_pack is

function itov(X, N : integer) return std_logic_vector is
begin
   return std_logic_vector(to_unsigned(X,N));
end itov;

function vtoi(X : std_logic_vector) return integer is
variable v : std_logic_vector(X'high - X'low downto 0) := X;
begin
   return to_integer(unsigned(v));
end vtoi;

end aic2_pack;

