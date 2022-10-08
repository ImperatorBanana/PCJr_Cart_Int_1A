;; Interrupt Vector CONSTANTS
interrupt_vec_table	EQU 0000h
int18offset		EQU 018h * 04h
int18segment	EQU int18offset + 02h

;; BIOS Service Interrupt CONSTANTS
int_video						EQU	10h
svc_video_mode					EQU	00h
svc_video_write_char_tty		EQU	0Eh
int_timeofday					EQU 1Ah
svc_timeofday_read_clk_cnt		EQU 00h

; Video Modes
val_video_mode_80_25_grey		EQU	02h

;; CART Equates
cart_rom_len					EQU	2000h

;; Port Map
port_pic_data			EQU 21h ; PIC Data port
mask_enable_timer_int	EQU 0FEh ; 1111 1110

CARTSEG segment
assume CS:CARTSEG, DS:CARTSEG 
ORG	0000h

HEADER: ; PC Jr Cartridge Header
	cartridgeid			dw		0AA55h
	cartridgelength		db		cart_rom_len/512	
	jmp					INIT					;; ENTRY POINT
	headerend			db		00h

; ----------- PRINT UTILS ------------
UTIL_PRINT_HEX_NIBBLES PROC NEAR
	; CX = # Of nibbles to print
	; AX = 1-4 nibbles to print from AH high -> AL Low
UTIL_PRINT_HEX_NIBBLES_LOOP:
	rol		ax,1 ; Grab the highest nibble by Rotating left 4x
	rol		ax,1 ;
	rol		ax,1 ;
	rol		ax,1 ; 
	push	ax ; Save off the Nth rotated AX
	and		al,00Fh ; Isolate the nibble
	add		al,'0' ; Shift into the ASCII Numeric Range
	cmp		al,'9' ; Check if <= 9
	jle		UTIL_PRINT_HEX_NIBBLES_CONT
	add		al,'A'-'9'-1 ; If not, shift up to ASCII 'A' range
UTIL_PRINT_HEX_NIBBLES_CONT:
	mov		ah,svc_video_write_char_tty ; Select DOS Print TTY service
	int		int_video ; Print current character
	pop		ax ; Restore Nth rotated AX
	loop	UTIL_PRINT_HEX_NIBBLES_LOOP
	ret
UTIL_PRINT_HEX_NIBBLES ENDP

UTIL_PRINT_BYTE MACRO 	; Print 2 Nibbles from AH
	; AH = byte
	mov		cx,02h
	call 	UTIL_PRINT_HEX_NIBBLES
ENDM

UTIL_PRINT_WORD MACRO 	; Print 4 Nibbles from AX
	; AX = word
	mov		cx,04h
	call 	UTIL_PRINT_HEX_NIBBLES
ENDM

UTIL_PRINT_NEWLINE MACRO ;; Print \r\n for a newline
	mov		al,00Dh
	mov		ah,svc_video_write_char_tty
	int		int_video
	mov		al,00Ah
	mov		ah,svc_video_write_char_tty
	int		int_video
ENDM

UTIL_PRINT_SPACE MACRO ;; Prints out a <space> character
	mov		al,' '
	mov		ah,svc_video_write_char_tty
	int		int_video
ENDM

; ------------ Program Functions --------------
QUERY_MASK_REG PROC NEAR
	in		al,port_pic_data
	xchg	ah,al ; UTIL_PRINT_BYTE prints AH
	UTIL_PRINT_BYTE
	UTIL_PRINT_NEWLINE
	ret
QUERY_MASK_REG ENDP

TIME_OF_DAY PROC NEAR
	mov		ah,svc_timeofday_read_clk_cnt
	int		int_timeofday ; Populates CX,DX
	push	dx ; Save DX
	xchg	ax,cx ; Move High Order Clock Count to AX for printing
	UTIL_PRINT_WORD
	UTIL_PRINT_SPACE
	pop		dx ; Retrieve DX
	xchg	ax,dx ; Move Low Order Clock Count to AX for printing
	UTIL_PRINT_WORD
	UTIL_PRINT_NEWLINE
	ret
TIME_OF_DAY ENDP

DELAY PROC NEAR ; Simple delay function
	mov		cx,0FFFFh
D1:	loop	D1
	ret
DELAY ENDP

;; ---------------- INIT - IPL Loader --------
INIT PROC FAR
	; Set up the interrupt vector to boot into the cartridge
	mov		ax,interrupt_vec_table
	mov		es,ax ; Set ES to 0000h (the interrupt vector segment)
	mov		ax,cs
	mov		es:int18segment,ax ; Move the current Code Segment to the Interrupt Vector 2nd 2 bytes
	mov		ax,offset MAIN
	mov		es:int18offset,ax ; Move the Main Offset to the Interrupt Vector 1st 2 bytes
	ret
INIT ENDP

;; ---------------- MAIN ---------------------
MAIN PROC FAR
	sti ; Re-enable interrupts since we got here via an interrupt
	
	; Set Video Mode
	mov		ah,svc_video_mode
	mov		al,val_video_mode_80_25_grey
	int		int_video

	; Print current mask, timer, then delay, then print timer again 
	call	QUERY_MASK_REG
	call	TIME_OF_DAY
	call	DELAY
	call	TIME_OF_DAY

	; Enable the timer interrupt (Unmask it)
	cli
	in		al,port_pic_data 
	and		al,mask_enable_timer_int
	out		port_pic_data,al
	sti
	
	; Print current mask, timer, then delay, then print timer again 
	call	QUERY_MASK_REG
	call	TIME_OF_DAY
	call	DELAY
	call	TIME_OF_DAY

INF_LOOP: ;Infinite loop
	jmp		INF_LOOP
	
	
MAIN ENDP

ORG	cart_rom_len - 16; 15(name) + 2(chksum) ;; TODO - can the assembler calculate this
FOOTER: ; PCJr Cartridge Footer
	;;								"123456789ABCDE"
	cart_name					db	"Forum Int 1a $" ; 
	cart_chksum					dw	0CDABh ;; TODO - can the assembler calculate this?

CARTSEG ENDS
END ; End program
