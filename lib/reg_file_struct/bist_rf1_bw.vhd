-- async / sync 1R sync 1W register file with bist wrapper
-- modeled from datasheet parameters

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rf_pack.all;
use work.bist_pack.all;

entity bist_RF1_BW is
   generic ( sync : boolean := false;
             lhqd : boolean := false;
             WIDTH : natural range 1 to 16;
             DEPTH : natural range 1 to 32 );
   port (
   clk: in  std_logic;
   rst: in  std_logic;
   bi : in  bist_scan_t;
   bo : out bist_scan_t;
   D  : in  std_logic_vector(WIDTH-1 downto 0);
   WA : in  integer range 0 to DEPTH-1;
   WE : in  std_logic_vector(1 downto 0);
   RA0: in  integer range 0 to DEPTH-1;
   Q0 : out std_logic_vector(WIDTH-1 downto 0));
begin
  assert WIDTH <= 32 report "bist command supports max width of 32" severity failure;
end bist_RF1_BW;

architecture bist of bist_RF1_BW is

signal wd   : std_logic_vector(WIDTH-1 downto 0);
signal sa   : integer range 0 to DEPTH-1;
signal se   : std_logic_vector(1       downto 0);
signal a0   : integer range 0 to DEPTH-1;
signal rq0  : std_logic_vector(WIDTH-1 downto 0);
signal fbq  : std_logic_vector(WIDTH-1 downto 0);
signal ba   : integer range 0 to DEPTH-1;
signal bp   : integer range 0 to 3;
signal be   : std_logic_vector(1       downto 0);
signal bq   : std_logic;
signal bc   : bist_cmd_t;

signal ctrl : std_logic_vector(7 downto 0);

begin
   -- The BIST multiplexors
   wd <= D   when bi.bist = '0' else bi.d & fbq(WIDTH-1 downto 1);
   sa <= WA  when bi.bist = '0' else ba;
   se <= WE  when bi.bist = '0' else be;
   a0 <= RA0 when bi.bist = '0' or bp /= 0 else ba;

   -- The register file and write registers
   rf : RF1_BW generic map( sync => sync, lhqd => lhqd,
                         WIDTH => WIDTH, DEPTH => DEPTH )
            port    map( clk => clk, rst => rst, D => wd, WA => sa, WE => se,
                         RA0 => a0, Q0 => rq0 );

   Q0  <= rq0;
   fbq <= rq0;

   -- The standard 8 bit BIST command register and bist output register
   cr : process(clk, rst, bi, ctrl, bc, fbq)
   begin
      if rst = '1' then
         ctrl <= (others => '0');
         bq   <= '0';
      elsif clk'event and clk = '1' then
         if bi.bist = '1' and bi.en = '1' and bc = SHIFT_CTRL then
            ctrl <= bi.ctrl & ctrl(7 downto 1);
         end if;
         if bi.bist = '1' and bi.en = '1' and bc = SHIFT_DATA then
            bq   <= fbq(0);
         end if;
      end if;
   end process;

   -- decode the BIST command register
   -- 7   6   5   4   3   2   1   0
   -- we  -port-  ------addr-------
   bc <= to_bist_cmd(bi.cmd);
   be <=                     ctrl(7         ) &
                             ctrl(7         ) when bc = SHIFT_DATA else
                                                   (others =>'0');
   bp <= to_integer(unsigned(ctrl(6 downto 5)));
   ba <= to_integer(unsigned(ctrl(4 downto 0)));

   -- bist outputs
   bo.bist <= bi.bist;
   bo.en   <= bi.en;
   bo.cmd  <= bi.cmd;
   bo.d    <= bq;
   bo.ctrl <= ctrl(0);
end bist;
