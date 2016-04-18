-- async / sync 1,2,4R sync 1W register file, using Artisan transparent latch 0.18um.
-- modeled from datasheet parameters

library ieee;
use ieee.std_logic_1164.all;

use work.bist_pack.all;

package rf_pack is

component RF1
   generic ( sync : boolean := false;
             lhqd : boolean := false;
             WIDTH : natural range 1 to 32;
             DEPTH : natural range 1 to 32 );
   port (
   clk: in  std_logic;
   rst: in  std_logic;
   D  : in  std_logic_vector(WIDTH-1 downto 0);
   WA : in  integer range 0 to DEPTH-1;
   WE : in  std_logic;
   RA0: in  integer range 0 to DEPTH-1;
   Q0 : out std_logic_vector(WIDTH-1 downto 0));
end component;

component RF1_BW
   generic ( sync : boolean := false;
             lhqd : boolean := false;
             WIDTH : natural range 1 to 16;
             DEPTH : natural range 1 to 32 );
   port (
   clk: in  std_logic;
   rst: in  std_logic;
   D  : in  std_logic_vector(WIDTH-1 downto 0);
   WA : in  integer range 0 to DEPTH-1;
   WE : in  std_logic_vector(1 downto 0);
   RA0: in  integer range 0 to DEPTH-1;
   Q0 : out std_logic_vector(WIDTH-1 downto 0));
end component;

component RF2
   generic ( sync : boolean := false;
             lhqd : boolean := false;
             WIDTH : natural range 1 to 32;
             DEPTH : natural range 1 to 32 );
   port (
   clk: in  std_logic;
   rst: in  std_logic;
   D  : in  std_logic_vector(WIDTH-1 downto 0);
   WA : in  integer range 0 to DEPTH-1;
   WE : in  std_logic;
   RA0: in  integer range 0 to DEPTH-1;
   Q0 : out std_logic_vector(WIDTH-1 downto 0);
   RA1: in  integer range 0 to DEPTH-1;
   Q1 : out std_logic_vector(WIDTH-1 downto 0));
end component;

component RF4
   generic ( sync : boolean := false;
             lhqd : boolean := false;
             WIDTH : natural range 1 to 32;
             DEPTH : natural range 1 to 32 );
   port (
   clk: in  std_logic;
   rst: in  std_logic;
   D  : in  std_logic_vector(WIDTH-1 downto 0);
   WA : in  integer range 0 to DEPTH-1;
   WE : in  std_logic;
   RA0: in  integer range 0 to DEPTH-1;
   Q0 : out std_logic_vector(WIDTH-1 downto 0);
   RA1: in  integer range 0 to DEPTH-1;
   Q1 : out std_logic_vector(WIDTH-1 downto 0);
   RA2: in  integer range 0 to DEPTH-1;
   Q2 : out std_logic_vector(WIDTH-1 downto 0);
   RA3: in  integer range 0 to DEPTH-1;
   Q3 : out std_logic_vector(WIDTH-1 downto 0));
end component;

component bist_RF1
   generic ( sync : boolean := false;
             lhqd : boolean := false;
             WIDTH : natural range 1 to 32;
             DEPTH : natural range 1 to 32 );
   port (
   clk: in  std_logic;
   rst: in  std_logic;
   bi : in  bist_scan_t;
   bo : out bist_scan_t;
   D  : in  std_logic_vector(WIDTH-1 downto 0);
   WA : in  integer range 0 to DEPTH-1;
   WE : in  std_logic;
   RA0: in  integer range 0 to DEPTH-1;
   Q0 : out std_logic_vector(WIDTH-1 downto 0));
end component;

component bist_RF1_BW
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
end component;

component bist_RF2
   generic ( sync : boolean := false;
             lhqd : boolean := false;
             WIDTH : natural range 1 to 32;
             DEPTH : natural range 1 to 32 );
   port (
   clk: in  std_logic;
   rst: in  std_logic;
   bi : in  bist_scan_t;
   bo : out bist_scan_t;
   D  : in  std_logic_vector(WIDTH-1 downto 0);
   WA : in  integer range 0 to DEPTH-1;
   WE : in  std_logic;
   RA0: in  integer range 0 to DEPTH-1;
   Q0 : out std_logic_vector(WIDTH-1 downto 0);
   RA1: in  integer range 0 to DEPTH-1;
   Q1 : out std_logic_vector(WIDTH-1 downto 0));
end component;

component bist_RF4
   generic ( sync : boolean := false;
             lhqd : boolean := false;
             WIDTH : natural range 1 to 32;
             DEPTH : natural range 1 to 32 );
   port (
   clk: in  std_logic;
   rst: in  std_logic;
   bi : in  bist_scan_t;
   bo : out bist_scan_t;
   D  : in  std_logic_vector(WIDTH-1 downto 0);
   WA : in  integer range 0 to DEPTH-1;
   WE : in  std_logic;
   RA0: in  integer range 0 to DEPTH-1;
   Q0 : out std_logic_vector(WIDTH-1 downto 0);
   RA1: in  integer range 0 to DEPTH-1;
   Q1 : out std_logic_vector(WIDTH-1 downto 0);
   RA2: in  integer range 0 to DEPTH-1;
   Q2 : out std_logic_vector(WIDTH-1 downto 0);
   RA3: in  integer range 0 to DEPTH-1;
   Q3 : out std_logic_vector(WIDTH-1 downto 0));
end component;

end package;
