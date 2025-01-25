# neopixel_hdl
A simple, crude neopixel core built for the SK6812 RGB LEDs that uses bram for data storage.

The core was designed to operate at 100Mhz using an SK6812. T0H, T0L, T1H T1L and TRST are all expressed in ticks relative to the clock speed. This core may not function if the ticks per cycle were lower as some of the states are not as effecient as they could be. However existing HDL examples were not well suited for the SK6812 LEDs and therefor I made my own.

## Adding the core to Vivado
Ensure you have a ``Block Memory Generator`` and its set to ``True Dual Port Ram``.
Then connect the following:

led_controller -> block memory generator (BRAM_PORTB)
- addr[31:0] -> addrb[31:0]
- clk -> clkb
- dout[31:0] -> doutb[31:0]
- en -> enb
- rst -> rstb
- web[3:0] -> web[3:0]

Then you will need an AXI BRAM Controller to interface with the LEDs from firmware, connect this to BRAM_PORTA.

![image](https://github.com/user-attachments/assets/55ca3de6-3d91-423d-88bb-d077171188f4)


## Controlling the LEDs from firmware
First, the amount of LEDs in the chain need to be programmed at the base address. If this is set to 0, the core will stop running until a value is added.
```c
  Xil_Out32(XPAR_AXI_BRAM_CTRL_0_BASEADDR, 4); // Tells our core that we have 4 LEDs
```

Then to program the LEDs you will need to offset the address by 4, then again for each LED. Data is stored in BRGX where X is not used. So to program a blue LED with the max brightness it would look like this:
```c
  uint32_t StartingAddress = XPAR_AXI_BRAM_CTRL_0_BASEADDR + 4; // + 4 to skip over the amount of LEDs in the chain address
  Xil_Out8(StartingAddress, 255);  // + 0 for the blue byte
  Xil_Out8(StartingAddress + 1, 0); // + 1 for the red byte
  Xil_Out8(StartingAddress + 2, 0); // + 2 for the green byte
  Xil_Out8(StartingAddress + 3, 0); // + 3 is unused.
```

