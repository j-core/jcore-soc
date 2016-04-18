library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.memory_pack.all;
use work.mem_test_pack.all;

entity memories is
  generic (
    FOR_SYNTHESIS : boolean := true);
  port (
    rst0 : in std_logic;
    clk0 : in std_logic;
    rst1 : in std_logic;
    clk1 : in std_logic;
    select_mem : in mem_type;
    p0 : in mem_port;
    p1 : in mem_port;
    dr0 : out data_array_t;
    dr1 : out data_array_t);
end entity;

architecture arch of memories is
  signal en0 : enables_t := (others => '0');
  signal en1 : enables_t := (others => '0');

  function build_enables(mem : mem_type; en : std_logic)
  return enables_t is
    variable r : enables_t := (others => '0');
  begin
    r(mem) := en;
    return r;
  end function;

  signal datar0 : data_array_t := (others => (others => '0'));
  signal datar1 : data_array_t := (others => (others => '0'));

begin
  dr0 <= datar0;
  dr1 <= datar1;
  
  -- set enables for each memory
  en0 <= build_enables(select_mem, p0.en);
  en1 <= build_enables(select_mem, p1.en);

  u_rom_gen_32x2048_1r: rom_1r
    generic map (
      DATA_WIDTH => 32,
      ADDR_WIDTH => 11)
    port map (
      clk => clk0,
      en => en0(ROM_GEN_32x2048_1R),
      a => p0.a(10 downto 0),
      d => datar0(ROM_GEN_32x2048_1R)(31 downto 0),
      margin => '0');

  u_rom_32x2048_r1: entity work.rom_32x2048_1r(sim)
    port map (
      clk => clk0,
      en => en0(ROM_FIXED_32x2048_1R),
      a => p0.a(10 downto 0),
      d => datar0(ROM_FIXED_32x2048_1R)(31 downto 0),
      margin => '0');

  u_ram_gen_2x8x256_1rw: ram_1rw
    generic map (
      SUBWORD_WIDTH => 8,
      SUBWORD_NUM => 2,
      ADDR_WIDTH => 8)
    port map (
      rst => rst0,
      clk => clk0,
      en => en0(RAM_GEN_2x8x256_1RW),
      wr => p0.wr,
      we => p0.we(1 downto 0),
      a => p0.a(7 downto 0),
      dw => p0.dw(15 downto 0),
      dr => datar0(RAM_GEN_2x8x256_1RW)(15 downto 0),
      margin => "00");

  u_ram: entity work.ram_2x8x256_1rw(sim)
    port map (
      rst => rst0,
      clk => clk0,
      en => en0(RAM_FIXED_2x8x256_1RW),
      wr => p0.wr,
      we => p0.we(1 downto 0),
      a => p0.a(7 downto 0),
      dw => p0.dw(15 downto 0),
      dr => datar0(RAM_FIXED_2x8x256_1RW)(15 downto 0),
      margin => "00");

  u_ram_gen_18x2048_1rw: ram_1rw
    generic map (
      SUBWORD_WIDTH => 18,
      SUBWORD_NUM => 1,
      ADDR_WIDTH => 11)
    port map (
      rst => rst0,
      clk => clk0,
      en => en0(RAM_GEN_18x2048_1RW),
      wr => p0.wr,
      we => p0.we(0 downto 0),
      a => p0.a(10 downto 0),
      dw => p0.dw(17 downto 0),
      dr => datar0(RAM_GEN_18x2048_1RW)(17 downto 0),
      margin => "00");

  u_ram_18x2048_1rw: entity work.ram_18x2048_1rw(sim)
    port map (
      rst => rst0,
      clk => clk0,
      en => en0(RAM_FIXED_18x2048_1RW),
      wr => p0.wr,
      a => p0.a(10 downto 0),
      dw => p0.dw(17 downto 0),
      dr => datar0(RAM_FIXED_18x2048_1RW)(17 downto 0),
      margin => "00");

  u_ram_gen_2x8x1024_1rw: ram_1rw
    generic map (
      SUBWORD_WIDTH => 8,
      SUBWORD_NUM => 2,
      ADDR_WIDTH => 10)
    port map (
      rst => rst0,
      clk => clk0,
      en => en0(RAM_GEN_2x8x1024_1RW),
      wr => p0.wr,
      we => p0.we(1 downto 0),
      a => p0.a(9 downto 0),
      dw => p0.dw(15 downto 0),
      dr => datar0(RAM_GEN_2x8x1024_1RW)(15 downto 0),
      margin => "00");

  u_ram_gen_2x8x2048_2rw: ram_2rw
    generic map (
      SUBWORD_WIDTH => 8,
      SUBWORD_NUM => 2,
      ADDR_WIDTH => 11)
    port map (
      rst0 => rst0,
      clk0 => clk0,
      en0 => en0(RAM_GEN_2x8x2048_2RW),
      wr0 => p0.wr,
      we0 => p0.we(1 downto 0),
      a0 => p0.a(10 downto 0),
      dw0 => p0.dw(15 downto 0),
      dr0 => datar0(RAM_GEN_2x8x2048_2RW)(15 downto 0),
      rst1 => rst1,
      clk1 => clk1,
      en1 => en1(RAM_GEN_2x8x2048_2RW),
      wr1 => p1.wr,
      we1 => p1.we(1 downto 0),
      a1 => p1.a(10 downto 0),
      dw1 => p1.dw(15 downto 0),
      dr1 => datar1(RAM_GEN_2x8x2048_2RW)(15 downto 0),
      margin0 => '0',
      margin1 => '0');

  u_ram_2x8x2048_2rw: entity work.ram_2x8x2048_2rw(sim)
    port map (
      rst0 => rst0,
      clk0 => clk0,
      en0 => en0(RAM_FIXED_2x8x2048_2RW),
      wr0 => p0.wr,
      we0 => p0.we(1 downto 0),
      a0 => p0.a(10 downto 0),
      dw0 => p0.dw(15 downto 0),
      dr0 => datar0(RAM_FIXED_2x8x2048_2RW)(15 downto 0),
      rst1 => rst1,
      clk1 => clk1,
      en1 => en1(RAM_FIXED_2x8x2048_2RW),
      wr1 => p1.wr,
      we1 => p1.we(1 downto 0),
      a1 => p1.a(10 downto 0),
      dw1 => p1.dw(15 downto 0),
      dr1 => datar1(RAM_FIXED_2x8x2048_2RW)(15 downto 0),
      margin0 => '0',
      margin1 => '0');

  notsynth: if not FOR_SYNTHESIS generate
    u_ram_gen_32x1x512_2rw: ram_2rw
      generic map (
        SUBWORD_WIDTH => 1,
        SUBWORD_NUM => 32,
        ADDR_WIDTH => 9)
      port map (
        rst0 => rst0,
        clk0 => clk0,
        en0 => en0(RAM_GEN_32x1x512_2RW),
        wr0 => p0.wr,
        we0 => p0.we(31 downto 0),
        a0 => p0.a(8 downto 0),
        dw0 => p0.dw(31 downto 0),
        dr0 => datar0(RAM_GEN_32x1x512_2RW)(31 downto 0),
        rst1 => rst1,
        clk1 => clk1,
        en1 => en1(RAM_GEN_32x1x512_2RW),
        wr1 => p1.wr,
        we1 => p1.we(31 downto 0),
        a1 => p1.a(8 downto 0),
        dw1 => p1.dw(31 downto 0),
        dr1 => datar1(RAM_GEN_32x1x512_2RW)(31 downto 0),
        margin0 => '0',
        margin1 => '0');

    u_ram_32x1x512_2rw: entity work.ram_32x1x512_2rw(sim)
      port map (
        rst0 => rst0,
        clk0 => clk0,
        en0 => en0(RAM_FIXED_32x1x512_2RW),
        wr0 => p0.wr,
        we0 => p0.we(31 downto 0),
        a0 => p0.a(8 downto 0),
        dw0 => p0.dw(31 downto 0),
        dr0 => datar0(RAM_FIXED_32x1x512_2RW)(31 downto 0),
        rst1 => rst1,
        clk1 => clk1,
        en1 => en1(RAM_FIXED_32x1x512_2RW),
        wr1 => p1.wr,
        we1 => p1.we(31 downto 0),
        a1 => p1.a(8 downto 0),
        dw1 => p1.dw(31 downto 0),
        dr1 => datar1(RAM_FIXED_32x1x512_2RW)(31 downto 0),
        margin0 => '0',
        margin1 => '0');
  end generate;
end architecture;

configuration memories_mems of memories is
  for arch
    for all : rom_1r
      use configuration work.rom_1r_sim;
    end for;
    for all : ram_1rw
      use configuration work.ram_1rw_sim;
    end for;
    for all : ram_2rw
      use configuration work.ram_2rw_sim;
    end for;
    for notsynth
      for all : ram_2rw
        use configuration work.ram_2rw_sim;
      end for;
    end for;
  end for;
end configuration;

configuration memories_inferred of memories is
  for arch
    for all : rom_1r
      use entity work.rom_1r(inferred);
    end for;
    for all : ram_1rw
      use entity work.ram_1rw(inferred);
    end for;
    for all : ram_2rw
      use entity work.ram_2rw(inferred);
    end for;
    for notsynth
      for all : ram_2rw
        use entity work.ram_2rw(inferred);
      end for;
    end for;
  end for;
end configuration;
