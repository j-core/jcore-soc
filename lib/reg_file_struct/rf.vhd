library ieee;
use ieee.std_logic_1164.all;

use work.rf_pack.all;

entity RF1 is
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
end RF1;

library ieee;
use ieee.std_logic_1164.all;

use work.rf_pack.all;

entity RF1_BW is
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
end RF1_BW;

library ieee;
use ieee.std_logic_1164.all;

use work.rf_pack.all;

entity RF2 is
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
end RF2;

library ieee;
use ieee.std_logic_1164.all;

use work.rf_pack.all;

entity RF4 is
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
end RF4;
