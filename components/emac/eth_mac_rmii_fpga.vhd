configuration eth_mac_rmii_fpga of eth_mac_rmii is
  for rtl
    for all : global_buffer
      use entity work.global_buffer(fpga);
    end for;
  end for;
end configuration;
