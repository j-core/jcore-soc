library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

use work.ddrc_cnt_pack.all;

entity sm_tb is
end sm_tb;

architecture sim of sm_tb is

component ddr_fsm 
    port(clk        : in std_logic;
         rst        : in std_logic;
         cmd        : in ddr_pcmd_t;
         bnkmis     : in std_logic;
         busy       : out std_logic);
end component;

    signal Aclk        : std_logic;
    signal Arst        : std_logic;
    signal Acmd        : ddr_pcmd_t;
    signal Abnkmis     : std_logic;
    signal Ybusy       : std_logic;
    signal tmp         : std_logic_vector(16 downto 0);

begin

   test_sm : ddr_fsm port map (
         rst        => Arst  ,
         clk        => Aclk  ,
         cmd        => Acmd  ,
         bnkmis     => Abnkmis ,
         busy       => Ybusy);
         
   process begin

	      		    tmp <= "10X000000X00X0000" ;
   wait for  2.5 ns ;       tmp <= "11X000000X00X0000" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0000" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0000" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0000" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X010000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X010000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X1110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X1110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0111" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0111" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0111" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0111" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0111" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0111" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X1110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X1110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X1110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X1111" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0111" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X10X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X10X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000010X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "01X000000X00X0110" ;
   wait for  2.5 ns ;       tmp <= "00X000000X00X0110" ;
   wait for  2.5 ns ;       assert false;
 
   end process;

   process (tmp) begin
     Arst        <= tmp(16);
     Aclk        <= tmp(15);

     Acmd.PREA   <= tmp(13);
     Acmd.LMR    <= tmp(12);
     Acmd.SREF   <= tmp(11);
     Acmd.SREFX  <= tmp(10);
     Acmd.READ   <= tmp(9);
     Acmd.WRITE  <= tmp(8);

     Acmd.BST    <= tmp(6);
     Acmd.IDLE   <= tmp(5);

     Abnkmis     <= tmp(3);
   end process;
end sim ;
