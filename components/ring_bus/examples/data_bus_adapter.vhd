library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ring_bus_pack.all;
use work.examples_pack.all;
use work.cpu2j0_pack.all;
entity data_bus_adapter is port (
  clk : in std_logic;
  rst : in std_logic;
  -- connections to predesessor in ring bus
  bus_i : in rbus_word_8b;
  stall_o : out std_logic;
  -- connections to successor in ring bus
  bus_o : out rbus_word_8b;
  stall_i : in std_logic;
  data_o : out cpu_data_o_t;
  data_i : in cpu_data_i_t;
  irq : in std_logic);
end entity;
architecture arch of data_bus_adapter is
  signal this_c : data_bus_adapter_reg;
  signal this_r : data_bus_adapter_reg := DATA_BUS_ADAPTER_RESET;
  procedure handle_new_cmd(
    this : inout data_bus_adapter_reg;
    word : in rbus_word_8b)
  is
    variable cmd : rbus_cmd;
    variable next_state : data_bus_adapter_state;
  begin
    if cmd_starts_msg(word) then
      next_state := IGNORE;
      if this.state = WRITE_RECEIVE then
        -- leaving WRITE_ISSUE requires transitioning to WRITE_ISSUE regardless of input cmd
        next_state := WRITE_ISSUE;
      elsif this.irq = '1' then
        this.irq := '0';
        next_state := INTERRUPT;
      elsif to_hops(word.d) = 0 then -- command is for this node
        cmd := to_cmd(word.d);
        if cmd = OFFSET then
          -- prepare to receive offset as address
          next_state := ADDRESS;
          this.a := (others => '0');
        elsif cmd = READ then
          next_state := READ_ISSUE;
        elsif cmd = WRITE then
          next_state := WRITE_RECEIVE;
          this.d := (others => '0');
        end if;
      end if;
      this.state := next_state;
      this.state_count := 0;
    end if;
  end;
  function zeros(constant len : in integer)
    return std_logic_vector is
    variable r : std_logic_vector(len - 1 downto 0);
  begin
    r := (others => '0');
    return r;
  end function;
begin
  p : process(this_r, bus_i, stall_i, data_i, irq)
    variable this : data_bus_adapter_reg;
    variable scratch : rbus_scratch_8b;
    variable rinputs : rbus_inputs_8b;
    variable routputs : rbus_outputs_8b;
    variable rack : std_logic;
    variable state_count_inc : state_count;
  begin
     this := this_r;
    assert this.node_this.bus_o.stall = '1' or can_discard(this.node_this.stalled)
      report "ring bus node contains queued word when not stalling predecessor"
      severity warning;
    -- detect rising edge of irq
    if this.prev_irq = '0' and irq = '1' then
      this.irq := '1';
    end if;
    this.prev_irq := irq;
    -- Step 1) based on bus inputs (bus_i and stall_i) and current mode, set up
    -- combinatorial outputs to the device.
    rbus_node_inputs(this.node_this, bus_i, stall_i, scratch, rinputs);
    -- state transition
    if this.state = READ_ISSUE then
      -- only an ACK can get us out of READ_ISSUE
      if data_i.ack = '1' then
      -- read complete, capture data and proceed to send data on bus
        this.d := data_i.d;
        this.data_o.en := '0';
        this.data_o.rd := '0';
        this.data_o.a := (others => '0');
        this.state := READ_REPLY;
        this.state_count := 0;
      end if;
    elsif this.state = WRITE_ISSUE then
      if data_i.ack = '1' then
        -- write complete
        this.data_o.en := '0';
        this.data_o.wr := '0';
        this.data_o.we := "0000";
        this.data_o.a := (others => '0');
        handle_new_cmd(this, rinputs.word);
      end if;
    elsif rinputs.en = '1' and rinputs.word.fr = '1' then
      handle_new_cmd(this, rinputs.word);
    end if;
    routputs := RBUS_OUTPUTS_FORWARD_8B;
    -- set outputs based on state
    case this.state is
      when IGNORE =>
      when ADDRESS =>
        routputs.mode := RECEIVE;
        -- check fr = '0' here to ignore BUSY commands
        if rinputs.en = '1' and rinputs.word.fr = '0' then
          -- shift in new address word
          this.a := shift_in_right(this.a, rinputs.word.d);
        end if;
      when READ_ISSUE =>
        if this.state_count = 0 then
          -- in first cycle, replace cmd with a WRITE
          routputs.mode := RECEIVE;
          routputs.word := cmd_word_8b(WRITE, 15);
          -- issue read request
          this.data_o.en := '1';
          this.data_o.rd := '1';
          this.data_o.wr := '0';
          this.data_o.a := this.a;
        else
          -- still waiting for the read to complete, stall the bus
          routputs.mode := TRANSMIT;
          routputs.word := cmd_word_8b(BUSY, 0);
        end if;
      when READ_REPLY =>
        routputs.mode := RECEIVE;
        if this.state_count < 4 then
          -- send left-most word
          routputs.word := data_word_8b(
            this.d(this.d'left downto this.d'left - routputs.word.d'length + 1));
        end if;
      when WRITE_RECEIVE =>
        routputs.mode := RECEIVE;
        -- check fr = '0' here to ignore BUSY commands
        if rinputs.en = '1' and rinputs.word.fr = '0' then
          -- shift in new address word
          this.d := shift_in_right(this.d, rinputs.word.d);
        end if;
      when WRITE_ISSUE =>
        routputs.mode := TRANSMIT;
        if this.state_count = 0 then
          -- issue write request
          this.data_o.en := '1';
          this.data_o.rd := '0';
          this.data_o.wr := '1';
          this.data_o.a := this.a;
          this.data_o.d := this.d;
          this.data_o.we := "1111";
        end if;
      when INTERRUPT =>
        routputs.mode := TRANSMIT;
        if this.state_count = 0 then
          routputs.word := cmd_word_8b(INTERRUPT, 15);
        end if;
    end case;
    -- node outputs
    -- Step 2) based on bus inputs, current mode, and combinatorial inputs from
    -- device, set new mode and bus outputs (bus_o and stall_o) and set
    -- combinartorial ACK back to device
    rbus_node_outputs(this.node_this, stall_i, scratch, routputs, rack);
    if this.state_count /= state_count'high then
      state_count_inc := this.state_count + 1;
    else
      state_count_inc := this.state_count;
    end if;
    -- the action to take based on successful bus word send depends on the
    -- state
    if rack = '1' then
      case this.state is
        when READ_ISSUE =>
          this.state_count := state_count_inc;
        when READ_REPLY =>
          -- shift out the left-most word
          this.d := shift_out_left(this.d, routputs.word.d'length);
          this.state_count := state_count_inc;
        when INTERRUPT =>
          this.state_count := state_count_inc;
          -- TODO: Is there a better way to determine when to leave INTERRUPT
          -- state? Should support sending an interrupt number.
          if this.state_count = 1 then
            this.state := IGNORE;
          end if;
        when others =>
      end case;
    end if;
    this_c <= this;
  end process;
  p_r0 : process(clk, rst)
  begin
     if rst='1' then
        this_r <= DATA_BUS_ADAPTER_RESET;
     elsif clk='1' and clk'event then
        this_r <= this_c;
     end if;
  end process;
  stall_o <= this_r.node_this.bus_o.stall;
  bus_o <= this_r.node_this.bus_o.word;
  data_o <= this_r.data_o;
end arch;
