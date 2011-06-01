#
# sousvide628 is free software.  It comes without any warranty, to
# to the extent permitted by applicable law.  You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want To
# Public License, Version 2, as published by Sam Hocevar.  See
# http://sam.zoy.org/wtfpl/COPYING for more details
#

all: sousvide628.hex

%.hex:	%.asm
	gpasm $<

clean:
	rm -f *.hex *.cod *.lst
