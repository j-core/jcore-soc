library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.cpu2j0_pack.all;

package wrbuf_pack is

constant WRBUF_ADDR_WIDTH_C      : natural := 2;
constant WRBUF_MEM_DEPTH_C       : natural := 2**WRBUF_ADDR_WIDTH_C;

subtype wr_addr_t is std_logic_vector(WRBUF_ADDR_WIDTH_C downto 0);
subtype rd_addr_t is std_logic_vector(WRBUF_ADDR_WIDTH_C downto 0);
type wrbuf_mem_t is array (0 to WRBUF_MEM_DEPTH_C-1) of std_logic_vector(68 downto 0);

type wrbuf_ai_t is record
   en       : std_logic;
   rd       : std_logic;
   wr       : std_logic;
   a        : std_logic_vector(31 downto 0);
   we       : std_logic_vector(3 downto 0);
   d        : std_logic_vector(31 downto 0);
end record;

type wrbuf_ao_t is record
   ack      : std_logic;
   d        : std_logic_vector(31 downto 0);
end record;

type wrbuf_bi_t is record
   ack      : std_logic;
   d        : std_logic_vector(31 downto 0);
end record;

type wrbuf_bo_t is record
   en       : std_logic;
   wr       : std_logic;
   rd       : std_logic;
   a        : std_logic_vector(31 downto 0);
   we       : std_logic_vector(3 downto 0);
   d        : std_logic_vector(31 downto 0);
end record;

type wrbuf_reg_t is record
   empty    : std_logic;
   ack      : std_logic;
   wen      : std_logic;
   waddr    : wr_addr_t;
   raddr    : rd_addr_t;
   yb       : cpu_data_o_t;
   stall    : std_logic;
   wack     : std_logic;
   rack     : std_logic;
   rw       : std_logic;
   d        : std_logic_vector(68 downto 0);
   ya       : cpu_data_i_t;
end record;

constant WRBUF_REG_RESET : wrbuf_reg_t := ( '1', '0', '0', (others => '0'), (others => '0'), ( '0', (others => '0'), '0', '0', (others => '0'), (others => '0') ), '0', '0', '0', '0', (others => '0'), ( (others => '0'), '0' ) );

type wrbuf_ctrl_t is record
   wen      : std_logic;
   wdata    : std_logic_vector(68 downto 0);
   waddr    : integer range 0 to WRBUF_MEM_DEPTH_C-1;
end record;

component wrbuf port (
   clk  : in  std_logic;
   rst  : in  std_logic;
   a    : in  cpu_data_o_t;
   b    : in  cpu_data_i_t;
   ya   : out cpu_data_i_t;
   yb   : out cpu_data_o_t);
end component;

end package;
