# FPGA-Based Programmable Pulse Sequencer
Minimal VHDL implementation of an FPGA-based programmable pulse sequencer.

This project was developed for educational purposes as part of a digital microelectronic systems design course, where students were free to choose and implement a system of their own interest. I used this opportunity to begin exploring digital systems for quantum computing and, coming from a bachelor's background in physics, to build practical experience with computer architecture, FPGA design, and hardware description languages.

The design is not intended to be a complete quantum-control system. It does not generate analog waveforms directly and does not include DDS/NCO blocks, DAC/ADC interfaces, RF front-end circuitry, readout discrimination, clock-domain crossing logic, or a complete real-time feedback stack.

Instead, the implemented module represents a simplified digital sequencing layer that outputs high-level pulse parameters intended for an external AWG/DDS-style backend.

## Project Scope

The project implements a programmable pulse sequencer core in VHDL.

The implemented design supports:

* loading a sequence of instructions into an internal RAM;
* reading instructions sequentially;
* decoding pulse, delay, and end-of-sequence commands;
* generating digital pulse parameters;
* waiting for a programmed number of clock cycles;
* handling simple conditional execution through an external feedback input;
* reporting computation status, end-of-computation, and error conditions.

The project does not implement:

* sampled waveform generation;
* DDS or NCO signal generation;
* DAC/ADC interfaces;
* RF modulation or up/down-conversion;
* multi-channel synchronization;
* real measurement discrimination;
* a complete quantum-control stack;
* a production-grade verification environment.

## Architecture Overview

The top-level design is composed of three main modules:

1. **Instruction Memory (`ram.vhd`)**
   A simple synchronous RAM used to store the instruction sequence.

2. **Finite State Machine (`fsm.vhd`)**
   The main control unit. It reads instructions from RAM, decodes them, updates the instruction counter, controls the timer, and drives the output pulse parameters.

3. **Timer (`timer.vhd`)**
   A countdown timer controlled by the FSM. It is used to keep a pulse or delay active for the required number of clock cycles.

The top-level entity `pps.vhd` connects these modules together.

Conceptually, the data flow is:

```text
External loader
      |
      v
Instruction RAM
      |
      v
FSM / Sequencer Core
      |
      +--> Timer
      |
      +--> Digital pulse-control outputs
```

The digital pulse-control outputs are intended to represent parameters that would be consumed by an external waveform-generation backend.

## Top-Level Interface

The top-level PPS module exposes the following main signals.

### Inputs

| Signal           | Description                                              |
| ---------------- | -------------------------------------------------------- |
| `clock`          | System clock.                                            |
| `reset`          | Synchronous reset, active high.                          |
| `data_w`         | Instruction word to be written into RAM.                 |
| `addr_w`         | RAM write address.                                       |
| `en_w`           | RAM write enable.                                        |
| `start_sequence` | Starts execution of the programmed instruction sequence. |
| `feedback_in`    | External feedback value used for conditional execution.  |

### Outputs

| Signal            | Description                                              |
| ----------------- | -------------------------------------------------------- |
| `trigger`         | Trigger/control field associated with the current pulse. |
| `pulse_en`        | Pulse enable signal.                                     |
| `pulse_amplitude` | Digital pulse-amplitude field.                           |
| `pulse_phase`     | Digital pulse-phase field.                               |
| `pulse_frequency` | Digital pulse-frequency field.                           |
| `pulse_waveform`  | Digital waveform-selection field.                        |
| `computing`       | High while the sequencer is executing a program.         |
| `computing_end`   | High when the sequence has reached its end.              |
| `error`           | High when an invalid condition is detected.              |

## Instruction Format

Each instruction is stored as a fixed-width word in RAM.

The default instruction width is 64 bits, although the design uses VHDL generics to make the format configurable.

The instruction is divided into fields:

```text
| Opcode | Duration | Amplitude | Phase | Frequency | Waveform | Trigger | Feedback Mode | Feedback Value | Unused |
```

The main fields are:

| Field            | Meaning                                                 |
| ---------------- | ------------------------------------------------------- |
| `Opcode`         | Selects the instruction type.                           |
| `Duration`       | Number of clock cycles associated with the instruction. |
| `Amplitude`      | Digital amplitude parameter.                            |
| `Phase`          | Digital phase parameter.                                |
| `Frequency`      | Digital frequency parameter.                            |
| `Waveform`       | Selects the waveform type or envelope type.             |
| `Trigger`        | Trigger/control output field.                           |
| `Feedback Mode`  | Enables conditional execution.                          |
| `Feedback Value` | Expected feedback value for conditional execution.      |

## Supported Instructions

The sequencer supports three main instruction types.

### `PULSE`

A `PULSE` instruction drives the pulse-control outputs and enables `pulse_en`.

During a pulse instruction, the following fields are used:

```text
Duration
Amplitude
Phase
Frequency
Waveform
Trigger
Feedback Mode
Feedback Value
```

Expected behavior:

```text
pulse_en        = 1
pulse_amplitude = instruction amplitude field
pulse_phase     = instruction phase field
pulse_frequency = instruction frequency field
pulse_waveform  = instruction waveform field
trigger         = instruction trigger field
```

The pulse remains active while the timer is running.

### `DELAY`

A `DELAY` instruction waits for a programmed number of clock cycles without enabling the pulse output.

Expected behavior:

```text
pulse_en = 0
trigger  = 0
```

The timer is still used to define the delay length.

### `END_SEQ`

An `END_SEQ` instruction terminates the sequence.

Expected behavior:

```text
computing     = 0
computing_end = 1
```

After the end of the sequence, the FSM returns to the ready state.

## Opcode Encoding

The default opcode encoding used in the VHDL source is:

| Instruction | Opcode |
| ----------- | ------ |
| `PULSE`     | `"01"` |
| `DELAY`     | `"10"` |
| `END_SEQ`   | `"11"` |

Other opcode values are treated as invalid and lead to the error state.

## FSM States

The FSM uses the following states:

| State                | Description                                                                    |
| -------------------- | ------------------------------------------------------------------------------ |
| `READY`              | Initial state after reset. The sequencer waits for `start_sequence`.           |
| `READ_ADDR`          | The current instruction address is provided to RAM.                            |
| `READ_DATA`          | The FSM waits for the synchronous RAM read data to become available.           |
| `DECODE_INSTRUCTION` | The instruction is decoded.                                                    |
| `WAIT_FEEDBACK`      | The FSM waits for a non-zero feedback value when feedback mode is enabled.     |
| `PULSE`              | Pulse parameters are applied and the timer is started.                         |
| `DELAY`              | Pulse output is disabled and the timer is started.                             |
| `WAIT_TIMER`         | The FSM waits until the timer completes.                                       |
| `DONE`               | The end-of-sequence instruction has been reached.                              |
| `ERROR`              | An invalid instruction or missing end-of-sequence condition has been detected. |

## Feedback-Based Conditional Execution

The design includes a simple feedback mechanism.

When `Feedback Mode = 1`, the FSM enters the `WAIT_FEEDBACK` state before executing the instruction.

The behavior is:

1. The FSM waits until `feedback_in` is different from zero.
2. The received feedback value is memorized.
3. If the memorized feedback matches the instruction feedback value, the instruction is executed.
4. If the instruction feedback value is zero, it is treated as a wildcard value.
5. If the received feedback does not match, the instruction is skipped and the FSM proceeds to the next address.

This mechanism is intentionally simple and educational. It does not include a valid/ready handshake, timeout logic, clock-domain crossing synchronization, or a realistic measurement-processing pipeline.

## Timer Behavior

The timer is implemented as a synchronous down counter.

The FSM provides:

```text
timer_start
timer_value
```

The timer returns:

```text
timer_end
```

When the timer reaches the end of the programmed interval, `timer_end` is asserted and the FSM proceeds to the next instruction.

A known behavior of the current implementation is that the effective pulse/delay duration observed in simulation has a one-clock-cycle offset with respect to the programmed value. This behavior is documented in the report and was left unchanged because the project was developed as a didactic prototype.

## Verification

The repository contains three VHDL testbenches.

### 1. Basic Sequence Testbench

File:

```text
tb/tb_pps_basic_sequence.vhd
```

Purpose:

* loads a basic sequence into RAM;
* executes a `PULSE` instruction;
* executes a `DELAY` instruction;
* executes a second `PULSE` instruction;
* terminates with `END_SEQ`.

This testbench is intended to verify the basic instruction flow and the interaction between RAM, FSM, and timer.

### 2. Error and Reset Testbench

File:

```text
tb/tb_pps_error_reset.vhd
```

Purpose:

* verifies the behavior when no `END_SEQ` instruction is found;
* verifies transition to the error state;
* verifies synchronous reset behavior;
* verifies that reset brings the FSM back to the ready state.

### 3. Feedback Testbench

File:

```text
tb/tb_pps_feedback.vhd
```

Purpose:

* verifies conditional execution with matching feedback;
* verifies wildcard feedback behavior;
* verifies instruction skipping when feedback does not match;
* verifies that the memorized feedback value is preserved when `feedback_in` returns to zero.

## Verification Methodology

The original verification was performed using ModelSim waveform inspection.

The testbenches included in this repository are not fully self-checking and do not contain a complete set of VHDL `assert` statements. This is intentional: the project was developed for educational purposes, and the main verification approach was based on manually inspecting the simulated waveforms.

To evaluate the simulations, the following signals should be observed:

```text
clock
reset
start_sequence
en_w
addr_w
data_w
feedback_in

current_state
next_state
instruction_counter
instruction
decoded_opcode
decoded_duration
decoded_feedback_mode
decoded_feedback_value
memorized_feedback
feedback_received

timer_start
timer_value
timer_end

pulse_en
pulse_amplitude
pulse_phase
pulse_frequency
pulse_waveform
trigger

computing
computing_end
error
```

Depending on the simulator, some internal FSM signals may need to be manually added to the waveform window.

## How to Use the Design

A typical sequence is:

1. Apply reset.
2. Write instructions into RAM using `data_w`, `addr_w`, and `en_w`.
3. Deassert `en_w`.
4. Assert `start_sequence` for one clock cycle.
5. Observe `computing`.
6. Wait for either `computing_end` or `error`.

Example conceptual flow:

```text
reset = 1
reset = 0

write instruction 0
write instruction 1
write instruction 2
write END_SEQ instruction

start_sequence = 1 for one clock cycle
start_sequence = 0

wait until computing_end = 1
```

## Example Program

A simple program may contain:

```text
Address 0x00: PULSE, duration = 10 cycles
Address 0x01: DELAY, duration = 5 cycles
Address 0x02: PULSE, duration = 8 cycles
Address 0x03: END_SEQ
```

This sequence generates one pulse, waits for a delay, generates another pulse, and then terminates the computation.

## Generics

The design uses VHDL generics to configure the size of the instruction fields.

Default values include:

| Generic                 | Default | Description                     |
| ----------------------- | ------: | ------------------------------- |
| `ADDR_WIDTH`            |       8 | RAM address width.              |
| `DATA_WIDTH`            |      64 | Instruction word width.         |
| `OPCODE_WIDTH`          |       2 | Opcode width.                   |
| `PULSE_DURATION_WIDTH`  |      16 | Duration field width.           |
| `PULSE_AMPLITUDE_WIDTH` |       8 | Amplitude field width.          |
| `PULSE_PHASE_WIDTH`     |       5 | Phase field width.              |
| `PULSE_FREQUENCY_WIDTH` |       8 | Frequency field width.          |
| `PULSE_WAVEFORM_WIDTH`  |       2 | Waveform-selection field width. |
| `TRIGGER_WIDTH`         |       3 | Trigger field width.            |
| `FEEDBACK_WIDTH`        |       3 | Feedback field width.           |

## Report

The original project report is included as:

```text
report.pdf
```

The report describes the design motivation, architecture, VHDL implementation, test plan, simulation results, and synthesis results.

The report is included as originally written for documentation purposes.

## Known Limitations

This project has several important limitations:

* It is a didactic prototype, not a production-ready pulse sequencer.
* It does not generate raw waveform samples.
* It outputs digital pulse parameters intended for an external waveform-generation backend.
* It does not include DDS/NCO logic.
* It does not include DAC/ADC interfaces.
* It does not include RF front-end logic.
* It does not implement a realistic readout or feedback-processing pipeline.
* The feedback interface is simplified and does not include valid/ready handshaking.
* The feedback input is assumed to be synchronous to the system clock.
* There is no timeout mechanism in `WAIT_FEEDBACK`.
* The timer has a known one-cycle offset in the current implementation.
* The testbenches are waveform-based and are not fully self-checking.
* The original ModelSim and Vivado project files are not included.

## Educational Value

Although intentionally simplified, the project demonstrates:

* modular VHDL design;
* synchronous RAM modeling;
* finite-state machine design;
* instruction decoding;
* timer-based control;
* conditional execution;
* basic simulation-based verification;
* FPGA-oriented digital architecture design.
