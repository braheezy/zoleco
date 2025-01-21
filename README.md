## zoleco
A ColecoVision emulator.

## Development
To develop the different parts of the emulator in isolation, the following exists:

- `examples/vgm_player`: Read a VGM file for the SN76489 sound chip and play it.
- `test.zig`: Execute the exhaustive [Z80 test suite for JSMoo](https://github.com/SingleStepTests/z80). Each opcode has 1000 test cases. Run with `zig build cputest`
