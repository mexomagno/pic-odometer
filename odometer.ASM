;******************************************************************************
;   This file is a basic code template for object module code                 *
;   generation on the PIC12F675. This file contains the                       *
;   basic code building blocks to build upon.                                 *
;                                                                             *
;   Refer to the MPASM User's Guide for additional information on             *
;   features of the assembler and linker (Document DS33014).                  *
;                                                                             *
;   Refer to the respective PIC data sheet for additional                     *
;   information on the instruction set.                                       *
;                                                                             *
;******************************************************************************
;                                                                             *
;    Filename:      velocimetro.asm                                           *
;    Date:           14/11/2013                                               *
;    File Version:  0.1                                                       *
;                                                                             *
;    Author:  Maximiliano Castro                                              *
;    Company: Cahco Electronics                                               *
;                                                                             *
;                                                                             *
;******************************************************************************
;                                                                             *
;    Files required: P12F675.INC                                              *
;                                                                             *
;                                                                             *
;                                                                             *
;******************************************************************************
;                                                                             *
;    Notes: En respuesta a la horrible versi�n demo del compilador XC8, me    *
;	he visto obligado a hacer mi programa en assembler.                       *
;                                                                             *
;******************************************************************************

;------------------------------------------------------------------------------
; PROCESSOR DECLARATION
;------------------------------------------------------------------------------

     LIST      P=12F675              ; list directive to define processor
     #INCLUDE <P12F675.INC>          ; processor specific variable definitions

;------------------------------------------------------------------------------
;
; CONFIGURATION WORD SETUP
;
; The 'CONFIG' directive is used to embed the configuration word within the 
; .asm file. The lables following the directive are located in the respective 
; .inc file.  See the data sheet for additional information on configuration 
; word settings.
;
;------------------------------------------------------------------------------

    __CONFIG   _CP_OFF & _CPD_OFF & _BODEN_OFF & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT 

;------------------------------------------------------------------------------
; VARIABLE DEFINITIONS
;------------------------------------------------------------------------------

; example of using Shared Uninitialized Data Section
INT_VAR     UDATA_SHR   0x20   
W_TEMP      RES     1             ; variable used for context saving 
STATUS_TEMP RES     1             ; variable used for context saving

;MIS VARIABLES
GENVAR		UDATA_SHR
gpiocopia	RES		1			;copia de GPIO
number		RES		1			;n�mero real
displaynumber		RES		1			;Numero en displays
pausa1		RES		1
pausa2		RES		1
freq		RES		1
waux		RES		1
display		RES		1			;display activo. 0 = menos significativo








;------------------------------------------------------------------------------
; EEPROM INITIALIZATION
;
; The 12F675 has 128 bytes of non-volatile EEPROM, starting at address 0x2100
; 
;------------------------------------------------------------------------------

DATAEE    CODE  0x2100
    DE    "MCHP"          ; Place 'M' 'C' 'H' 'P' at address 0,1,2,3

;------------------------------------------------------------------------------
; OSCILLATOR CALIBRATION VALUE
;------------------------------------------------------------------------------

OSC       CODE    0x03FF

; Internal RC calibration value is placed at location 0x3FF by Microchip as
; a 0xADDLW K instruction, where the K is a literal value to be loaded into 
; the OSCCAL register.  

;------------------------------------------------------------------------------
; RESET VECTOR
;------------------------------------------------------------------------------

RESET_VECTOR  CODE    0x0000  ; processor reset vector
        GOTO    INIT         ; go to beginning of program
		;No hace nada m�s, pues sino no habr�a espacio para las instrucciones... el vector
		;de interrupciones est� 4 posiciones m�s arriba! asi que se env�a al main del programa
		;que est� por ah� en otro lugar m�s espacioso.
;------------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE
;------------------------------------------------------------------------------

INT_VECTOR    CODE    0x0004  ; interrupt vector location. SIEMPRE est� aca, por lo
							  ; menos en este tipo de chips.
        MOVWF   W_TEMP        ; save off current W register contents
        MOVF    STATUS,w      ; move status register into W register
        MOVWF   STATUS_TEMP   ; save off contents of STATUS register

; isr code can go here or be located as a call subroutine elsewhere


;***************************************************
;;C�digo de interrupciones
		;borrar flag de interrupci�n y cambiar valor del timer
		bcf		INTCON,T0IF
		movlw	.256-.250+.3
		banksel	TMR0
		addwf	TMR0,f
		
;cambiar display
		comf	display
		btfsc	display,0
		goto 	if1
		;else
		bcf		gpiocopia,5
		;displaynumber = number%10
		movf	number,w
		call	divide_10
		movwf	displaynumber
		goto	endif1
if1
		bsf		gpiocopia,5
		;displaynumber = number/10
		movf	number,w
		call	divide_10
		movf	waux,w
		movwf	displaynumber
endif1
		
		
;aumentar contadores de frecuencia
		decfsz	pausa1,f
		goto	write_display
		movlw	.40
		movwf	pausa1
		
		decfsz	pausa2,f
		goto	write_display
		movlw	.50
		movwf	pausa2
;llega ac� cuando cumpli� el tiempo de delay fijado
		
write_display
		;**********************************
		;Escribir n�mero en el display activo
		btfsc	displaynumber,0
		goto 	bitset0
		bcf		gpiocopia,0
		goto	next1
bitset0
		bsf		gpiocopia,0
next1
		btfsc	displaynumber,1
		goto 	bitset1
		bcf		gpiocopia,1
		goto	next2
bitset1
		bsf		gpiocopia,1
next2
		btfsc	displaynumber,2
		goto 	bitset2
		bcf		gpiocopia,2
		goto	next3
bitset2
		bsf		gpiocopia,2
next3
		btfsc	displaynumber,3
		goto 	bitset3
		bcf		gpiocopia,4
		goto	fin_handler
bitset3
		bsf		gpiocopia,4
;***************************************************
fin_handler		
        MOVF    STATUS_TEMP,w ; retrieve copy of STATUS register
        MOVWF   STATUS        ; restore pre-isr STATUS register contents
        SWAPF   W_TEMP,f
        SWAPF   W_TEMP,w      ; restore pre-isr W register contents
        RETFIE                ; return from interrupt


divide_10
    clrf    waux          ; result = 0
  
    addlw   .256-.160       ; W -= 160
    rlf     waux,    f    ; load cf to result bit
    btfss   waux,    0    ; skip if positive (CF == 1)    
    addlw   .160            ; else reload W    (CF == 0)
  
    addlw   .256-.80        ; W -= 80
    rlf     waux,    f    ; load cf to result bit
    btfss   waux,    0    ; skip if positive (CF == 1)    
    addlw   .80             ; else reload W    (CF == 0)

    addlw   .256-.40        ; W -= 40
    rlf     waux,    f    ; load cf to result bit
    btfss   waux,    0    ; skip if positive (CF == 1)    
    addlw   .40             ; else reload W    (CF == 0)

    addlw   .256-.20        ; W -= 20
    rlf     waux,    f    ; load cf to result bit
    btfss   waux,    0    ; skip if positive (CF == 1)    
    addlw   .20             ; else reload W    (CF == 0)

    addlw   .256-.10        ; W -= 10
    rlf     waux,    f    ; load cf to result bit
    btfss   waux,    0    ; skip if positive (CF == 1)    
    addlw   .10             ; else reload W    (CF == 0)

    ;addlw   .256-.5         ; W -= 5
    ;rlf     waux,    f    ; load cf to result bit
    ;btfss   waux,    0    ; skip if positive (CF == 1)    
    ;addlw   .5              ; else reload W    (CF == 0)

    return                  ; return the result
;w contiene w % 10
;waux contiene w / 10
;------------------------------------------------------------------------------
; MAIN PROGRAM
;------------------------------------------------------------------------------

MAIN_PROG     CODE

INIT

;------------------------------------------------------------------------------
; OSCCAL RESTORE (not required if internal OSC is not used)
;------------------------------------------------------------------------------

        errorlevel -302
        BSF     STATUS,RP0    ; set file register bank to 1 
        ;CALL    0x3FF         ; retrieve factory calibration value
        MOVLW	0X2F			;Valor de calibraci�n obtenido experimentalmente
        MOVWF   OSCCAL        ; update register with factory cal value 
        BCF     STATUS,RP0    ; set file register bank to 0
        errorlevel +302
;------------------------------------------------------------------------------
; PLACE USER PROGRAM HERE
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; FUNCIONES
;------------------------------------------------------------------------------
;recibe valor en w y entrega en w la divisi�n por 10



main
		;setear puertos como output
		bsf		STATUS,RP0
		banksel	TRISIO
		clrf	TRISIO
		;setear GPIO3 como input (no es necesario, pero lo har� de todas maneras)
		bsf		TRISIO,TRISIO3
		;Setear ANSEL para que sea digital
		;movlw	0x0
		;movwf	ANSEL
		;habilitar interrupciones timer0
		bsf		INTCON,T0IE
		;habilitar interrupciones GPIO3
		
		;limpiar flag de interrupci�n, por si acaso
		bcf		INTCON,T0IF
		;fijar prescaler en 1
		bsf		OPTION_REG,PSA
		;setear reloj interno como fuente de reloj
		bcf		OPTION_REG,T0CS
		;inicializar GPIO
		movlw	.0
		movwf	displaynumber
		clrf	gpiocopia
		banksel	GPIO
		clrf	GPIO
		;inicializar variables contadoras de interrupciones
		movlw	.40
		movwf	pausa1
		movlw	.50
		movwf	pausa2
		;inicializar display activo
		movlw	.0
		movwf	display
		;inicializar n�mero a mostrar
		movlw	.0
		movwf	number
		;habilitar interrupciones globales
		clrf	freq
		bsf		INTCON,GIE

;funcionamiento principal del programa
while1
		; actualizar valores seteados en los interrupts
		movf	gpiocopia,w
		banksel	GPIO
		movwf	GPIO
		
		
		
		
		
		
		
		btfsc	GPIO,GP3
		goto	endwhile
;cambiar n�mero
		incf	number,f
		movlw	.100
		xorwf	number,w ;si es 100, resulta cero y activa Z
		btfss	STATUS,Z	;Hay que aumentar n�mero
		goto	$+2
		;Si llega a 10, reiniciarlo
		clrf	number
endwhile	
		goto 	while1






        END                       ; directive 'end of program'
