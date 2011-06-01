;
; sousvide628 is free software.  It comes without any warranty, to
; to the extent permitted by applicable law.  You can redistribute it
; and/or modify it under the terms of the Do What The Fuck You Want To
; Public License, Version 2, as published by Sam Hocevar.  See
; http://sam.zoy.org/wtfpl/COPYING for more details
;

 RADIX hex
 processor p16f628a
 LIST p=p16f628a
 LIST n=0
 LIST r=hex
 LIST st=on
 LIST f=inhx8m
 include  p16f628a.inc
 __CONFIG _BODEN_ON & _CP_OFF & _DATA_CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_OFF & _INTRC_OSC_NOCLKOUT

#define swout PORTA,0x03
#define cmpout CMCON,C2OUT

; 0x70 through 0x7f are mapped in all banks
debcnt		EQU		0x70

 ORG 0x00
; initial setup
 bcf STATUS,RP0			; bank 0
 bcf STATUS,RP1			; ...
 clrf PORTA			; clear port A
 goto $ + 0x02			; (jump over the interrupt vector)
 goto intrh			; (interrupt vector)
 clrf PORTB			; clear port B
 movlw 0x05			; move 0x05...
 movwf CMCON			; ...into cmcon to turn on C2V, uninverted

 bsf STATUS,RP0			; bank 1
 bsf PCON,OSCF			; osc=4MHz
 movlw 0x07			; a<2:0>
 movwf TRISA			; are inputs
 movlw 0xFF			; b<7:0>
 movwf TRISB			; are inputs
 movlw 0xD3			; move 0xD7...
 movwf OPTION_REG		; into OPTION => disable pullups, TMR0=sysclk/4,
                                ;                prescale TMR0, prescaler = 1/8

 bcf STATUS,RP0			; bank 0
 clrf debcnt                    ; clear debounce counter
 
; set up interrupts
 clrf TMR0			; clear tmr0
 clrf INTCON	        	; clear interrupts
 bsf INTCON,T0IE		; enable peripheral interrupts
 bsf INTCON,GIE			; enable interrupts

; busyloop---purely interrupt driven code
 nop
 goto $ - 1			; loop forever

; timer0 interrupt is the only thing enabled,
; so we don't have to bother checking flags
; tmr0 happens at 4MHz/4/8/256 = 488Hz
intrh:
 incfsz debcnt,w                ; unless ( debcnt + 1 == 0
 goto chkdebcnt                 ; ...
 btfsc swout                    ; and swout == 0 )
 goto chkdebcnt                 ; check the other end of the scale
 bsf swout                      ; otherwise, turn on the switch

chkdebcnt:
 decfsz debcnt,w                ; unless ( debcnt - 1 == 0
 goto incdebounce               ; ...
 btfss swout                    ; and swout == 1 )
 goto incdebounce               ; run the debouncer
 bcf swout                      ; otherwise, turn off the switch

incdebounce:
 btfss cmpout                   ; if cmpout == 0
 goto decdebounce               ; decrement instead
 incfsz debcnt,w                ; otherwise, increment
 movwf debcnt                   ; if w!=0, debcnt=w
 goto endintrh                  ; done

decdebounce:
 ; can only have gotten here from incdebounce,
 ; which means we know that cmpout == 0 now
 decfsz debcnt,w                ; decrement debcnt
 movwf debcnt                   ; if w!=0, debcnt=w

endintrh:
 bcf INTCON,T0IF                ; clear tmr0 interrupt flag
 retfie				; return from the interrupt

 END
