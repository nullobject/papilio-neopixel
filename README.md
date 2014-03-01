# Papilio NeoPixel

This circuit implements a PicoBlaze microcontroller which controls a
[NeoPixel](http://learn.adafruit.com/adafruit-neopixel-uberguide) LED.

Address and value data is clocked out from the PicoBlaze microcontroller (U1)
into the 2-phase data demultiplexer (U2) and stored in the dual-port RAM (U3).
The WS2812 driver (U4) continually refreshes the NeoPixel LED data from RAM.

![Schematic](/images/schematic.png)


## References

* [WS2812 datasheet](http://www.adafruit.com/datasheets/WS2812.pdf)
* [WS2812 RGB LED string driver](http://opencores.org/project,ws2812)
