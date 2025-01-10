## VGM Player

An example of running a Video Game Music [(VGM)](<https://en.wikipedia.org/wiki/VGM_(file_format)>) audio file using a [SN76948](https://en.wikipedia.org/wiki/Texas_Instruments_SN76489) sound chip emulator.

In the root of the project, run

    zig build

Then

    ./zig-out/bin/vgm_player <.vgm file>

You should hear a pickup coin sound.

You can play your own VGM files, but they need to be for the SN76489 chip. Check with `file`:

```console
❯  file what.vgm
what.vgm: VGM Video Game Music dump v1.5, soundchip(s)= SN76489 (PSG), YM2612 (OPN2),
```

This site is 🤌 at generating compliant VGM files for the SN76489: https://harmlesslion.com/sn_sfxr/. Get the 44k ones.
