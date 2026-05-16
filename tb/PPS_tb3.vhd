-- commento per chi esamina il codice: questo tb necessita usare come top entity ppstb anziche pps. Questo perché mi era necessario monitorare l'indirizzo di lettura della ram.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PPS_tb3 is
end entity PPS_tb3;

architecture behavior of PPS_tb3 is

  constant ADDR_WIDTH            : positive := 8;
  constant DATA_WIDTH            : positive := 64;
  constant OPCODE_WIDTH          : positive := 2;
  constant PULSE_DURATION_WIDTH  : positive := 16;
  constant PULSE_AMPLITUDE_WIDTH : positive := 8;
  constant PULSE_PHASE_WIDTH     : positive := 5;
  constant PULSE_FREQUENCY_WIDTH : positive := 8;
  constant PULSE_WAVEFORM_WIDTH  : positive := 2;
  constant TRIGGER_WIDTH         : positive := 3;
  constant FEEDBACK_WIDTH        : positive := 3;

  constant CLK_PERIOD : time := 10 ps;

  signal s_clock           : std_logic := '0';
  signal s_reset           : std_logic;
  signal s_data_w          : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal s_addr_w          : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal s_en_w            : std_logic;
  signal s_start_sequence  : std_logic;
  signal s_feedback_in     : std_logic_vector(FEEDBACK_WIDTH - 1 downto 0);
  signal s_trigger         : std_logic_vector(TRIGGER_WIDTH - 1 downto 0);
  signal s_pulse_en        : std_logic;
  signal s_pulse_amplitude : std_logic_vector(PULSE_AMPLITUDE_WIDTH - 1 downto 0);
  signal s_pulse_phase     : std_logic_vector(PULSE_PHASE_WIDTH - 1 downto 0);
  signal s_pulse_frequency : std_logic_vector(PULSE_FREQUENCY_WIDTH - 1 downto 0);
  signal s_computing       : std_logic;
  signal s_computing_end   : std_logic;
  signal s_error           : std_logic;
  signal s_fsm_current_addr : std_logic_vector(ADDR_WIDTH - 1 downto 0);

  -- | Opcode | Duration | Amplitude | Phase | Frequency | Waveform | Trigger | Feedback | Unused |
  constant INST0 : std_logic_vector(DATA_WIDTH - 1 downto 0) :=
  "01" & -- Opcode
  "0000000000001010" & -- Duration
  "01100110" & -- Amplitude
  "00101" & -- Phase
  "00010100" & -- Frequency
  "01" & -- Waveform
  "011" & -- Trigger
  "0" & -- Feedback_Mode
  "000" & -- Feedback_Value
  "0000000000000000"; -- Unused

  constant INST1 : std_logic_vector(DATA_WIDTH - 1 downto 0) :=
  "01" & -- Opcode
  "0000000000000010" & -- Duration
  "00100110" & -- Amplitude
  "00001" & -- Phase
  "00011100" & -- Frequency
  "11" & -- Waveform
  "000" & -- Trigger
  "1" & -- Feedback_Mode
  "001" & -- Feedback_Value 
  "0000000000000000"; -- Unused

  constant INST2 : std_logic_vector(DATA_WIDTH - 1 downto 0) :=
  "10" & -- Opcode
  "0000000000001011" & -- Duration
  "00000000" & -- Amplitude
  "00000" & -- Phase
  "00000000" & -- Frequency
  "00" & -- Waveform
  "000" & -- Trigger
  "1" & -- Feedback_Mode
  "000" & -- Feedback_Value 
  "0000000000000000"; -- Unused

  constant INST3 : std_logic_vector(DATA_WIDTH - 1 downto 0) :=
  "01" & -- Opcode
  "0000000010001010" & -- Duration
  "01100011" & -- Amplitude
  "00100" & -- Phase
  "00011100" & -- Frequency
  "11" & -- Waveform
  "000" & -- Trigger
  "1" & -- Feedback_Mode
  "010" & -- Feedback_Value 
  "0000000000000000"; -- Unused

  constant INST4 : std_logic_vector(DATA_WIDTH - 1 downto 0) :=
  "01" & -- Opcode
  "0000000000100110" & -- Duration
  "00101010" & -- Amplitude
  "00001" & -- Phase
  "00011100" & -- Frequency
  "01" & -- Waveform
  "000" & -- Trigger
  "1" & -- Feedback_Mode
  "101" & -- Feedback_Value 
  "0000000000000000"; -- Unused

  constant INST5 : std_logic_vector(DATA_WIDTH - 1 downto 0) :=
  "01" & -- Opcode
  "0000000000010010" & -- Duration
  "11100111" & -- Amplitude
  "00111" & -- Phase
  "00000100" & -- Frequency
  "01" & -- Waveform
  "010" & -- Trigger
  "0" & -- Feedback_Mode
  "000" & -- Feedback_Value 
  "0000000000000000"; -- Unused

    constant INST6 : std_logic_vector(DATA_WIDTH - 1 downto 0) :=
  "01" & -- Opcode
  "0000101011001010" & -- Duration
  "01100110" & -- Amplitude
  "00100" & -- Phase
  "00000100" & -- Frequency
  "11" & -- Waveform
  "011" & -- Trigger
  "0" & -- Feedback_Mode
  "000" & -- Feedback_Value
  "0000000000000000"; -- Unused

  constant INST7 : std_logic_vector(DATA_WIDTH - 1 downto 0) :=
  "11" & -- Opcode
  "0000000000000000" & -- Duration
  "00000000" & -- Amplitude
  "00000" & -- Phase
  "00000000" & -- Frequency
  "00" & -- Waveform
  "000" & -- Trigger
  "0" & -- Feedback_Mode
  "000" & -- Feedback_Value
  "0000000000000000"; -- Unused
-- dopo l'analisi su modelsim ho visto che non erano necessarie tutte le istuzioni per osservare quello che volevo vedere, ma solo le prime 4 istruzioni
begin

  -- istanza UUT (Unit Under Test)
  uut : entity work.PPS
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
      clock           => s_clock,
      reset           => s_reset,
      data_w          => s_data_w,
      addr_w          => s_addr_w,
      en_w            => s_en_w,
      start_sequence  => s_start_sequence,
      feedback_in     => s_feedback_in,
      trigger         => s_trigger,
      pulse_en        => s_pulse_en,
      pulse_amplitude => s_pulse_amplitude,
      pulse_phase     => s_pulse_phase,
      pulse_frequency => s_pulse_frequency,
      computing       => s_computing,
      computing_end   => s_computing_end,
      error           => s_error,
      fsm_read_addr_out => s_fsm_current_addr
    );

  -- clock
  clk_process : process
  begin
    loop
      s_clock <= '0';
      wait for CLK_PERIOD / 2;
      s_clock <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
  end process clk_process;

  -- stimulus
  p_stimulus : process
  begin
    -- inizializzazione
    s_reset          <= '1';
    s_en_w           <= '0';
    s_start_sequence <= '0';
    s_feedback_in    <= (others => '0');
    s_data_w         <= (others => '0');
    s_addr_w         <= (others => '0');
    wait for 2 * CLK_PERIOD;
    s_reset <= '0';
    wait for CLK_PERIOD;

    -- scrittura istruzioni nella RAM
    s_en_w <= '1';
    wait for CLK_PERIOD;

    -- istruzione 0
    s_addr_w <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
    s_data_w <= INST0;
    wait for CLK_PERIOD;

    -- istruzione 1
    s_addr_w <= std_logic_vector(to_unsigned(1, ADDR_WIDTH));
    s_data_w <= INST1;
    wait for CLK_PERIOD;

    -- istruzione 2
    s_addr_w <= std_logic_vector(to_unsigned(2, ADDR_WIDTH));
    s_data_w <= INST2;
    wait for CLK_PERIOD;

    -- istruzione 3
    s_addr_w <= std_logic_vector(to_unsigned(3, ADDR_WIDTH));
    s_data_w <= INST3;
    wait for CLK_PERIOD;

    -- istruzione 4
    s_addr_w <= std_logic_vector(to_unsigned(4, ADDR_WIDTH));
    s_data_w <= INST4;
    wait for CLK_PERIOD;

    -- istruzione 5
    s_addr_w <= std_logic_vector(to_unsigned(5, ADDR_WIDTH));
    s_data_w <= INST5;
    wait for CLK_PERIOD;

    -- istruzione 6
    s_addr_w <= std_logic_vector(to_unsigned(6, ADDR_WIDTH));
    s_data_w <= INST6;
    wait for CLK_PERIOD;

    -- istruzione 7
    s_addr_w <= std_logic_vector(to_unsigned(7, ADDR_WIDTH));
    s_data_w <= INST7;
    wait for CLK_PERIOD;

    -- Fine scrittura RAM
    s_en_w   <= '0';
    s_addr_w <= (others => '0');
    s_data_w <= (others => '0');
    wait for CLK_PERIOD;

    -- avvio della sequenza
    s_start_sequence <= '1';
    wait for CLK_PERIOD;
    s_start_sequence <= '0';

    --feedback check
    wait until s_fsm_current_addr = std_logic_vector(to_unsigned(1, ADDR_WIDTH));
    wait for 3 * CLK_PERIOD;
    s_feedback_in <= "001";

    wait until s_fsm_current_addr = std_logic_vector(to_unsigned(2, ADDR_WIDTH));
    wait for 3 * CLK_PERIOD;
    s_feedback_in <= "010";

    wait until s_fsm_current_addr = std_logic_vector(to_unsigned(3, ADDR_WIDTH));
    wait for 3 * CLK_PERIOD;
    s_feedback_in <= "001";
    wait for 2 * CLK_PERIOD;
    s_feedback_in <= "000";
    wait for 6 * CLK_PERIOD;
    s_feedback_in <= "011";
    wait; 

  end process;

end architecture;