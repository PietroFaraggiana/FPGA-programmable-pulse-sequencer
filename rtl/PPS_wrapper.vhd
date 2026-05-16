library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PPS_wrapper is
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
    clock           : in std_logic;
    reset           : in std_logic;
    data_w          : in std_logic_vector(DATA_WIDTH - 1 downto 0);
    addr_w          : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
    en_w            : in std_logic;
    start_sequence  : in std_logic;
    feedback_in     : in std_logic_vector(FEEDBACK_WIDTH - 1 downto 0);
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
end entity PPS_wrapper;

architecture structural of PPS_wrapper is

  component PPS is
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
      clock           : in std_logic;
      reset           : in std_logic;
      data_w          : in std_logic_vector(DATA_WIDTH - 1 downto 0);
      addr_w          : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
      en_w            : in std_logic;
      start_sequence  : in std_logic;
      feedback_in     : in std_logic_vector(FEEDBACK_WIDTH - 1 downto 0);
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
  end component PPS;
  -- segnali per i registri IO
  signal s_data_w          : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal s_addr_w          : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal s_en_w            : std_logic;
  signal s_start_sequence  : std_logic;
  signal s_feedback_in     : std_logic_vector(FEEDBACK_WIDTH - 1 downto 0);
  signal i_trigger         : std_logic_vector(TRIGGER_WIDTH - 1 downto 0);
  signal i_pulse_en        : std_logic;
  signal i_pulse_amplitude : std_logic_vector(PULSE_AMPLITUDE_WIDTH - 1 downto 0);
  signal i_pulse_phase     : std_logic_vector(PULSE_PHASE_WIDTH - 1 downto 0);
  signal i_pulse_frequency : std_logic_vector(PULSE_FREQUENCY_WIDTH - 1 downto 0);
  signal i_pulse_waveform  : std_logic_vector(PULSE_WAVEFORM_WIDTH - 1 downto 0);
  signal i_computing       : std_logic;
  signal i_computing_end   : std_logic;
  signal i_error           : std_logic;

begin

  u_pps_core : PPS
  generic map(
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
  port map
  (
    clock           => clock,
    reset           => reset,
    data_w          => s_data_w,
    addr_w          => s_addr_w,
    en_w            => s_en_w,
    start_sequence  => s_start_sequence,
    feedback_in     => s_feedback_in,
    trigger         => i_trigger,
    pulse_en        => i_pulse_en,
    pulse_amplitude => i_pulse_amplitude,
    pulse_phase     => i_pulse_phase,
    pulse_frequency => i_pulse_frequency,
    pulse_waveform  => i_pulse_waveform,
    computing       => i_computing,
    computing_end   => i_computing_end,
    error           => i_error
  );
  p_input_r : process (clock)
  begin
    if rising_edge(clock) then
      if (reset = '1') then
        s_data_w         <= (others => '0');
        s_addr_w         <= (others => '0');
        s_en_w           <= '0';
        s_start_sequence <= '0';
        s_feedback_in    <= (others => '0');
      else
        s_data_w         <= data_w;
        s_addr_w         <= addr_w;
        s_en_w           <= en_w;
        s_start_sequence <= start_sequence;
        s_feedback_in    <= feedback_in;
      end if;
    end if;
  end process;

  p_output_r : process (clock)
  begin
    if rising_edge(clock) then
      if (reset = '1') then
        trigger         <= (others => '0');
        pulse_en        <= '0';
        pulse_amplitude <= (others => '0');
        pulse_phase     <= (others => '0');
        pulse_frequency <= (others => '0');
        pulse_waveform  <= (others => '0');
        computing       <= '0';
        computing_end   <= '0';
        error           <= '0';
      else
        trigger         <= i_trigger;
        pulse_en        <= i_pulse_en;
        pulse_amplitude <= i_pulse_amplitude;
        pulse_phase     <= i_pulse_phase;
        pulse_frequency <= i_pulse_frequency;
        pulse_waveform  <= i_pulse_waveform;
        computing       <= i_computing;
        computing_end   <= i_computing_end;
        error           <= i_error;
      end if;
    end if;
  end process;

end architecture;