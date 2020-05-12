-- Models a 16x2048 RAM with 2 read/write ports.

-- Uses Vital_Timing to simulate read delay and check setup and hold times.
-- This is not a proper Vital model but just uses some of the Vital_timing procedures.

library ieee;
use ieee.numeric_std.all;
use ieee.vital_timing.all;
use work.memory_pack.all;
architecture sim of ram_2x8x2048_2rw is
  type mem_t is array (integer range 0 to 2**a0'length - 1)
    of std_logic_vector(dr0'length-1 downto 0);
  shared variable mem : mem_t;
  signal wr_we0 : std_logic_vector(we0'length - 1 downto 0);
  signal wr_we1 : std_logic_vector(we1'length - 1 downto 0);
  constant SUBWORD_WIDTH : integer := 8;

  signal dr0_tmp : std_logic_vector(15 downto 0) := (others => '0');
  signal dr1_tmp : std_logic_vector(15 downto 0) := (others => '0');

  -- rising edge delay  (min : typical : max) = (0.133 : 0.184 : 0.291)
  -- falling edge delay (min : typical : max) = (0.757 : 1.118 : 1.886)
  -- Use max values from verilog model
  constant tpd_DR0 : VitalDelayType01 := (tr01 => 0.291 ns, tr10 => 1.886 ns);

  -- rising edge delay  (min : typical : max) = (0.133 : 0.184 : 0.291)
  -- falling edge delay (min : typical : max) = (0.755 : 1.116 : 1.886)
  -- Use max values from verilog model
  constant tpd_DR1 : VitalDelayType01 := (tr01 => 0.291 ns, tr10 => 1.886 ns);

  constant TimingChecksOn : boolean := true;
begin
  -- combine wr and we signals so that xst will infer a block RAM
  wr_we0 <= mask_bits(wr0, we0);
  wr_we1 <= mask_bits(wr1, we1);

  process(clk0, en0, wr0, we0, wr_we0, a0, dw0)
    variable Tviol_en_clk : X01 := '0';
    variable en_clk_TimingData : VitalTimingDataType;
    variable Tviol_wr_clk : X01 := '0';
    variable wr_clk_TimingData : VitalTimingDataType;
    variable Tviol_we_clk : X01 := '0';
    variable we_clk_TimingData : VitalTimingDataType;
    variable Tviol_a_clk : X01 := '0';
    variable a_clk_TimingData : VitalTimingDataType;
    variable Tviol_dw_clk : X01 := '0';
    variable dw_clk_TimingData : VitalTimingDataType;

    variable violation : X01 := '0';
  begin
    -----------------------
    -- Timing Check Section
    -----------------------
    if TimingChecksOn then
      VitalSetupHoldCheck (
        TestSignal => en0,
        TestSignalName => "en0",
        RefSignal => clk0,
        RefSignalName => "clk0",
        SetupHigh => 0.170 ns, -- 0.089 : 0.118 : 0.170
        SetupLow => 0.170 ns, -- 0.089 : 0.118 : 0.170
        HoldHigh => 0.299 ns, -- 0.139 : 0.192 : 0.299
        HoldLow => 0.299 ns, -- 0.139 : 0.192 : 0.299
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => en_clk_TimingData,
        Violation => Tviol_en_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => wr0,
        TestSignalName => "wr0",
        RefSignal => clk0,
        RefSignalName => "clk0",
        SetupHigh => 0.331 ns, -- 0.177 : 0.232 : 0.331
        SetupLow => 0.331 ns, -- 0.177 : 0.232 : 0.331
        HoldHigh => 0.267 ns, -- 0.123 : 0.171 : 0.267
        HoldLow => 0.267 ns, -- 0.123 : 0.171 : 0.267
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => wr_clk_TimingData,
        Violation => Tviol_wr_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => we0,
        TestSignalName => "we0",
        RefSignal => clk0,
        RefSignalName => "clk0",
        SetupHigh => 0.281 ns, -- 0.138 : 0.186 : 0.281
        SetupLow => 0.281 ns, -- 0.138 : 0.186 : 0.281
        HoldHigh => 0.211 ns, -- 0.108 : 0.148 : 0.211
        HoldLow => 0.211 ns, -- 0.108 : 0.148 : 0.211
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => we_clk_TimingData,
        Violation => Tviol_we_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => a0,
        TestSignalName => "a0",
        RefSignal => clk0,
        RefSignalName => "clk0",
        SetupHigh => 0.301 ns, -- 0.149 : 0.201 : 0.301
        SetupLow => 0.301 ns, -- 0.149 : 0.201 : 0.301
        HoldHigh => 0.0 ns, -- 0.000 : 0.000 : 0.000
        HoldLow => 0.0 ns, -- 0.000 : 0.000 : 0.000
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => a_clk_TimingData,
        Violation => Tviol_a_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => dw0,
        TestSignalName => "dw0",
        RefSignal => clk0,
        RefSignalName => "clk0",
        SetupHigh => 0.160 ns, -- 0.084 : 0.109 : 0.160
        SetupLow => 0.160 ns, -- 0.084 : 0.109 : 0.160
        HoldHigh => 0.330 ns, -- 0.160 : 0.222 : 0.330
        HoldLow => 0.330 ns, -- 0.160 : 0.222 : 0.330
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => dw_clk_TimingData,
        Violation => Tviol_dw_clk,
        MsgSeverity => WARNING);
    end if;

    violation := Tviol_en_clk or Tviol_wr_clk or Tviol_we_clk or Tviol_a_clk or Tviol_dw_clk;
    if is_x(en0) then
      assert false
        report "RAM 2x8x2048 2rw EN0 UNKNOWN"
        severity WARNING;
    elsif is_x(wr0) then
      assert false
        report "RAM 2x8x2048 2rw WR0 UNKNOWN"
        severity WARNING;
    elsif is_x(we0) then
      assert false
        report "RAM 2x8x2048 2rw WE0 UNKNOWN"
        severity WARNING;
    elsif is_x(a0) then
      assert false
        report "RAM 2x8x2048 2rw ADDRESS0 UNKNOWN"
        severity WARNING;
    elsif is_x(dw0) then
      assert false
        report "RAM 2x8x2048 2rw DATAWRITE0 UNKNOWN"
        severity WARNING;
    else
      if clk0'event and clk0 = '1' then
        if en0 = '1' then
          if wr_we0 = (wr_we0'range => '0') then
            -- synchronous latched read
            dr0_tmp <= mem(to_integer(unsigned(a0)));
          else
            -- synchronous write
            for i in integer range 0 to wr_we0'length-1 loop
              if wr_we0(i) = '1' then
                mem(to_integer(unsigned(a0)))((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH)
                  := dw0((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH);
              end if;
            end loop;
          end if;
        end if;
      end if;
      if violation = '1' then
        dr0_tmp <= (others => 'X');
      end if;
    end if;
  end process;

  process(clk1, en1, wr1, we1, wr_we1, a1, dw1)
    variable Tviol_en_clk : X01 := '0';
    variable en_clk_TimingData : VitalTimingDataType;
    variable Tviol_wr_clk : X01 := '0';
    variable wr_clk_TimingData : VitalTimingDataType;
    variable Tviol_we_clk : X01 := '0';
    variable we_clk_TimingData : VitalTimingDataType;
    variable Tviol_a_clk : X01 := '0';
    variable a_clk_TimingData : VitalTimingDataType;
    variable Tviol_dw_clk : X01 := '0';
    variable dw_clk_TimingData : VitalTimingDataType;

    variable violation : X01 := '0';
  begin
    -----------------------
    -- Timing Check Section
    -----------------------
    if TimingChecksOn then
      VitalSetupHoldCheck (
        TestSignal => en1,
        TestSignalName => "en1",
        RefSignal => clk1,
        RefSignalName => "clk1",
        SetupHigh => 0.170 ns, -- 0.089 : 0.118 : 0.170
        SetupLow => 0.170 ns, -- 0.089 : 0.118 : 0.170
        HoldHigh => 0.299 ns, -- 0.139 : 0.192 : 0.299
        HoldLow => 0.299 ns, -- 0.139 : 0.192 : 0.299
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => en_clk_TimingData,
        Violation => Tviol_en_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => wr1,
        TestSignalName => "wr1",
        RefSignal => clk1,
        RefSignalName => "clk1",
        SetupHigh => 0.331 ns, -- 0.177 : 0.232 : 0.331
        SetupLow => 0.331 ns, -- 0.177 : 0.232 : 0.331
        HoldHigh => 0.267 ns, -- 0.123 : 0.171 : 0.267
        HoldLow => 0.267 ns, -- 0.123 : 0.171 : 0.267
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => wr_clk_TimingData,
        Violation => Tviol_wr_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => we1,
        TestSignalName => "we1",
        RefSignal => clk1,
        RefSignalName => "clk1",
        SetupHigh => 0.281 ns, -- 0.138 : 0.186 : 0.281
        SetupLow => 0.281 ns, -- 0.138 : 0.186 : 0.281
        HoldHigh => 0.209 ns, -- 0.108 : 0.147 : 0.209
        HoldLow => 0.209 ns, -- 0.108 : 0.147 : 0.209
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => we_clk_TimingData,
        Violation => Tviol_we_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => a1,
        TestSignalName => "a1",
        RefSignal => clk1,
        RefSignalName => "clk1",
        SetupHigh => 0.299 ns, -- 0.149 : 0.200 : 0.299
        SetupLow => 0.299 ns, -- 0.149 : 0.200 : 0.299
        HoldHigh => 0.0 ns, -- 0.000 : 0.000 : 0.000
        HoldLow => 0.0 ns, -- 0.000 : 0.000 : 0.000
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => a_clk_TimingData,
        Violation => Tviol_a_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => dw1,
        TestSignalName => "dw1",
        RefSignal => clk1,
        RefSignalName => "clk1",
        SetupHigh => 0.160 ns, -- 0.084 : 0.108 : 0.160
        SetupLow => 0.160 ns, -- 0.084 : 0.109 : 0.160
        HoldHigh => 0.328 ns, -- 0.160 : 0.221 : 0.328
        HoldLow => 0.328 ns, -- 0.160 : 0.221 : 0.328
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => dw_clk_TimingData,
        Violation => Tviol_dw_clk,
        MsgSeverity => WARNING);
    end if;

    violation := Tviol_en_clk or Tviol_wr_clk or Tviol_we_clk or Tviol_a_clk or Tviol_dw_clk;
    if is_x(en1) then
      assert false
        report "RAM 2x8x2048 2rw EN1 UNKNOWN"
        severity WARNING;
    elsif is_x(wr1) then
      assert false
        report "RAM 2x8x2048 2rw WR1 UNKNOWN"
        severity WARNING;
    elsif is_x(we1) then
      assert false
        report "RAM 2x8x2048 2rw WE1 UNKNOWN"
        severity WARNING;
    elsif is_x(a1) then
      assert false
        report "RAM 2x8x2048 2rw ADDRESS1 UNKNOWN"
        severity WARNING;
    elsif is_x(dw1) then
      assert false
        report "RAM 2x8x2048 2rw DATAWRITE1 UNKNOWN"
        severity WARNING;
    else
      if clk1'event and clk1 = '1' then
        if en1 = '1' then
          if wr_we1 = (wr_we1'range => '0') then
            -- synchronous latched read
            dr1_tmp <= mem(to_integer(unsigned(a1)));
          else
            -- synchronous write
            for i in integer range 0 to wr_we1'length-1 loop
              if wr_we1(i) = '1' then
                mem(to_integer(unsigned(a1)))((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH)
                  := dw1((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH);
              end if;
            end loop;
          end if;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------
  --       PATH DELAY SECTION       --
  ------------------------------------

  dr0_pathdelay_gen: for i in 0 to 15 generate
    process(dr0_tmp(i))
      variable d_GlitchData : VitalGlitchDataType;
    begin
      VitalPathDelay01(
        OutSignal => dr0(i),
        GlitchData => d_GlitchData,
        OutSignalName => "dr0" & integer'image(i),
        OutTemp => dr0_tmp(i),
        Paths => (
          0 => (InputChangeTime => dr0_tmp(i)'LAST_EVENT,
                PathDelay => tpd_DR0,
                PathCondition => true)),
        DefaultDelay => VitalZeroDelay01,
        -- glitch detection and what to do when glitch occurs
        Mode => OnEvent,
        XOn => true,
        MsgOn => true,
        MsgSeverity => warning,
       --CONSTANT NegPreemptOn       : IN    BOOLEAN             := FALSE;  --IR225 3/14/98
        IgnoreDefaultDelay => TRUE -- behaviour is reversed
        );
    end process;
  end generate;
  dr1_pathdelay_gen: for i in 0 to 15 generate
    process(dr1_tmp(i))
      variable d_GlitchData : VitalGlitchDataType;
    begin
      VitalPathDelay01(
        OutSignal => dr1(i),
        GlitchData => d_GlitchData,
        OutSignalName => "dr1" & integer'image(i),
        OutTemp => dr1_tmp(i),
        Paths => (
          0 => (InputChangeTime => dr1_tmp(i)'LAST_EVENT,
                PathDelay => tpd_DR1,
                PathCondition => true)),
        DefaultDelay => VitalZeroDelay01,
        -- glitch detection and what to do when glitch occurs
        Mode => OnEvent,
        XOn => true,
        MsgOn => true,
        MsgSeverity => warning,
       --CONSTANT NegPreemptOn       : IN    BOOLEAN             := FALSE;  --IR225 3/14/98
        IgnoreDefaultDelay => TRUE -- behaviour is reversed
        );
    end process;
  end generate;
end architecture;
