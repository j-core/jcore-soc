-- Models a 32x512 RAM with 2 read/write ports.

-- Uses Vital_Timing to simulate read delay and check setup and hold times.
-- This is not a proper Vital model but just uses some of the Vital_timing procedures.

-- This memory is not appropriate for FPGA synthesis. Xilinx Block RAMs do
-- not support the per bit write enable inputs.
library ieee;
use ieee.numeric_std.all;
use ieee.vital_timing.all;
architecture sim of ram_32x1x512_2rw is
  type mem_t is array (integer range 0 to 2**a0'length - 1)
    of std_logic_vector(dr0'length-1 downto 0);
  shared variable mem : mem_t;

  -- Stop XST from trying to infer a block RAM.
  -- The inference seems to cause an error
  --   "INTERNAL_ERROR:Xst:cmain.c:3423:1.29 -"
  attribute ram_style: string;
  attribute ram_style of mem : variable is "distributed";

  signal dr0_tmp : std_logic_vector(31 downto 0) := (others => '0');
  signal dr1_tmp : std_logic_vector(31 downto 0) := (others => '0');

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
  process(clk0, en0, wr0, we0, a0, dw0)
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
        HoldHigh => 0.260 ns, -- 0.119 : 0.165 : 0.260
        HoldLow => 0.260 ns, -- 0.119 : 0.165 : 0.260
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
        HoldHigh => 0.228 ns, -- 0.103 : 0.144 : 0.228
        HoldLow => 0.228 ns, -- 0.103 : 0.144 : 0.228
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
        SetupHigh => 0.187 ns, -- 0.089 : 0.122 : 0.187
        SetupLow => 0.187 ns, -- 0.089 : 0.122 : 0.187
        HoldHigh => 0.223 ns, -- 0.123 : 0.161 : 0.223
        HoldLow => 0.223 ns, -- 0.123 : 0.161 : 0.223
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
        SetupHigh => 0.236 ns, -- 0.117 : 0.158 : 0.236
        SetupLow => 0.236 ns, -- 0.117 : 0.158 : 0.236
        HoldHigh => 0.388 ns, -- 0.179 : 0.249 : 0.388
        HoldLow => 0.388 ns, -- 0.179 : 0.249 : 0.388
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
        SetupHigh => 0.239 ns, -- 0.112 : 0.154 : 0.239
        SetupLow => 0.239 ns, -- 0.112 : 0.154 : 0.239
        HoldHigh => 0.167 ns, -- 0.098 : 0.124 : 0.167
        HoldLow => 0.167 ns, -- 0.098 : 0.124 : 0.167
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => dw_clk_TimingData,
        Violation => Tviol_dw_clk,
        MsgSeverity => WARNING);
    end if;

    violation := Tviol_en_clk or Tviol_wr_clk or Tviol_we_clk or Tviol_a_clk or Tviol_dw_clk;
    if is_x(en0) then
      assert false
        report "RAM 32x1x512 2rw EN0 UNKNOWN"
        severity WARNING;
    elsif is_x(wr0) then
      assert false
        report "RAM 32x1x512 2rw WR0 UNKNOWN"
        severity WARNING;
    elsif is_x(we0) then
      assert false
        report "RAM 32x1x512 2rw WE0 UNKNOWN"
        severity WARNING;
    elsif is_x(a0) then
      assert false
        report "RAM 32x1x512 2rw ADDRESS0 UNKNOWN"
        severity WARNING;
    elsif is_x(dw0) then
      assert false
        report "RAM 32x1x512 2rw DATAWRITE0 UNKNOWN"
        severity WARNING;
    else
      if clk0'event and clk0 = '1' then
        if en0 = '1' then
          if wr0 = '1' then
            -- synchronous write
            for i in integer range 0 to we0'length-1 loop
              if we0(i) = '1' then
                mem(to_integer(unsigned(a0)))(i) := dw0(i);
              end if;
            end loop;
          else
            -- synchronous read
            dr0_tmp <= mem(to_integer(unsigned(a0)));
          end if;
        end if;
      end if;
      if violation = '1' then
        dr0_tmp <= (others => 'X');
      end if;
    end if;
  end process;

  process(clk1, en1, wr1, we1, a1, dw1)
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
        HoldHigh => 0.260 ns, -- 0.119 : 0.165 : 0.260
        HoldLow => 0.260 ns, -- 0.119 : 0.165 : 0.260
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
        HoldHigh => 0.228 ns, -- 0.103 : 0.144 : 0.228
        HoldLow => 0.228 ns, -- 0.103 : 0.144 : 0.228
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
        SetupHigh => 0.187 ns, -- 0.089 : 0.122 : 0.187
        SetupLow => 0.187 ns, -- 0.089 : 0.122 : 0.187
        HoldHigh => 0.223 ns, -- 0.123 : 0.161 : 0.222
        HoldLow => 0.222 ns, -- 0.123 : 0.161 : 0.222
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
        SetupHigh => 0.235 ns, -- 0.117 : 0.158 : 0.235
        SetupLow => 0.235 ns, -- 0.117 : 0.158 : 0.235
        HoldHigh => 0.388 ns, -- 0.179 : 0.249 : 0.388
        HoldLow => 0.388 ns, -- 0.179 : 0.249 : 0.388
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
        SetupHigh => 0.239 ns, -- 0.112 : 0.154 : 0.239
        SetupLow => 0.239 ns, -- 0.112 : 0.154 : 0.239
        HoldHigh => 0.166 ns, -- 0.098 : 0.123 : 0.166
        HoldLow => 0.166 ns, -- 0.098 : 0.123 : 0.166
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => dw_clk_TimingData,
        Violation => Tviol_dw_clk,
        MsgSeverity => WARNING);
    end if;

    violation := Tviol_en_clk or Tviol_wr_clk or Tviol_we_clk or Tviol_a_clk or Tviol_dw_clk;
    if is_x(en1) then
      assert false
        report "RAM 32x1x512 2rw EN1 UNKNOWN"
        severity WARNING;
    elsif is_x(wr1) then
      assert false
        report "RAM 32x1x512 2rw WR1 UNKNOWN"
        severity WARNING;
    elsif is_x(we1) then
      assert false
        report "RAM 32x1x512 2rw WE1 UNKNOWN"
        severity WARNING;
    elsif is_x(a1) then
      assert false
        report "RAM 32x1x512 2rw ADDRESS1 UNKNOWN"
        severity WARNING;
    elsif is_x(dw1) then
      assert false
        report "RAM 32x1x512 2rw DATAWRITE1 UNKNOWN"
        severity WARNING;
    else
      if clk1'event and clk1 = '1' then
        if en1 = '1' then
          if wr1 = '1' then
            -- synchronous write
            for i in integer range 0 to we1'length-1 loop
              if we1(i) = '1' then
                mem(to_integer(unsigned(a1)))(i) := dw1(i);
              end if;
            end loop;
          else
            -- synchronous read
            dr1_tmp <= mem(to_integer(unsigned(a1)));
          end if;
        end if;
      end if;
      if violation = '1' then
        dr1_tmp <= (others => 'X');
      end if;
    end if;
  end process;

  ------------------------------------
  --       PATH DELAY SECTION       --
  ------------------------------------

  dr0_pathdelay_gen: for i in 0 to 31 generate
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
  dr1_pathdelay_gen: for i in 0 to 31 generate
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
