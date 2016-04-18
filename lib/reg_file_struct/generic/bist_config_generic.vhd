configuration bist_rf1_inferred of bist_RF1 is
  for bist
    for rf : RF1
      use entity work.RF1(inferred);
    end for;
  end for;
end configuration;

configuration bist_rf1_bw_inferred of bist_RF1_BW is
  for bist
    for rf : RF1_BW
      use entity work.RF1_BW(inferred);
    end for;
  end for;
end configuration;

configuration bist_rf2_inferred of bist_RF2 is
  for bist
    for rf : RF2
      use entity work.RF2(inferred);
    end for;
  end for;
end configuration;

configuration bist_rf4_inferred of bist_RF4 is
  for bist
    for rf : RF4
      use entity work.RF4(inferred);
    end for;
  end for;
end configuration;
