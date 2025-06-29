## zoleco

A ColecoVision emulator.

![hello](./demos/hello.png)
![frogger](./demos/frogger.png)

See [demos](#demos) for more.

## Usage

You need Zig and SDL2 to run this project.

```bash
# macos
brew install sdl2 zig
```

Then build and run:

```bash
zig build
./zig-out/bin/zoleco <path to rom>
```

### Keybindings

The emulator supports two controllers with the following default keybindings:

#### Controller 1

- Movement: Arrow keys
- Left Action Button: A
- Right Action Button: S
- Blue Button: D
- Purple Button: F
- Keypad: Number keys 0-9
- Asterisk: Period (.)
- Hash: Right Shift

#### Controller 2

- Movement: IJKL (I=up, J=left, K=down, L=right)
- Left Action Button: G
- Right Action Button: H
- Blue Button: J
- Purple Button: K
- Keypad: Z,X,C,V,B,N,M,<,>
- Asterisk: Forward Slash (/)
- Hash: Right Shift

Press ESC to quit the emulator.

## Development

To develop the different parts of the emulator in isolation, the following exists:

- `examples/vgm_player`: Read a VGM file for the SN76489 sound chip and play it.
- `test.zig`: Execute the exhaustive [Z80 test suite for JSMoo](https://github.com/SingleStepTests/z80). Each opcode has 1000 test cases. Run with `zig build cputest`

## Demos

![smurf1](./demos/smurf1.png)
![smurf2](./demos/smurf2.png)
![qbert](./demos/qbert.mp4)
