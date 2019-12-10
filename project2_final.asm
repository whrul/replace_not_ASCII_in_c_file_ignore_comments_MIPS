# Author: Walerij Hrul
#
# Program przetwarzający tekst poprawnego programu w języku
# C poprzez zastępowanie w stałych znakowych (pojedynczych znakach i łańcuchach)
# znaków spoza zakresu ASCII odpowiednimi sekwencjami \xnn.
#
# registers used:
#	$s0 - input file descriptor
#	$s1 - number of readed bytes from inputBuffer
#	$s2 - number of loaded bytes into inputBuffer 
#	$s3 - output file descriptor
#	$s4 - actual size of output buffer
#	$s5 - previous readed byte
#	$s6 - current mode flag: 1 - within single line comment; 2 -within  multi line comment; 3 - within quotation marks; 0 - otherwise
#
#	fixUserInputFunc():
#	$a0 - name of file as func argument for removing \n
#	$t0, $t1 for removing \n in file name from user input
#	$t0 - address of actulal byte
#	$t1 - value of actual byte
#
#	getcFunc():	
#	$a0 - descriptor of file for reading
#	$v0 - flag: negative - error; 0 - end of file; positive - success
#	$v1 - readed byte
#
#	putcFunc():
#	$a0 - descriptor of file for writing
#	$a1 - byte for writting
#	$v0 - flag: negative - error; otherwise - success
#	$t0 - calculate address of byte in buffer where write new one 
#
#	putcSmartFunc():
#	$a0 - descriptor of file for writing
#	$a1 - byte for writting (not within ASCII)
#	$v0 - flag: negative - error; otherwise - success
#	$t0 - address of byte in buffer where write new byte 
#	$t1 - byte for writting
#	$t2 - low half of byte
#	$t3 - high half of byte
#	$t4 - diff for calculating ASCII codes for hex > 9
#


# -------------------------------------------------------------------------------------------------------------------------
	.data
inputFileName:
	.space	64
outputFileName:
	.space	64
inputBuffer:
	.space	512
outputBuffer:
	.space	512
inputFileMsg:
	.asciiz "Input file name: "
outputFileMsg:
	.asciiz "Output file name: "
openErrorMsg:
	.asciiz "Cannot open file."
writeErrorMsg:
	.asciiz	"Cannot write into opened file."
readErrorMsg:
	.asciiz	"Cannot read from opened file."
# -------------------------------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------------------------------
	.text	
main:	
	# set start values BEGIN:
	li	$s1, 0				# there are not any bytes in buffers
	li	$s2, 0				#
	li	$s4, 0				#
	li	$s5, 0				# previous readed byte
	li	$s6, 0				# current mode
	# set start values END
# ----------------------------------------------

	# get data from user and open files BEGIN:
	li	$v0, 4				# ask user for input file name
	la	$a0, inputFileMsg
	syscall
	
	li	$v0, 8				# read from user file name
	la	$a0, inputFileName		# destinated inputBuffer
	li	$a1, 64				# max 64 bytes with \0
	syscall

	la	$a0, inputFileName
	jal	fixUserInputFunc		# remove \n from input name
	
	
	li	$v0, 13				# try to open file
	la	$a0, inputFileName		# name of file
	li	$a1, 0				# read mode
	li	$a2, 0				# mode is ignored
	syscall
	move	$s0, $v0			# save descriptor
	bltz	$s0, open_input_file_error	# negative if cannot open file
	
	li	$v0, 4				# ask user for ouput file name
	la	$a0, outputFileMsg
	syscall
	
	li	$v0, 8				# read from user file name
	la	$a0, outputFileName		# destinated inputBuffer
	li	$a1, 64				# max 64 bytes with \0
	syscall

	la	$a0, outputFileName
	jal	fixUserInputFunc		# remove \n from input name
	
	li	$v0, 13				# open file for writing
	la	$a0, outputFileName		# file name
	li	$a1, 1				# flag for writing with append
	li	$a2, 0				# mode is ignored
	syscall
	move	$s3, $v0			# save file descriptor
	bltz	$s3, open_output_file_error	# negative if cannot open file
	# get data from user and open files END	
# ----------------------------------------------

	b	main_loop
step:						# write next byte; jump to closing files if error with errorMsg for user			
	bne	$v1, '"', not_quotation
	beq	$s6, 1, mode_setted		# nothing to check if it's within comment
	beq	$s6, 2, mode_setted		#
	bne	$s6, 0, quotation_second
	li	$s6, 3				# set flag 'within string'
	b	mode_setted
quotation_second:
	beq	$s5, '\\', mode_setted		# ignore if quotation is a part of string
	li	$s6, 0				# change mode when exit string
	b	mode_setted			
	
not_quotation:
	bne	$v1, '/', not_slash		
	beq	$s6, 1, mode_setted		# within one line comment	
	beq	$s6, 3, mode_setted		# within string
	beq	$s6, 0, one_line_comment
	bne	$s5, '*', mode_setted		# */ was detected while multi-line flag active
	li	$s6, 0				# reset mode flag
	b	mode_setted
one_line_comment:
	bne	$s5, '/', mode_setted		# // was detected
	li	$s6, 1				# set flag as single line comment
	b	mode_setted

not_slash:
	bne	$v1, '*', not_star
	bne	$s6, 0, mode_setted
	bne	$s5, '/', mode_setted		# check for multiline comment /*
	li	$s6, 2
	b	mode_setted
	
not_star:
	bne	$v1, '\n', mode_setted	
	bne	$s6, 1, mode_setted		# if \n while single line comment, reset mode flag
	li	$s6, 0				#
	
mode_setted:	
	move	$s5, $v1			# save readed byte as previous readed byte
	move	$a0, $s3			# load file descriptor as first argument
	move	$a1, $v1			# load byte as second argument
	jal	putcFunc			# call func for writing byte
	bgez	$v0, main_loop			# $v0 contains negative if error was occured
	li	$v0, 4				# show error msg
	la	$a0, writeErrorMsg
	syscall
	b	close_files			# close files if error
main_loop:					# read next byte; jump to closing files if error with errorMsg for user
	move	$a0, $s0			# load file descriptor as first argument
	jal	getcFunc			# call func for reading byte
	bgtz	$v0, step
	beqz	$v0, close_files		# close_files if end of file
	
	li	$v0, 4				# show error msg
	la	$a0, readErrorMsg
	syscall
# ----------------------------------------------
	
close_files:					# write into output file from output buffer; reset buffers; close files
	li	$v0, 16				# close
	move	$a0, $s0			# input file
	syscall
	
	move	$s1, $s2			# reset buffer
	
	li	$v0, 15				# write to file	
	move	$a0, $s3			# file descriptor
	la	$a1, outputBuffer		# address of buffer from wchich to write
	move	$a2, $s4			# buffer length to write
	syscall
	
	bgez	$v0, without_error		# $v0 contains negative if error
	li	$v0, 4				# show error msg
	la	$a0, writeErrorMsg
	syscall
without_error:		
	li	$v0, 16				# close
	move	$a0, $s3			# ouput file
	syscall
	
	li	$s4, 0				# reset buffer
	# close files END
	
	b	exit				# finish programm

open_output_file_error:
	li	$v0, 16				# close
	move	$a0, $s0			# input file
	syscall	
open_input_file_error:
	li	$v0, 4				# show error msg
	la	$a0, openErrorMsg
	syscall

exit:
	li	$v0, 10				# exit the programm
	syscall
# -------------------------------------------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------------------------------------------
	# functions BEGIN:
fixUserInputFunc:				# remove \n from input name
	move	$t0, $a0			# load address of first byte of file name
loop_throw_file_name:				# remove \n from file name
	lbu	$t1, ($t0)			# get its value
	beqz	$t1, exit_loop			# if \0 there is no \n. nothing to do
	beq	$t1, '\n', is_new_line_symbol
	addu	$t0, $t0, 1			# move to next byte
	b	loop_throw_file_name
is_new_line_symbol:				# replace \n with \0 in file name
	li	$t1, '\0'
	sb	$t1, ($t0)
exit_loop:
	jr	$ra
# ----------------------------------------------	
	
getcFunc:
	bne	$s1, $s2, return_byte		# if there are unreaded bytes skip upload new data
	li	$v0, 14				# read from file; file descriptor already in $a0
	la	$a1, inputBuffer		# destinated inputBuffer
	li	$a2, 512			# max byte to read
	syscall
	li 	$s1, 0				# save number of readed bytes
	move 	$s2, $v0			# save number of loaded bytes
	
	bgtz	$s2, return_byte
	jr	$ra				# $v0 already contains info 0 - if end of file; negative - if error
return_byte:
	la	$t0, inputBuffer		# get address of first unreaded byte from inputBuffer
	addu	$t0, $t0, $s1			#
	lbu	$v1, ($t0)			# load byte for returning
	addu	$s1, $s1, 1			# increase number of readed bytes in inputBuffer	
	li	$v0, 1				# set flag as positive
	jr	$ra
# ----------------------------------------------

putcFunc:
	bltu	$s4, 512, add_byte_to_buffer	# check if buffer is full
	li	$v0, 15				# write to file	
	move	$t0, $a1			# save argument byte
	la	$a1, outputBuffer		# address of buffer from wchich to write; $a0 already contains file descriptor
	move	$a2, $s4			# buffer length to write
	syscall
	move	$a1, $t0
	bgez	$v0, successfully		# $v0 contains number of written bytes, negative if error
	jr	$ra				# $v0 already negative
successfully:
	li	$s4, 0
add_byte_to_buffer:
	la	$t0, outputBuffer		# get address of empty byte to write argument byte
	addu	$t0, $t0, $s4			#
	bgeu	$a1, 128, is_not_ascii
	sb	$a1, ($t0)			# store it
	addu	$s4, $s4, 1			# increase actual size of output buffer
	li	$v0, 1				# return flag success
	b	exit_putc_func
is_not_ascii:
	move	$s5, $ra
	jal	putcSmartFunc			# $a0 already contains file descriptor; $a1 - not ascii byte; success/error flag will returned in $v0
	move	$ra, $s5
exit_putc_func:	
	jr	$ra	
# ----------------------------------------------	
				
putcSmartFunc:
	bltu	$s4, 506, add_bytes_to_buffer	# check if buffer have space to save a 6-byte sequence
	li	$v0, 15				# write to file	
	move	$t0, $a1			# save argument byte
	la	$a1, outputBuffer		# address of buffer from wchich to write; $a0 already contains file descriptor
	move	$a2, $s4			# buffer length to write
	syscall
	move	$a1, $t0
	bgez	$v0, successfully_S		# $v0 contains number of written bytes, negative if error
	jr	$ra				# $v0 already negative
successfully_S:
	li	$s4, 0				# reset buffer
add_bytes_to_buffer:
	la	$t0, outputBuffer		# get address of byte in buffer to write next byte
	addu	$t0, $t0, $s4			#
	beq	$s6, 3, should_change		# should change only in mode 3 (within string)
	sb 	$a1, ($t0)
	addu	$s4, $s4, 1			
	li	$v0, 1
	jr	$ra
should_change:			
	li	$t1, '\\'			# write '/' symbol	
	sb	$t1, ($t0)			#
	addu	$s4, $s4, 1			# increase actual size of output buffer
	addu	$t0, $t0, 1			# move address to writing next byte	
	
	li	$t1, 'x'			
	sb	$t1, ($t0)			
	addu	$s4, $s4, 1			
	addu	$t0, $t0, 1			
	
	move	$t1, $a1			# $t1 contains argument byte
	andi	$t2, $t1, 0x0F			# $t2 contains low part of byte
	andi	$t3, $t1, 0xF0			# $t3 contains high part of byte writted as low 
	srl	$t3,$t3, 4			#
	
	li	$t4, 'A'			# $t4 contains the differnce for calculating ASCII code for hex dig > 9
	subu	$t4, $t4, '9'			#
	subu	$t4, $t4, 1			#
	
	move	$t1, $t3
	addu	$t1, $t1, '0'
	bleu	$t1, '9', high_is_correct
	addu	$t1, $t1, $t4
high_is_correct:
	sb	$t1, ($t0)
	addu	$s4, $s4, 1
	addu	$t0, $t0, 1
	
	move	$t1, $t2
	addu	$t1, $t1, '0'
	bleu	$t1, '9', low_is_correct
	addu	$t1, $t1, $t4
low_is_correct:
	sb	$t1, ($t0)
	addu	$s4, $s4, 1
	addu	$t0, $t0, 1		
	
	li	$t1, '"'			
	sb	$t1, ($t0)			
	addu	$s4, $s4, 1			
	addu	$t0, $t0, 1				
	
	li	$t1, '"'			
	sb	$t1, ($t0)			
	addu	$s4, $s4, 1			
	addu	$t0, $t0, 1				
	
	li	$v0, 1				# success flag
	jr	$ra
	# functions END
# -------------------------------------------------------------------------------------------------------------------------




