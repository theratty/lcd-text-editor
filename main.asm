.DSEG 0, 50

SIGNS_BEGIN:
	.DB 
	0x1C, 'a',
	0x32, 'b',
	0x21, 'c',
	0x23, 'd',
	0x24, 'e',
	0x2B, 'f',
	0x34, 'g',
	0x33, 'h',
	0x43, 'i',
	0x3B, 'j',
	0x42, 'k',
	0x4B, 'l',
	0x3A, 'm',
	0x31, 'n',
	0x44, 'o',
	0x4D, 'p',
	0x15, 'q',
	0x2D, 'r',
	0x1B, 's',
	0x2C, 't',
	0x3C, 'u',
	0x2A, 'v',
	0x1D, 'w',
	0x22, 'x',
	0x35, 'y',
	0x1A, 'z',
	0x45, '0',
	0x16, '1',
	0x1E, '2',
	0x26, '3',
	0x25, '4',
	0x2E, '5',
	0x36, '6',
	0x3D, '7',
	0x3E, '8',
	0x46, '9',
	0x0E, '`',
	0x4E, '-',
	0x55, '=',
	0x5D, '\\',
	0x29, ' ',
	0x54, '[',
	0x5B, ']',
	0x4C, ';',
	0x52, '\'',
	0x41, ',',
	0x49, '.',
	0x4A, '/',
	0x66, 254, ; BACKSPACE
	0x5A, 255  ; ENTER
SIGNS_END:

.CSEG

.CONST 	PS2_COUNTER, 255
.CONST 	SIGN, 254
.CONST 	SIGN_READY, 0

.CONST 	TEMP_STORED_SING, 253

.CONST 	CUR_COL, 202
.CONST 	CUR_ROW, 203


.CONST 	PS2_CONFIG, 0b00000011
.CONST 	PS2_INT_EDGE_CONFIG, 0b00000001
.CONST 	PS2_INT_VALUE_CONFIG, 0b00000000
.CONST 	PS2_INT_MASK_CONFIG, 0b00000001
.CONST 	PS2_SIGNAL_LEN, 11

.CONST 	WAIT_FOR_SIGN_STATE, 1
.CONST 	WAIT_FOR_NEXT_PART_STATE, 2
.CONST 	SKIP_NEXT_SIGN_STATE, 3
.CONST 	STATE, 15

.PORT 	value_port, 0x30
.PORT 	control_port, 0x31
.PORT 	stack, 0xf1
.PORT 	uart0, 0x60
.PORT 	uart0_status, 0x61
.PORT 	ps2, 0x70
.PORT 	ps2_int_edge, 0x71
.PORT 	ps2_int_value, 0x72
.PORT 	ps2_int_mask, 0x73
.PORT 	leds, 0x0
.PORT 	int_mask, 0xE1
.PORT 	int_status, 0xE0


.MACRO PUSH, 1
	OUT 	#1, stack
.ENDM

.MACRO POP, 1
	IN 		#1, stack
.ENDM

CALL 	reset_regs
EINT
LOAD 	s0, 0b00000010
OUT		s0, int_mask
CALL 	configure_ps2

CALL 	init_display

CALL 	push_reg
LOAD 	s0, 0x80
_PUSH 	s0
CALL 	set_cursor
CALL 	pop_reg

LOAD 	s0, WAIT_FOR_SIGN_STATE
STORE 	s0, STATE


main:
	FETCH 	s0, SIGN_READY
	COMP 	s0, 0
	JUMP 	Z, skip

	LOAD 	s1, 0
	STORE 	s1, SIGN_READY

	FETCH 	s1, STATE

	COMP 	s1, WAIT_FOR_SIGN_STATE
	JUMP 	Z, handle_wait_for_sign_state

	COMP 	s1, SKIP_NEXT_SIGN_STATE
	JUMP 	Z, handle_skip_next_sign_state

	COMP 	s1, WAIT_FOR_NEXT_PART_STATE
	JUMP 	Z, handle_wait_for_next_part_state
skip:
	JUMP 	main

handle_wait_for_sign_state:
	COMP 	s0, 0xF0
	JUMP 	Z, handle_f0_received

	COMP 	s0, 0xE0
	JUMP 	Z, handle_e0_received

	JUMP handle_sing

handle_f0_received:
	LOAD 	s1, SKIP_NEXT_SIGN_STATE
	STORE 	s1, STATE
	JUMP 	skip

handle_e0_received:
	LOAD 	s1, WAIT_FOR_NEXT_PART_STATE
	STORE 	s1, STATE
	JUMP 	skip

handle_sing:
	LOAD 	s1, SIGNS_BEGIN
handle_sing_before_for:
	COMP 	s1, SIGNS_END
	JUMP 	Z, handle_sing_before_fin

	FETCH 	s2, s1
	COMP 	s2, s0
	JUMP 	Z, handle_sing_after_for

	ADD 	s1, 2
	JUMP 	handle_sing_before_for

handle_sing_after_for:
	ADD 	s1, 1
	FETCH 	s3, s1

	COMP 	s3, 255 ;enter
	JUMP 	Z, handle_enter

	COMP 	s3, 254 ;backspace
	JUMP 	Z, handle_backspace

	CALL 	push_reg
	CALL 	move_cur_to_bot_left_if_needef
	CALL 	pop_reg

	STORE 	s3, TEMP_STORED_SING
	FETCH 	s4, CUR_COL
	COMP 	s4, 0x0F
	JUMP 	Z, handle_sing_before_fin

	ADD 	s4, 1
	STORE 	s4, CUR_COL

	CALL 	push_reg
	FETCH 	s0, TEMP_STORED_SING
	_PUSH 	s0
	CALL 	write_data
	CALL 	pop_reg


handle_sing_before_fin:
	LOAD 	s1, WAIT_FOR_SIGN_STATE
	STORE 	s1, STATE

	JUMP 	skip

move_cur_to_top_right_if_needef:
	FETCH 	s0, CUR_ROW
	FETCH 	s1, CUR_COL

	COMP 	s0, 1
	RET 	NZ
	
	COMP 	s1, 0
	RET 	NZ

	LOAD 	s0, 0
	STORE 	s0, CUR_ROW
	LOAD 	s0, 0x0F
	STORE 	s0, CUR_COL
	CALL 	push_reg
	LOAD 	s0, 0x8F
	_PUSH 	s0
	CALL 	set_cursor
	CALL 	pop_reg
	RET

move_cur_to_bot_left_if_needef:
	FETCH 	s0, CUR_ROW
	FETCH 	s1, CUR_COL

	COMP 	s0, 0
	RET 	NZ
	COMP 	s1, 0x0F
	RET 	NZ

	LOAD 	s0, 1
	STORE 	s0, CUR_ROW
	LOAD 	s0, 0
	STORE 	s0, CUR_COL
	CALL 	push_reg
	LOAD 	s0, 0xC0
	_PUSH 	s0
	CALL 	set_cursor
	CALL 	pop_reg
	RET

handle_backspace:
	CALL 	handle_left_fun

	LOAD 	s3, ' '
	STORE 	s3, TEMP_STORED_SING
	FETCH 	s4, CUR_COL
	COMP 	s4, 0x0F
	JUMP 	Z, handle_sing_before_fin

	ADD 	s4, 1
	STORE 	s4, CUR_COL

	CALL 	push_reg
	FETCH 	s0, TEMP_STORED_SING
	_PUSH 	s0
	CALL 	write_data
	CALL 	pop_reg

	CALL 	handle_left_fun

	JUMP 	handle_sing_before_fin

handle_enter:
	FETCH 	s0, CUR_ROW
	COMP 	s0, 1
	JUMP 	Z, handle_sing_before_fin
	LOAD 	s0, 1
	STORE 	s0, CUR_ROW

	LOAD 	s0, 0
	STORE 	s0, CUR_COL

	CALL 	push_reg
	LOAD 	s0, 0xC0
	_PUSH 	s0
	CALL 	set_cursor
	CALL 	pop_reg

	JUMP 	handle_sing_before_fin

handle_skip_next_sign_state:
	LOAD 	s1, WAIT_FOR_SIGN_STATE
	STORE 	s1, STATE
	JUMP 	skip

handle_wait_for_next_part_state:
	COMP 	s0, 0xF0
	JUMP 	Z, handle_f0_received
	JUMP 	handle_special

handle_special:
	COMP 	s0, 0x6B ; left arrow
	JUMP 	Z, handle_left

	COMP 	s0, 0x74 ; right arrow
	JUMP 	Z, handle_right

	COMP 	s0, 0x75 ; up arrow
	JUMP 	Z, handle_up

	COMP 	s0, 0x72 ; down arrow
	JUMP 	Z, handle_down

handle_special_before_fin:
	LOAD 	s1, WAIT_FOR_SIGN_STATE
	STORE 	s1, STATE
	JUMP 	skip

handle_left:
	CALL 	handle_left_fun
	JUMP 	handle_special_before_fin

handle_left_fun:
	FETCH 	s0, CUR_ROW
	FETCH 	s1, CUR_COL

	CALL 	push_reg
	CALL 	move_cur_to_top_right_if_needef
	CALL 	pop_reg

	COMP 	s1, 0
	JUMP 	Z, handle_special_before_fin
	SUB 	s1, 1

first_line_left:
	COMP 	s0, 0
	JUMP 	NZ, seconc_line_left
	LOAD 	s3, 0x80
	OR 		s3, s1

	JUMP after_sec_line_left

seconc_line_left:
	LOAD 	s3, 0xC0
	OR 		s3, s1

after_sec_line_left:
	STORE 	s1, CUR_COL
	CALL 	push_reg
	LOAD 	s0, s3
	_PUSH 	s0
	CALL 	set_cursor
	CALL 	pop_reg

	RET

handle_right:
	FETCH 	s0, CUR_ROW
	FETCH 	s1, CUR_COL

	CALL 	push_reg
	CALL 	move_cur_to_bot_left_if_needef
	CALL 	pop_reg

	COMP 	s1, 0x0F
	JUMP 	Z, handle_special_before_fin
	ADD 	s1, 1

first_line_right:
	COMP 	s0, 0
	JUMP 	NZ, seconc_line_right
	LOAD 	s3, 0x80
	OR 		s3, s1

	JUMP 	after_sec_line_right

seconc_line_right:
	LOAD 	s3, 0xC0
	OR 		s3, s1

after_sec_line_right:
	STORE 	s1, CUR_COL
	CALL 	push_reg
	LOAD 	s0, s3
	_PUSH 	s0
	CALL 	set_cursor
	CALL 	pop_reg
	JUMP 	handle_special_before_fin


handle_up:
	FETCH 	s0, CUR_ROW
	FETCH 	s1, CUR_COL

	COMP 	s0, 0
	JUMP 	Z, handle_special_before_fin
	SUB 	s0, 1

	LOAD 	s3, 0x80
	OR 		s3, s1

	LOAD 	s4, 0
	STORE 	s4, CUR_ROW

	CALL 	push_reg
	LOAD 	s0, s3
	_PUSH 	s0
	CALL 	set_cursor
	CALL 	pop_reg

	JUMP 	handle_special_before_fin


handle_down:
	FETCH 	s0, CUR_ROW
	FETCH 	s1, CUR_COL

	COMP 	s0, 1
	JUMP 	Z, handle_special_before_fin
	ADD 	s0, 1

	LOAD 	s3, 0xC0
	OR 		s3, s1

	LOAD 	s4, 1
	STORE 	s4, CUR_ROW

	CALL 	push_reg
	LOAD 	s0, s3
	_PUSH 	s0
	CALL 	set_cursor
	CALL 	pop_reg

	JUMP 	handle_special_before_fin

configure_ps2:
	LOAD 	s0, PS2_CONFIG
	OUT 	s0, ps2
	LOAD 	s0, PS2_INT_EDGE_CONFIG
	OUT 	s0, ps2_int_edge
	LOAD 	s0, PS2_INT_VALUE_CONFIG
	OUT 	s0, ps2_int_value
	LOAD 	s0, PS2_INT_MASK_CONFIG
	OUT 	s0, ps2_int_mask
	RET

write_data:
	_POP 	s0
	LOAD 	s1, 0b00000010
	OUT 	s0, value_port
	OUT 	s1, control_port
	CALL 	wait_1_ms_with_stack
	OR 		s1, 0b00000001
	OUT 	s1, control_port
	LOAD 	s0, s0
	AND 	s1, 0b11111110
	OUT 	s1, control_port
	CALL 	wait_1_ms_with_stack

	RET

init_display:
	; 1
	CALL 	call_38x4
	CALL 	call_38x4
	CALL 	call_38x4
	CALL 	call_38x4

	; 2
	LOAD 	s0, 0x06
	LOAD 	s1, 0
	OUT 	s0, value_port
	OUT 	s1, control_port
	CALL 	wait_2_ms_with_stack
	OR 		s1, 0b00000001
	OUT 	s1, control_port
	LOAD 	s0, s0
	AND 	s1, 0b11111110
	OUT 	s1, control_port
	CALL 	wait_2_ms_with_stack

	; 3
	LOAD 	s0, 0x0E
	LOAD 	s1, 0
	OUT 	s0, value_port
	OUT 	s1, control_port
	CALL 	wait_2_ms_with_stack
	OR 		s1, 0b00000001
	OUT 	s1, control_port
	LOAD 	s0, s0
	AND 	s1, 0b11111110
	OUT 	s1, control_port
	CALL 	wait_2_ms_with_stack

	; 4
	LOAD 	s0, 0x01
	LOAD 	s1, 0
	OUT 	s0, value_port
	OUT 	s1, control_port
	CALL 	wait_2_ms_with_stack
	OR 		s1, 0b00000001
	OUT 	s1, control_port
	LOAD 	s0, s0
	AND 	s1, 0b11111110
	OUT 	s1, control_port
	CALL 	wait_2_ms_with_stack

	; 5
	CALL 	push_reg
	LOAD 	s0, 0b10000000
	_PUSH 	s0
	CALL 	set_cursor
	CALL 	pop_reg

	RET


set_cursor:
	_POP 	s0
	LOAD 	s1, 0
	OUT 	s0, value_port
	OUT 	s1, control_port
	CALL 	wait_1_ms_with_stack
	OR 		s1, 0b00000001
	OUT 	s1, control_port
	LOAD 	s0, s0
	AND 	s1, 0b11111110
	OUT 	s1, control_port
	CALL 	wait_1_ms_with_stack

	RET

call_38x4:
	LOAD 	s0, 0x38
	LOAD 	s1, 0
	OUT 	s0, value_port
	OUT 	s1, control_port
	CALL 	wait_2_ms_with_stack
	OR 		s1, 0b00000001
	OUT 	s1, control_port
	LOAD 	s0, s0
	AND 	s1, 0b11111110
	OUT 	s1, control_port
	CALL 	wait_5_ms_with_stack
	RET

wait_1_ms_with_stack:
	CALL 	push_reg
	LOAD 	s0, 1
	_PUSH 	s0
	CALL 	delay
	CALL 	pop_reg
	RET

wait_2_ms_with_stack:
	CALL 	push_reg
	LOAD 	s0, 2
	_PUSH 	s0
	CALL 	delay
	CALL 	pop_reg
	RET

wait_5_ms_with_stack:
	CALL 	push_reg
	LOAD 	s0, 5
	_PUSH 	s0
	CALL 	delay
	CALL 	pop_reg
	RET

push_reg:
	_PUSH 	s0
	_PUSH 	s1
	_PUSH 	s2
	_PUSH 	s3
	_PUSH 	s4
	_PUSH 	s5
	_PUSH 	s6
	_PUSH 	s7
	_PUSH 	s8
	_PUSH 	s9
	_PUSH 	sA
	_PUSH 	sB
	_PUSH 	sC
	_PUSH 	sD
	_PUSH 	sE
	_PUSH 	sF
	RET


pop_reg:
	_POP 	sF
	_POP 	sE
	_POP 	sD
	_POP 	sC
	_POP 	sB
	_POP 	sA
	_POP 	s9
	_POP 	s8
	_POP 	s7
	_POP 	s6
	_POP 	s5
	_POP 	s4
	_POP 	s3
	_POP 	s2
	_POP 	s1
	_POP 	s0
	RET

reset_regs:
	LOAD 	sF, 0
	LOAD 	sE, 0
	LOAD 	sD, 0
	LOAD 	sC, 0
	LOAD 	sB, 0
	LOAD 	sA, 0
	LOAD 	s9, 0
	LOAD 	s8, 0
	LOAD 	s7, 0
	LOAD 	s6, 0
	LOAD 	s5, 0
	LOAD 	s4, 0
	LOAD 	s3, 0
	LOAD 	s2, 0
	LOAD 	s1, 0
	LOAD 	s0, 0
	RET

delay:
	_POP 	s4
wait:	
	CALL 	delay_1ms
	SUB 	s4, 1
	JUMP 	NZ, wait
	RET

delay_1ms:
	LOAD 	s3, 10
wait_1ms:
	CALL 	delay_1m
	SUB 	s3, 1
	JUMP 	NZ, wait_1ms
	RET

delay_1m:
	LOAD 	s2, 25
wait_1m:
	CALL 	delay_40u
	SUB 	s2, 1
	JUMP 	NZ, wait_1m
	RET

delay_40u:
	LOAD 	s1, 38
wait_40u:
	CALL 	delay_1u
	SUB 	s1, 1
	JUMP 	NZ, wait_40u
	RET

delay_1u:
	LOAD 	s0, 24
wait_1u:
	SUB 	s0, 1
	JUMP 	NZ, wait_1u
	RET

interrupt_handler:
	CALL 	push_reg
	FETCH 	s0, PS2_COUNTER
	ADD 	s0, 1
	STORE 	s0, PS2_COUNTER

	COMP 	s0, 1
	JUMP 	Z, skip_int
	COMP 	s0, 10
	JUMP 	Z, skip_int
	COMP 	s0, 11
	JUMP 	Z, skip_int_fin

	IN 		s2, ps2
	SR0 	s2
	RR 		s2

	FETCH 	s1, SIGN
	SR0 	s1
	OR 		s1, s2
	STORE 	s1, SIGN

	JUMP 	skip_int

skip_int_fin:
	FETCH 	s1, SIGN
	STORE 	s1, SIGN_READY

	LOAD 	sE, 0
	STORE 	sE, SIGN
	STORE 	sE, PS2_COUNTER

skip_int:
	LOAD 	sD, 0
	OUT 	sD, int_status
	CALL 	pop_reg
	RETI

.CSEG 	0x3FF
JUMP 	interrupt_handler
