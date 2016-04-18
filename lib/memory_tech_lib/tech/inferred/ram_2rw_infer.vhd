-- Directly implement memory usig VHDL array. Used either in simulation or
-- relies on xst to infer block RAM.
architecture inferred of ram_2rw is
  type mem_t is array (integer range 0 to 2**ADDR_WIDTH - 1)
    of std_logic_vector(dw0'length - 1 downto 0);
  shared variable mem : mem_t;
  signal wr_we0 : std_logic_vector(SUBWORD_NUM - 1 downto 0);
  signal wr_we1 : std_logic_vector(SUBWORD_NUM - 1 downto 0);
begin
  one_subword : if SUBWORD_NUM = 1 generate
    process(clk0)
    begin
      if clk0'event and clk0 = '1' then
        if en0 = '1' then
          if wr0 = '1' then
            -- synchronous write
            mem(to_integer(unsigned(a0))) := dw0;
          else
            -- synchronous latched read
            dr0 <= mem(to_integer(unsigned(a0)));
          end if;
        end if;
      end if;
    end process;

    process(clk1)
    begin
      if clk1'event and clk1 = '1' then
        if en1 = '1' then
          if wr1 = '1' then
            -- synchronous write
            mem(to_integer(unsigned(a1))) := dw1;
          else
            -- synchronous latched read
            dr1 <= mem(to_integer(unsigned(a1)));
          end if;
        end if;
      end if;
    end process;
  end generate;
  subwords : if SUBWORD_NUM /= 1 generate
    -- combine wr and we signals so that xst will infer a block RAM
    wr_we0 <= mask_bits(wr0, we0);
    wr_we1 <= mask_bits(wr1, we1);

    process(clk0)
    begin
      if clk0'event and clk0 = '1' then
        if en0 = '1' then
          if wr_we0 = (wr_we0'range => '0') then
            -- synchronous latched read
            dr0 <= mem(to_integer(unsigned(a0)));
          end if;
          -- synchronous write
          for i in integer range 0 to SUBWORD_NUM-1 loop
            if wr_we0(i) = '1' then
              mem(to_integer(unsigned(a0)))((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH)
                := dw0((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH);
            end if;
          end loop;
        end if;
      end if;
    end process;

    process(clk1)
    begin
      if clk1'event and clk1 = '1' then
        if en1 = '1' then
          if wr_we1 = (wr_we1'range => '0') then
            -- synchronous latched read
            dr1 <= mem(to_integer(unsigned(a1)));
          end if;
          -- synchronous write
          for i in integer range 0 to SUBWORD_NUM-1 loop
            if wr_we1(i) = '1' then
              mem(to_integer(unsigned(a1)))((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH)
                := dw1((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH);
            end if;
          end loop;
        end if;
      end if;
    end process;
  end generate;
end architecture;
