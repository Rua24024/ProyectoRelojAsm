/*
* modo_hora.asm
*
* Creado:
* Autor : Sebastian Ruano 
* Descripción:
* Modo hora. Muestra HHMM, incrementa el reloj automáticamente y hace parpadear D8.
*/
/****************************************/
.include "M328PDEF.inc"

/****************************************/
/* Constantes */
.equ T0_COMPARE   = 124
.equ T1_COMPARE_H = HIGH(7811)
.equ T1_COMPARE_L = LOW(7811)

/****************************************/
/* SRAM */
.dseg
.org SRAM_START
mux:        .byte 1
blink_500ms:.byte 1

u_min:      .byte 1
d_min:      .byte 1
u_hor:      .byte 1
d_hor:      .byte 1
sec_cnt:    .byte 1

/****************************************/
/* Código */
.cseg
.org 0x0000
    RJMP RESET

.org 0x0016
    RJMP TMR1_ISR

.org 0x001C
    RJMP TMR0_ISR

/****************************************/
/* Configuración de la pila */
RESET:
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16
    RJMP    SETUP

/****************************************/
/* Configuración MCU */
SETUP:
    CLI
    CLR     R1

    LDI     R16, 0x00
    STS     UCSR0B, R16

    LDI     R16, (1<<DDB0)|(1<<DDB1)|(1<<DDB2)|(1<<DDB3)|(1<<DDB4)
    OUT     DDRB, R16
    CBI     PORTB, PORTB0
    CBI     PORTB, PORTB1
    CBI     PORTB, PORTB2
    CBI     PORTB, PORTB3
    CBI     PORTB, PORTB4

    LDI     R16, 0xFF
    OUT     DDRD, R16
    LDI     R16, 0b11111101
    OUT     PORTD, R16

    CLR     R16
    STS     mux, R16
    STS     blink_500ms, R16
    STS     sec_cnt, R16
    STS     u_min, R16
    STS     d_min, R16
    STS     u_hor, R16
    STS     d_hor, R16

    ; Timer0 ~2 ms para multiplexado
    LDI     R16, (1<<WGM01)
    OUT     TCCR0A, R16
    LDI     R16, (1<<CS02)
    OUT     TCCR0B, R16
    LDI     R16, T0_COMPARE
    OUT     OCR0A, R16
    CLR     R16
    OUT     TCNT0, R16
    LDI     R16, (1<<OCF0A)
    OUT     TIFR0, R16
    LDI     R16, (1<<OCIE0A)
    STS     TIMSK0, R16

    ; Timer1 ~500 ms
    CLR     R16
    STS     TCCR1A, R16
    LDI     R16, (1<<WGM12)|(1<<CS12)|(1<<CS10)
    STS     TCCR1B, R16
    LDI     R16, T1_COMPARE_H
    STS     OCR1AH, R16
    LDI     R16, T1_COMPARE_L
    STS     OCR1AL, R16
    CLR     R16
    STS     TCNT1H, R16
    STS     TCNT1L, R16
    LDI     R16, (1<<OCIE1A)
    STS     TIMSK1, R16

    SEI

/****************************************/
/* Loop principal */
MAIN_LOOP:
    RJMP    MAIN_LOOP


/****************************************/
/* Subrutinas no interrupt */
DIGITS_OFF:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    OUT     PORTB, R18
    RET

DIGIT_UM_ON:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    ORI     R18, (1<<PB4)
    OUT     PORTB, R18
    RET

DIGIT_DM_ON:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    ORI     R18, (1<<PB3)
    OUT     PORTB, R18
    RET

DIGIT_UH_ON:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    ORI     R18, (1<<PB2)
    OUT     PORTB, R18
    RET

DIGIT_DH_ON:
    IN      R18, PORTB
    ANDI    R18, 0b11100001
    ORI     R18, (1<<PB1)
    OUT     PORTB, R18
    RET

SEG7_WRITE:
    PUSH    R18
    PUSH    R19

    IN      R19, PORTD
    ANDI    R19, (1<<PD1)
    ORI     R19, 0b11111101
    OUT     PORTD, R19

    SBRS    R16, 0
    CBI     PORTD, PORTD2
    SBRS    R16, 1
    CBI     PORTD, PORTD3
    SBRS    R16, 2
    CBI     PORTD, PORTD4
    SBRS    R16, 3
    CBI     PORTD, PORTD5
    SBRS    R16, 4
    CBI     PORTD, PORTD6
    SBRS    R16, 5
    CBI     PORTD, PORTD7
    SBRS    R16, 6
    CBI     PORTD, PORTD0

    POP     R19
    POP     R18
    RET

SEG7_DECODE:
    PUSH    ZL
    PUSH    ZH
    LDI     ZH, HIGH(TABLA*2)
    LDI     ZL, LOW(TABLA*2)
    ADD     ZL, R16
    ADC     ZH, R1
    LPM     R16, Z
    POP     ZH
    POP     ZL
    RET

/****************************************/
/* Tabla 7 segmentos ánodo común */
TABLA:
    .DB 0x40,0x79,0x24,0x30,0x19,0x12,0x02,0x78
    .DB 0x00,0x10

/****************************************/
/* Rutinas de tiempo */
INC_CLOCK:
    LDS     R18, u_min
    INC     R18
    CPI     R18, 10
    BRLO    SAVE_UMIN
    CLR     R18
    STS     u_min, R18

    LDS     R18, d_min
    INC     R18
    CPI     R18, 6
    BRLO    SAVE_DMIN
    CLR     R18
    STS     d_min, R18

    LDS     R18, u_hor
    INC     R18
    LDS     R16, d_hor
    CPI     R16, 2
    BRNE    HOUR_NORMAL
    CPI     R18, 4
    BRLO    SAVE_UHOR
    CLR     R18
    STS     u_hor, R18
    CLR     R18
    STS     d_hor, R18
    RET

HOUR_NORMAL:
    CPI     R18, 10
    BRLO    SAVE_UHOR
    CLR     R18
    STS     u_hor, R18
    LDS     R18, d_hor
    INC     R18
    CPI     R18, 3
    BRLO    SAVE_DHOR
    CLR     R18

SAVE_DHOR:
    STS     d_hor, R18
    RET

SAVE_UHOR:
    STS     u_hor, R18
    RET

SAVE_DMIN:
    STS     d_min, R18
    RET

SAVE_UMIN:
    STS     u_min, R18
    RET

/****************************************/
/* Rutinas de interrupción */
TMR0_ISR:
    PUSH    R16
    PUSH    R17
    PUSH    R18
    IN      R17, SREG
    PUSH    R17

    RCALL   DIGITS_OFF

    LDS     R16, mux
    CPI     R16, 0
    BREQ    SHOW_UM
    CPI     R16, 1
    BREQ    SHOW_DM
    CPI     R16, 2
    BREQ    SHOW_UH
    RJMP    SHOW_DH

SHOW_UM:
    LDS     R16, u_min
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_UM_ON
    LDI     R16, 1
    STS     mux, R16
    RJMP    END_T0

SHOW_DM:
    LDS     R16, d_min
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_DM_ON
    LDI     R16, 2
    STS     mux, R16
    RJMP    END_T0

SHOW_UH:
    LDS     R16, u_hor
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_UH_ON
    LDI     R16, 3
    STS     mux, R16
    RJMP    END_T0

SHOW_DH:
    LDS     R16, d_hor
    RCALL   SEG7_DECODE
    RCALL   SEG7_WRITE
    RCALL   DIGIT_DH_ON
    CLR     R16
    STS     mux, R16

END_T0:
    POP     R17
    OUT     SREG, R17
    POP     R18
    POP     R17
    POP     R16
    RETI

TMR1_ISR:
    PUSH    R16
    PUSH    R17
    PUSH    R18
    IN      R17, SREG
    PUSH    R17

    ; Parpadeo de D8 cada 500 ms
    LDS     R16, blink_500ms
    CPI     R16, 0
    BREQ    BLINK_ON
    CLR     R16
    STS     blink_500ms, R16
    CBI     PORTB, PORTB0
    RJMP    COUNT_TIME

BLINK_ON:
    LDI     R16, 1
    STS     blink_500ms, R16
    SBI     PORTB, PORTB0

COUNT_TIME:
    LDS     R16, sec_cnt
    INC     R16
    CPI     R16, 2
    BRLO    SAVE_HALF
    CLR     R16
    STS     sec_cnt, R16
    RCALL   INC_CLOCK
    RJMP    END_T1

SAVE_HALF:
    STS     sec_cnt, R16

END_T1:
    POP     R17
    OUT     SREG, R17
    POP     R18
    POP     R17
    POP     R16
    RETI
