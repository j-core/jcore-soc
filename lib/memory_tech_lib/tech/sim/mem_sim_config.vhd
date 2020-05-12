configuration rom_1r_sim of rom_1r is
  for memories
    for rows
      for genrom_32x2048
        for all : rom_32x2048_1r
          use entity work.rom_32x2048_1r(sim);
        end for;
      end for;
    end for;
  end for;
end configuration;

configuration ram_1rw_sim of ram_1rw is
  for memories
    for rows
      for genram_18x2048
        for all : ram_18x2048_1rw
          use entity work.ram_18x2048_1rw(sim);
        end for;
      end for;
      for genram_2x8x256
        for all : ram_2x8x256_1rw
          use entity work.ram_2x8x256_1rw(sim);
        end for;
      end for;
    end for;
  end for;
end configuration;

configuration ram_2rw_sim of ram_2rw is
  for memories
    for rows
      for genram_32x1x512
        for all : ram_32x1x512_2rw
          use entity work.ram_32x1x512_2rw(sim);
        end for;
      end for;
      for genram_2x8x2048
        for all : ram_2x8x2048_2rw
          use entity work.ram_2x8x2048_2rw(sim);
        end for;
      end for;
    end for;
  end for;
end configuration;
