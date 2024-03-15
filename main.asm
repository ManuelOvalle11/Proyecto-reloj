//*****************************************************************************
// Universidad del Valle de Guatemala
// IE2023: Programación de microcontroladores
// Autor: Manuel Ovalle 
// Proyecto: Proyecto Reloj 
// Hardware: ATMEGA328P
// Creado: 14/03/2024
//*****************************************************************************
// Encabezado
//*****************************************************************************

.include "M328PDEF.inc"
.cseg //Indica inicio del código
.org 0x00 //Indica el RESET
	JMP Main

.org 0x0008 // Vector de ISR : PCINT1
    JMP Control_botones 

.org 0x001A // Vector de ISR : TIMER1_OVF
    JMP ISR_TIMER_OVF1

.org 0x0020
	JMP ISR_TIMER_OVF0		//Interrupciones

Main:
//*****************************************************************************
// Formato Base
//*****************************************************************************
LDI R16, LOW(RAMEND) 
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17
//*****************************************************************************
// MCU
//*****************************************************************************

Setup:
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16 // Habilitamos el prescalar
	LDI R16, 0b0000_0100
	STS CLKPR, R16 // Frecuencia 1MGHz

	LDI R16, 0b0000_1111
	OUT PORTC, R16

	LDI R16, 0b0011_0000
	OUT DDRC, R16	// Entradas y salidas PORTC 

	LDI R16, 0b1111_1111 
	OUT DDRD, R16	// Entradas y salidas PORTD 

	LDI R16, 0b0011_1111
	OUT DDRB, R16	// Entradas y salidas PORTB 

	CLR R16
	LDI R16, (1 << TOIE0)
	STS TIMSK0, R16 //Habilitar interrupción de overflow para timer0

	LDI R16, (1 << TOIE1)
	STS TIMSK1, R16 //Habilitar interrupción de overflow para timer1

	LDI		R16, (0<<TXEN0)|(0<<RXEN0)
	STS		UCSR0B, R16			// Desactivar RX and TX 

	LDI R16, (1 << PCIE1)
    STS PCICR, R16 //Configurar PCIE1

	LDI R16, (1 << PCINT8) | (1 << PCINT9) | (1 << PCINT10) | (1 << PCINT11)
    STS PCMSK1, R16 //Habilitar la interrupción para los pines correspondientes


CALL Timer_1 // Timer_1
CALL Timer_0		//Timer_0

	SEI //  Interruciones globales 

	//					    0		1	2		3	4		5	6		7	8	9		
		Tabla_Display: .DB 0x3F, 0x9, 0x5E, 0x76, 0x65, 0x73, 0x7B, 0x26, 0x7F, 0x77, 0x70


	LDI ZH, HIGH(Tabla_Display << 1)
	LDI ZL, LOW(Tabla_Display << 1)
	LPM R19, Z
	MOV R24, ZL		//Display Minutos1
	MOV R25, ZL		//Display Minutos2
	MOV R26, ZL		//Display Horas1
	MOV R27, ZL		//Display Horas2

	MOV R18, ZL		//Display Dia1
	INC R18

	MOV R23, ZL		//Display Dia2
	MOV R28, ZL		//Display Meses1 
	INC R28

	MOV R29, ZL		//Display Meses2



	// Limpieza general de registros a utilizar
	CLR R17
	CLR R19
	CLR R21
	CLR R22

	//Loop general
	Loop:


	CPI R22, 1
	BREQ Minutes_Edit0 
	CPI R22, 2
	BREQ Hour_Edit0 

	CPI R22, 3
	BREQ Fecha_0 

	CPI R22, 4
	BREQ Edit_diasFecha_0 

	CPI R22, 5
	BREQ Edit_mesesFecha_0

	CPI R22, 0
	BREQ reloj

	RJMP Loop

reloj:
	SBRC R20, 1
	RJMP Display_count
	SBRC R20, 0
	RJMP Display_show
	RJMP Loop

//*****************************************************************************
Timer_0:
	CLR R16
	OUT TCCR0A, R16 ; modo normal

	CLR R16
	LDI R16, (1 << CS02 | 1 << CS00)
	OUT TCCR0B, R16 ; prescaler 1024

	LDI R16, 200 ; valor calculado donde inicia a contar
	OUT TCNT0, R16
	RET

//*****************************************************************************

Timer_1:
	CLR R16
	STS TCCR1A, R16 ; MODO NORMAL
	CLR R16 
	LDI R16, (1 << CS12 )|( 1 << CS10) ;PREESCALER DE 1024
	STS TCCR1B, R16
	CLR R16

	LDI R16, 0x1E ;DESBORDAMIENTO
	//LDI R16, 0xFF ;DESBORDAMIENTO
	STS TCNT1H, R16	;METEMOS VALOR INICIAL
	LDI R16, 0x1B ;DESBORDAMIENTO
	//LDI R16, 0xFF ;DESBORDAMIENTO
	STS TCNT1L, R16	;METEMOS VALOR INICIAL

	RET

//*****************************************************************************

//Interrupcion para incrementar el display
ISR_TIMER_OVF0:
	PUSH R16
	LDI R16, 251 ; Cargar el valor calculado en donde debería iniciar.
	OUT TCNT0, R16
	POP R16
SBR R20, 0b0000_0001

RETI

//*****************************************************************************

//Interrupcion para incrementar el display
ISR_TIMER_OVF1:
	LDI R16, 0x1E ;DESBORDAMIENTO LOW
	//LDI R16, 0xFF ;DESBORDAMIENTO
	STS TCNT1H, R16	;METEMOS VALOR INICIAL
	LDI R16, 0x1B ;DESBORDAMIENTO HIGH
	//LDI R16, 0xFF ;DESBORDAMIENTO
	STS TCNT1L, R16	;METEMOS VALOR INICIAL 

	SBR R20, 0b0000_0010

RETI

//*****************************************************************************

Minutes_Edit0:
RJMP Minutes_Edit1 

Hour_Edit0:
RJMP Hour_Edit1

Fecha_0:
RJMP Fecha_1

Edit_diasFecha_0:
RJMP Edit_diasFecha_1

Edit_mesesFecha_0:
RJMP Edit_mesesFecha_1

//*****************************************************************************

Display:	// Display de 7 segmentos 
SBIS PORTD, PD7
RJMP Apagar_Puntos
RJMP Enceder_Puntos

Enceder_Puntos:
OUT PORTD, R19
SBI PORTD, PD7
RJMP Puntos

Apagar_Puntos:
OUT PORTD, R19
CBI PORTD, PD7
RJMP Puntos

Puntos:

CPI R17, 50
BREQ Activar_Puntos 
INC R17

RET

Activar_Puntos:
	CLR R17
	SBIS PORTD, PD7
	RJMP Enceder_Puntos2
	RJMP Apagar_Puntos2

Enceder_Puntos2:
	SBI PORTD, PD7
	RET

Apagar_Puntos2:
	CBI PORTD, PD7
	RET


Display_count:
	CBR R20, 0b0000_0010

	RJMP Minutos1_inc

//*****************************************************************************

Display_show: //Revisa que debe de aumentar 
	CBR R20, 0b0000_0001

	SBIC PORTB, PB3
	RJMP Horas2
	SBIC PORTB, PB0
	RJMP Horas1
	SBIC PORTB, PB1
	RJMP Minutos2

	RJMP Minutos1

//*****************************************************************************

Minutos2:
	CBI PORTB, PB3
	SBI PORTB, PB2
	CBI PORTB, PB1
	CBI PORTB, PB0

	MOV ZL, R25
	LPM R19, Z
	CALL Display

	RJMP Loop

//*****************************************************************************

Minutos1:
	SBI PORTB, PB3
	CBI PORTB, PB2
	CBI PORTB, PB1
	CBI PORTB, PB0

	MOV ZL, R24
	LPM R19, Z
	CALL Display

	RJMP Loop


//*****************************************************************************


Horas2:
	CBI PORTB, PB3
	CBI PORTB, PB2
	CBI PORTB, PB1
	SBI PORTB, PB0

	MOV ZL, R27
	LPM R19, Z
	CALL Display

	RJMP Loop


//*****************************************************************************
Horas1:
	CBI PORTB, PB3
	CBI PORTB, PB2
	SBI PORTB, PB1
	CBI PORTB, PB0

	MOV ZL, R26
	LPM R19, Z
	CALL Display

	RJMP Loop

//*****************************************************************************
Display_show2:
RJMP Display_show

Minutes_Edit1:
RJMP Minutes_Edit 

Hour_Edit1:
RJMP Hour_Edit

Fecha_1:
RJMP Fecha

Edit_diasFecha_1:
RJMP Edit_diasFecha

Edit_mesesFecha_1:
RJMP Edit_mesesFecha

//*****************************************************************************


Minutos1_inc:
	CBR R20, 0b0000_1010
	INC R24
	MOV ZL, R24
	LPM R19, Z
	CPI R19, 0x70
	BREQ Reset_Minutos1_inc
	RJMP Loop 

Reset_Minutos1_inc:
	LDI R24, LOW(Tabla_Display << 1)
	CPI R25, 0x73
	BREQ Bzero_minutes
	RJMP Minutos2_inc

Bzero_minutes:
	DEC R24
	RJMP Minutos2_inc

Minutos2_inc: 
	INC R25
	MOV ZL, R25
	LPM R19, Z
	CPI R19, 0x7B
	BREQ Reset_Minutos2_inc
	RJMP Loop 

Reset_Minutos2_inc:
	CPI R22,1
	BREQ Reset_edit_minutes
	LDI R25, LOW(Tabla_Display << 1)
	RJMP Horas1_inc

Reset_edit_minutes:
	LDI R25, LOW(Tabla_Display << 1)
	DEC R24
	RJMP Minutos1_inc

Horas1_inc:
	CBR R20, 0b0000_1000

	INC R26
	MOV ZL, R27
	LPM R19, Z

	CPI R19, 0x5E
	BREQ Hour_top
	RJMP Normal_Hour

Hour_top:
	
	MOV ZL, R26
	LPM R19, Z
	CPI R19, 0x77
	BREQ Bzero_hours
	CPI R19, 0x65
	BREQ Reset_Horas1_inc
	RJMP Loop 	

Normal_Hour:
	
	MOV ZL, R26
	LPM R19, Z

	CPI R19, 0x70
	BREQ Reset_Horas1_inc
	RJMP Loop 	

Bzero_hours:
	dec R26
	RJMP Horas2_inc


Reset_Horas1_inc:
	LDI R26, LOW(Tabla_Display << 1)
	RJMP Horas2_inc

Horas2_inc: 
	INC R27
	MOV ZL, R27
	LPM R19, Z
	CPI R19, 0x76
	BREQ Reset_Horas2_inc
	RJMP Loop 	

Reset_Horas2_inc:
	CPI R22,2
	BREQ Reset_edit_hour
	LDI R27, LOW(Tabla_Display << 1)
	RJMP Dias1_inc

Reset_edit_hour:
	LDI R27, LOW(Tabla_Display << 1)
	RJMP Dias1_inc

//*****************************************************************************
Display_show3:
RJMP Display_show2

Minutos1_inc0:
RJMP Minutos1_inc
//*****************************************************************************

//Interrupcion botones  

Control_botones:
	
	IN R21, PINC
	SBRS R21, PC0
	INC R22
	CPI R22, 8
	BREQ Reset_botones 

	SBRS R21, PC2
	SBR R20, 0b0000_1000

	SBRS R21, PC1
	SBR R20, 0b0000_0100

	RETI

	Reset_botones:
	CLR R22
	RETI

//*****************************************************************************

Mode_Menu:

	RJMP Minutes_Edit

Minutes_Edit:
	SBRC R20, 0
	RJMP Display_show3

	SBRC R20, 3
	RJMP Minutos1_inc0

	SBRC R20, 2
	RJMP Minutos1_dec

	SBI PORTB, PB5 
	RJMP Loop

Hour_Edit:

	SBRC R20, 0
	RJMP Display_show3

	SBRC R20, 3
	RJMP Horas1_inc

	SBRC R20, 2
	RJMP Horas1_dec

	CBI PORTB, PB5 
	RJMP Loop

Minutos1_dec:
	CBR R20, 0b0000_0100
	MOV ZL, R24
	LPM R19, Z
	CPI R19, 0x3F
	BREQ Reset_Minutos1_dec
	DEC R24
	
	RJMP Loop 

Reset_Minutos1_dec:
	LDI R17, 9
	LDI R24, LOW(Tabla_Display << 1)
	ADD R24, R17
	RJMP Minutos2_dec

Minutos2_dec: 
	MOV ZL, R25
	LPM R19, Z
	CPI R19, 0x3F
	BREQ Reset_Minutos2_dec
	DEC R25
	RJMP Loop 

Reset_Minutos2_dec:
	LDI R17, 5
	LDI R25, LOW(Tabla_Display << 1)
	ADD R25, R17
	RJMP Loop

Horas1_dec:
	CBR R20, 0b0000_0100
	MOV ZL, R26
	LPM R19, Z
	DEC R26

	CPI R19, 0x3F
	BREQ Reset_Horas1_dec
	RJMP Loop

Reset_Horas1_dec:
	
	MOV ZL, R27
	LPM R19, Z
	CPI R19, 0x3F
	BREQ Reset_tophour_dec
	RJMP Reset_normalhour_dec

Reset_tophour_dec:
	LDI R17,3
	LDI R26, LOW(Tabla_Display << 1)
	ADD R26, R17
	RJMP Horas2_dec 

Reset_normalhour_dec:
	LDI R17,9
	LDI R26, LOW(Tabla_Display << 1)
	ADD R26, R17
	RJMP Horas2_dec 

Horas2_dec: 
	MOV ZL, R27
	LPM R19, Z
	DEC R27

	CPI R19, 0x3F
	BREQ Reset_Horas_2

	RJMP Loop 	

Reset_Horas_2:
	LDI R17,2
	LDI R27, LOW(Tabla_Display << 1)
	ADD R27, R17
	RJMP Loop 

Fecha: 
	SBRC R20, 0
	RJMP Display_show_fecha

	SBRC R20, 1
	RJMP Display_count

	RJMP Loop

Display_show_fecha: //Revisa que debe de aumentar 
	CBR R20, 0b0000_0001

	SBIC PORTB, PB3
	RJMP Meses2
	SBIC PORTB, PB0
	RJMP Meses1
	SBIC PORTB, PB1
	RJMP Dias2

	RJMP Dias1

//*****************************************************************************

Dias2:
	CBI PORTB, PB3
	SBI PORTB, PB2
	CBI PORTB, PB1
	CBI PORTB, PB0

	MOV ZL, R23
	LPM R19, Z
	CALL Display

	RJMP Loop


Dias1:
	SBI PORTB, PB3
	CBI PORTB, PB2
	CBI PORTB, PB1
	CBI PORTB, PB0

	MOV ZL, R18
	LPM R19, Z
	CALL Display

	RJMP Loop


Meses2:
	CBI PORTB, PB3
	CBI PORTB, PB2
	CBI PORTB, PB1
	SBI PORTB, PB0

	MOV ZL, R29
	LPM R19, Z
	CALL Display

	RJMP Loop

Meses1:
	CBI PORTB, PB3
	CBI PORTB, PB2
	SBI PORTB, PB1
	CBI PORTB, PB0

	MOV ZL, R28
	LPM R19, Z
	CALL Display

	RJMP Loop

//*****************************************************************************

Dias1_inc:
	CBR R20, 0b0000_1010 
	INC R18
	MOV ZL, R29
	LPM R19, Z
	CPI R19, 0x3F
	BREQ Meses_0X
	RJMP Meses_XX

Dias2_inc:
	INC R23
	MOV ZL, R29
	LPM R19, Z
	CPI R19, 0x3F
	BREQ Meses_0X
	RJMP Meses_XX

Meses1_inc:	
	CBR R20, 0b0000_1000
	INC R28
	CPI R22, 4
	BREQ Reset_edit_dias
	MOV ZL, R29
	LPM R19, Z
	CPI R19, 0x9
	BREQ Meses_0X_1
	RJMP Meses_XX_1

	Meses_0X_1:
	MOV ZL, R28
	LPM R19, Z
	CPI R19, 0x76
	BREQ rst_meses11
	RJMP Loop

	Meses_XX_1:
	MOV ZL, R28
	LPM R19, Z
	CPI R19, 0x70
	BREQ rst_meses1
	RJMP Loop

	rst_meses11:
	LDI R28, LOW(Tabla_Display << 1)
	INC R28
	RJMP Meses2_inc

	rst_meses1:
	LDI R28, LOW(Tabla_Display << 1)
	RJMP Meses2_inc

Meses2_inc:
	CBR R20, 0b0000_1000
	INC R29
	MOV ZL, R29
	LPM R19, Z
	CPI R19, 0x5E
	BREQ rst_meses2
	RJMP Loop

	rst_meses2:
	LDI R29, LOW(Tabla_Display << 1)
	RJMP Loop
			
Meses_0X:
	MOV ZL, R28
	LPM R19, Z
	CPI R19, 0x9 
	BREQ dias_31
	CPI R19, 0x5E 
	BREQ dias_29
	CPI R19, 0x76
	BREQ dias_31
	CPI R19, 0x65
	BREQ dias_30
	CPI R19, 0x73
	BREQ dias_31
	CPI R19, 0x7B
	BREQ dias_30
	CPI R19, 0x26
	BREQ dias_31
	CPI R19, 0x7F
	BREQ dias_31
	CPI R19, 0x77
	BREQ dias_30


Meses_XX:
	MOV ZL, R28
	LPM R19, Z
	CPI R19, 0x3F
	BREQ dias_31
	CPI R19, 0x9
	BREQ dias_30
	CPI R19, 0x5E
	BREQ dias_31
	CPI R19, 0x76
	BREQ End_Date

Reset_edit_dias:
	LDI R18, LOW(Tabla_Display << 1)
	LDI R23, LOW(Tabla_Display << 1)
	DEC R28
	RJMP Dias1_inc


dias_31:
	MOV ZL, R23
	LPM R19, Z
	CPI R19, 0x76
	BREQ Reset_dias31_v3
	RJMP Reset_dias31_v2

Reset_dias31_v3:
	MOV ZL, R18
	LPM R19, Z
	CPI R19, 0x5E
	BREQ Reset_dias1_top
	RJMP Loop

Reset_dias31_v2:
	MOV ZL, R18
	LPM R19, Z
	CPI R19, 0x70
	BREQ Reset_dias1

	RJMP Loop

dias_30:
	MOV ZL, R23
	LPM R19, Z
	CPI R19, 0x76
	BREQ Reset_dias30_v3
	RJMP Reset_dias31_v2

Reset_dias30_v3:
	MOV ZL, R18
	LPM R19, Z
	CPI R19, 0x9
	BREQ Reset_dias1_top
	RJMP Loop

dias_29:
	MOV ZL, R23
	LPM R19, Z
	CPI R19, 0x5E
	BREQ Reset_dias29_v3
	RJMP Reset_dias31_v2

Reset_dias29_v3:
	MOV ZL, R18
	LPM R19, Z
	CPI R19, 0x70
	BREQ Reset_dias1_top
	RJMP Loop

Reset_dias1:
	LDI R18, LOW(Tabla_Display << 1)
	RJMP Dias2_inc

Reset_dias1_top:
	LDI R23, LOW(Tabla_Display << 1)
	LDI R18, LOW(Tabla_Display << 1)
	INC R18

	MOV ZL, R28
	LPM R19, Z
	CPI R19, 0x77
	BREQ End_Meses0X
	RJMP Meses1_inc


End_Meses0X:
	LDI R28, LOW(Tabla_Display << 1)
	RJMP Meses2_inc

End_Date:

	LDI R18, LOW(Tabla_Display << 1)
	INC R18
	LDI R23, LOW(Tabla_Display << 1)
	LDI R28, LOW(Tabla_Display << 1)
	INC R28
	LDI R29, LOW(Tabla_Display << 1)
	RJMP Loop

		//					 0		1	2		3	4		5	6		7	8	9		
//		Tabla_Display: .DB 0x3F, 0x9, 0x5E, 0x76, 0x65, 0x73, 0x7B, 0x26, 0x7F, 0x77, 0x70

Edit_diasFecha:
	SBRC R20, 0
	RJMP Display_show_fecha

	SBRC R20, 3
	RJMP Dias_inc_edit

	RJMP Loop

Dias_inc_edit:
	RJMP Dias1_inc


Edit_mesesFecha:
	SBRC R20, 0
	RJMP Display_show_fecha

	SBRC R20, 3
	RJMP Meses_inc_edit

	RJMP Loop

Meses_inc_edit:
	RJMP Meses1_inc


