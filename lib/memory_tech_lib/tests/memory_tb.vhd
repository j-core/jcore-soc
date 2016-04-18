library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.test_pkg.all;
use work.memory_pack.all;
use work.mem_test_pack.all;

entity memory_tb is
end memory_tb;

architecture tb of memory_tb is
  signal select_mem : mem_type;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  constant ADDR_WIDTH : integer := 32;
  constant DATA_WIDTH : integer := 32;

  signal p0 : mem_port := MEM_PORT_NOP;
  signal p1 : mem_port := MEM_PORT_NOP;

  signal dr0 : data_array_t := (others => (others => '0'));
  signal dr1 : data_array_t := (others => (others => '0'));

  procedure tick(signal clk : inout std_logic) is
  begin
    wait for 10 ns;
    clk <= '1';
    wait for 10 ns;
    clk <= '0';
  end procedure;

  function to_bit(b : boolean) return std_logic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end function;

  for mems : memories use configuration work.memories_inferred;

begin
  mems: memories
    generic map (
      FOR_SYNTHESIS => false)
    port map (
      rst0 => rst,
      clk0 => clk,
      rst1 => rst,
      clk1 => clk,
      select_mem => select_mem,
      p0 => p0,
      p1 => p1,
      dr0 => dr0,
      dr1 => dr1);

  process
  begin
    test_plan(75, "memory_tb");

    -- Memories do synchronous reads and writes at the rising clock edge. Setup
    -- read/write requests at the negative edge and check the results at the
    -- following negative edge.
    tick(clk);
    rst <= '0';
    tick(clk);

    p0 <= MEM_PORT_NOP;
    p1 <= MEM_PORT_NOP;

    -- TODO: How to test ROM? Need to support initializnig it first
    test_comment("RAM_GEN_32x2048_1R");
    select_mem <= ROM_GEN_32x2048_1R;
    tick(clk);

    --for m in one_port_rams'left to one_port_rams'right loop
    --select_mem <= one_port_rams(m);
    --end loop;

    test_comment("RAM_GEN_2x8x256_1RW");
    select_mem <= RAM_GEN_2x8x256_1RW;
    p0 <= writemem(3, x"0000abcd");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read back write to 3");

    p0 <= MEM_PORT_NOP;
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data latched");
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data still latched");

    p0 <= writemem(2047, x"FFFFFFFF");
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data latched during write");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "reread back write to 3");
    p0 <= readmem(2047);
    tick(clk);
    test_equal(dr0(select_mem), x"0000FFFF", "read write end of mem");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "rereread back write to 3");

    p0 <= writemem(3, x"0000FFFF", "01");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abFF", "read after 1 byte write");
    p0 <= writemem(3, x"00000000", "00");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abFF", "read after 0 byte write");
    p0 <= writemem(3, x"00000000", "10");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"000000FF", "read after 1 byte write");
    p0 <= writemem(3, x"0000abcd", "11");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read after 2 byte write");
    p0 <= MEM_PORT_NOP;


    test_comment("RAM_FIXED_2x8x256_1RW");
    select_mem <= RAM_FIXED_2x8x256_1RW;
    p0 <= writemem(3, x"0000abcd");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read back write to 3");

    p0 <= MEM_PORT_NOP;
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data latched");
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data still latched");

    p0 <= writemem(2047, x"FFFFFFFF");
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data latched during write");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "reread back write to 3");
    p0 <= readmem(2047);
    tick(clk);
    test_equal(dr0(select_mem), x"0000FFFF", "read write end of mem");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "rereread back write to 3");

    p0 <= writemem(3, x"0000FFFF", "01");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abFF", "read after 1 byte write");
    p0 <= writemem(3, x"00000000", "00");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abFF", "read after 0 byte write");
    p0 <= writemem(3, x"00000000", "10");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"000000FF", "read after 1 byte write");
    p0 <= writemem(3, x"0000abcd", "11");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read after 2 byte write");
    p0 <= MEM_PORT_NOP;


    test_comment("RAM_GEN_18x2048_1RW");
    select_mem <= RAM_GEN_18x2048_1RW;
    p0 <= writemem(3, x"0000abcd");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read back write to 3");

    p0 <= MEM_PORT_NOP;
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data latched");
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data still latched");

    p0 <= writemem(2047, x"FFFFFFFF");
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data latched during write");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "reread back write to 3");
    p0 <= readmem(2047);
    tick(clk);
    test_equal(dr0(select_mem), x"0003FFFF", "read write end of mem");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "rereread back write to 3");
    p0 <= MEM_PORT_NOP;


    test_comment("RAM_FIXED_18x2048_1RW");
    select_mem <= RAM_FIXED_18x2048_1RW;
    p0 <= writemem(3, x"0000abcd");
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read back write to 3");

    p0 <= MEM_PORT_NOP;
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data latched");
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data still latched");

    p0 <= writemem(2047, x"FFFFFFFF");
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "read data latched during write");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "reread back write to 3");
    p0 <= readmem(2047);
    tick(clk);
    test_equal(dr0(select_mem), x"0003FFFF", "read write end of mem");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "rereread back write to 3");
    p0 <= MEM_PORT_NOP;


    test_comment("RAM_GEN_2x8x2048_2RW");
    select_mem <= RAM_GEN_2x8x2048_2RW;
    p0 <= writemem(3, x"0000abcd");
    p1 <= MEM_PORT_NOP;
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "p0 read back write to 3");
    p0 <= MEM_PORT_NOP;
    p1 <= readmem(3);
    tick(clk);
    test_equal(dr1(select_mem), x"0000abcd", "p1 read back write to 3");
    p0 <= readmem(3);
    p1 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000abcd0000abcd", "p0 & p1 read back write to 3");

    p0 <= MEM_PORT_NOP;
    p1 <= MEM_PORT_NOP;
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000abcd0000abcd", "read data latched");
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000abcd0000abcd", "read data still latched");

    p0 <= writemem(2047, x"FFFFFFFF");
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000abcd0000abcd", "read data latched during write");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "reread back write to 3");
    p0 <= readmem(2047);
    tick(clk);
    test_equal(dr0(select_mem), x"0000FFFF", "read write end of mem");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "rereread back write to 3");


    p0 <= writemem(5, x"00001256");
    p1 <= writemem(6, x"00007834");
    tick(clk);
    p0 <= readmem(6);
    p1 <= readmem(5);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000783400001256", "read after simultaneous writes");

    p0 <= writemem(5, x"0000FFFF", x"00000000");
    p1 <= writemem(6, x"00000000", x"00000000");
    tick(clk);
    p0 <= readmem(6);
    p1 <= readmem(5);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000783400001256", "read after writes with we=0");

    p0 <= writemem(5, x"0000FFFF", x"00000001");
    p1 <= writemem(6, x"00000000", x"00000002");
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000783400001256", "reads latched during partial writes");
    p0 <= readmem(6);
    p1 <= readmem(5);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"00000034000012FF", "read after writes with we=10 and we=01");


    test_comment("RAM_FIXED_2x8x2048_2RW");
    select_mem <= RAM_FIXED_2x8x2048_2RW;
    p0 <= writemem(3, x"0000abcd");
    p1 <= MEM_PORT_NOP;
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "p0 read back write to 3");
    p0 <= MEM_PORT_NOP;
    p1 <= readmem(3);
    tick(clk);
    test_equal(dr1(select_mem), x"0000abcd", "p1 read back write to 3");
    p0 <= readmem(3);
    p1 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000abcd0000abcd", "p0 & p1 read back write to 3");

    p0 <= MEM_PORT_NOP;
    p1 <= MEM_PORT_NOP;
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000abcd0000abcd", "read data latched");
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000abcd0000abcd", "read data still latched");

    p0 <= writemem(2047, x"FFFFFFFF");
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000abcd0000abcd", "read data latched during write");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "reread back write to 3");
    p0 <= readmem(2047);
    tick(clk);
    test_equal(dr0(select_mem), x"0000FFFF", "read write end of mem");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"0000abcd", "rereread back write to 3");


    p0 <= writemem(5, x"00001256");
    p1 <= writemem(6, x"00007834");
    tick(clk);
    p0 <= readmem(6);
    p1 <= readmem(5);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000783400001256", "read after simultaneous writes");

    p0 <= writemem(5, x"0000FFFF", x"00000000");
    p1 <= writemem(6, x"00000000", x"00000000");
    tick(clk);
    p0 <= readmem(6);
    p1 <= readmem(5);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000783400001256", "read after writes with we=0");

    p0 <= writemem(5, x"0000FFFF", x"00000001");
    p1 <= writemem(6, x"00000000", x"00000002");
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"0000783400001256", "reads latched during partial writes");
    p0 <= readmem(6);
    p1 <= readmem(5);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"00000034000012FF", "read after writes with we=10 and we=01");



    test_comment("RAM_GEN_32x1x512_2RW");
    select_mem <= RAM_GEN_32x1x512_2RW;
    p0 <= writemem(3, x"1234abcd");
    p1 <= MEM_PORT_NOP;
    tick(clk);
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"1234abcd", "p0 read back write to 3");
    p0 <= MEM_PORT_NOP;
    p1 <= readmem(3);
    tick(clk);
    test_equal(dr1(select_mem), x"1234abcd", "p1 read back write to 3");
    p0 <= readmem(3);
    p1 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"1234abcd1234abcd", "p0 & p1 read back write to 3");

    p0 <= MEM_PORT_NOP;
    p1 <= MEM_PORT_NOP;
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"1234abcd1234abcd", "read data latched");
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"1234abcd1234abcd", "read data still latched");

    p0 <= writemem(2047, x"FFFFFFFF");
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"1234abcd1234abcd", "read data latched during write");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"1234abcd", "reread back write to 3");
    p0 <= readmem(2047);
    tick(clk);
    test_equal(dr0(select_mem), x"FFFFFFFF", "read write end of mem");
    p0 <= readmem(3);
    tick(clk);
    test_equal(dr0(select_mem), x"1234abcd", "rereread back write to 3");


    p0 <= writemem(5, x"12345678");
    p1 <= writemem(6, x"abcdefcb");
    tick(clk);
    p0 <= readmem(6);
    p1 <= readmem(5);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"abcdefcb12345678", "read after simultaneous writes");

    p0 <= writemem(5, x"0000FFFF", x"00000000");
    p1 <= writemem(6, x"00000000", x"00000000");
    tick(clk);
    p0 <= readmem(6);
    p1 <= readmem(5);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"abcdefcb12345678", "read after writes with we=0");

    p0 <= writemem(5, x"FFFF0000", x"11111111");
    p1 <= writemem(6, x"00000000", x"12345678");
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"abcdefcb12345678", "reads latched during partial writes");
    p0 <= readmem(6);
    p1 <= readmem(5);
    tick(clk);
    test_equal(dr0(select_mem) & dr1(select_mem), x"a9c9a98313354668", "read after writes with mixed we");
    wait;
  end process;
end architecture;
