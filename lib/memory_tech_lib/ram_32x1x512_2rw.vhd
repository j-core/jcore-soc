-- RAM with 1 read/write port, sync reads and writes, 32 bits wide with 32
-- 1-bit write select inputs, and 512 entries deep.
library ieee;
use ieee.std_logic_1164.all;
entity ram_32x1x512_2rw is
  port (
    rst0 : in  std_logic;
    clk0 : in  std_logic;
    en0  : in  std_logic;
    wr0  : in  std_logic;
    we0  : in  std_logic_vector(31 downto 0);
    a0   : in  std_logic_vector( 8 downto 0);
    dw0  : in  std_logic_vector(31 downto 0);
    dr0  : out std_logic_vector(31 downto 0);
    rst1 : in  std_logic;
    clk1 : in  std_logic;
    en1  : in  std_logic;
    wr1  : in  std_logic;
    we1  : in  std_logic_vector(31 downto 0);
    a1   : in  std_logic_vector( 8 downto 0);
    dw1  : in  std_logic_vector(31 downto 0);
    dr1  : out std_logic_vector(31 downto 0);
    margin0 : in std_logic;
    margin1 : in std_logic);
end entity;
