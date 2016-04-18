library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

use work.bist_pack.all;
use work.rf_pack.all;

package bist_tb_pack is
  constant RF_MAX_NUM_PORT : natural := 4;

  -- An array of read port numbers. Used to specify the read port for each of
  -- the RF's in a chain on BIST collars. The value with the lowest numeric
  -- index is used by the first RF in the BIST chain.
  type port_numbers is array (integer range <>)
    of natural range 0 to RF_MAX_NUM_PORT-1;

  procedure bist_data(
    signal clk : in std_logic;
    signal bi : out bist_scan_t;
    signal bo : in bist_scan_t;
    input : in std_logic_vector;
    output : out std_logic_vector;
    num_rf : in natural := 1);

  procedure bist_ctrl(
    signal clk : in std_logic;
    signal bi : out bist_scan_t;
    we : in std_logic;
    read_addr : in natural;
    read_ports : in port_numbers);

  -- perform a single step of the march c algorithm for 1 read port and 1
  -- background value. Sets the output arg result to false if an error is
  -- detected or true if no errors
  procedure bist_march_c_step(
    signal clk : in std_logic;
    signal bi : out bist_scan_t;
    signal bo : in bist_scan_t;
    bkgnd : in std_logic_vector;
    result : out boolean;
    read_ports : in port_numbers;
    constant DEPTH : in integer);

  -- runs the march c algorithm. Uses hard-coded 16-bit wide background values
  procedure bist_march_c16(
    signal clk : in std_logic;
    signal bi : out bist_scan_t;
    signal bo : in bist_scan_t;
    result : out boolean;
    read_ports : in port_numbers;
    constant DEPTH : in integer);

  -- returns true if the given data before is equal to a integer number of
  -- copies of the part vector concatenated together
  function is_repeated(
    data : std_logic_vector;
    part : std_logic_vector)
    return boolean;
end package;

package body bist_tb_pack is

  procedure bist_data(
    signal clk : in std_logic;
    signal bi : out bist_scan_t;
    signal bo : in bist_scan_t;
    input : in std_logic_vector;
    output : out std_logic_vector;
    num_rf : in natural := 1)
  is
    variable inputv : std_logic_vector(input'length - 1 downto 0) := input;
    variable outputv : std_logic_vector(output'length - 1 downto 0) := (others => '0');
    variable index : integer;
  begin
    assert input'length * num_rf = output'length
      report "output must be input'length times num RF in length"
      severity failure;

    bi.bist <= '1';
    bi.en <= '1';
    bi.ctrl <= '0';
    bi.cmd <= to_slv(SHIFT_DATA);

    index := 0;
    for i in 1 to num_rf loop -- each RF needs it's own copy of input shifted in
      -- shift an extra data bit in for each RF before shifting in the actual
      -- data. This bit will end up in the bq flip-flop that is in the bist
      -- collar after the RF.
      bi.d <= '0';
      wait until clk'event and clk = '1';

      for j in inputv'right to inputv'left loop
        bi.d <= inputv(j);

        -- small delay seems needed here to get the correct bo.d value
        wait for 1 ns;
        outputv(index) := bo.d;
        index := index + 1;

        wait until clk'event and clk = '1';
      end loop;
    end loop;
    bi.cmd <= to_slv(NOP);
    output := outputv;
  end procedure;

  procedure bist_ctrl(
    signal clk : in std_logic;
    signal bi : out bist_scan_t;
    we : in std_logic;
    read_addr : in natural;
    read_ports : in port_numbers)
  is
    variable ctrl : std_logic_vector(7 downto 0);
    alias read_portsv : port_numbers(read_ports'length - 1 downto 0) is read_ports;
  begin
    ctrl(7) := we;
    ctrl(4 downto 0) := std_logic_vector(to_unsigned(read_addr, 5));

    bi.bist <= '1';
    bi.en <= '1';
    bi.d <= '0';
    bi.cmd <= to_slv(SHIFT_CTRL);

    for i in read_portsv'right to read_portsv'left loop
      -- shift the ctrl word in with a different port number for RF bist collar
      ctrl(6 downto 5) := std_logic_vector(to_unsigned(read_portsv(i), 2));
      for j in ctrl'right to ctrl'left loop
        bi.ctrl <= ctrl(j);
        wait until clk'event and clk = '1';
      end loop;
    end loop;
    bi.cmd <= to_slv(NOP);
  end procedure;

  -- check that a data vector contains a smaller part vector repeated an
  -- integer number of times
  function is_repeated(
    data : std_logic_vector;
    part : std_logic_vector)
  return boolean is
    alias datav : std_logic_vector(data'length-1 downto 0) is data;
    alias partv : std_logic_vector(part'length-1 downto 0) is part;
    variable num_parts : natural;
  begin
    num_parts := natural(floor(real(data'length) / real(part'length)));
    if num_parts * part'length /= data'length then
      assert false
        report "is_repeated inputs have mismatching lengths"
        severity warning;
      return false;
    end if;

    for i in 0 to num_parts-1 loop
      if datav((i+1) * part'length - 1 downto i * part'length) /= partv then
        return false;
      end if;
    end loop;
    return true;
  end function;

  procedure bist_march_c_step(
    signal clk : in std_logic;
    signal bi : out bist_scan_t;
    signal bo : in bist_scan_t;
    bkgnd : in std_logic_vector;
    result : out boolean;
    read_ports : in port_numbers;
    constant DEPTH : in integer)
  is
    variable num_rf : natural := read_ports'length;
    variable output : std_logic_vector((bkgnd'length * num_rf) - 1 downto 0);
    variable bkgnd_i : std_logic_vector(bkgnd'length-1 downto 0);
  begin
    bkgnd_i := not bkgnd;
    result := true;

    -- /\(w0)
    for i in 0 to DEPTH-1 loop
      bist_ctrl(clk, bi, '1', i, read_ports);
      bist_data(clk, bi, bo, bkgnd, output, num_rf);
    end loop;

    -- /\(r0 w1 r1)
    for i in 0 to DEPTH-1 loop
      bist_ctrl(clk, bi, '1', i, read_ports);
      bist_data(clk, bi, bo, bkgnd_i, output, num_rf);
      if not is_repeated(output, bkgnd) then
        assert false report "read 1 mismatch" severity warning;
        result := false;
      end if;
      bist_data(clk, bi, bo, bkgnd_i, output, num_rf);
      if not is_repeated(output, bkgnd_i) then
        assert false report "read 2 mismatch" severity warning;
        result := false;
      end if;
    end loop;

    -- /\(r1 w0)
    for i in 0 to DEPTH-1 loop
      bist_ctrl(clk, bi, '1', i, read_ports);
      bist_data(clk, bi, bo, bkgnd, output, num_rf);
      if not is_repeated(output, bkgnd_i) then
        assert false report "read 3 mismatch" severity warning;
        result := false;
      end if;
    end loop;

    -- \/(r0 w1)
    for i in DEPTH-1 downto 0 loop
      bist_ctrl(clk, bi, '1', i, read_ports);
      bist_data(clk, bi, bo, bkgnd_i, output, num_rf);
      if not is_repeated(output, bkgnd) then
        assert false report "read 4 mismatch" severity warning;
        result := false;
      end if;
    end loop;

    -- \/(r1 w0)
    for i in DEPTH-1 downto 0 loop
      bist_ctrl(clk, bi, '1', i, read_ports);
      bist_data(clk, bi, bo, bkgnd, output, num_rf);
      if not is_repeated(output, bkgnd_i) then
        assert false report "read 5 mismatch" severity warning;
        result := false;
      end if;
    end loop;

    -- /\(r0)
    for i in 0 to DEPTH-1 loop
      bist_ctrl(clk, bi, '1', i, read_ports);
      bist_data(clk, bi, bo, bkgnd, output, num_rf);
      if not is_repeated(output, bkgnd) then
        assert false report "read 6 mismatch" severity warning;
        result := false;
      end if;
    end loop;
  end procedure;

  procedure bist_march_c16(
    signal clk : in std_logic;
    signal bi : out bist_scan_t;
    signal bo : in bist_scan_t;
    result : out boolean;
    read_ports : in port_numbers;
    constant DEPTH : in integer) is

    variable r : boolean;
    variable temp : boolean;
  begin
    r := true;
    bist_march_c_step(clk, bi, bo, x"0000", temp, read_ports, DEPTH);
    r := r and temp;
    bist_march_c_step(clk, bi, bo, x"00FF", temp, read_ports, DEPTH);
    r := r and temp;
    bist_march_c_step(clk, bi, bo, x"0F0F", temp, read_ports, DEPTH);
    r := r and temp;
    bist_march_c_step(clk, bi, bo, x"3333", temp, read_ports, DEPTH);
    r := r and temp;
    bist_march_c_step(clk, bi, bo, x"3355", temp, read_ports, DEPTH);
    r := r and temp;
    result := r;
  end procedure;
end package body;
