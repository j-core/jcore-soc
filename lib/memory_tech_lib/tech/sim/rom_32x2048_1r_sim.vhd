library ieee;
use ieee.numeric_std.all;
use ieee.vital_timing.all;
architecture sim of rom_32x2048_1r is
  type mem_t is array (integer range 0 to 2**a'length - 1) of std_logic_vector(d'length - 1 downto 0);
  signal mem : mem_t;
  signal d_tmp : std_logic_vector(31 downto 0) := (others => 'X');

  -- rising edge delay  (min : typical : max) = (1.251 : 1.838 : 3.164)
  -- falling edge delay  (min : typical : max) = (0.272 : 0.378 : 0.603)
  -- Use max values from verilog model
  constant tpd_D : VitalDelayType01 := (tr01 => 3.164 ns, tr10 => 0.603 ns);

  constant TimingChecksOn : boolean := true;
begin

  -----------------------
  -- BEHAVIOR SECTION
  -----------------------
  process(clk, en, a, margin)
    variable Tviol_en_clk : X01 := '0';
    variable en_clk_TimingData : VitalTimingDataType;
    variable Tviol_a_clk : X01 := '0';
    variable a_clk_TimingData : VitalTimingDataType;

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
        SetupHigh => 0.312 ns, -- 0.141 : 0.202 : 0.312
        SetupLow => 0.312 ns, -- 0.141 : 0.202 : 0.312
        HoldHigh => 0.280 ns, -- 0.126 : 0.176 : 0.280
        HoldLow => 0.280 ns, -- 0.126 : 0.176 : 0.280
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => en_clk_TimingData,
        Violation => Tviol_en_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => a,
        TestSignalName => "a",
        RefSignal => clk,
        RefSignalName => "clk",
        SetupHigh => 0.448 ns, -- 0.199 : 0.283 : 0.448
        SetupLow => 0.448 ns, -- 0.199 : 0.283 : 0.448
        HoldHigh => 0.352 ns, -- 0.158 : 0.220 : 0.352
        HoldLow => 0.352 ns, -- 0.158 : 0.220 : 0.352
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => a_clk_TimingData,
        Violation => Tviol_a_clk,
        MsgSeverity => WARNING);
    end if;

    violation := Tviol_en_clk or Tviol_a_clk;
    if is_x(en) then
      assert false
        report "ROM 32x2048 EN UNKNOWN"
        severity WARNING;
    elsif is_x(a) then
      assert false
        report "ROM 32x2048 ADDRESS UNKNOWN"
        severity WARNING;
    else
      if clk'event and clk = '1' then
        if en = '1' then
          -- synchronous read
          d_tmp <= mem(to_integer(unsigned(a)));
        end if;
      end if;
      if violation = '1' then
        d_tmp <= (others => 'X');
      end if;
    end if;
  end process;

  ------------------------------------
  --       PATH DELAY SECTION       --
  ------------------------------------

  d_pathdelay_gen: for i in 0 to 31 generate
    process(d_tmp(i))
      variable d_GlitchData : VitalGlitchDataType;
    begin
      VitalPathDelay01(
        OutSignal => d(i),
        GlitchData => d_GlitchData,
        OutSignalName => "d" & integer'image(i),
        OutTemp => d_tmp(i),
        Paths => (
          0 => (InputChangeTime => d_tmp(i)'LAST_EVENT,
                PathDelay => tpd_D,
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
