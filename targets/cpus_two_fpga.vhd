use work.memory_pack.all;

architecture two_cpus_fpga of cpus is
  signal cpu0_instr_bus_o : instr_bus_o_t;
  signal cpu0_instr_bus_i : instr_bus_i_t;

  signal cpu0_data_bus_o : data_bus_o_t;
  signal cpu0_data_bus_i : data_bus_i_t;

  signal cpu1_instr_bus_o : instr_bus_o_t;
  signal cpu1_instr_bus_i : instr_bus_i_t;

  signal cpu1_data_bus_o : data_bus_o_t;
  signal cpu1_data_bus_i : data_bus_i_t;

  signal cpu0_ram_o        : cpu_data_o_t;
  signal cpu0_ram_prearb_o : cpu_data_o_t;
  signal cpu0_ram_i : cpu_data_i_t;
  signal cpu0_rom_o : cpu_data_o_t;
  signal cpu0_rom_i : cpu_data_i_t;
  signal cpu1_ram_o : cpu_data_o_t; -- declared to process cpu1en
  signal ram0_arb_o : ram_arb_o_t; -- only three control signals
  signal ram1_arb_o : ram_arb_o_t; -- only three control signals
  signal cpu0ram_a_en : std_logic;
  signal cpu1ram_a_en : std_logic;

  signal clkn : std_logic;

  signal cpu0_lock : std_logic;
  signal cpu1_lock : std_logic;

  -- split DEV_SRAM memory bus into ROM and shared RAM buses
  procedure split_local_mem_bus(
    signal master_i : out cpu_data_i_t;
    signal master_o : in  cpu_data_o_t;
    signal rom_i    : in  cpu_data_i_t;
    signal rom_o    : out cpu_data_o_t;
    signal ram_i    : in  cpu_data_i_t;
    signal ram_o    : out cpu_data_o_t) is
  begin
    -- assign request to both ram and rom. en/rd/wr are masked to zero for
    -- unused bus below.
    rom_o <= master_o;
    ram_o <= master_o;

    -- already know a(31 downto 28) = "0000" due to cpu_core decoding
    if master_o.a(27 downto 15) = "0000000000000" then
      -- first 32KB are ROM
      master_i <= rom_i;
      -- prevent ram access
      ram_o.en <= '0';
      ram_o.rd <= '0';
      ram_o.wr <= '0';
    elsif master_o.a(27 downto 11) = "00000000000010000" then
      -- next 2KB are RAM
      master_i <= ram_i;
      -- prevent rom access
      rom_o.en <= '0';
      rom_o.rd <= '0';
      rom_o.wr <= '0';
    else
      -- ignore operations to other memory and return 0
      master_i.ack <= master_o.en;
      master_i.d <= (others => '0');
    end if;
  end;

  component cpu_rom is
    generic (
      ADDR_WIDTH : natural);
    port (
      clk : in std_logic;
      rst : in std_logic;
      dbus_o : in  cpu_data_o_t;
      dbus_i : out cpu_data_i_t;
      ibus_o : in  cpu_instruction_o_t;
      ibus_i : out cpu_instruction_i_t);
    end component;

begin

  cpu0_mem_lock <= cpu0_lock;
  cpu1_mem_lock <= cpu1_lock;

  -- clock memories on negative edge so that memory access are acked before the
  -- end of the cycle.
  -- TODO: Check memory access times are fast enough
  clkn <= not clk;

  cpu0 : cpu_core
    port map (
      clk => clk,
      rst => rst,
      instr_bus_o => cpu0_instr_bus_o,
      instr_bus_i => cpu0_instr_bus_i,
      data_bus_lock => cpu0_lock,
      data_bus_o => cpu0_data_bus_o,
      data_bus_i => cpu0_data_bus_i,
      debug_o => debug_o,
      debug_i => debug_i,
      event_o => cpu0_event_o,
      event_i => cpu0_event_i,
      data_master_en => cpu0_data_master_en,
      data_master_ack => cpu0_data_master_ack);

  cpu0_periph_dbus_o <= cpu0_data_bus_o(DEV_PERIPH);
  cpu0_data_bus_i(DEV_PERIPH) <= cpu0_periph_dbus_i;

  cpu0_ddr_ibus_o <= cpu0_instr_bus_o(DEV_DDR);
  cpu0_instr_bus_i(DEV_DDR) <= cpu0_ddr_ibus_i;

  cpu0_ddr_dbus_o <= cpu0_data_bus_o(DEV_DDR);
  cpu0_data_bus_i(DEV_DDR) <= cpu0_ddr_dbus_i;

  cpu1 : cpu_core
    port map (
      clk => clk,
      rst => rst,
      instr_bus_o => cpu1_instr_bus_o,
      instr_bus_i => cpu1_instr_bus_i,
      data_bus_lock => cpu1_lock,
      data_bus_o => cpu1_data_bus_o,
      data_bus_i => cpu1_data_bus_i,
      -- TODO: Add separate debug ports for cpu1
      debug_o => open,
      debug_i => CPU_DEBUG_NOP,
      event_o => cpu1_event_o,
      event_i => cpu1_event_i,
      data_master_en => cpu1_data_master_en,
      data_master_ack => cpu1_data_master_ack);

  cpu1_periph_dbus_o <= cpu1_data_bus_o(DEV_PERIPH);
  cpu1_data_bus_i(DEV_PERIPH) <= cpu1_periph_dbus_i;

  cpu1_ddr_ibus_o <= cpu1_instr_bus_o(DEV_DDR);
  cpu1_instr_bus_i(DEV_DDR) <= cpu1_ddr_ibus_i;

  cpu1_ddr_dbus_o <= cpu1_data_bus_o(DEV_DDR);
  cpu1_data_bus_i(DEV_DDR) <= cpu1_ddr_dbus_i;

  -- Instead of a single RAM like on the FPGA, the ASIC has a ROM for holding
  -- the boot code, which is attached only to CPU0, and a shared dual port RAM.
  -- The SRAM in the FPGA is 32KB

  split_local_mem_bus(
    master_i => cpu0_data_bus_i(DEV_SRAM),
    master_o => cpu0_data_bus_o(DEV_SRAM),
    rom_i    => cpu0_rom_i,
    rom_o    => cpu0_rom_o,
    ram_i    => cpu0_ram_i,
    ram_o    => cpu0_ram_prearb_o);

  -- cpu1 is not connected to the rom
  cpu1_instr_bus_i(DEV_SRAM) <= loopback_bus(cpu1_instr_bus_o(DEV_SRAM));

  -- 32KB of ROM
  -- choose one "rom : cpu_rom" or "sram : entity work.memory_fpga"

--  rom is commented out in two_cpus_fpga
--  rom : cpu_rom
--    generic map (
--      ADDR_WIDTH => 15)
--    port map (
--      clk => clkn,
--      rst => rst,
--      ibus_i => cpu0_instr_bus_i(DEV_SRAM),
--      ibus_o => cpu0_instr_bus_o(DEV_SRAM),
--      dbus_i => cpu0_rom_i,
--      dbus_o => cpu0_rom_o);

--  memo: to create fpga map, choose previous work.memory_fpga to reuse
--  previous 32KB RAM init design
  sram : entity work.memory_fpga(struc)
    port map (
      clk => clk,
      ibus_i => cpu0_instr_bus_o(DEV_SRAM),
      ibus_o => cpu0_instr_bus_i(DEV_SRAM),
      db_i => cpu0_rom_o,
      db_o => cpu0_rom_i);

  -- 2KB of shared RAM
  -- caution: 0.5cycle SRAM access critical path. (caution again)

  shared_ram : ram_2rw
    generic map (
      SUBWORD_WIDTH => 8,
      SUBWORD_NUM => 4,
      ADDR_WIDTH => 9)
    port map (
      rst0 => rst,
      clk0 => clkn,
      en0  => cpu0_ram_o.en,
      wr0  => cpu0_ram_o.wr,
      we0  => cpu0_ram_o.we,
      a0   => cpu0_ram_o.a(10 downto 2),
      dw0  => cpu0_ram_o.d,
      dr0  => cpu0_ram_i.d,
      rst1 => rst,
      clk1 => clkn,
      en1  => cpu1_ram_o.en,
      wr1  => cpu1_ram_o.wr,
      we1  => cpu1_ram_o.we,
      a1   => cpu1_ram_o.a(10 downto 2),
      dw1  => cpu1_ram_o.d,
      dr1  => cpu1_data_bus_i(DEV_SRAM).d,
      -- TODO: Expose margin ports
      margin0 => '0',
      margin1 => '0');

  -- cpu0 ram enable (= ram arbitration, lock) processing
  cpu0_ram_o.en  <= cpu0_ram_prearb_o.en and cpu0ram_a_en;
  cpu0_ram_o.wr  <= cpu0_ram_prearb_o.wr and cpu0ram_a_en;
  cpu0_ram_o.we  <= cpu0_ram_prearb_o.we and
                   (cpu0ram_a_en & cpu0ram_a_en & 
                    cpu0ram_a_en & cpu0ram_a_en);
  cpu0_ram_o.a   <= cpu0_ram_prearb_o.a;
  cpu0_ram_o.d   <= cpu0_ram_prearb_o.d;

  -- cpu1 ram enable (= not cpu1 halt, ram arbitration, lock)) processing
  cpu1_ram_o.en  <= cpu1_data_bus_o(DEV_SRAM).en and cpu1ram_a_en;
  cpu1_ram_o.wr  <= cpu1_data_bus_o(DEV_SRAM).wr and cpu1ram_a_en;
  cpu1_ram_o.we  <= cpu1_data_bus_o(DEV_SRAM).we and
                   (cpu1ram_a_en & cpu1ram_a_en & 
                    cpu1ram_a_en & cpu1ram_a_en);
  cpu1_ram_o.a   <= cpu1_data_bus_o(DEV_SRAM).a;
  cpu1_ram_o.d   <= cpu1_data_bus_o(DEV_SRAM).d;

  -- ack for shared_ram (reflecting arbitration)
  cpu0_ram_i.ack                <= cpu0_ram_o.en;
  cpu1_data_bus_i(DEV_SRAM).ack <= cpu1_ram_o.en;

  cpumreg : entity work.cpumreg
    port map (
      clk => clk,
      rst => rst, 
      db0_i => cpu0_data_bus_o(DEV_CPU),
      db1_i => cpu1_data_bus_o(DEV_CPU),
      ram0_arb_o => ram0_arb_o,
      ram1_arb_o => ram1_arb_o,
      db0_o => cpu0_data_bus_i(DEV_CPU),
      db1_o => cpu1_data_bus_i(DEV_CPU),
      cpu0ram_a_en => cpu0ram_a_en,
      cpu1ram_a_en => cpu1ram_a_en);

   ram0_arb_o.en   <= cpu0_ram_prearb_o.en;
   ram0_arb_o.wr   <= cpu0_ram_prearb_o.wr;
   ram0_arb_o.lock <= cpu0_lock;
   ram1_arb_o.en   <= cpu1_data_bus_o(DEV_SRAM).en;
   ram1_arb_o.wr   <= cpu1_data_bus_o(DEV_SRAM).wr;
   ram1_arb_o.lock <= cpu1_lock;

end architecture;

configuration two_cpus_fpga of cpus is
  for two_cpus_fpga
    for shared_ram : ram_2rw
      use entity work.ram_2rw(inferred);
    end for;
    for all : cpu_core
      use entity work.cpu_core(arch);
      for arch
        for u_cpu : cpu
          use configuration work.cpu_fpga;
        end for;
      end for;
    end for;
  end for;
end configuration;
