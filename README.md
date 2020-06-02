# Whirlwind NES Core

Whirlwind is an Nintendo Entertainment System (NES) compatible FPGA core. It was designed using the Terasic DE10-Standard Development Kit, and utilizes the ADV7123 VGA DAC for video and the WM87312 codec for audio, though these can be changed for your particular development environment. The 6502 soft core was created by Jens Gutschmidt (huge thanks for this well designed core) - further information may be found on the OpenCores [project page](https://opencores.org/projects/cpu6502_true_cycle).   Joypad input is currently accepted as simple input from DB9 style joysticks.  Though Whirlwind is currently in development, it is able to play most NROM128/256 and SxROM cartridges (ie mapper 0 and 1), and has been successfully tested with:

* Super Mario Bros
* Legend of Zelda
* Metroid
* Mega Man 2
* Blaster Master
* Tetris
* Dr. Mario
* Willow
* A Boy and his Blob
* Kung Fu
* Excitebike
* Ice Climber
* Donkey Kong
* Popeye

Though some of these will have audio issues due to known limitations below.

Games with known playability issues:

* Zelda II: Adventure of Link (overworld map does not populate correctly, and game is unplayable after leaving palace)

Additional mappers will be developed soon (mapper 2 is scheduled next).  Whirlwind currently also has the following limitations:

1. Only the player 1 joypad is implemented
2. The DMC channel in the APU is currently unimplemented (sound effects such as doors opening in Zelda are missing)
3. The APU mixer levels slightly deviate from real NES
4. The pulse channel sweeps sometimes end prematurely (some sound effects don't sound quite right)
5. Likely other bugs, please let me know if you encounter any!

See it in action on YouTube:

[![Whirlwind NES FPGA Core SxROM](https://img.youtube.com/vi/DMrxPlXxLRo/0.jpg)](https://www.youtube.com/watch?v=DMrxPlXxLRo)
[![Whirlwind NES FPGA Core NROM](https://img.youtube.com/vi/b3563P8Pnhs/0.jpg)](https://www.youtube.com/watch?v=b3563P8Pnhs)

If you make use of this core, please let me know any difficulties you run into.  Thanks!
