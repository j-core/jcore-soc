library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.test_pkg.all;
use work.ring_bus_pack.all;

entity word_tap is
end;

architecture tb  of word_tap is
begin
  process
  begin
    test_plan(16, "bus words");

    test_equal(cmd_word_9b(IDLE, 0).fr, '1', "cmd8 has fr 1");
    test_equal(data_word_9b(x"12" & '0').fr, '0', "data9 has fr 0");

    test_equal(cmd_word_8b(IDLE, 0).fr, '1', "cmd8 has fr 1");
    test_equal(data_word_8b(x"12").fr, '0', "data9 has fr 0");

    test_ok(to_cmd(cmd_word_8b(IDLE, 0).d) = IDLE, "cmd8 is IDLE");
    test_ok(to_cmd(cmd_word_8b(WRITE, 2).d) = WRITE, "cmd8 is WRITE");
    test_equal(to_hops(cmd_word_8b(IDLE, 0).d), 0, "cmd8 zero hops");
    test_equal(to_hops(cmd_word_8b(WRITE, 2).d), 2, "cmd8 hops");

    test_ok(to_cmd(cmd_word_9b(IDLE, 0).d) = IDLE, "cmd9 is IDLE");
    test_ok(to_cmd(cmd_word_9b(WRITE, 2).d) = WRITE, "cmd9 is WRITE");
    test_equal(to_hops(cmd_word_9b(IDLE, 0).d), 0, "cmd9 zero hops");
    test_equal(to_hops(cmd_word_9b(WRITE, 2).d), 2, "cmd9 hops");

    test_ok(is_idle(cmd_word_9b(IDLE, 0)), "cmd9 is_idle IDLE");
    test_ok(not is_idle(cmd_word_9b(READ, 0)), "cmd9 is_idle READ");
    test_ok(is_idle(cmd_word_8b(IDLE, 0)), "cmd8 is_idle IDLE");
    test_ok(not is_idle(cmd_word_8b(READ, 0)), "cmd8 is_idle READ");
    wait;
    end process;
end tb;
