
all: sousvide628.hex

%.hex:	%.asm
	gpasm $<

clean:
	rm -f *.hex *.cod *.lst
