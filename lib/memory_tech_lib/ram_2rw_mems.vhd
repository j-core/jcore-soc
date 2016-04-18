-- Implement memory by instantiating one or more fixed-size components. These
-- components can either be the real memory macros or VHDL models of them used
-- in simulation.
architecture memories of ram_2rw is
  constant mem_layout : mem_layout_t := memory_layout(1);
  type dr_array_t is array (0 to mem_layout.rows-1) of std_logic_vector(dr0'length - 1 downto 0);
  signal dr0_array : dr_array_t;
  signal dr1_array : dr_array_t;
  signal enables0 : std_logic_vector(mem_layout.rows-1 downto 0);
  signal enables1 : std_logic_vector(mem_layout.rows-1 downto 0);
  signal expanded_we0 : std_logic_vector(we0'length * mem_layout.we_scale - 1 downto 0);
  signal expanded_we1 : std_logic_vector(we0'length * mem_layout.we_scale - 1 downto 0);
  signal selected_row0 : integer := 0;
  signal selected_row1 : integer := 0;
  signal selected_row_read0 : integer := 0;
  signal selected_row_read1 : integer := 0;
begin
  assert mem_layout.t /= INVALID report "Invalid memory dimensions" severity failure;
  assert mem_layout.cols = 1
    report "Do not yet support instantiating multiple columns of memories" severity failure;

  select_row: if a0'left >= mem_layout.bank_addr_width generate
    selected_row0 <= to_integer(unsigned(a0(a0'left downto mem_layout.bank_addr_width)));
    selected_row1 <= to_integer(unsigned(a1(a1'left downto mem_layout.bank_addr_width)));
    process (clk0, en0, wr0)
    begin
      if clk0'event and clk0 = '1' then
        if en0 = '1' and wr0 = '0' then
          -- Keep separate selected row for reading to keep latched read
          -- behaviour. Only update it when a read happens.
          selected_row_read0 <= to_integer(unsigned(a0(a0'left downto mem_layout.bank_addr_width)));
        end if;
      end if;
    end process;
    process (clk1, en1, wr1)
    begin
      if clk1'event and clk1 = '1' then
        if en1 = '1' and wr1 = '0' then
          -- Keep separate selected row for reading to keep latched read
          -- behaviour. Only update it when a read happens.
          selected_row_read1 <= to_integer(unsigned(a1(a1'left downto mem_layout.bank_addr_width)));
        end if;
      end if;
    end process;
  end generate;
  dr0 <= dr0_array(selected_row_read0);
  dr1 <= dr1_array(selected_row_read1);

  expanded_we0 <= expand_bits(we0, mem_layout.we_scale);
  expanded_we1 <= expand_bits(we1, mem_layout.we_scale);

  process (selected_row0, selected_row1, en0, en1)
  begin
    enables0 <= (others => '0');
    enables1 <= (others => '0');
    enables0(selected_row0) <= en0;
    enables1(selected_row1) <= en1;
  end process;

  rows: for row in 0 to mem_layout.rows - 1 generate
    genram_32x1x512: if mem_layout.t = RAM_32x1x512 generate
      mem: ram_32x1x512_2rw
        port map (
          rst0 => rst0,
          clk0 => clk0,
          en0 => enables0(row),
          wr0 => wr0,
          we0 => expanded_we0,
          a0 => a0(8 downto 0),
          dw0 => dw0,
          dr0 => dr0_array(row),
          rst1 => rst1,
          clk1 => clk1,
          en1 => enables1(row),
          wr1 => wr1,
          we1 => expanded_we1,
          a1 => a1(8 downto 0),
          dw1 => dw1,
          dr1 => dr1_array(row),
          margin0 => margin0,
          margin1 => margin1);
    end generate;

    genram_2x8x2048: if mem_layout.t = RAM_2x8x2048 generate
      mem: ram_2x8x2048_2rw
        port map (
          rst0 => rst0,
          clk0 => clk0,
          en0 => enables0(row),
          wr0 => wr0,
          we0 => expanded_we0,
          a0 => a0(10 downto 0),
          dw0 => dw0,
          dr0 => dr0_array(row),
          rst1 => rst1,
          clk1 => clk1,
          en1 => enables1(row),
          wr1 => wr1,
          we1 => expanded_we1,
          a1 => a1(10 downto 0),
          dw1 => dw1,
          dr1 => dr1_array(row),
          margin0 => margin0,
          margin1 => margin1);
    end generate;
  end generate;
end architecture;
