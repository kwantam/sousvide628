# pic16f628a sous vide controller

This code runs a pic16f628a as a controller for a Sous-Vide water bath. It's assumed that pin A3 is used as the output driving a relay which turns on the heating element (and possibly circulation pump), and comparator 2 is used to compare the output of a temperature sensor (I use an LM335) to a reference voltage (e.g., generated with a potentiometer).

This code is basically just a debouncer. If you wanted to invert the sense of this and use it, e.g., to control a freezer at a particular temperature, you'd swap the polarity of the inputs to the comparator. You'd probably have to add a lockout interval (e.g., the relay is locked into its present position for a few minutes after each time it switches) so you don't destroy the compressor by short-cycling it. Most compressors have a short-cycle switch built into them, but there's no reason to take chances.

This code should assemble just fine with gpasm. See the Makefile for details.

## License

sousvide628 is free software.  It comes without any warranty, to
to the extent permitted by applicable law.  You can redistribute it
and/or modify it under the terms of the Do What The Fuck You Want To
Public License, Version 2, as published by Sam Hocevar.  See
http://sam.zoy.org/wtfpl/COPYING for more details

