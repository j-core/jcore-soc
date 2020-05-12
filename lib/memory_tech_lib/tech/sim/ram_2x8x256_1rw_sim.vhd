-- Models a 16x256 RAM with 1 read/write port.

-- Uses Vital_Timing to simulate read delay and check setup and hold times.
-- This is not a proper Vital model but just uses some of the Vital_timing procedures.

library ieee;
use ieee.numeric_std.all;
use ieee.vital_timing.all;
use work.memory_pack.all;

architecture sim of ram_2x8x256_1rw is
  type mem_t is array (integer range 0 to 2**a'length - 1)
    of std_logic_vector(dw'length - 1 downto 0);
  signal mem : mem_t;
  constant SUBWORD_WIDTH : integer := 8;
  signal wr_we : std_logic_vector(we'length - 1 downto 0);
  signal dr_tmp : std_logic_vector(15 downto 0) := (others => 'X');

  -- rising edge delay  (min : typical : max) = (0.131 : 0.181 : 0.289)
  -- falling edge delay  (min : typical : max) = (0.476 : 0.675 : 1.090)
  -- Use max values from verilog model
  constant tpd_DR : VitalDelayType01 := (tr01 => 0.289 ns, tr10 => 1.090 ns);

  constant TimingChecksOn : boolean := true;
begin
  -- combine wr and we signals so that xst will infer a block RAM
  wr_we <= mask_bits(wr, we);

  process(clk, en, wr, a, dw)
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
        TestSignal => en,
        TestSignalName => "en",
        RefSignal => clk,
        RefSignalName => "clk",
        SetupHigh => 0.144 ns, -- 0.074 : 0.099 : 0.144
        SetupLow => 0.144 ns, -- 0.074 : 0.099 : 0.144
        HoldHigh => 0.162 ns, -- 0.075 : 0.103 : 0.162
        HoldLow => 0.162 ns, -- 0.075 : 0.103 : 0.162
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
        SetupHigh => 0.479 ns, -- 0.211 : 0.303 : 0.479
        SetupLow => 0.479 ns, -- 0.211 : 0.303 : 0.479
        HoldHigh => 0.163 ns, -- 0.074 : 0.103 : 0.163
        HoldLow => 0.163 ns, -- 0.074 : 0.103 : 0.163
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => wr_clk_TimingData,
        Violation => Tviol_wr_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => we,
        TestSignalName => "we",
        RefSignal => clk,
        RefSignalName => "clk",
        SetupHigh => 0.660 ns, -- 0.298 : 0.414 : 0.660
        SetupLow => 0.660 ns, -- 0.298 : 0.414 : 0.660
        HoldHigh => 0.000 ns, -- 0.000 : 0.000 : 0.000
        HoldLow => 0.000 ns, -- 0.000 : 0.000 : 0.000
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => we_clk_TimingData,
        Violation => Tviol_we_clk,
        MsgSeverity => WARNING);
      VitalSetupHoldCheck (
        TestSignal => a,
        TestSignalName => "a",
        RefSignal => clk,
        RefSignalName => "clk",
        SetupHigh => 0.170 ns, -- 0.077 : 0.108 : 0.170
        SetupLow => 0.170 ns, -- 0.077 : 0.108 : 0.170
        HoldHigh => 0.367 ns, -- 0.158 : 0.225 : 0.367
        HoldLow => 0.367 ns, -- 0.158 : 0.225 : 0.367
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
        SetupHigh => 0.474 ns, -- 0.211 : 0.294 : 0.474
        SetupLow => 0.474 ns, -- 0.211 : 0.294 : 0.474
        HoldHigh => 0.036 ns, -- 0.030 : 0.034 : 0.036
        HoldLow => 0.036 ns, -- 0.030 : 0.034 : 0.036
        CheckEnabled => TRUE,
        RefTransition => '/',
        TimingData => dw_clk_TimingData,
        Violation => Tviol_dw_clk,
        MsgSeverity => WARNING);
    end if;

    violation := Tviol_en_clk or Tviol_wr_clk or Tviol_we_clk or Tviol_a_clk or Tviol_dw_clk;
    if is_x(en) then
      assert false
        report "RAM 2x8x256 1rw EN UNKNOWN"
        severity WARNING;
    elsif is_x(wr) then
      assert false
        report "RAM 2x8x256 1rw WR UNKNOWN"
        severity WARNING;
    elsif is_x(we) then
      assert false
        report "RAM 2x8x256 1rw WE UNKNOWN"
        severity WARNING;
    elsif is_x(a) then
      assert false
        report "RAM 2x8x256 1rw ADDRESS UNKNOWN"
        severity WARNING;
    elsif is_x(dw) then
      assert false
        report "RAM 2x8x256 1rw DATAWRITE UNKNOWN"
        severity WARNING;
    else
      if clk'event and clk = '1' then
        if en = '1' then
          if wr_we = (wr_we'range => '0') then
            -- synchronous latched read
            dr_tmp <= mem(to_integer(unsigned(a)));
          else
            -- synchronous write
            for i in integer range 0 to we'length-1 loop
              if wr_we(i) = '1' then
                mem(to_integer(unsigned(a)))((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH)
                  <= dw((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH);
              end if;
            end loop;
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

  dr_pathdelay_gen: for i in 0 to 15 generate
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
