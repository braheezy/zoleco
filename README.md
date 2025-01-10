package emulator

import (
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/charmbracelet/log"
	"github.com/hajimehoshi/ebiten/v2"
)

// stateCounts represents the number of clock cycles each 8080 CPU instruction takes to execute.
// The array index corresponds to the opcode, and the value at each index is the cycle count for that opcode.
// This is used in the main execution loop to track the total number of cycles run and ensure accurate timing.
var stateCounts = []int{
	4, 10, 7, 5, ...
}

// opcodeExec is a function to execute for the current opcode
type opcodeExec func([]byte)

// CPU8080 emulates an Intel 8080 CPU processor
type CPU8080 struct {
	// PC is the current program counter, the address of the next instruction to be executed
	PC uint16
	// programData is a pointer to bytes containing the device Memory (64kb)
	Memory [64 * 1024]byte
	// programSize is the number of bytes in the program
	programSize int
	// Registers are the CPU's 8-bit Registers
	Registers Registers
	// sp is the stack pointer, the index to memory
	sp uint16
	// flags indicate the results of arithmetic and logical operations
	flags flags
	// Logger object to use
	Logger *log.Logger
	// Lookup table of opcode functions
	opcodeTable map[byte]opcodeExec
	// Options are the current options to use on the emulator
	Options EmulatorOptions
	// For timing sync
	cycleCount  int
	totalCycles int
	// Hardware is the struct holding HardwareIO device interface methods
	Hardware HardwareIO
	// Mutex for thread-safe access to the CPU state
	mu sync.Mutex
	// Whether or not interrupts are currently being handled
	interruptsEnabled bool
	// InterruptRequest is a channel to request an interrupt by sending an opcode.
	InterruptRequest chan byte
}

// EmulatorOptions describe tunable settings about emulator execution
type EmulatorOptions struct {
	LimitTPS bool
}

// Registers are the 7 primary registers for the 8080.
type Registers struct {
	A, B, C, D, E, H, L byte
}

// flags represent the conditions bits set after data operations. These can be checked by later instructions to
// affect execution.
type flags struct {
	// Zero flag set if result is zero
	Z bool
	// Sign flag set if result is negative
	S bool
	// Auxillary Carry flag set if a carry out of bit 3 occurs
	H bool
	// Carry flag set during arithmetic operations
	// Addition: if sum exceeds max byte value, carry occurs
	// Subtraction: if result is less than zero, carry occurs
	C bool
	// Parity flag set if number of bits in result is even
	P bool
}

// NewEmulator creates a new emulator, combing the provided HardwareIO with a CPU8080
func NewEmulator(io HardwareIO) *CPU8080 {
	// Load the ROM from the hardware
	program := io.ROM()

	// Initialize emulator virtual machine
	vm := &CPU8080{
		Logger:            log.New(os.Stdout),
		Hardware:          io,
		InterruptRequest:  make(chan byte, 1),
		interruptsEnabled: true,
	}
	start := io.StartAddress()
	// Put the program into memory at the location it wants to be
	copy(vm.Memory[start:], program)

	// Calculate program size for graceful termination
	vm.programSize = len(program) + start
	// Initialize program counter to start address
	vm.PC = uint16(start)

	// Give the hardware initialization time with the hardware
	vm.Hardware.Init(&vm.Memory)

	// Define all supported opcodes
	vm.opcodeTable = map[byte]opcodeExec{
		0x00: vm.nop,
		0x01: vm.load_BC,
		0x02: vm.stax_B,
		...
	}

	return vm
}

// StartInterruptRoutines starts a goroutine for each interrupt condition.
// These goroutines will check if the interrupt condition is met and request an interrupt if so.
// While the goroutines run in an infinite loop, the condition is only checked at the specified cycle interval.
func (vm *CPU8080) StartInterruptRoutines() {
	for _, condition := range vm.Hardware.InterruptConditions() {
		go func(cond Interrupt) {
			ticker := time.NewTicker(time.Duration(cond.Cycle) * time.Nanosecond)
			for {
				<-ticker.C
				if vm.interruptsEnabled && vm.cycleCount >= cond.Cycle {
					// Run the interrupt routine
					cond.Action(vm)
				}
			}
		}(condition)
	}
}

// runCycles executes the CPU for cycleCount amount of times.
// This is the main execution loop of the emulator.
func (vm *CPU8080) runCycles(cycleCount int) {
	// Record when the frame started, in case we need to slow down later
	// for historically accurate speeds.
	var startTime time.Time
	if vm.Options.LimitTPS {
		startTime = time.Now()
	}

	for vm.cycleCount < cycleCount {
		select {
		// After every opcode execution, check if an interrupt was requested
		case opcode := <-vm.InterruptRequest:
			vm.handleInterrupt(opcode)
		// Process next opcode
		default:
			if int(vm.PC) >= vm.programSize {
				// There's nothing left to process!
				break
			}

			// Some hardware perform IO operations through system calls instead
			// of IN/OUT opcodes. Allow that to happen here.
			vm.Hardware.HandleSystemCall(vm)

			// Parse the next 3 bytes for this opcode execution.
			currentCode := vm.Memory[vm.PC : vm.PC+3]
			op := currentCode[0]
			vm.PC++
			vm.cycleCount += stateCounts[op]
			vm.totalCycles += stateCounts[op]

			if opcodeFunc, exists := vm.opcodeTable[op]; exists {
				opcodeFunc(currentCode[1:])
			} else {
				vm.Logger.Fatal("unsupported", "address", fmt.Sprintf("%04X", vm.PC-1), "opcode", fmt.Sprintf("%02X", op), "totalCycles", vm.totalCycles)
			}
		}
	}

	// Handle slowdown for accurate speed emulation
	if vm.Options.LimitTPS {
		elapsed := time.Since(startTime)
		if remaining := vm.Hardware.FrameDuration() - elapsed; remaining > 0 {
			time.Sleep(remaining)
		}
	}
}

// toByte packs flags according to the PSW layout to be pushed onto the stack.
func (f *flags) toByte() byte {
	var b byte
	// Set the Sign flag in the highest bit (bit 7)
	if f.S {
		b |= 1 << 7
	}
	// Set the Zero flag in bit 6
	if f.Z {
		b |= 1 << 6
	}
	// Set the Auxiliary Carry flag in bit 4
	if f.H {
		b |= 1 << 4
	}
	// Set the Parity flag in bit 2
	if f.P {
		b |= 1 << 2
	}
	// Bit 1 is always 1
	b |= 1 << 1
	// Set the Carry flag in bit 0
	if f.C {
		b |= 1
	}
	return b
}

// fromByte unpacks flags from the stack
func fromByte(b byte) *flags {
	return &flags{
		S: b&(1<<7) != 0,
		Z: b&(1<<6) != 0,
		H: b&(1<<4) != 0,
		P: b&(1<<2) != 0,
		C: b&1 != 0,
	}
}

// carrySub returns true if a carry would happen if subtrahend is subtracted from value.
func carrySub(value, subtrahend byte) bool {
	return value < subtrahend
}

// carryAdd returns true if a carry would happen if addend is added to value.
func carryAdd(value, addend byte) bool {
	return uint16(value)+uint16(addend) > 0xFF
}

// auxCarrySub returns true if auxillary carry would happen if subtrahend is subtracted from value.
func auxCarrySub(value, subtrahend byte) bool {
	// Check if borrow is needed from higher nibble to lower nibble
	return (value & 0xF) < (subtrahend & 0xF)
}

// auxCarryAdd returns true if auxillary carry would happen if addend is added to value.
func auxCarryAdd(value, addend byte) bool {
	// Check if carry is needed from higher nibble to lower nibble
	return (value&0xF)+(addend&0xF) > 0xF
}

// parity returns true if the number of bits in x is even.
func parity(x uint16) bool {
	y := x ^ (x >> 1)
	y = y ^ (y >> 2)
	y = y ^ (y >> 4)
	y = y ^ (y >> 8)

	// Rightmost bit of y holds the parity value
	// if (y&1) is 1 then parity is odd else even
	return y&1 == 0
}
func (fl *flags) setZ(value uint16) {
	fl.Z = value == 0
}
func (fl *flags) setS(value uint16) {
	fl.S = value&0x80 != 0
}
func (fl *flags) setP(value uint16) {
	fl.P = parity(value)
}
func toUint16(high, low byte) uint16 {
	return uint16(high)<<8 | uint16(low)
}

// Update fulfills the Game interface for ebiten.
// This runs the emulator for one frame.
func (vm *CPU8080) Update() error {

	// Reset cycle count
	vm.cycleCount = 0
	// Execute opcodes
	vm.runCycles(vm.Hardware.CyclesPerFrame())

	return nil
}

// Draw fulfills the Game interface for ebiten
func (vm *CPU8080) Draw(screen *ebiten.Image) {
	// Use hardware to draw on the display
	vm.Hardware.Draw(screen)
}

// y fulfills the Game interface for ebiten
func (vm *CPU8080) Layout(outsideWidth, outsideHeight int) (screenWidth, screenHeight int) {
	return outsideWidth, outsideHeight
}