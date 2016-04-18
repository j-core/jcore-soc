library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.cpu2j0_pack.all;
use work.test_pkg.all;

entity spi_tb is
end entity;

architecture tb of spi_tb is
  constant CLOCK_HALF_PERIOD : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal db_o : cpu_data_o_t := NULL_DATA_O;
  signal db_i : cpu_data_i_t;

  constant NUM_CS : integer := 2;

  signal spi_clk : std_logic;
  signal cs : std_logic_vector(NUM_CS - 1 downto 0);
  signal mosi : std_logic;
  signal miso : std_logic := '0';

  procedure tick(signal clk : inout std_logic) is
  begin
    wait for CLOCK_HALF_PERIOD;
    clk <= '1';
    wait for CLOCK_HALF_PERIOD;
    clk <= '0';
  end procedure;

  type spi_reg is ( CTRL, DATA );

  function reg_to_addr(reg : spi_reg) return std_logic_vector is
  begin
    case reg is
      when CTRL =>
        return x"00000000";
      when DATA =>
        return x"00000004";
    end case;
  end;

  function read_reg_req(reg : spi_reg)
    return cpu_data_o_t is
    variable r : cpu_data_o_t := NULL_DATA_O;
  begin
    r.en := '1';
    r.rd := '1';
    r.a := reg_to_addr(reg);
    return r;
  end function;

  function write_reg_req(reg : spi_reg; value : std_logic_vector)
    return cpu_data_o_t is
    alias v : std_logic_vector(value'length-1 downto 0) is value;
    variable r : cpu_data_o_t := NULL_DATA_O;
  begin
    r.en := '1';
    r.wr := '1';
    r.we := "1111";
    r.a := reg_to_addr(reg);
    r.d := x"00000000";
    r.d(v'range) := v;
    return r;
  end function;

begin
  spi : entity work.spi2
    generic map (
      NUM_CS => NUM_CS,
      CLK_FREQ => real(1.0e9 ns / CLOCK_HALF_PERIOD) / 2.0,
      CPOL => '0',
      CPHA => '0')
    port map (
      clk => clk,
      rst => rst,
      db_i => db_o,
      db_o => db_i,
      spi_clk => spi_clk,
      cs => cs,
      miso => miso,
      mosi => mosi);
  process
  begin
    rst <= '1';
    tick(clk);
    tick(clk);
    rst <= '0';

    -- each call to tick moves the clock forward one cycle, stopping at the
    -- negative cycle
    tick(clk);
    tick(clk);
    tick(clk);

    -- By setting db_o, and assuming that spi entity will always ack at the following rising
    -- edge, we can call tick to read or write registers of the spi peripheral

    db_o <= write_reg_req(DATA, x"6A"); -- data to send
    tick(clk);
    tick(clk);
    --db_o <= write_reg_req(CTRL, x"F800000A"); -- begin transaction. slow speed with loopback
    db_o <= write_reg_req(CTRL, x"0A"); -- begin transaction. fast speed with loopback
    tick(clk);
    tick(clk);
    db_o <= NULL_DATA_O;

    tick(clk);
    tick(clk);
    tick(clk);
    tick(clk);
    tick(clk);
    tick(clk);
    db_o <= read_reg_req(CTRL); -- check that busy bit is set during transaction
    tick(clk);
    tick(clk);

    db_o <= read_reg_req(CTRL);
    tick(clk);
    tick(clk);
    db_o <= NULL_DATA_O;

    -- wait for a full transaction at 400kHz
    for i in 0 to integer(1.0e9 ns / 400.0e3 / (2 * CLOCK_HALF_PERIOD) * 10) loop
      tick(clk);
    end loop;

    db_o <= read_reg_req(CTRL); -- check that not busy anymore
    tick(clk);
    tick(clk);
    db_o <= read_reg_req(DATA); -- check received value. Should match sent
                                -- value due to loopback
    tick(clk);
    tick(clk);
    db_o <= NULL_DATA_O;
    tick(clk);
    tick(clk);
    wait;
  end process;
end architecture;

