library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.test_pkg.all;
use work.memory_pack.all;
use work.mem_test_pack.all;

entity simple_test is
end simple_test;

architecture tb of simple_test is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal p0 : mem_port := MEM_PORT_NOP;
  signal p1 : mem_port := MEM_PORT_NOP;

  signal dr0 : std_logic_vector(15 downto 0);
  signal dr1 : std_logic_vector(15 downto 0);

  procedure tick(signal clk : inout std_logic) is
  begin
    wait for 10 ns;
    clk <= '1';
    wait for 10 ns;
    clk <= '0';
  end procedure;

begin

  u_ram_2x8x2048_2rw: entity work.ram_2x8x2048_2rw(sim)
    port map (
      rst0 => rst,
      clk0 => clk,
      en0 => p0.en,
      wr0 => p0.wr,
      we0 => p0.we(1 downto 0),
      a0 => p0.a(10 downto 0),
      dw0 => p0.dw(15 downto 0),
      dr0 => dr0,
      rst1 => rst,
      clk1 => clk,
      en1 => p1.en,
      wr1 => p1.wr,
      we1 => p1.we(1 downto 0),
      a1 => p1.a(10 downto 0),
      dw1 => p1.dw(15 downto 0),
      dr1 => dr1,
      margin0 => '0',
      margin1 => '0');

  process
  begin
    test_plan(6, "simple_test");

    test_equal(expand_bits("10", 1), "10", "expand 10 by 1");
    test_equal(expand_bits("10", 2), "1100", "expand 10 by 2");
    test_equal(expand_bits("10", 3), "111000", "expand 10 by 3");
    test_equal(expand_bits("10110", 4), "11110000111111110000", "expand 10110 by 4");

    -- Memories do synchronous reads and writes at the rising clock edge. Setup
    -- read/write requests at the negative edge and check the results at the
    -- following negative edge.
    tick(clk);
    rst <= '0';
    tick(clk);

    p0 <= MEM_PORT_NOP;
    p1 <= MEM_PORT_NOP;
    tick(clk);

    p0 <= writemem(0, x"0000aaaa");
    tick(clk);
    p0 <= writemem(1, x"0000bbbb");
    tick(clk);
    p0 <= writemem(2, x"0000cccc");
    tick(clk);
    p0 <= writemem(3, x"0000dddd");
    tick(clk);
    p0 <= writemem(4, x"0000eeee");
    tick(clk);
    p0 <= writemem(5, x"0000ffff");
    tick(clk);

    p0 <= MEM_PORT_NOP;
    p1 <= MEM_PORT_NOP;
    tick(clk);
    p0 <= readmem(2);
    p1 <= readmem(4);
    tick(clk);
    test_equal(dr0, x"cccc", "p0 read");
    test_equal(dr1, x"eeee", "p1 read");

    p0 <= MEM_PORT_NOP;
    p1 <= MEM_PORT_NOP;
    tick(clk);
    wait;
  end process;
end architecture;
