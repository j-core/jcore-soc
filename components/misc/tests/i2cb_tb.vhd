library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cpu2j0_pack.all;
use work.test_pkg.all;

entity i2cb_tb is
end entity;

architecture tb of i2cb_tb is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal db_o : cpu_data_o_t := NULL_DATA_O;
  signal db_i : cpu_data_i_t;

  signal scl : std_logic;
  signal sda : std_logic;

  subtype i2c_buf_t is std_logic_vector(32*5-1 downto 0);

  procedure tick(signal clk : inout std_logic) is
  begin
    wait for 10 ns;
    clk <= '1';
    wait for 10 ns;
    clk <= '0';
  end procedure;

  type i2c_reg is ( CTRL0, CTRL1, CTRL2 );

  function reg_to_addr(reg : i2c_reg) return std_logic_vector is
  begin
    case reg is
      when CTRL0 =>
        return x"00000000";
      when CTRL1 =>
        return x"00000004";
      when others =>
        return x"00000008";
    end case;
  end;

  function read_reg_req(reg : i2c_reg)
    return cpu_data_o_t is
    variable r : cpu_data_o_t := NULL_DATA_O;
  begin
    r.en := '1';
    r.rd := '1';
    r.a := reg_to_addr(reg);
    return r;
  end function;

  function write_reg_req(reg : i2c_reg; value : std_logic_vector(31 downto 0))
    return cpu_data_o_t is
    variable r : cpu_data_o_t := NULL_DATA_O;
  begin
    r.en := '1';
    r.wr := '1';
    r.we := "1111";
    r.a := reg_to_addr(reg);
    r.d := value;
    return r;
  end function;

  function write_ctrl0(i2c_reset : std_logic := '0';
                       reg_start : std_logic := '0';
                       irq_enable : std_logic := '0';
                       reg_dly : std_logic_vector(7 downto 0) := x"00";
                       ack_to : std_logic_vector(3 downto 0) := x"0")
    return cpu_data_o_t is
  begin
    return write_reg_req(CTRL0, x"000" & ack_to & reg_dly & "00" & irq_enable & reg_start & i2c_reset & "000");
  end function;

  function write_ctrl1(xlen : std_logic_vector(4 downto 0))
    return cpu_data_o_t is
  begin
    return write_reg_req(CTRL1, x"000000" & "000" & xlen);
  end function;

  function write_ctrl2(speed_sel : std_logic_vector(1 downto 0) := "00";
                       twi_nclk : std_logic := '0')
    return cpu_data_o_t is
  begin
    return write_reg_req(CTRL2, x"000000" & "0" & twi_nclk & "0000" & speed_sel);
  end function;

  function read_buf_req(constant addr : in integer)
    return cpu_data_o_t is
    variable r : cpu_data_o_t := NULL_DATA_O;
  begin
    r.en := '1';
    r.rd := '1';
    r.a := std_logic_vector(to_unsigned(12 + 4 * addr, 32));
    return r;
  end function;

  function write_buf_req(constant addr : in integer; value : std_logic_vector(31 downto 0))
    return cpu_data_o_t is
    variable r : cpu_data_o_t := NULL_DATA_O;
  begin
    r.en := '1';
    r.wr := '1';
    r.we := "1111";
    r.a := std_logic_vector(to_unsigned(12 + 4 * addr, 32));
    r.d := value;
    return r;
  end function;

  procedure get_txb(signal clk : inout std_logic;
                    signal db_o : out cpu_data_o_t;
                    signal db_i : in cpu_data_i_t;
                    data : out i2c_buf_t) is
  begin
    for i in 0 to 4 loop
      db_o <= read_buf_req(i);
      tick(clk);
      data(32*((4-i)+1) - 1 downto 32*(4-i)) := db_i.d;
    end loop;
    db_o <= NULL_DATA_O;
  end procedure;

  procedure set_txb(signal clk : inout std_logic;
                    signal db_o : out cpu_data_o_t;
                    data : in i2c_buf_t) is
  begin
    for i in 0 to 4 loop
      db_o <= write_buf_req(i, data(32*((4-i)+1) - 1 downto 32*(4-i)));
      tick(clk);
    end loop;
    db_o <= NULL_DATA_O;
  end procedure;

begin
  i2c : entity work.i2c(pc2)
    generic map (
      c_busclk_period => 20)
    port map (
      clk_bus => clk,
      reset => rst,
      db_i => db_o,
      db_o => db_i,
      twi_clk => scl,
      twi_dat => sda,
      irq => open);
  process
    variable buf : i2c_buf_t := (others => '0');
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
    tick(clk);

    -- By setting db_o, and assuming that i2c entity will always ack at the following rising
    -- edge, we can call tick to read or write registers of the i2cb peripheral

    -- zero the 3 ctrl regs
    db_o <= write_reg_req(CTRL0, x"00000000");
    tick(clk);
    db_o <= write_reg_req(CTRL1, x"00000000");
    tick(clk);
    db_o <= write_reg_req(CTRL2, x"00000000");
    tick(clk);
    db_o <= NULL_DATA_O;

    -- example of reading the 3 registers
    --db_o <= read_reg_req(CTRL0);
    --tick(clk);
    --db_o <= read_reg_req(CTRL1);
    --tick(clk);
    --db_o <= read_reg_req(CTRL2);
    --tick(clk);
    --db_o <= NULL_DATA_O;
    --tick(clk);

    -- Do the writes necessary to set all of the bytes in the i2cb tx buffer
    buf(159 downto 152) := "01010101";
    set_txb(clk, db_o, buf);

    -- Try to set up a I2C transaction
    db_o <= write_ctrl0(i2c_reset => '1');
    tick(clk);
    db_o <= write_ctrl0(i2c_reset => '0');
    tick(clk);

    db_o <= write_ctrl2(speed_sel => "11");
    tick(clk);

    db_o <= write_ctrl1(xlen => "00100");
    tick(clk);
    db_o <= write_ctrl0(reg_start => '1',
                        ack_to => "1111",
                        reg_dly => x"01");
    tick(clk);
    db_o <= NULL_DATA_O;
    tick(clk);

    -- wait for a long time to see something happen
    for i in 0 to 400 loop
      tick(clk);
    end loop;
    wait;
  end process;
end architecture;

