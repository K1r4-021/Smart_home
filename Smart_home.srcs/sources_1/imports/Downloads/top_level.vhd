library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_level is
    port (
        clk              : in  std_logic;

        -- 00 = Reset, 01 = Normal, 10 = Away, 11 = Night
        control_mode     : in  std_logic_vector(1 downto 0) := "00";

        -- Sensors and requests
        temperature      : in  std_logic_vector(7 downto 0);
        person           : in  std_logic;
        door_request     : in  std_logic;
        password_entered : in  std_logic_vector(3 downto 0);
        door_forced      : in  std_logic;
        smoke            : in  std_logic;
        emergency_button : in  std_logic;

        -- Outputs
        fan_mode         : out std_logic_vector(1 downto 0);
        light_on         : out std_logic;
        door_open        : out std_logic;
        door_locked      : out std_logic;
        alarm            : out std_logic;
        secure_home      : out std_logic;
        lockout_active   : out std_logic
    );
end entity top_level;

architecture rtl of top_level is

    signal cpu_reset : std_logic;

    -- KCPSM3 processor interface
    signal address       : std_logic_vector(9 downto 0);
    signal instruction   : std_logic_vector(17 downto 0);
    signal port_id       : std_logic_vector(7 downto 0);
    signal out_port      : std_logic_vector(7 downto 0);
    signal in_port       : std_logic_vector(7 downto 0);
    signal write_strobe  : std_logic;
    signal read_strobe   : std_logic;
    signal interrupt_ack : std_logic;

    -- Input port 01h:
    -- bit0 = person
    -- bit1 = door_request
    -- bit2 = door_forced
    -- bit3 = smoke
    -- bit4 = emergency_button
    signal sensor_bits : std_logic_vector(7 downto 0);

    -- Output port 10h:
    -- bits 1:0 = fan_mode
    -- bit2     = light_on
    -- bit3     = door_open / unlock command
    -- bit4     = door_locked
    -- bit5     = alarm
    -- bit6     = secure_home
    -- bit7     = lockout_active
    signal output_latch : std_logic_vector(7 downto 0)
                         := x"10";

    signal emergency_alarm_latch : std_logic := '0';

    -- 100 MHz clock: 1,000,000 cycles = 10 ms.
    constant TICK_PERIOD_CYCLES : natural := 1000000;
    constant TICK_HIGH_CYCLES   : natural := 1000;

    signal tick_counter : natural range
        0 to TICK_PERIOD_CYCLES - 1 := 0;

    signal tick_10ms : std_logic := '0';

begin

    ------------------------------------------------------------
    -- CONTROL MODE / RESET
    ------------------------------------------------------------

    cpu_reset <= '1' when control_mode = "00" else '0';


    ------------------------------------------------------------
    -- SENSOR PACKING
    ------------------------------------------------------------

    sensor_bits <=
        "000" &
        emergency_button &
        smoke &
        door_forced &
        door_request &
        person;


    ------------------------------------------------------------
    -- KCPSM3 PROCESSOR
    ------------------------------------------------------------

    processor : entity work.kcpsm3
        port map (
            address       => address,
            instruction   => instruction,
            port_id       => port_id,
            write_strobe  => write_strobe,
            out_port      => out_port,
            read_strobe   => read_strobe,
            in_port       => in_port,
            interrupt     => '0',
            interrupt_ack => interrupt_ack,
            reset         => cpu_reset,
            clk           => clk
        );


    ------------------------------------------------------------
    -- PROGRAM ROM
    ------------------------------------------------------------

    program_rom : entity work.smart_home
        port map (
            address     => address,
            instruction => instruction,
            clk         => clk
        );


    ------------------------------------------------------------
    -- INPUT PORT MULTIPLEXER
    ------------------------------------------------------------

    input_port_mux : process (
        port_id,
        control_mode,
        sensor_bits,
        password_entered,
        temperature,
        tick_10ms
    )
    begin
        in_port <= (others => '0');

        case port_id is
            when x"00" =>
                in_port <= "000000" & control_mode;

            when x"01" =>
                in_port <= sensor_bits;

            when x"02" =>
                in_port <= "0000" & password_entered;

            when x"03" =>
                in_port <= temperature;

            when x"04" =>
                in_port <= "0000000" & tick_10ms;

            when others =>
                in_port <= (others => '0');
        end case;
    end process input_port_mux;


    ------------------------------------------------------------
    -- 10 ms TIMER TICK GENERATOR
    ------------------------------------------------------------

    timer_process : process (clk)
    begin
        if rising_edge(clk) then
            if cpu_reset = '1' then
                tick_counter <= 0;
                tick_10ms <= '0';
            else
                if tick_counter = TICK_PERIOD_CYCLES - 1 then
                    tick_counter <= 0;
                else
                    tick_counter <= tick_counter + 1;
                end if;

                if tick_counter < TICK_HIGH_CYCLES then
                    tick_10ms <= '1';
                else
                    tick_10ms <= '0';
                end if;
            end if;
        end if;
    end process timer_process;


    ------------------------------------------------------------
    -- OUTPUT PORT LATCH
    ------------------------------------------------------------

    output_process : process (clk)
    begin
        if rising_edge(clk) then
            if cpu_reset = '1' then
                output_latch <= x"10";
            elsif write_strobe = '1' and port_id = x"10" then
                output_latch <= out_port;
            end if;
        end if;
    end process output_process;


    ------------------------------------------------------------
    -- EMERGENCY ALARM LATCH
    ------------------------------------------------------------

    emergency_alarm_process : process (clk)
    begin
        if rising_edge(clk) then
            if cpu_reset = '1' then
                emergency_alarm_latch <= '0';
            elsif emergency_button = '1' then
                emergency_alarm_latch <= '1';
            end if;
        end if;
    end process emergency_alarm_process;


    ------------------------------------------------------------
    -- OUTPUT ASSIGNMENTS
    ------------------------------------------------------------

    fan_mode       <= output_latch(1 downto 0);
    light_on       <= output_latch(2);
    door_open      <= output_latch(3);
    door_locked    <= output_latch(4);

    -- Alarm from PSM or emergency-button latch.
    alarm          <= output_latch(5) or emergency_alarm_latch;

    -- Set by PSM output bit 6 when Away mode is selected.
    secure_home    <= output_latch(6);

    lockout_active <= output_latch(7);

end architecture rtl;