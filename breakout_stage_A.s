# Breakout game
# Template: 		Fearghal Morgan
# Implementation: 	Anthony Bird
#					Luke Canny
# Oct 2022
# Description:		This is stage A of RISC-V assembly Breakout implementation.
#					Lines marked with <TODO> indicate modification required for stage B
#					For more info on stage A/B specs, see repository documentation (README.txt)

# ====== Register allocation START ======
# x0 always = 0
# x1 return address
# x2 stack pointer (when used)
# x3 IOIn(31:0) switches, address 0x00030008
# x4 program variable
# x5 memory address
# x6 dlyCount
# x7 counter variable
# x8 paddleNumDlyCount
# x9 ballNumDlyCount
# x10 X/YAdd ref             
# x11 Not used
# x12 Not used 
# x13 Not used
# x14 zone
# x15 dlyCountMax. 12.5MHz clock frequency. Two instructions per delay cycle => 6,250,000 delay cycles per second, 625,000 (0x98968) delay cycles per 100msec

# Wall
#  x16 wallVec value, default 0xffffffff
# Ball
#  x17 ballVec
#  x18 CSBallXAdd (4:0)
#  x19 NSBallXAdd (4:0)
#  x20 CSBallYAdd (4:0)
#  x21 NSBallYAdd (4:0)
#  x22 CSBallDir  (2:0)
#  x23 NSBallDir  (2:0)
#  x24 ballNumDlyMax (4:0)
# Paddle
#  x25 paddleVec
#  x26 paddleSize (5)
#  x27 paddleXAddLSB
#  x28 paddleNumDlyMax (4:0)
# Score and Lives 
#  x29 Score
#  x30 Lives
# x31  Not used

# ====== Register allocation END ======

main:
  #jal x1, clearArena 
  #jal x1, waitForGameGo    # wait for IOIn(2) input to toggle 0-1-0

  jal x1, setupDefaultArena # initialise arena values 
  #jal x1, setupArena1       
  
  jal x1, updateWallMem
  jal x1, updateBallVec
  jal x1, updateBallMem
  jal x1, updatePaddleMem
  jal x1, UpdateScoreMem
  jal x1, UpdateLivesMem
  add x8, x0, x28           # load paddleNumDlyCount start value
  add x9, x0, x24           # load ballNumDlyCount start value

  loop1:
   jal x1, delay
   processPaddle:
    bne x8, x0, processBall # paddleNumDlyCount = 0? => skip chkPaddle
    jal x1, chkPaddle 		# read left/right controls to move paddle between left and right boundaries
    jal x1, updatePaddleMem
    add x8,  x0, x28        # load paddleNumDlyCount start value
   processBall:
    bne x9, x0, loop1       # ballNumDlyCount = 0? => skip check ball functions 
    jal x1, chkBallZone     # find ball zone, update 1. ball, 2. wall, 3. score, 4. lives, loop or end game   *****Retuun x19 NSBallXAdd, x21 NSBallXAdd
# <TODO>: jump to endgame if lives = 0
	jal x1, updateBallVec   
    jal x1, updateBallMem   # clear CSBallYAdd row, write ballVec to NSBallYAdd, CSBallYAdd = NSBallYAdd (and for XAdd too) 
	jal x1, updateWallMem
	jal x1, UpdateScoreMem
    jal x1, UpdateLivesMem
    add x9, x0, x24         # load ballNumDlyCount start value
    jal x0, loop1

   1b: jal x0, 1b           # loop until reset asserted
 

# ====== Wall functions START ======
# The Wall Memory location is 0x0000003c (ROW 15) -> Note: 3c = 60 (4x15)
# This function is only called from the set up. We want to load 0xffffffff into memory address 0x0000003c
updateWallMem:

#======== The commented code is not even required because setupDefaultArena loads the registers with the right values :>

 andi x5, x5, 0			  # and immediate register 5 with 0 to clear it.
 addi x5, x5, 60	      # add immediate 60 to register x5
 # lui x16, 0xfffff	      #  x16 wallVec value, default 0xffffffff
 # srai x16, x16, 16	  # shift right arthmetic immediate
 
 sw x16, 0(x5)			  # store 0xffffffff into memory
 jalr x0,  0(x1)          # ret
# ====== Wall functions END ======


# ====== Ball functions START ======
updateBallVec:          			# Generate new ballVec using x19 (NSBallXAdd)
	addi x17, x0, 1					# reset ballVec
	addi x13,  x0, 0				# x13 = unused register to be used as a counter. Counting from 0
	beq x19, x13, skipBallVec		# loop again until in position
	loop2:
		slli x17, x17, 1			# shift ballVec left by one bit
		addi x13, x13,  1			# incrment counter
		bne x19, x13, loop2			# loop again until in position
	skipBallVec:
	jalr x0, 0(x1)           		# ret


updateBallMem: 		      # write to memory. Requires NSBallXAdd and NSBallYAdd. 
# clear CSBallYAdd row IN MEMORY, write ballVec to NSBallYAdd IN MEMORY, CSBallYAdd <= NSBallYAdd (and for XAdd too) 	
 sw x0, 0(x20)			# Clear CSBallYAdd row in memory. (aka clearing image)
 sw x17, 0(x21)			# Write ballVec to NSBallYAdd POSITION IN MEMORY
 
 andi x20, x0, 0		# Clear CSBallYAdd 
 xor x20, x20, x21		# CSBallYAdd <= NSBallYAdd
 andi x18, x18, 0		# Clear CSBallXAdd
 xor x18, x18, x19		# CSBallXAdd <= NSBallXAdd

 add x22, x23, x0		# CSBallDir <= NSBallDir

 ret_updateBallMem:
  jalr x0, 0(x1)        # ret


chkBallZone:
# <TODO>: 	- Implement NE, NW, SE, SW ball movement
#			- New ball direction vector based on paddle point-of-contact
#			- Ball movement into row 15 (wall) at points where wall is missing
#			- Ball bounce from arena boundaries
	updateNSBallYAdd:
		addi x12, x0, 1				# x12 = unused register
		beq x22, x12, goUp
		bne x22, x12, goDown
		
	chkWallValue:	
		or x11, x17, x16 			# combine ballVec and wallVec 
		beq x11, x16, scorePoint	# if the ball has not hit a gap in the wall -> score a point
		addi x21, x21, 4			# if next wall segment is missing -> continue to arena boundary
		beq x0, x0, goDown			# bounce off arena
		
	scorePoint:
		addi x29, x29, 1 			# increment score
		xor x16, x17, x16			# remove segment of wall that contacts ball
		beq x0, x0, goDown			# invert ball direction
		
	goUp:
		# check for wall
		addi x23, x0, 1				# set NSBallDir to 'up'
		addi x13, x0, 0x00000038 	# x13 = spare register | 0x00000038 = row below wall 
		beq x20, x13, chkWallValue
		addi x21, x21, 4			# increment NSBallYAdd by 4 (move one row up)		
		beq x0, x0, ret_chkBallZone	# Added by Luke 07/11/22 - return the function.
		
	goDown:
		# check for paddle
		addi x23, x0, 0					# set NSBallDir to 'down' 
		addi x13, x0, 0x0000000c		# 0x0000000c = row above paddle
		beq x20, x13, chkPaddlePos	
		addi x21, x21, -4				# decrement NSBallYAdd by 4 (move one row down)
		beq x0, x0, ret_chkBallZone		# Added by Luke 07/11/22 - return the function.
				
	chkPaddlePos:
		or x11, x17, x25 				# combine ballVec and paddleVec
		beq x11, x25, goUp				# if ball is in line with paddle -> bounce	
		addi x21, x21, -4				# decrement NSBallYAdd by 4 (move one row down)
		addi x30, x30, -1 				# decrement a life if  ball not in line with paddle
		beq x0, x0, respawn
	
	respawn:
		beq x30, x0, ret_chkBallZone	# check number of lives -> 0 lives = Endgame
		addi x21, x21, 4				# increment NSBallYAdd for respawn above paddle
		addi x23, x0, 1					# invert NSBallDir
# <TODO>: change NSBallXadd to move ball back to the center
		
	ret_chkBallZone:
		jalr x0, 0(x1)          		# ret

# ====== Ball functions END ======


# ====== Paddle functions START ======
updatePaddleMem:     # Generate new paddleVec and write to memory. Requires paddleSize and paddleXAddLSB 
 addi x4, x0, 1	 	 # Set program variable to 1.
 addi x25, x0, 1	 # Set LSB of paddle vec to 1.
 
 paddleLoop:
	slli x25, x25, 1 # Shift vec left by 1.
	addi x25, x25, 1 # Set LSB to 1.
	addi x4, x4, 1	 # Increment counter.
 bne x4, x26, paddleLoop
 
 sll x25, x25, x27   # Shift paddle left by XAddLSB
 
 addi x5, x0, 8		 # Set memory address 
 sw x25, 0(x5)		 # Swap Word into Memory
 jalr x0, 0(x1)      # ret


chkPaddle:
 # <TODO>: read left/right paddle control switches, memory address 0x00030008
 # one clock delay is required in memory peripheral to register change in switch state
 lui  x4, 0x00030    # 0x00030000 
 addi x4, x4, 8      # 0x00030008 # IOIn(31:0) address 
 lw   x3, 0(x4)      # read IOIn(31:0) switches
 ret_chkPaddle:
  jalr x0, 0(x1)    # ret
# ====== Paddle functions END ======


# ====== Score and Lives functions START ======
UpdateScoreMem:  
 addi x5, x0, 0      # memory base address
 sw   x29, 0(x5)     # store score 
 jalr x0, 0(x1)      # ret

UpdateLivesMem:  
 addi x5, x0, 0      # memory base address
 sw   x30, 4(x5)     # store lives
 jalr x0, 0(x1)      # ret

# ====== Score and Lives functions END ======


# ====== Setup arena variables START ======
setupDefaultArena: 
 # dlyCountMax 
					  # 12.5MHz clock frequency. Two instructions per delay cycle => 6,250,000 delay cycles per second, 625,000 (0x98968) delay cycles per 100msec
  lui  x15, 0x98968   # 0x98968000 
  srli x15, x15, 12   # 0x00098968 
  #addi x15, x0, 2     # low count delay, for testing 
 # Wall
  xori x16, x0, -1    # wall x16 = 0xffffffff
 # Ball
  lui x17,  0x00010   # ballVec 0b0000 0000 0000 0001 0000 0000 0000 0000 = 0x0007c000
  addi x18, x0, 16    # CSBallXAdd (4:0)
  addi x19, x0, 16    # NSBallXAdd (4:0)
  addi x20, x0, 12    # CSBallYAdd (4:0)			# Changed from 13 to 12...
  addi x21, x0, 12    # NSBallYAdd (4:0)			# Changed from 13 to 12... 
  addi x22, x0, 1     # CSBallDir  (2:0) N 
  addi x23, x0, 1	  # NSBallDir  (2:0) N
  addi x24, x0, 1     # ballNumDlyCount (4:0)
 # Paddle
  lui  x25, 0x0007c   # paddleVec 0b0000 0000 0000 0111 1100 0000 0000 0000 = 0x0007c000
  addi x26, x0, 5     # paddleSize
  addi x27, x0, 12    # paddleXAddLSB
  addi x28, x0, 1     # paddleNumDlyCount 
 # Score
  addi x29, x0, 0     # score
  addi x30, x0, 3     # lives 
 jalr x0, 0(x1)       # ret


setupArena1: 
 # dlyCountMax 
					  # 12.5MHz clock frequency. Two instructions per delay cycle => 6,250,000 delay cycles per second, 625,000 (0x98968) delay cycles per 100msec
  lui  x15, 0x98968   # 0x98968000 
  srli x15, x15, 12   # 0x00098968 
  #addi x15, x0, 2    # low count delay, for testing 
 # Wall
  lui  x16, 0xfedcb  
 # Ball
 # lui  x17, 0x00010  # ballVec 0b0000 0000 0000 0001 0000 0000 0000 0000 = 0x0007c000
  addi x18, x0, 6     # CSBallXAdd (4:0)
  addi x19, x0, 6     # NSBallXAdd (4:0)
  addi x20, x0, 8     # CSBallYAdd (4:0)
  addi x21, x0, 8     # NSBallYAdd (4:0)
  addi x22, x0, 6     # CSBallDir  (2:0)  NW
  addi x23, x0, 6	  # NSBallDir  (2:0)  NW
  addi x24, x0, 20    # ballNumDlyCount (4:0)
 # Paddle
  lui  x25, 0x007f8   # 0x007f8000 paddleVec = 0b0000 0000 0111 1111 1000 0000 0000 0000
  addi x26, x0, 8     # paddleSize
  addi x27, x0, 3     # paddleXAddLSB
  addi x28, x0, 10    # paddleNumDlyCount 
 # Score
  addi x29, x0, 3     # score
  addi x30, x0, 5     # lives 
  jalr x0, 0(x1)      # ret


clearArena: 
                      # initialise registers 
  addi x5, x0, 0      # base memory address
  addi x4, x0, 0      # loop counter
  addi x7, x0, 15     # max count value
  clearMemLoop:
    sw x0, 0(x5)      # clear memory word
	addi x5, x5, 4    # increment memory byte address
	addi x4, x4, 1    # increment loop counter 	
	ble  x4, x7, clearMemLoop  
  jalr x0, 0(x1)    # ret

# ====== Setup arena variables END ======


# ====== Other functions START ======
delay:
 add x6, x0, x15         # load dlyCount start value
 mainDlyLoop:
  addi x6, x6, -1        # decrement dlyCount
  bne  x6, x0, mainDlyLoop
  addi x8, x8, -1        # decrement paddleNumDlyCount
  addi x9, x9, -1        # decrement ballNumDlyCount
  jalr x0, 0(x1)         # ret
  

waitForGameGo:                    # wait 0-1-0 on input IOIn(2) control switches to start game	
                                  # one clock delay required in memory peripheral to register change in switch state
 lui  x4, 0x00030                 # 0x00030000 
 addi x4, x4, 8                   # 0x00030008 IOIn(31:0) address 
 addi x8, x0, 4                   # IOIn(2) = 1 compare value  

 waitUntilIOIn2Eq0: 
  lw   x3, 0(x4)                  # read IOIn(31:0) switches
  andi x7, x3, 4                  # mask to keep IOIn(2) 
  beq  x7, x0, waitUntilIOIn2Eq1  # chk / progress if IOIn(2) = 0
  beq  x0, x0, waitUntilIOIn2Eq0  # unconditional loop (else keep checking)
 
 waitUntilIOIn2Eq1: 
  lw   x3, 0(x4)                  # read IOIn(31:0) switches
  andi x7, x3, 4                  # mask to keep IOIn(2) 
  beq  x7, x8, waitUntilIOIn2Eq0b # chk / progress if IOIn(2) = 1
  beq  x0, x0, waitUntilIOIn2Eq1  # unconditional loop (else keep checking)

 waitUntilIOIn2Eq0b: 
  lw   x3, 0(x4)                  # read IOIn(31:0) switches
  andi x7, x3, 4                  # mask to keep IOIn(2) 
  beq  x7, x0, ret_waitForGameGo  # chk / progress if IOIn(2) = 0
  beq  x0, x0, waitUntilIOIn2Eq0b # unconditional loop (else keep checking)

 ret_waitForGameGo:
  jalr x0, 0(x1)                  # ret



endGame:                          
# <TODO>: highlight game over in display 
  jalr x0, 0(x1)                  # ret
  
# ====== Other functions END ======
