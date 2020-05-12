-- Models a 18x2048 RAM with 1 read/write port.

-- Uses Vital_Timing to simulate read delay and check setup and hold times.
-- This is not a proper Vital model but just uses some of the Vital_timing procedures.

library ieee;
use ieee.numeric_std.all;
use ieee.vital_timing.all;
architecture sim of ram_18x2048_1rw is
  type mem_t is array (integer range 0 to 2**a'length - 1)
    of std_logic_vector(dw'length - 1 downto 0);
  signal mem : mem_t;
  signal dr_tmp : std_logic_vector(17 downto 0) := (others => 'X');

  -- rising edge delay  (min : typical : max) = (0.160 : 0.221 : 0.353)
  -- falling edge delay  (min : typical : max) = (0.708 : 0.995 : 1.609)
  -- Use max values from verilog model
  constant tpd_DR : VitalDelayType01 := (tr01 => 0.353 ns, tr10 => 1.609 ns);

  constant TimingChecksOn : boolean := true;
begin
  process(clk, en, wr, a, dw)
    variable Tviol_en_clk : X01 := '0';
    variable en_clk_TimingData : VitalTimingDataType;
    variable Tviol_wr_clk : X01 := '0';
    variable wr_clk_TimingData : VitalTimingDataType;
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
        TestSignal => en,
        TestSignalName => "en",
        RefSignal => clk,
        RefSignalName => "clk",
        SetupHigh => 0.144 ns, -- 0.074 : 0.099 : 0.144
        SetupLow => 0.144 ns, -- 0.074 : 0.099 : 0.144
        HoldHigh => 0.171 ns, -- 0.079 : 0.109 : 0.171
        HoldLow => 0.171 ns, -- 0.079 : 0.109 : 0.171
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => en_clk_TimingData,
        Violation => Tviol_en_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => wr,
        TestSignalName => "wr",
        RefSignal => clk,
        RefSignalName => "clk",
        SetupHigh => 0.442 ns, -- 0.194 : 0.279 : 0.442
        SetupLow => 0.442 ns, -- 0.194 : 0.279 : 0.442
        HoldHigh => 0.171 ns, -- 0.078 : 0.109 : 0.171
        HoldLow => 0.171 ns, -- 0.078 : 0.109 : 0.171
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => wr_clk_TimingData,
        Violation => Tviol_wr_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => a,
        TestSignalName => "a",
        RefSignal => clk,
        RefSignalName => "clk",
        SetupHigh => 0.170 ns, -- 0.077 : 0.108 : 0.170
        SetupLow => 0.170 ns, -- 0.077 : 0.108 : 0.170
        HoldHigh => 0.435 ns, -- 0.189 : 0.268 : 0.435
        HoldLow => 0.435 ns, -- 0.189 : 0.268 : 0.435
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => a_clk_TimingData,
        Violation => Tviol_a_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => dw,
        TestSignalName => "dw",
        RefSignal => clk,
        RefSignalName => "clk",
        SetupHigh => 0.492 ns, -- 0.224 : 0.313 : 0.492
        SetupLow => 0.492 ns, -- 0.224 : 0.313 : 0.492
        HoldHigh => 0.099 ns, -- 0.055 : 0.068 : 0.099
        HoldLow => 0.099 ns, -- 0.055 : 0.068 : 0.099
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => dw_clk_TimingData,
        Violation => Tviol_dw_clk,
        MsgSeverity => WARNING);
    end if;

    violation := Tviol_en_clk or Tviol_wr_clk or Tviol_a_clk or Tviol_dw_clk;
    if is_x(en) then
      assert false
        report "RAM 18x2048 1rw EN UNKNOWN"
        severity WARNING;
    elsif is_x(wr) then
      assert false
        report "RAM 18x2048 1rw WR UNKNOWN"
        severity WARNING;
    elsif is_x(a) then
      assert false
        report "RAM 18x2048 1rw ADDRESS UNKNOWN"
        severity WARNING;
    elsif is_x(dw) then
      assert false
        report "RAM 18x2048 1rw DATAWRITE UNKNOWN"
        severity WARNING;
    else
      if clk'event and clk = '1' then
        if en = '1' then
          if wr = '1' then
            -- synchronous write
            mem(to_integer(unsigned(a))) <= dw;
          else
            -- synchronous latched read
            dr_tmp <= mem(to_integer(unsigned(a)));
          end if;
        end if;
      end if;
      if violation = '1' then
        dr_tmp <= (others => 'X');
      end if;
    end if;
  end process;

  ------------------------------------
  --       PATH DELAY SECTION       --
  ------------------------------------

  dr_pathdelay_gen: for i in 0 to 17 generate
    process(dr_tmp(i))
      variable d_GlitchData : VitalGlitchDataType;
    begin
      VitalPathDelay01(
        OutSignal => dr(i),
        GlitchData => d_GlitchData,
        OutSignalName => "dr" & integer'image(i),
        OutTemp => dr_tmp(i),
        Paths => (
          0 => (InputChangeTime => dr_tmp(i)'LAST_EVENT,
                PathDelay => tpd_DR,
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
