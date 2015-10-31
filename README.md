# PropellerGameboy
The code is entirely PASM and is pretty complicated, particularly the cpu. It runs at a constant 24 Propeller instructions per Gameboy instruction (96MHz), and in order to maintain the timing and ensure hub accesses are always predictable there are NOPs throughout. It's also just two instructions short of the limit and I've already taken a lot of steps to compress it by reusing addresses, coverting two NOPs to READBYTEs, etc. Each Gameboy instruction has up to 8 Propeller hub instructions to execute it that are loaded from the hub, however normal instructions only have time to load three from the hub. Longer instructions will execute a JMP from the hub that puts them in a longer pipeline and some instructions or parts of instructions are implemented directly for performance. 2 bit TV output is the perfect number of colors for a Gameboy screen and sound is generated using a counter. I used a Wii Classic Controller Pro for input. They're surprisingly easy to interface with using I2C, though I had to split the I2C code up between video output lines because I ran out of cores.

The implementation is pretty complete. What's not implemented:

1. Link cable and stereo sound - Just not enough pins.

2. Wave sound channel - Tetris doesn't use it so I have to way to test it but there's no reason it couldn't be implemented.

3. The DAA instructions - More correctly the half-carry and subtract flags it requires. Not nearly enough cycles. You can see the that the score counts in hex.

4. There are some display and input bugs I haven't tracked down.
