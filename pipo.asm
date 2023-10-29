;;; PC-9801 Boot Sound (Pipo)
;;; for ATtiny25/45/85

;;; avra pipo.asm
;;; avrdude -c [programmer type] -p t85 -b 2400 -e -U flash:w:pipo.hex


;;; ------------------------------------------------------------
;;; 1 count = 0.1 ms (TIMER1)
;;; max.: 65535

.define DURATION_BOOT	10000	; 1 sec

.define DURATION_PI	1500	; 150 ms
.define DURATION_PO	1600	; 160 ms


.include "tn85def.inc"


;;; ------------------------------------------------------------
.org	0x0000

	;; Interrupt Vectors
	rjmp	RESET		; RESET
	rjmp	RESET		; INT0_ISR
	rjmp	RESET		; PCINT0_ISR
	rjmp	RESET		; TIM1_COMPA_ISR
	rjmp	RESET		; TIM1_OVF_ISR
	rjmp	RESET		; TIM0_OVF_ISR
	rjmp	RESET		; EE_RDY_ISR
	rjmp	RESET		; ANA_COMP_ISR
	rjmp	RESET		; ADC_ISR
	rjmp	RESET		; TIM1_COMPB_ISR
	rjmp	RESET		; TIM0_COMPA_ISR
	rjmp	RESET		; TIM0_COMPB_ISR
	rjmp	RESET		; WDT_ISR
	rjmp	RESET		; USI_START_ISR
	rjmp	RESET		; USI_OVF_ISR


RESET:
	;; set system clock prescaler (500 kHz (= 8 MHz / 16))
	ldi	r16, (1<<CLKPCE) ; clock prescaler change enable
	out	CLKPR, r16
	ldi	r16, 0x04	 ; clock division factor = 16
	out	CLKPR, r16

	;; set stack pointer
.ifdef SPH
	ldi	r16, HIGH(RAMEND)
	out	SPH, r16
.endif
	ldi	r16, LOW(RAMEND)
 	out	SPL, r16

	;; beep off
	cbi	PORTB, PORTB0
	sbi	DDRB, DDB0


;;; ------------------------------------------------------------
PWM_SETUP:
	;; toggle OC0A on compare match | OC0B disconnect | CTC
	ldi	r16, (1<<COM0A0)|(0<<COM0B0)|(2<<WGM00)
	out	TCCR0A, r16

TIMER_SETUP:
	;; 50 counts by 500 kHz = 0.1 ms
	ldi	r16, 50
 	out	OCR1C, r16

	;; clear timer/counter on compare match
	;; and start timer (prescaler = 1)
	ldi	r16, (1<<PWM1A)|(1<<CS10)
	out	TCCR1, r16


;;; ------------------------------------------------------------
BOOT:
	ldi	r25, HIGH(DURATION_BOOT)
	ldi	r24, LOW(DURATION_BOOT)

LOOP_BOOT:
	in	r16, TIFR
	sbrs	r16, TOV1
	rjmp	LOOP_BOOT

	;; clear flag
	out	TIFR, r16

	sbiw	r25:r24, 1
	brne	LOOP_BOOT


;;; ------------------------------------------------------------
WAIT_PI:
	;; set frequency for "PI" (2 kHz)
	;; (125 / 500 kHz = 0.25 ms, correspond to 1 / 2 of 1 / 2000 Hz)
	ldi	r16, 124
	out	OCR0A, r16

	ldi	r25, HIGH(DURATION_PI)
	ldi	r24, LOW(DURATION_PI)

	;; start PWM
	ldi	r16, (1<<CS00)
	out	TCCR0B, r16

_WAIT_PI_LOOP:
	in	r16, TIFR
	sbrs	r16, TOV1
	rjmp	_WAIT_PI_LOOP

	;; clear flag
	out	TIFR, r16

	sbiw	r25:r24, 1
	brne	_WAIT_PI_LOOP


WAIT_PO:
	;; set frequency for "PO" (1 kHz)
	ldi	r16, 249
	out	OCR0A, r16

	ldi	r25, HIGH(DURATION_PO)
	ldi	r24, LOW(DURATION_PO)

_WAIT_PO_LOOP:
	in	r16, TIFR
	sbrs	r16, TOV1
	rjmp	_WAIT_PO_LOOP

	;; clear flag
	out	TIFR, r16

	sbiw	r25:r24, 1
	brne	_WAIT_PO_LOOP


EXIT:
	;; stop PWM, disconnect OC0x and beep off
	clr	r16
	out	TCCR0A, r16
	out	TCCR0B, r16
	cbi	PORTB, PORTB0


	;; set sleep mode as Power-down
	ldi	r16, (1<<SE)|(2<<SM0)
	out	MCUCR, r16
	ldi	r16, (1<<PRTIM0)|(1<<PRTIM1)|(1<<PRUSI)|(1<<PRADC)
	out	PRR, r16

	sleep

	rjmp	RESET
