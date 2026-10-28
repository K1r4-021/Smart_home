library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.ENV.ALL;

entity top_level_tb is
end entity top_level_tb;

architecture simulation of top_level_tb is

    constant CLK_PERIOD  : time := 10 ns;
    constant SETTLE_TIME : time := 100 us;

    -- Inputs
    signal clk              : std_logic := '0';
    signal control_mode     : std_logic_vector(1 downto 0) := "00";
    signal temperature      : std_logic_vector(7 downto 0) := x"00";
    signal person           : std_logic := '0';
    signal door_request     : std_logic := '0';
    signal password_entered : std_logic_vector(3 downto 0) := "0000";
    signal door_forced      : std_logic := '0';
    signal smoke            : std_logic := '0';
    signal emergency_button : std_logic := '0';

    -- Outputs
    signal fan_mode         : std_logic_vector(1 downto 0);
    signal light_on         : std_logic;
    signal door_open        : std_logic;
    signal door_locked      : std_logic;
    signal alarm            : std_logic;
    signal secure_home      : std_logic;
    signal lockout_active   : std_logic;

begin

    ------------------------------------------------------------
    -- DEVICE UNDER TEST
    ------------------------------------------------------------

    dut : entity work.top_level
        port map (
            clk              => clk,
            control_mode     => control_mode,
            temperature      => temperature,
            person           => person,
            door_request     => door_request,
            password_entered => password_entered,
            door_forced      => door_forced,
            smoke            => smoke,
            emergency_button => emergency_button,
            fan_mode         => fan_mode,
            light_on         => light_on,
            door_open        => door_open,
            door_locked      => door_locked,
            alarm            => alarm,
            secure_home      => secure_home,
            lockout_active   => lockout_active
        );


    ------------------------------------------------------------
    -- 100 MHz CLOCK
    ------------------------------------------------------------

    clock_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;


    ------------------------------------------------------------
    -- TEST SEQUENCE
    ------------------------------------------------------------

    stimulus_process : process
    begin

        --------------------------------------------------------
        -- TEST 1: DEFAULT RESET MODE
        --------------------------------------------------------

        report "TEST 1: Reset mode" severity note;

        control_mode <= "00";
        wait for SETTLE_TIME;

        assert fan_mode = "00"
            report "FAIL: Fan should be OFF during reset"
            severity error;

        assert light_on = '0'
            report "FAIL: Light should be OFF during reset"
            severity error;

        assert door_locked = '1'
            report "FAIL: Door should be locked during reset"
            severity error;

        assert door_open = '0'
            report "FAIL: Door unlock command should be OFF during reset"
            severity error;

        assert alarm = '0'
            report "FAIL: Alarm should be OFF during reset"
            severity error;

        assert secure_home = '0'
            report "FAIL: secure_home should be 0 during reset"
            severity error;

        assert lockout_active = '0'
            report "FAIL: Lockout should be inactive during reset"
            severity error;


        --------------------------------------------------------
        -- TEST 2: NORMAL MODE
        --------------------------------------------------------

        report "TEST 2: Normal mode" severity note;

        control_mode <= "01";
        temperature <= std_logic_vector(to_unsigned(20, 8));
        wait for SETTLE_TIME;

        assert secure_home = '0'
            report "FAIL: secure_home should be 0 in Normal mode"
            severity error;

        assert fan_mode = "00"
            report "FAIL: Fan should be OFF at 20 C"
            severity error;


        --------------------------------------------------------
        -- TEST 3: AWAY MODE AND SECURE_HOME
        --------------------------------------------------------

        report "TEST 3: Away mode secure_home status"
            severity note;

        control_mode <= "10";
        wait for SETTLE_TIME;

        assert secure_home = '1'
            report "FAIL: secure_home should be 1 in Away mode"
            severity error;

        assert fan_mode = "00"
            report "FAIL: Fan should be OFF in Away mode"
            severity error;

        assert light_on = '0'
            report "FAIL: Light should be OFF in Away mode"
            severity error;


        --------------------------------------------------------
        -- TEST 4: PERSON DETECTION IN AWAY MODE
        --------------------------------------------------------

        report "TEST 4: Person detected in Away mode"
            severity note;

        person <= '1';
        wait for SETTLE_TIME;

        assert alarm = '1'
            report "FAIL: Person detection in Away mode should activate alarm"
            severity error;

        assert secure_home = '1'
            report "FAIL: secure_home should remain 1 in Away mode"
            severity error;

        person <= '0';

        -- Reset clears the latched alarm.
        control_mode <= "00";
        wait for SETTLE_TIME;

        assert alarm = '0'
            report "FAIL: Reset should clear alarm"
            severity error;


        --------------------------------------------------------
        -- TEST 5: NIGHT MODE
        --------------------------------------------------------

        report "TEST 5: Night mode" severity note;

        control_mode <= "11";
        temperature <= std_logic_vector(to_unsigned(25, 8));
        person <= '1';
        wait for SETTLE_TIME;

        assert secure_home = '0'
            report "FAIL: secure_home should be 0 in Night mode"
            severity error;

        assert light_on = '0'
            report "FAIL: Light should be OFF in Night mode"
            severity error;

        assert fan_mode = "10"
            report "FAIL: Fan should be MEDIUM at 25 C in Night mode"
            severity error;

        person <= '0';


        --------------------------------------------------------
        -- TEST 6: FAN THRESHOLDS IN NORMAL MODE
        --------------------------------------------------------

        report "TEST 6: Fan threshold tests" severity note;

        control_mode <= "01";

        temperature <= std_logic_vector(to_unsigned(20, 8));
        wait for SETTLE_TIME;
        assert fan_mode = "00"
            report "FAIL: Fan should be OFF at 20 C"
            severity error;

        temperature <= std_logic_vector(to_unsigned(21, 8));
        wait for SETTLE_TIME;
        assert fan_mode = "01"
            report "FAIL: Fan should be LOW at 21 C"
            severity error;

        temperature <= std_logic_vector(to_unsigned(25, 8));
        wait for SETTLE_TIME;
        assert fan_mode = "10"
            report "FAIL: Fan should be MEDIUM at 25 C"
            severity error;

        temperature <= std_logic_vector(to_unsigned(35, 8));
        wait for SETTLE_TIME;
        assert fan_mode = "11"
            report "FAIL: Fan should be HIGH at 35 C"
            severity error;


        --------------------------------------------------------
        -- TEST 7: NORMAL LIGHTING
        --------------------------------------------------------

        report "TEST 7: Normal mode lighting" severity note;

        temperature <= std_logic_vector(to_unsigned(20, 8));
        person <= '1';
        wait for SETTLE_TIME;

        assert light_on = '1'
            report "FAIL: Person detection should turn light ON"
            severity error;

        person <= '0';
        wait for SETTLE_TIME;

        assert light_on = '1'
            report "FAIL: Light should remain ON before timeout"
            severity error;


        --------------------------------------------------------
        -- TEST 8: SMOKE ALARM
        --------------------------------------------------------

        report "TEST 8: Smoke alarm" severity note;

        smoke <= '1';
        wait for SETTLE_TIME;

        assert alarm = '1'
            report "FAIL: Smoke should activate alarm"
            severity error;

        smoke <= '0';
        control_mode <= "00";
        wait for SETTLE_TIME;

        assert alarm = '0'
            report "FAIL: Reset should clear smoke alarm"
            severity error;


        --------------------------------------------------------
        -- TEST 9: FORCED ENTRY ALARM
        --------------------------------------------------------

        report "TEST 9: Forced-entry alarm" severity note;

        control_mode <= "01";
        door_forced <= '1';
        wait for SETTLE_TIME;

        assert alarm = '1'
            report "FAIL: Forced entry should activate alarm"
            severity error;

        door_forced <= '0';
        control_mode <= "00";
        wait for SETTLE_TIME;


        --------------------------------------------------------
        -- TEST 10: EMERGENCY BUTTON
        --------------------------------------------------------

        report "TEST 10: Emergency button activates alarm"
            severity note;

        control_mode <= "01";
        emergency_button <= '1';
        wait for SETTLE_TIME;

        assert alarm = '1'
            report "FAIL: Emergency button should activate alarm"
            severity error;

        emergency_button <= '0';
        control_mode <= "00";
        wait for SETTLE_TIME;


        --------------------------------------------------------
        -- TEST 11: CORRECT PASSWORD
        --------------------------------------------------------

        report "TEST 11: Correct door password" severity note;

        control_mode <= "01";
        password_entered <= "1010";
        door_request <= '0';
        wait for SETTLE_TIME;

        door_request <= '1';
        wait for SETTLE_TIME;

        assert door_open = '1'
            report "FAIL: Correct password should unlock door"
            severity error;

        assert door_locked = '0'
            report "FAIL: Door should be unlocked after correct password"
            severity error;

        door_request <= '0';
        wait for SETTLE_TIME;


        --------------------------------------------------------
        -- TEST 12: RESET LOCKS DOOR
        --------------------------------------------------------

        report "TEST 12: Reset locks door" severity note;

        control_mode <= "00";
        wait for SETTLE_TIME;

        assert door_open = '0'
            report "FAIL: Door unlock command should clear on reset"
            severity error;

        assert door_locked = '1'
            report "FAIL: Door should be locked after reset"
            severity error;

        assert secure_home = '0'
            report "FAIL: secure_home should be 0 after reset"
            severity error;


        --------------------------------------------------------
        -- TEST 13: THREE INCORRECT PASSWORD ATTEMPTS
        --------------------------------------------------------

        report "TEST 13: Password lockout" severity note;

        control_mode <= "01";
        password_entered <= "0011";
        door_request <= '0';
        wait for SETTLE_TIME;

        -- Attempt 1
        door_request <= '1';
        wait for SETTLE_TIME;
        door_request <= '0';
        wait for SETTLE_TIME;

        assert lockout_active = '0'
            report "FAIL: Lockout should not activate after one attempt"
            severity error;

        -- Attempt 2
        door_request <= '1';
        wait for SETTLE_TIME;
        door_request <= '0';
        wait for SETTLE_TIME;

        assert lockout_active = '0'
            report "FAIL: Lockout should not activate after two attempts"
            severity error;

        -- Attempt 3
        door_request <= '1';
        wait for SETTLE_TIME;

        assert lockout_active = '1'
            report "FAIL: Lockout should activate after three attempts"
            severity error;

        door_request <= '0';
        wait for SETTLE_TIME;


        --------------------------------------------------------
        -- TEST 14: RESET CLEARS LOCKOUT
        --------------------------------------------------------

        report "TEST 14: Reset clears lockout" severity note;

        control_mode <= "00";
        wait for SETTLE_TIME;

        assert lockout_active = '0'
            report "FAIL: Reset should clear lockout"
            severity error;

        assert door_locked = '1'
            report "FAIL: Door should be locked after reset"
            severity error;


        --------------------------------------------------------
        -- TEST COMPLETE
        --------------------------------------------------------

        report "All testbench checks completed."
            severity note;

        stop;
        wait;

    end process;

end architecture simulation;