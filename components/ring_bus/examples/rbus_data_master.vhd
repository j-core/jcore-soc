library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ring_bus_pack.all;
use work.examples_pack.all;
use work.cpu2j0_pack.all;
entity rbus_data_master is port (
  clk : in std_logic;
  rst : in std_logic;
  -- ports to data bus master
  data_i : in cpu_data_o_t;
  data_o : out cpu_data_i_t;
  -- ports to start of ring
  bus_o : out rbus_word_8b;
  stall_i : in std_logic;
  -- ports to end of ring
  bus_i : in rbus_word_8b;
  stall_o : out std_logic);
end entity;
architecture arch of rbus_data_master is
  signal this_c : rbus_data_master_reg;
  signal this_r : rbus_data_master_reg := RBUS_DATA_MASTER_RESET;
begin
  p : process(this_r, data_i, stall_i, bus_i)
    variable this : rbus_data_master_reg;
    variable scratch : rbus_scratch_8b;
    variable rinputs : rbus_inputs_8b;
    variable routputs : rbus_outputs_8b;
    variable rack : std_logic;
    variable cmd : rbus_cmd;
    variable count_inc : state_count;
  begin
     this := this_r;
    -- Use two rbus nodes. One for transmitting to start and one for receiving
    -- from the end.
    -- start new read or write requests when requests arrive on data bus
    if this.send_state = IDLE then
      if data_i.en = '1' and not this.request.active then
        this.send_state := SEND_OFFSET;
        this.send_count := 0;
        this.request.active := true;
        this.request.cmd := OFFSET;
        this.request.send_data := data_i.a;
        -- TODO: set up request and select bus based on request address
        this.request.hops := 1;
      end if;
    end if;
    rbus_node_inputs(this.recv_node, bus_i, '0', scratch, rinputs);
    -- end node is always in receive mode
    routputs.mode := RECEIVE;
    routputs.word := IDLE_8B;
    -- drop ack after one cycle and allow new request
    if this.data_o.ack = '1' then
      this.data_o := (ack => '0', d => (others => '0'));
      this.request.active := false;
    end if;
    -- process words received from the bus
    if rinputs.en = '1' then
      -- transition recv state machine based on received word
      if cmd_starts_msg(rinputs.word) then
        -- a new command is being received from the bus
        -- first finish processing old state
        if this.recv_state = RECV_WRITE then
          -- done receiving WRITE. ACK appropriate request
          this.data_o.ack := '1';
          this.data_o.d := this.request.recv_data;
        end if;
        cmd := to_cmd(rinputs.word.d);
        if cmd = WRITE then
          -- TODO: check what is sending the WRITE by looking at hops to match
          -- WRITE back to original READ.
          this.recv_state := RECV_WRITE;
          this.request.recv_data := (others => '0');
        else
          this.recv_state := IDLE;
        end if;
        this.recv_count := 0;
      end if;
      if this.recv_count /= state_count'high then
        count_inc := this.recv_count + 1;
      else
        count_inc := this.recv_count;
      end if;
      -- deal with data
      if this.recv_state = RECV_WRITE then
        if rinputs.word.fr = '0' then -- ignore BUSY
          this.request.recv_data := shift_in_right(this.request.recv_data,
                                                   rinputs.word.d);
          this.recv_count := count_inc;
        end if;
      end if;
    end if;
    rbus_node_outputs(this.recv_node, '0', scratch, routputs, rack);
    rbus_node_inputs(this.send_node, IDLE_8B, stall_i, scratch, rinputs);
    -- start node is always in transmit mode
    routputs.mode := TRANSMIT;
    -- decide what to send on bus
    routputs.word := IDLE_8B;
    if this.send_state = SEND_OFFSET
      or this.send_state = SEND_READ
      or this.send_state = SEND_WRITE
    then
      if this.send_count = 0 then
        routputs.word := cmd_word_8b(this.request.cmd, this.request.hops);
      else
        routputs.word := data_word_8b(
          this.request.send_data(this.request.send_data'left downto
                                 this.request.send_data'left
                                 - routputs.word.d'length + 1));
      end if;
    end if;
    rbus_node_outputs(this.send_node, stall_i, scratch, routputs, rack);
    if this.send_count /= state_count'high then
      count_inc := this.send_count + 1;
    else
      count_inc := this.send_count;
    end if;
    if rack = '1' then
      if this.send_count /= 0 then
        this.request.send_data := shift_out_left(this.request.send_data,
                                                 routputs.word.d'length);
      end if;
      if this.send_state = SEND_OFFSET then
        if this.send_count = 4 then
          -- send address complete
          if data_i.rd = '1' then
            this.send_state := SEND_READ;
            this.request.cmd := READ;
            this.request.send_data := (others => '0');
          else
            this.send_state := SEND_WRITE;
            this.request.cmd := WRITE;
            this.request.send_data := data_i.d;
          end if;
          this.send_count := 0;
        else
          this.send_count := count_inc;
        end if;
      elsif this.send_state = SEND_READ or this.send_state = SEND_WRITE then
        if this.send_count = 4 then
          -- send complete
          if this.send_state = SEND_WRITE then
            -- done sending write data, so the data bus request is complete
            -- TODO: Could ACK even earlier after first registering the address
            -- and data to write. But would need some sort of back pressure...
            this.data_o.ack := '1';
            this.data_o.d := (others => '0');
          end if;
          this.send_state := IDLE;
          this.send_count := 0;
        else
          this.send_count := count_inc;
        end if;
      end if;
    end if;
this_c <= this;
  end process;
  p_r0 : process(clk, rst)
  begin
     if rst='1' then
        this_r <= RBUS_DATA_MASTER_RESET;
     elsif clk='1' and clk'event then
        this_r <= this_c;
     end if;
  end process;
  data_o <= this_r.data_o;
  bus_o <= this_r.send_node.bus_o.word;
  stall_o <= this_r.recv_node.bus_o.stall;
end arch;
