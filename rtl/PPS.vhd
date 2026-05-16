library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PPS is-- programmable pulse sequencer
    generic (
        ADDR_WIDTH            : positive := 8;
        DATA_WIDTH            : positive := 64;
        OPCODE_WIDTH          : positive := 2;
        PULSE_DURATION_WIDTH  : positive := 16;
        PULSE_AMPLITUDE_WIDTH : positive := 8;
        PULSE_PHASE_WIDTH     : positive := 5;
        PULSE_FREQUENCY_WIDTH : positive := 8;
        PULSE_WAVEFORM_WIDTH  : positive := 2;
        TRIGGER_WIDTH         : positive := 3;
        FEEDBACK_WIDTH        : positive := 3
    );
    port (
        clock           : in  std_logic;
        reset           : in  std_logic;
        data_w          : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        addr_w          : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
        en_w            : in  std_logic;
        start_sequence  : in  std_logic;
        feedback_in     : in  std_logic_vector(FEEDBACK_WIDTH - 1 downto 0);
        trigger         : out std_logic_vector(TRIGGER_WIDTH - 1 downto 0);
        pulse_en        : out std_logic;
        pulse_amplitude : out std_logic_vector(PULSE_AMPLITUDE_WIDTH - 1 downto 0);
        pulse_phase     : out std_logic_vector(PULSE_PHASE_WIDTH - 1 downto 0);
        pulse_frequency : out std_logic_vector(PULSE_FREQUENCY_WIDTH - 1 downto 0);
        pulse_waveform  : out std_logic_vector(PULSE_WAVEFORM_WIDTH - 1 downto 0);
        computing       : out std_logic;
        computing_end   : out std_logic;
        error           : out std_logic
    );
end entity PPS;

architecture structural of PPS is

    component FSM is
        generic (
            ADDR_WIDTH            : positive := 8;
            DATA_WIDTH            : positive := 64;
            OPCODE_WIDTH          : positive := 2;
            PULSE_DURATION_WIDTH  : positive := 16;
            PULSE_AMPLITUDE_WIDTH : positive := 8;
            PULSE_PHASE_WIDTH     : positive := 5;
            PULSE_FREQUENCY_WIDTH : positive := 8;
            PULSE_WAVEFORM_WIDTH  : positive := 2;
            TRIGGER_WIDTH         : positive := 3;
            FEEDBACK_WIDTH        : positive := 3
        );
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            start_sequence  : in  std_logic;
            error_out       : out std_logic;
            computing       : out std_logic;
            computation_end : out std_logic;
            data_r          : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
            addr_r          : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
            timer_end       : in  std_logic;
            timer_value     : out std_logic_vector(PULSE_DURATION_WIDTH - 1 downto 0);
            timer_start     : out std_logic;
            pulse_amplitude : out std_logic_vector(PULSE_AMPLITUDE_WIDTH - 1 downto 0);
            pulse_phase     : out std_logic_vector(PULSE_PHASE_WIDTH - 1 downto 0);
            pulse_frequency : out std_logic_vector(PULSE_FREQUENCY_WIDTH - 1 downto 0);
            pulse_waveform  : out std_logic_vector(PULSE_WAVEFORM_WIDTH - 1 downto 0);
            pulse_enable    : out std_logic;
            trigger_out     : out std_logic_vector(TRIGGER_WIDTH - 1 downto 0);
            feedback_in     : in  std_logic_vector(FEEDBACK_WIDTH - 1 downto 0)
        );
    end component FSM;


    component RAM is
        generic (
            DATA_WIDTH : positive := 64;
            ADDR_WIDTH : positive := 8
        );
        port (
            clk    : in  std_logic;
            reset  : in  std_logic;
            en_w   : in  std_logic;
            addr_w : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data_w : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
            addr_r : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data_r : out std_logic_vector(DATA_WIDTH - 1 downto 0)
        );
    end component RAM;

    component timer is
        generic (
            PULSE_DURATION_WIDTH : positive := 16
        );
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            time_value  : in  std_logic_vector(PULSE_DURATION_WIDTH - 1 downto 0);
            timer_start : in  std_logic;
            timer_end   : out std_logic
        );
    end component timer;


    signal data_r      : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal addr_r        : std_logic_vector(ADDR_WIDTH - 1 downto 0);
    signal timer_end : std_logic;
    signal timer_value : std_logic_vector(PULSE_DURATION_WIDTH - 1 downto 0);
    signal timer_start : std_logic;

begin
    -- istanziazione della FSM
    u_fsm : FSM
        generic map (
            ADDR_WIDTH            => ADDR_WIDTH,
            DATA_WIDTH            => DATA_WIDTH,
            OPCODE_WIDTH          => OPCODE_WIDTH,
            PULSE_DURATION_WIDTH  => PULSE_DURATION_WIDTH,
            PULSE_AMPLITUDE_WIDTH => PULSE_AMPLITUDE_WIDTH,
            PULSE_PHASE_WIDTH     => PULSE_PHASE_WIDTH,
            PULSE_FREQUENCY_WIDTH => PULSE_FREQUENCY_WIDTH,
            PULSE_WAVEFORM_WIDTH  => PULSE_WAVEFORM_WIDTH,
            TRIGGER_WIDTH         => TRIGGER_WIDTH,
            FEEDBACK_WIDTH        => FEEDBACK_WIDTH
        )
        port map (
            clk             => clock,
            reset           => reset,
            start_sequence  => start_sequence,
            error_out       => error,
            computing       => computing,
            computation_end => computing_end,
            data_r          => data_r,
            addr_r          => addr_r,
            timer_end       => timer_end,
            timer_value     => timer_value,
            timer_start     => timer_start,
            pulse_amplitude => pulse_amplitude,
            pulse_phase     => pulse_phase,
            pulse_frequency => pulse_frequency,
            pulse_waveform  => pulse_waveform,
            pulse_enable    => pulse_en,
            trigger_out     => trigger,
            feedback_in     => feedback_in 
        );

    -- Istanziazione della RAM
    u_ram : RAM
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk    => clock,
            reset  => reset,
            en_w   => en_w,
            addr_w => addr_w,
            data_w => data_w,
            addr_r => addr_r,
            data_r => data_r
        );

    -- Istanziazione del Timer
    u_timer : timer
        generic map (
            PULSE_DURATION_WIDTH => PULSE_DURATION_WIDTH
        )
        port map (
            clk         => clock,
            reset       => reset,
            time_value  => timer_value,
            timer_start => timer_start,
            timer_end   => timer_end
        );
end architecture;