library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.cpu2j0_pack.all;
use work.config.all;

package ddr_pack is

type sd_data_i_t is record
         dq_latp    : std_logic_vector(15 downto 0);
         dq_latn    : std_logic_vector(15 downto 0);
         dm_latp    : std_logic_vector(1 downto 0);
         dm_latn    : std_logic_vector(1 downto 0);
         dq_lat_en  : std_logic;
         dqs_lat_en : std_logic;
         rd_lat_en  : std_logic;
end record;

type sd_data_o_t is record
         dqo_lat    : std_logic_vector(31 downto 0);
end record;

type dr_data_i_t is record
         dqi        : std_logic_vector(15 downto 0);
         dqsi       : std_logic_vector(1 downto 0);
end record;

type dr_data_o_t is record
         dqo        : std_logic_vector(15 downto 0);
         dmo        : std_logic_vector(1 downto 0);
         dqso       : std_logic_vector(1 downto 0);
         dq_outen   : std_logic_vector(17 downto 0);
         dqs_outen  : std_logic_vector(1 downto 0);
end record;

type sd_ctrl_t is record
         cs      : std_logic;
         cke     : std_logic;
         ba      : std_logic_vector(1 downto 0);
         a       : std_logic_vector((CFG_SA_WIDTH-1) downto 0);
         ras     : std_logic;
         cas     : std_logic;
         we      : std_logic;
end record;

component ddr_ctrl is
     generic (c_data_width : integer := 16; c_sa_width : integer := 13;
              c_dll_enable : integer range 0 to 2 := 0; c_period_clkbus : integer);
     port (
         ddr_clk0      : in std_logic;
         ddr_clk90     : in std_logic;
         clk_2x        : in std_logic;
         reset_in      : in std_logic;
         db_i          : in cpu_data_o_t;
         db_o          : out cpu_data_i_t;
         dbo_ack_r     : out std_logic;
         sd_data_o     : out sd_data_i_t;
         sd_data_i     : in  sd_data_o_t;
         sd_ctrl       : out sd_ctrl_t);
end component;

component ddr_iocells
    port(ddr_clk0   : in std_logic;
         ddr_clk90  : in std_logic;
         reset      : in std_logic;
         dr_data_i  : in  dr_data_i_t;
         dr_data_o  : out dr_data_o_t;
         sd_data_i  : in  sd_data_i_t;
         sd_data_o  : out sd_data_o_t;
         ckpo       : out std_logic);
end component;

component ddr_iocells_k7
    port(ddr_clk0   : in std_logic;
         ddr_clk90  : in std_logic;
         reset      : in std_logic;
         dr_data_i  : in  dr_data_i_t;
         dr_data_o  : out dr_data_o_t;
         sd_data_i  : in  sd_data_i_t;
         sd_data_o  : out sd_data_o_t;
         ckpo       : out std_logic);
end component;

end package;

