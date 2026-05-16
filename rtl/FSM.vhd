library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FSM is
  generic (
    ADDR_WIDTH            : positive := 8;
    DATA_WIDTH            : positive := 64;
    OPCODE_WIDTH          : positive := 2; -- larghezza dell'opcode
    PULSE_DURATION_WIDTH  : positive := 16; -- risoluzione del timer
    PULSE_AMPLITUDE_WIDTH : positive := 8; -- risoluzione dell'ampiezza
    PULSE_PHASE_WIDTH     : positive := 5; -- risoluzione della fase
    PULSE_FREQUENCY_WIDTH : positive := 8; -- risoluzione della frequenza
    PULSE_WAVEFORM_WIDTH  : positive := 2; -- numero potenza di due forme d'onda
    TRIGGER_WIDTH         : positive := 3; -- larghezza del segnale di trigger
    FEEDBACK_WIDTH        : positive := 3 -- larghezza del segnale di feedback
  );
  port (
    clk             : in std_logic;
    reset           : in std_logic;
    start_sequence  : in std_logic;
    error_out       : out std_logic;
    computing       : out std_logic;
    computation_end : out std_logic;
    -- segnali per la RAM
    data_r : in std_logic_vector(DATA_WIDTH - 1 downto 0);
    addr_r : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
    -- segnali per il timer
    timer_end   : in std_logic;
    timer_value : out std_logic_vector(PULSE_DURATION_WIDTH - 1 downto 0);
    timer_start : out std_logic;
    -- segnali per gli impulsi
    pulse_amplitude : out std_logic_vector(PULSE_AMPLITUDE_WIDTH - 1 downto 0);
    pulse_phase     : out std_logic_vector(PULSE_PHASE_WIDTH - 1 downto 0);
    pulse_frequency : out std_logic_vector(PULSE_FREQUENCY_WIDTH - 1 downto 0);
    pulse_waveform  : out std_logic_vector(PULSE_WAVEFORM_WIDTH - 1 downto 0);
    pulse_enable    : out std_logic;
    -- segnali di trigger
    trigger_out : out std_logic_vector(TRIGGER_WIDTH - 1 downto 0);
    feedback_in : in std_logic_vector(FEEDBACK_WIDTH - 1 downto 0)
  );
end entity;

architecture Behavioral of FSM is
  -- stati della FSM
  type state_t is (READY, READ_ADDR, READ_DATA, DECODE_INSTRUCTION, WAIT_FEEDBACK, PULSE, DELAY, WAIT_TIMER, DONE, ERROR);
  -- segnali interni
  signal current_state       : state_t; -- se non resetto all'inizio, allora non entro mai in ready
  signal next_state          : state_t;
  signal instruction_counter : unsigned(ADDR_WIDTH - 1 downto 0);
  signal instruction         : std_logic_vector(DATA_WIDTH - 1 downto 0);

  signal decoded_opcode         : std_logic_vector(OPCODE_WIDTH - 1 downto 0);
  signal decoded_duration       : std_logic_vector(PULSE_DURATION_WIDTH - 1 downto 0);
  signal decoded_amplitude      : std_logic_vector(PULSE_AMPLITUDE_WIDTH - 1 downto 0);
  signal decoded_phase          : std_logic_vector(PULSE_PHASE_WIDTH - 1 downto 0);
  signal decoded_frequency      : std_logic_vector(PULSE_FREQUENCY_WIDTH - 1 downto 0);
  signal decoded_waveform       : std_logic_vector(PULSE_WAVEFORM_WIDTH - 1 downto 0);
  signal decoded_trigger        : std_logic_vector(TRIGGER_WIDTH - 1 downto 0);
  signal decoded_feedback_mode  : std_logic;
  signal decoded_feedback_value : std_logic_vector(FEEDBACK_WIDTH - 1 downto 0);

  -- segnali per la gestione del feedback
  signal memorized_feedback : std_logic_vector(FEEDBACK_WIDTH - 1 downto 0);
  signal feedback_received  : std_logic;

  -- costanti per gli Opcode
  constant OP_PULSE   : std_logic_vector(OPCODE_WIDTH - 1 downto 0) := "01";
  constant OP_DELAY   : std_logic_vector(OPCODE_WIDTH - 1 downto 0) := "10";
  constant OP_END_SEQ : std_logic_vector(OPCODE_WIDTH - 1 downto 0) := "11";

  -- | Opcode | Duration | Amplitude | Phase | Frequency | Waveform | Trigger | Feedback | Unused |
  constant OPCODE_MSB : natural := DATA_WIDTH - 1;
  constant OPCODE_LSB : natural := OPCODE_MSB - OPCODE_WIDTH + 1;

  constant DURATION_MSB : natural := OPCODE_LSB - 1;
  constant DURATION_LSB : natural := DURATION_MSB - PULSE_DURATION_WIDTH + 1;

  constant AMPLITUDE_MSB : natural := DURATION_LSB - 1;
  constant AMPLITUDE_LSB : natural := AMPLITUDE_MSB - PULSE_AMPLITUDE_WIDTH + 1;

  constant PHASE_MSB : natural := AMPLITUDE_LSB - 1;
  constant PHASE_LSB : natural := PHASE_MSB - PULSE_PHASE_WIDTH + 1;

  constant FREQUENCY_MSB : natural := PHASE_LSB - 1;
  constant FREQUENCY_LSB : natural := FREQUENCY_MSB - PULSE_FREQUENCY_WIDTH + 1;

  constant WAVEFORM_MSB : natural := FREQUENCY_LSB - 1;
  constant WAVEFORM_LSB : natural := WAVEFORM_MSB - PULSE_WAVEFORM_WIDTH + 1;

  constant TRIGGER_MSB : natural := WAVEFORM_LSB - 1;
  constant TRIGGER_LSB : natural := TRIGGER_MSB - TRIGGER_WIDTH + 1;

  constant FEEDBACK_MODE_MSB : natural := TRIGGER_LSB - 1;
  constant FEEDBACK_MODE_LSB : natural := FEEDBACK_MODE_MSB;

  constant FEEDBACK_VALUE_MSB : natural := FEEDBACK_MODE_LSB - 1;
  constant FEEDBACK_VALUE_LSB : natural := FEEDBACK_VALUE_MSB - FEEDBACK_WIDTH + 1;

  constant ADDR_MAX      : unsigned(ADDR_WIDTH - 1 downto 0)                   := to_unsigned(2 ** ADDR_WIDTH - 1, ADDR_WIDTH);
  constant ZERO_FEEDBACK : std_logic_vector(FEEDBACK_WIDTH - 1 downto 0)       := (others => '0');
  constant ZERO_DURATION : std_logic_vector(PULSE_DURATION_WIDTH - 1 downto 0) := (others => '0');
begin

  -- decodifica dell'istruzione
  decoded_opcode         <= instruction(OPCODE_MSB downto OPCODE_LSB);
  decoded_duration       <= instruction(DURATION_MSB downto DURATION_LSB);
  decoded_amplitude      <= instruction(AMPLITUDE_MSB downto AMPLITUDE_LSB);
  decoded_phase          <= instruction(PHASE_MSB downto PHASE_LSB);
  decoded_frequency      <= instruction(FREQUENCY_MSB downto FREQUENCY_LSB);
  decoded_waveform       <= instruction(WAVEFORM_MSB downto WAVEFORM_LSB);
  decoded_trigger        <= instruction(TRIGGER_MSB downto TRIGGER_LSB);
  decoded_feedback_mode  <= instruction(FEEDBACK_MODE_MSB);
  decoded_feedback_value <= instruction(FEEDBACK_VALUE_MSB downto FEEDBACK_VALUE_LSB);

  -- process per i calcolo del prossimo stato
  -- LOGICA COMBINATORIA
  p_next_state : process (current_state, start_sequence, timer_end, data_r, instruction_counter,
    decoded_opcode, decoded_duration, decoded_amplitude, decoded_phase,
    decoded_frequency, decoded_waveform, decoded_trigger,
    feedback_in, decoded_feedback_mode, decoded_feedback_value,
    memorized_feedback, feedback_received)
  begin
    -- inizializzazione valori per evitare latch
    next_state      <= current_state;
    addr_r          <= std_logic_vector(instruction_counter);
    timer_value     <= (others => '0');
    timer_start     <= '0';
    pulse_amplitude <= (others => '0');
    pulse_phase     <= (others => '0');
    pulse_frequency <= (others => '0');
    pulse_waveform  <= (others => '0');
    pulse_enable    <= '0';
    trigger_out     <= (others => '0');
    computing       <= '1';
    computation_end <= '0';
    error_out       <= '0';

    case current_state is
      when READY =>
        computing <= '0';
        if start_sequence = '1' then
          next_state <= READ_ADDR;
        end if;

      when READ_ADDR =>
        addr_r     <= std_logic_vector(instruction_counter);
        next_state <= READ_DATA;

      when READ_DATA => -- necessario per dare tempo a instruction di aggiornarsi
        next_state <= DECODE_INSTRUCTION;

      when DECODE_INSTRUCTION =>
        if decoded_opcode = OP_END_SEQ then
          next_state <= DONE;
        elsif instruction_counter = ADDR_MAX then -- se siamo qui opcode non è END_SEQ e se è l'ultimo indirizzo, è un errore.
          next_state <= ERROR;
        elsif decoded_feedback_mode = '1' then
          if decoded_opcode = OP_PULSE or decoded_opcode = OP_DELAY then
            next_state <= WAIT_FEEDBACK;
          else
            next_state <= ERROR; -- Opcode non valido con feedback mode
          end if;
        else -- decoded_feedback_mode = '0'
          if decoded_opcode = OP_PULSE then
            next_state <= PULSE;
          elsif decoded_opcode = OP_DELAY then
            next_state <= DELAY;
          else -- opcode non valido
            next_state <= ERROR;
          end if;
        end if;

      when WAIT_FEEDBACK =>
        if feedback_received = '1' and
          (memorized_feedback = decoded_feedback_value or decoded_feedback_value = ZERO_FEEDBACK) then
          -- feedback ricevuto e corrisponde oppure jolly, procedi con l'operazione
          if decoded_opcode = OP_PULSE then
            next_state <= PULSE;
          elsif decoded_opcode = OP_DELAY then
            next_state <= DELAY;
          else
            next_state <= ERROR; -- Opcode non valido
          end if;
        elsif feedback_received = '1' then --feedback ricevuto ma sbagliato
          next_state <= READ_ADDR;
        else
          next_state <= WAIT_FEEDBACK;
        end if;

      when PULSE =>
        pulse_amplitude <= decoded_amplitude;
        pulse_phase     <= decoded_phase;
        pulse_frequency <= decoded_frequency;
        pulse_waveform  <= decoded_waveform;
        trigger_out     <= decoded_trigger;
        pulse_enable    <= '1';
        if decoded_duration = ZERO_DURATION then
          timer_start <= '0'; -- Non avviare il timer esterno
          next_state  <= READ_ADDR; -- Passa subito alla prossima istruzione (pulse di 0 cicli effettivi)
        else
          timer_value <= decoded_duration;
          timer_start <= '1'; -- Avvia il timer esterno
          next_state  <= WAIT_TIMER;
        end if;

      when DELAY =>
        pulse_enable <= '0';
        trigger_out  <= (others => '0');
        if decoded_duration = ZERO_DURATION then
          timer_start <= '0';
          next_state  <= READ_ADDR;
        else
          timer_value <= decoded_duration;
          timer_start <= '1';
          next_state  <= WAIT_TIMER;
        end if;

      when WAIT_TIMER =>
        if decoded_opcode = OP_PULSE then
          pulse_enable    <= '1';
          pulse_amplitude <= decoded_amplitude;
          pulse_phase     <= decoded_phase;
          pulse_frequency <= decoded_frequency;
          pulse_waveform  <= decoded_waveform;
          trigger_out     <= decoded_trigger;
        else
          pulse_enable <= '0';
          trigger_out  <= (others => '0');
        end if;
        timer_start <= '0';
        if timer_end = '1' then
          next_state <= READ_ADDR;
        end if;
      when DONE =>
        computing       <= '0';
        computation_end <= '1';
        next_state      <= READY;

      when ERROR =>
        computing       <= '0';
        computation_end <= '0';
        pulse_enable    <= '0';
        timer_start     <= '0';
        trigger_out     <= (others => '0');
        error_out       <= '1';
        next_state      <= ERROR;
    end case;
  end process;

  -- process per aggiornare lo stato
  -- LOGICA SEQUENZIALE
  p_state_update : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        current_state       <= READY;
        instruction_counter <= (others => '0');
        instruction         <= (others => '0');
        memorized_feedback  <= ZERO_FEEDBACK;
        feedback_received   <= '0';
      else

        current_state <= next_state;

        if current_state = READ_DATA and next_state = DECODE_INSTRUCTION then
          instruction <= data_r;
        end if;

        if (current_state = READY and next_state = READ_ADDR) or (current_state = DONE and next_state = READY) then -- inizio sequenza, reset feedback memorizzato
          instruction_counter <= (others => '0');
        elsif (current_state = WAIT_TIMER and timer_end = '1') or--caumento indirizzo
          (current_state = PULSE and decoded_duration = ZERO_DURATION) or
          (current_state = DELAY and decoded_duration = ZERO_DURATION) or
          (current_state = WAIT_FEEDBACK and next_state = READ_ADDR) then
          if instruction_counter < ADDR_MAX then
            instruction_counter <= instruction_counter + 1;
          end if;
        end if;

        -- Gestione di memorized_feedback
        if (current_state = READY and next_state = READ_ADDR) then -- inizio sequenza, reset feedback memorizzato
          memorized_feedback <= ZERO_FEEDBACK;
        elsif current_state = DECODE_INSTRUCTION then -- ogni volta che siamo in decodifica 
          if decoded_feedback_mode = '0' then --se feedback mode è 0 si resetta la memoria di feedback
            memorized_feedback <= ZERO_FEEDBACK;
          else-- decoded_feedback_mode = '1', memorizza il feedback
            if feedback_in /= ZERO_FEEDBACK then
              memorized_feedback <= feedback_in;
            end if;
          end if;
        end if;

        -- Gestione di feedback_received, necessario per rimanere in WAIT_FEEDBACK
        if current_state = DECODE_INSTRUCTION and next_state = WAIT_FEEDBACK then
          if feedback_in /= ZERO_FEEDBACK then
            feedback_received <= '1';
          else
            feedback_received <= '0';
          end if;
        elsif current_state = WAIT_FEEDBACK then
          if feedback_received = '0' and feedback_in /= ZERO_FEEDBACK then
            feedback_received  <= '1';
            memorized_feedback <= feedback_in;-- aggiungo così posso memorizzare anche in questo stato
          end if;
        else
          feedback_received <= '0';
        end if;
      end if;
    end if;
  end process;
end architecture;
