# Author: Walerij Hrul
#
# Read data from file and put it in another by using buffers and own funcs putc(), getc()
#
# registers used:
#	$s0 - input file descriptor
#	$s1 - number of readed bytes from inputBuffer
#	$s2 - number of loaded bytes into inputBuffer 
#	$s3 - output file descriptor
#	$s4 - actual size of output buffer
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
#

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

	.text	
main:	
	# set start values:
	li	$s1, 0				# there are not any bytes in buffers
	li	$s2, 0				#
	li	$s4, 0				#


	# get data from user and open files:
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
	li	$a1, 1				# flag for writing
	li	$a2, 0				# mode is ignored
	syscall
	move	$s3, $v0			# save file descriptor
	bltz	$s3, open_output_file_error	# negative if cannot open file


	# main part
	b	main_loop
	
step:						# write next byte; jump to closing files if error with errorMsg for user			
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
	
	
	# files closing
close_files:					# write into output file from output buffer; reset buffers; close files
	li	$v0, 16				# close input file
	move	$a0, $s0			# 
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
	
	b	exit				# finish programm


	# exit the program		
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




	# own functions
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



	
	
getcFunc:
	bne	$s1, $s2, return_byte		# if there are unreaded bytes skip upload new data
	li	$v0, 14				# read from file; file descriptor already in $a0
	la	$a1, inputBuffer		# destinated inputBuffer
	li	$a2, 512			# max byte to read
	syscall
	li 	$s1, 0				# set number of readed bytes
	move 	$s2, $v0			# save number of loaded bytes
	
	bgtz	$s2, return_byte
	jr	$ra				# $v0 already contains info 0 - if end of file; negative - if error
return_byte:
	la	$t0, inputBuffer		# get address of first unreaded byte in inputBuffer
	addu	$t0, $t0, $s1			#
	lbu	$v1, ($t0)			# load byte for returning
	addu	$s1, $s1, 1			# increase number of readed bytes from inputBuffer	
	li	$v0, 1				# set flag as positive
	jr	$ra





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
	la	$t0, outputBuffer		# store argument byte in ouputBuffer
	addu	$t0, $t0, $s4			#
	sb	$a1, ($t0)			# 
	addu	$s4, $s4, 1			# increase actual size of output buffer
	li	$v0, 1				# return flag success
	jr	$ra	
