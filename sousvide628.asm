 RADIX hex
 processor p16f628a
 LIST p=p16f628a
 LIST n=0
 LIST r=hex
 LIST st=on
 LIST f=inhx8m
 include  p16f628a.inc
 __CONFIG _BODEN_ON & _CP_OFF & _DATA_CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_OFF & _INTRC_OSC_NOCLKOUT

; 0x70 through 0x7f are mapped in all banks
mswcnt		EQU		0x70
hswcnt		EQU		0x71
sixt		EQU		0x72
seconds		EQU		0x73
minutes		EQU		0x74
hours		EQU		0x75
grid		EQU		0x76
sectmp		EQU		0x77
mintmp		EQU		0x78
hrtmp		EQU		0x79
grtmp		EQU		0x7A
clkconfig	EQU		0x7B
dot1		EQU		0x7C
dot2		EQU		0x7D
dot3		EQU		0x7E
dot4		EQU		0x7F

 ORG 0x00
; initial setup
 bcf STATUS,RP0			; bank 0
 bcf STATUS,RP1			; ...
 clrf PORTA			; clear port A
 goto $ + 0x02			; (jump over the interrupt vector)
 goto intrh			; (interrupt vector)
 clrf PORTB			; clear port B
 movlw 0x05			; move 0x05...
 movwf CMCON			; ...into cmcon to turn on C2Vout

 bsf STATUS,RP0			; bank 1
 bsf PCON,OSCF			; osc=4MHz
 movlw 0x0F			; a<3:0>
 movwf TRISA			; are inputs
 movlw 0xFF			; b<7:0>
 movwf TRISB			; are inputs
 movlw 0xD7			; move 0xD7...
 movwf OPTION_REG		; into OPTION => disable pullups, TMR0=sysclk/4,
                                ;                prescale TMR0, prescaler = 1/256

;;; EDITED UP TO HERE SO FAR

 bcf STATUS,RP0			; bank 0
 clrf CCPR1L			; clear duty cycle for now (set below)
 movlw 0x0F			; 0x0F goes into...
 movwf CCP1CON			; ...ccp1con => cp1x=cp1y=0, PWM mode on
 movlw 0x7C			; 0x7C goes into...
 movwf T2CON			; ...t2con => 1/16 postscaler, 1:1 prescaler, t2 on
; clear memory locations we'll be using
 clrf segsave
 clrf seg2save
 clrf sixtcnt
 clrf ampm
 clrf mswcnt
 clrf hswcnt
 clrf sixt
 clrf seconds
 clrf minutes
 clrf hours
 clrf grid
 clrf sectmp
 clrf mintmp
 clrf hrtmp
 clrf grtmp
 clrf clkconfig
 clrf dot1
 clrf dot2
 clrf dot3
 clrf dot4

; do configuration stuff
 btfsc PORTB,0x06		; if RB6 is high
 goto readconfig		; no resistor is installed, so we are in EEPROM setup mode
 movf PORTB,w			; otherwise, read in the PORTB value
 xorlw 0xFF			; invert the value (resistor installed = 0, want 1)
 andlw 0xB7			; kill the values of RB6 and RB3 (these should always be zero)
 movwf clkconfig		; this is the clock configuration word
 goto docfgsetup		; now we're ready to set up the part

; read config word from EEPROM since we're not in resistor mode
readconfig:
 bsf STATUS,RP0			; bank 1
 movlw 0x3F			; address 63
 movwf EEADR			; into the EEPROM address register
 bsf EECON1,RD			; read the data
 movf EEDATA,w			; read the config word
 movwf clkconfig		; write it to clkconfig
 bcf STATUS,RP0			; bank 0
; now check status buttons for config updates
 btfss mswitch			; if the minutes button is being pushed
 bsf mswcnt,0x00		; save the push state
 btfss hswitch			; if the hours button is being pushed
 bsf mswcnt,0x01		; save the push state
 movf mswcnt,w			; load the button config
 btfsc STATUS,Z			; if no buttons were pushed (cfgbuttons == 0)
 goto docfgsetup		; setup the config registers and be done
 addlw 0xFE			; else add -2 to w
 btfsc STATUS,Z			; if result == 0
 goto cfgmod2			; cfgbuttons was 2
 btfsc STATUS,C			; else if result == 1 (overflow of w + 254 means new result is positive)
 goto cfgmod3			; cfgbuttons was 3
;goto cfgmod1			; else result == -1, so go to cfgmod1

;
; clkconfig:
; H x M M x D D D
; ^ ^ ^ ^ ^ ^ ^ ^
; | | | | | | | \ - \
; | | | | | | \ - - -\  duty cycle for PWM
; | | | | | \ - - - -/  (4 + this number is duty cycle)
; | | | | |
; | | | | \ - - - - ->  unused (for now!)
; | | | |
; | | | \ - - - - - -\  space mode (blank, complex,
; | | \ - - - - - - -/  simple '-', simple 'o')
; | |
; | \ - - - - - - - ->  unused (for now!)
; |
; \ - - - - - - - - ->  50/60Hz operation (set = 50Hz)
;

;cfgmod1: change from 50Hz to 60Hz
 movlw 0x80			; load 0x80
 xorwf clkconfig,f		; flip the MSB of clkconfig
 goto writeconfig		; write the new config and continue

;cfgmod2: cycle through display modes
cfgmod2:
 movf clkconfig,w		; load clkconfig
 andlw 0xBF			; be sure that bit 6 is blank
 addlw 0x10			; add 1 to the top nibble
 movwf clkconfig		; write back incremented state (possibly overflowing into unused bit 6)
 goto writeconfig		; write the new config and continue

cfgmod3:
 movf clkconfig,w		; load clkconfig
 andlw 0xF7			; be sure that bit 3 is blank
 addlw 0x01			; add 1 to the bottom nibble
 movwf clkconfig		; write back incremented state (possibly overflowing into unused bit 3)
;goto writeconfig		; write the new config and continue

writeconfig:
 bsf STATUS,RP0			; bank 1
 bsf EECON1,WREN		; enable writing
 movlw 0x3F			; address 63
 movwf EEADR			; into EEADR
 movf clkconfig,w		; load clock config into w
 andlw 0xB7			; make sure that the data is valid
 movwf EEDATA			; write to eedata
 movlw 0x55			; move 0x55
 movwf EECON2			; into EECON2
 movlw 0xAA			; move 0xAA
 movwf EECON2			; into EECON2
 bsf EECON1,WR			; set the wr bit
 bcf EECON1,WREN		; disable further writes
 bcf STATUS,RP0			; bank 0

docfgsetup:
 bsf STATUS,RP0			; bank 1
 clrf TRISB			; portB is all outputs
 bcf STATUS,RP0			; bank 0
; set up 50/60 Hz
 movlw 0x3C			; load 60 into w
 btfsc _is_50			; if we're in 50Hz mode
 movlw 0x32			; load 50 instead
 movwf sixtcnt			; write w to sixtcnt
; set up brightness
 movlw 0x07			; 0b00000111
 andwf clkconfig,w		; mask off duty cycle bits
 addlw 0x04			; add 4
 movwf CCPR1L			; this is our duty cycle
; set up display mode
 btfsc clkconfig,0x05		; if clkconfig<5>
 goto $ + 4			; pick which of the simple modes
 btfss clkconfig,0x04		; else
 goto dointsetup		; clkconfig<5:4> == 0, blank
 goto cfgcomplex		; clkconfig<5:4> == 1, complex
 btfss clkconfig,0x04		; ...
 goto cfgsimpd			; clkconfig<5:4> == 2, simple dash
;goto cfgsimpo			; clkconfig<5:4> == 3, simple o
;cfgsimpo:
 movlw 0x70			; bottom 3 segments
 movwf dot1			; into dot1
 movlw 0x08			; just bar
 movwf dot2			; into dot2
 movlw 0x70			; bottom 3 segments
 movwf dot3			; into dot3
 movlw 0x08			; just bar
 movwf dot4			; into dot4
 goto dointsetup		; done
cfgsimpd:
 movlw 0x08			; just bar
 movwf dot2			; into dot2
 movlw 0x08			; just bar
 movwf dot4			; into dot4
 goto dointsetup		; done
cfgcomplex:
 clrf dot1			; dot1 empty
 movlw 0x0F			; top 4 segments
 movwf dot2			; into dot2
 movlw 0x70			; bottom 3 segments
 movwf dot3			; into dot3
 movlw 0x08			; just bar
 movwf dot4			; into dot4
;goto dointsetup		; done

; set up interrupts
;bsf PIE1,TMR2IE		; done above when we're already in bank 1
dointsetup:
 bcf PIR1,TMR2IF		; clear timer2 interrupt flag
 movlw 0xFF			; load -1
 movwf TMR0			; into tmr0
 bcf INTCON,T0IF		; clear timer0 interrupt flag
 bsf INTCON,PEIE		; enable peripheral interrupts
 bsf INTCON,GIE			; enable interrupts

; busyloop---purely interrupt driven code
 nop
 goto $ - 1			; loop forever

intrh:
; check the min switch
 bcf STATUS,RP0			; bank 0
 btfsc mswitch			; if the minutes button is not being pushed
 goto checkhclr			; check hswitch and clear mswcnt
 incfsz mswcnt,f		; otherwise, increment mswcnt
 goto checkh			; if we didn't wrap around, check the hour switch
 goto dominute			; else do minutes

checkhclr:
 clrf mswcnt			; clear the minute debounce counter
checkh:
; check the hr switch
 btfsc hswitch			; if the hours button is not being pushed
 goto check60clr		; check the 60hz input and clear hswcnt
 incfsz hswcnt,f		; otherwise, increment hswcnt
 goto check60			; if we didn't wrap around, check the 60hz input
 goto dohour			; else do hours

check60clr:
 clrf hswcnt			; clear the hour debounce counter
check60:
; check the 60Hz input
 btfss INTCON,T0IF		; if the t0if isn't set
 goto domux			; just do the mux

; handle sixt increment
 bcf INTCON,T0IF		; first, handle the timer stuff
 movlw 0xFF			; reset clkset value
 movwf TMR0			; put it in TMR0
 incf sixt,f			; increment sixt
 movf sixtcnt,w			; xor sixtcnt...
 xorwf sixt,w			; ...with sixt
 btfss STATUS,Z			; if sixt != sixtcnt
 goto domux			; just handle muxing
 clrf sixt			; clear sixtieths count

; handle second increment
 incf seconds,f			; increment seconds
 movlw 0x3C			; xor 60...
 xorwf seconds,w		; ...with seconds
 btfss STATUS,Z			; if seconds != 60
 goto domux			; just handle muxing
 clrf seconds			; clear seconds count

; handle minute increment
dominute:
 incf minutes,f			; increment minutes
 movlw 0x3C			; xor 60...
 xorwf minutes,w		; ...with minutes
 btfss STATUS,Z			; if minutes != 60
 goto domux			; just handle muxing
 clrf minutes			; clear minutes count

; handle hour increment
dohour:
 incf hours,f			; increment hours
 movlw 0x18			; xor 24...
 xorwf hours,w			; ...with hours
 btfss STATUS,Z			; if hours != 24
 goto domux			; just handle muxing
 clrf hours			; else clear hours

domux:
 movlw 0x40			; gridmsb
 movwf PORTA			; in porta
 movlw 0x04			; gridm2sb
 movwf PORTB			; in portb
 incf grid,f			; increment the grid we're looking at
 movlw 0x08			; xor 8...
 xorwf grid,w			; ...with grid
 btfss STATUS,Z			; if grid != 8
 goto notdot			; not displaying the dot

 movlw 0xFF			; put 0xFF
 movwf grid			; in grid (next time it overflows to 0)
; handle am/pm dot
 clrf ampm			; clear am/pm
 movlw 0x0C			; load 12
 subwf hours,w			; hours - 12
 btfss STATUS,C			; if c is not set
 goto $ + 3			; just do updates
 bsf _segper			; otherwise, we are PM, so set the period
 bsf _is_pm			; and the flag
 bcf gridm2sb			; clear the m2sb to set grid = 8
 movf seconds,w			; load seconds
 movwf sectmp			; update sectmp
 movf minutes,w			; load minutes
 movwf mintmp			; update mintmp
 movf hours,w			; load hours
 movwf hrtmp			; update hrtmp
 movlw 0x0C			; load 12
 btfsc _is_pm			; if it's PM
 subwf hrtmp,f			; subtract 12 from hrtmp
 movf hrtmp,f			; touch hrtmp register
 btfsc STATUS,Z			; if hrtmp is zero
 movwf hrtmp			; make it 12 instead
 goto theend			; done

notdot:
; handle non-dot grids
 bsf STATUS,RP0			; bank 1
 movf grid,w			; load grid
 movwf grtmp			; save in grtmp
 btfss STATUS,Z			; is grid == 0?
 goto $ + 2			; if no, go on
 goto secnum			; else display number for grid 0
 decfsz grtmp,f			; is grid == 1?
 goto $ + 2			; if no, go on
 goto secnum			; else display number for grid 1
 decfsz grtmp,f			; is grid == 2?
 goto $ + 2			; if no, go on
 goto disp2dash			; grid 2 is always a dash
 decfsz grtmp,f			; is grid == 3?
 goto $ + 2			; if no, go on
 goto minnum			; else display number for grid 3
 decfsz grtmp,f			; is grid == 4?
 goto $ + 2			; if no, go on
 goto minnum			; else display number for grid 4
 decfsz grtmp,f			; is grid == 5?
 goto hrnum			; if no, it must be 6 or 7; either one uses hrnum
;goto disp5dash			; grid 5 is always a dash
;disp5dash:
 btfsc sectmp,0x00		; if seconds is odd
 goto topdot			; display the top dot
 goto botdot			; else display the bottom dot

disp2dash:
 btfss sectmp,0x00		; if seconds is even
 goto topdot			; display the top dot
 goto botdot			; else display the bottom dot

topdot:
 bcf STATUS,RP0			; bank 0
 movf grid,w			; load grid
 iorwf dot1,w			; load in configured dots
 movwf PORTB			; write to port B
 movf dot2,w			; load in configured dots
 movwf PORTA			; write to port A
 goto theend			; we're done
 
botdot:
 bcf STATUS,RP0			; bank 0
 movf grid,w			; load grid
 iorwf dot3,w			; load in configured dots
 movwf PORTB			; write grid and segments to PORTB
 movf dot4,w			; load in configured dots
 movwf PORTA			; into port A
 goto theend			; and we're done

secnum:
 movf sectmp,w			; load seconds
 btfsc gridpar			; if grid is odd
 addlw 0x40			; get the high digit (stored at offset 0x40 in EEPROM)
 movwf EEADR			; into the EEPROM address
 goto dataloaded		; common code for all displays

minnum:
 movf mintmp,w			; load minutes
 btfss gridpar			; if grid is even
 addlw 0x40			; get the high digit (stored at offset 0x40 in EEPROM)
 movwf EEADR			; into the EEPROM address
 goto dataloaded		; common code for all displays

hrnum:
 movf hrtmp,w			; load hours
 btfsc gridpar			; if grid is odd
 addlw 0x40			; get the high digit (stored at offset 0x40 in EEPROM)
 movwf EEADR			; into the EEPROM address
;goto dataloaded		; common code for all displays

dataloaded:
 bsf EECON1,RD			; read data from EEPROM
 movf EEDATA,w			; load EEPROM data
 bcf STATUS,RP0			; bank 0
 movwf segsave			; save EEDATA to segsave
 andlw 0x0F			; mask off top nibble
 movwf seg2save			; save until later
 xorwf segsave,w		; XOR remaining bits with original data to get top nibble
 iorwf grid,w			; and then OR in the grid number
 movwf PORTB			; write PORTB
 bcf gridmsb			; turn off the grid MSB
 movf seg2save,w		; load PORTA value
 movwf PORTA			; write PORTA

theend:
 bcf PIR1,TMR2IF		; clear timer2 interrupt flag
 retfie				; return from the interrupt

 END
