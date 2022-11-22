  # Breakout game
# Template: 		
#                   Fearghal Morgan
# Implementation: 	
#                   Anthony Bird     Luke Canny
# Nov 2022
# Description:		
#                   Final implementation of Breakout game, written in RISC-V assembly
#                   Includes bonus feature of static paddle placed in arena

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
# x11 program variable (for combining rows)
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
# x31  BONUS: Static PaddleVec
# ====== Register allocation END ======


main:
  # jal x1, clearArena 
  # jal x1, waitForGameGo    # wait for IOIn(2) input to toggle 0-1-0

  # jal x1, setupDefaultArena   # default arena for gameplay
  jal x1, testbench0         # Run Test 0 



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
    jal x1, chkPaddle 		  # read left/right controls to move paddle between left and right boundaries
    jal x1, updatePaddleMem
    add x8, x0, x28         # load paddleNumDlyCount start value
   processBall:
    bne x9, x0,  loop1      # ballNumDlyCount = 0? => skip check ball functions 
    jal x1, chkBallZone     # find ball zone, update 1. ball, 2. wall, 3. score, 4. lives, loop or end game   *****Retuun x19 NSBallXAdd, x21 NSBallXAdd
	  jal x1, updateBallAdd	  # update ball X and Y addresses, based on direction found from chkBallZone
	  beq x0, x30,  endGame	  # jump to ENDGAME scenario
	  jal x1, updateBallVec   
    jal x1, updateBallMem   # clear CSBallYAdd row, write ballVec to NSBallYAdd, CSBallYAdd = NSBallYAdd (and for XAdd too) 
	  jal x1, updateWallMem
	  jal x1, UpdateScoreMem
    jal x1, UpdateLivesMem
    add x9, x0, x24         # load ballNumDlyCount start value
    jal x0, loop1
   
# ====== Wall functions START ======
# The Wall Memory location is 0x0000003c (ROW 15) -> Note: 3c = 60 (4x15)
# This function is only called from the set up. We want to load 0xffffffff into memory address 0x0000003c
updateWallMem:
 andi x5, x5, 0			  # and immediate register 5 with 0 to clear it.
 addi x5, x5, 60	    # add immediate 60 to register x5
 sw   x16, 0(x5)			# store 0xffffffff into memory
 jalr x0,  0(x1)      # ret
# ====== Wall functions END ======


# ====== Ball functions START ======
updateBallVec:          	    # Generate new ballVec using x19 (NSBallXAdd)
	addi  x17,  x0,   1					# reset ballVec
	addi  x7,   x0,   0				    
	beq   x19,  x7,   skipBallVec		
	getBallVecXPos:             # loop until ball in correct X address
		slli  x17,  x17,  1			    
		addi  x7,   x7,   1			     
		bne   x19,  x7,   getBallVecXPos			  
	skipBallVec:
	jalr x0, 0(x1)           		# ret


updateBallMem: 		            # write ball to memory
  # clear CSBallYAdd row IN MEMORY, write ballVec to NSBallYAdd IN MEMORY, CSBallYAdd <= NSBallYAdd (and for XAdd too) 	
  sw    x0,   0(x20)			                # Clear CSBallYAdd row in memory. (aka clearing image)
  addi  x4,   x0,   44
  beq   x4,   x21,  updateStaticPaddle    # if NSBallYAdd will be in static paddle row
  sw    x17,  0(x21)			                # Write ballVec to NSBallYAdd POSITION IN MEMORY
  addi  x5,   x0,   0	
  sw    x31,  44(x5)			                # re-write static paddles back into memory
  beq   x0,   x0,   skipUpdateStaticPaddle 

  updateStaticPaddle:	
  or    x4,   x31,  x17   # merge ballVec and static paddleVec
  addi  x5,   x0,   0
  sw    x4,   44(x5)

  skipUpdateStaticPaddle:
  andi  x20,  x0,   0		  # Clear CSBallYAdd 
  xor   x20,  x20,  x21		# CSBallYAdd <= NSBallYAdd
  andi  x18,  x18,  0		  # Clear CSBallXAdd
  xor   x18,  x18,  x19		# CSBallXAdd <= NSBallXAdd

  ret_updateBallMem:
  jalr  x0,   0(x1)       # ret


chkBallZone:                  # determine ball location and trigger game event
  # finding ball Zone based on ball X & Y addresses
  addi  x4,   x0,   12
  beq   x20,  x4,   zone1		    # if in row 3
  addi  x4,   x0,   31
  beq   x18,  x4,   zone3OR4    # else if column 31
  addi  x4,   x0,   0
  beq   x18,  x4,   zone3OR4    # else if in column 0
  addi  x4,   x0,   56
  beq   x20,  x4,   zone2       # else if in row 14
  addi  x4,   x0,   40
  beq   x20,  x4,   zone5OR6    # else if in row 9
  addi  x4,   x0,   48
  beq   x20,  x4,   zone5OR6    # else if in row 11
  beq   x0,   x0,   zone5       # anywhere else in arena
	zone3OR4:
		addi  x4,   x0, 56
		blt   x20,  x4, zone3       # if lower than row 14 -> arena boundary
		beq   x0,   x0, zone4       # else -> arena corner
	zone5OR6:
		addi  x4,   x0, 10
		blt   x18,  x4, zone5OR6_1 
		beq   x18,  x4, zone5OR6_3
		addi  x4,   x0, 29
		blt   x18,  x4, zone5OR6_2
		beq   x18,  x4, zone5OR6_3
		
		zone5OR6_1:                  
			addi  x4,   x0,   2
			bge   x18,  x4,   zone6
			bne   x18,  x4,   zone5
			xori  x4,   x22,  2
			beq   x22,  x4,   zone5 
			beq   x0,   x0,   zone6
			
			
		zone5OR6_2:
			addi  x4,   x0,   21
			bge   x18,  x4,   zone6
			bne   x18,  x4,   zone5
			xori  x4,   x22,  2
			beq   x22,  x4,   zone5
			beq   x0,   x0,   zone6
		
		zone5OR6_3:
			xori  x4,   x22,  1
			beq   x22,  x4,   zone5
			beq   x0,   x0,   zone6
		
	
	zone1:	# above paddle (row 3)
		or    x11,  x17,  x25 				  # combine ballVec and paddleVec
		bne   x11,  x25,  respawn			  # if ball is not in line with paddle -> respawn
		slli  x12,  x25,  1  
		or    x11,  x12,  x17
		bne   x11,  x12,  rightRebound    
		srli  x12,  x25,  1
		or    x11,  x12,  x17
		bne   x11,  x12,  leftRebound
		addi  x23,  x0,   4					    # NSBallDir = N
		beq   x0,   x0,   ret_chkBallZone
		
		leftRebound:                # ball contacts left-side of paddle
			addi  x23,  x0, 6				  # NSBallDir = NW
			beq   x0,   x0, ret_chkBallZone
		rightRebound:             # ball contacts right-side of paddle 
			addi  x23,  x0, 5				  # NSBallDir = NE
			beq   x0,   x0, ret_chkBallZone
			
	zone2:	# below wall (row 14)
		addi  x4,   x0,   4
		blt   x22,  x4,   zone5          # if CSBallDir = S or SW or SE
		or    x11,  x17,  x16            # combine ballVec and wallVec 				
		beq   x11,  x16,  scorePoint   # if x11 = wallVec -> point of contact must have been a '1' -> score a point
		addi  x4,   x0,   4
		xor   x23,  x22,  x4				    # NSBallDir(2) = 0
		beq   x0,   x0,   ret_chkBallZone

	
  zone3: 	# arena boundary
		ori x4,   x22,  2
		beq x22,  x4,   leftBoundary   # if ball is moving left
		ori x4,   x22,  1
		beq x22,  x4,   rightBoundary  # if ball is moving right
		
		leftBoundary:
			xori  x23,  x23,  3
			beq   x0,   x0,   ret_chkBallZone
	
		rightBoundary:
			xori  x23,  x23,  3
			beq   x0,   x0,   ret_chkBallZone
		
		
	zone4:	# corner	
		xori  x23,  x23,  7				    # invert BallDir
		beq   x0,   x0,   ret_chkBallZone
		
		
	zone5:	# free space
		add   x23,  x0,   x22				    # NSBallDir = CSBallDir i.e. no change
		beq   x0,   x0,   ret_chkBallZone
		
	zone6:	# approaching static paddle 
		xori  x23,  x22,  4
		beq   x0,   x0,   ret_chkBallZone
	
	
	# addditional branches
	respawn:
		beq   x30,  x0,   ret_chkBallZone	# check number of lives -> 0 lives = Endgame
		addi  x30,  x30,  -1				# decrement lives
		addi  x18,  x0,   16				# reset ball X value to center arena
		addi  x23,  x0,   4					# set ball direction to N
		beq   x0,   x0,   ret_chkBallZone
		
	scorePoint:
		addi  x29,  x29,  1
		xor   x16,  x17,  x16 
		addi  x4,   x0,   4
		xor   x23,  x22,  x4				    # NSBallDir(2) = 0
		beq   x0,   x0,   ret_chkBallZone
		
	ret_chkBallZone:
		add   x22,  x23,  x0		        # CSBallDir <= NSBallDir
		jalr  x0,   0(x1)          		  # ret


updateBallAdd:                 # using CSBallDir to update NSBallXAdd & NSBallYAdd
  addi  x4,   x0, 0
  beq   x22,  x4, S
  addi  x4,   x0, 1
  beq   x22,  x4, SE
  addi  x4,   x0, 2
  beq   x22,  x4, SW 
  addi  x4,   x0, 4
  beq   x22,  x4, N 
  addi  x4,   x0, 5
  beq   x22,  x4, NE 
  addi  x4,   x0, 6
  beq   x22,  x4, NW
	
	S:  # South
		addi  x21,  x20,  -4	# NSBallYAdd = CSBallYAdd - 1
		addi  x19,  x18,  0	  # NSBallXAdd = CSBallXAdd
		beq   x0,   x0,   ret_updateBallAdd
	SE: # South East
		addi  x21,  x20,  -4	# NSBallYAdd = CSBallYAdd - 1
		addi  x19,  x18,  -1	# NSBallXAdd = CSBallXAdd - 1
		beq   x0,   x0,   ret_updateBallAdd
	SW: # South West
		addi  x21,  x20,  -4	# NSBallYAdd = CSBallYAdd - 1
		addi  x19,  x18,  1	# NSBallXAdd = CSBallXAdd + 1
		beq   x0,   x0,   ret_updateBallAdd
	N:  # North 
		addi  x21,  x20,  4	# NSBallYAdd = CSBallYAdd + 1
		addi  x19,  x18,  0	# NSBallXAdd = CSBallXAdd
		beq   x0,   x0,   ret_updateBallAdd
	NE: # North East
		addi  x21,  x20,  4	# NSBallYAdd = CSBallYAdd + 1
		addi  x19,  x18,  -1	# NSBallXAdd = CSBallXAdd - 1
		beq   x0,   x0,   ret_updateBallAdd
	NW:	# North West
		addi  x21,  x20,  4	# NSBallYAdd = CSBallYAdd + 1
		addi  x19,  x18,  1	# NSBallXAdd = CSBallXAdd + 1
		beq   x0,   x0,   ret_updateBallAdd
	
	ret_updateBallAdd:
		jalr  x0,   0(x1)
# ====== Ball functions END ======


# ====== Paddle functions START ======
updatePaddleMem:      # Generate new paddleVec and write to memory. Requires paddleSize and paddleXAddLSB 
 addi x7,   x0, 1	 	    
 addi x25,  x0, 1	    # Set LSB of paddle vec to 1.
 
 paddleLoop:
    slli  x25,  x25,  1  
    addi  x25,  x25,  1  
    addi  x7,   x7,   1	  # Increment counter.
    bne   x7,   x26,  paddleLoop
 
  sll   x25,  x25,  x27   # Shift paddle left by XAddLSB
  addi  x5,   x0,   8		  # Set memory address 
  sw    x25,  0(x5)		    # write paddleVec into Memory
  jalr  x0,   0(x1)       # ret


chkPaddle:
  # one clock delay is required in memory peripheral to register change in switch state
  lui   x4,   0x00030       # 0x00030000 
  addi  x4,   x4,   8       # 0x00030008 # IOIn(31:0) address  
  lw    x3,   0(x4)         # read IOIn(31:0) switches
  addi  x11,  x0,   1
  and   x11,  x11,  x3
  bne   x11,  x0,   paddleRight
  addi  x11,  x0,   2
  and   x11,  x11,  x3
  bne   x11,  x0,   paddleLeft
  beq   x0,   x0,   ret_chkPaddle
  paddleLeft:
    addi  x27,  x27,  1
    beq   x0,   x0,   ret_chkPaddle
  paddleRight:
    sub   x27,  x27,  x11
  ret_chkPaddle:
    jalr  x0,   0(x1)    # ret
# ====== Paddle functions END ======


# ====== Score and Lives functions START ======
UpdateScoreMem:  
 addi   x5,   x0,   0     # memory base address
 sw     x29,  0(x5)       # store score 
 jalr   x0,   0(x1)       # ret

UpdateLivesMem:  
 addi   x5,   x0,   0     # memory base address
 sw     x30,  4(x5)       # store lives
 jalr   x0,   0(x1)       # ret

# ====== Score and Lives functions END ======


# ====== Setup arena variables START ======
setupDefaultArena:  
	# 12.5MHz clock frequency. Two instructions per delay cycle => 6,250,000 delay cycles per second, 625,000 (0x98968) delay cycles per 100msec
  lui   x15,  0x98968     # 0x98968000 
  srli  x15,  x15,  9	    # 0x00098968 
  # addi x15, x0, 2       # low count delay, for testing 
  # Wall
  xori  x16,  x0,   -1    # wall x16 = 0xffffffff
  # Ball
  lui   x17,  0x00010     # ballVec 0b0000 0000 0000 0001 0000 0000 0000 0000 = 0x0007c000
  addi  x18,  x0,   16    # CSBallXAdd (4:0)
  addi  x19,  x0,   16    # NSBallXAdd (4:0)
  addi  x20,  x0,   12    # CSBallYAdd (4:0)			
  addi  x21,  x0,   12    # NSBallYAdd (4:0)			 
  addi  x22,  x0,   4     # CSBallDir  (2:0) = 100 = N
  addi  x23,  x0,   4 	  # NSBallDir  (2:0) = 100 = N
  addi  x24,  x0,   1     # ballNumDlyCount (4:0)
  # Paddle
  lui   x25,  0x0007c     # paddleVec 0b0000 0000 0000 0111 1100 0000 0000 0000 = 0x0007c000
  addi  x26,  x0,   5     # paddleSize
  addi  x27,  x0,   14    # paddleXAddLSB
  addi  x28,  x0,   1     # paddleNumDlyCount 
  # BONUS: Static Paddles
  lui   x31,  0x1fc00
  addi  x31,  x31,  0x3f8
  addi  x5,   x0,   0
  sw    x31,  44(x5)
  # Score
  addi  x29,  x0,   0     # score
  addi x30,   x0,   3     # lives 
  jalr  x0,   0(x1)       # ret


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
  addi x5, x0, 0      # base memory address
  addi x7, x0, 0      # loop counter
  addi x4, x0, 15     # max count value
  clearMemLoop:
    sw    x0, 0(x5)      # clear memory word
	  addi  x5, x5,   4    # increment memory byte address
	  addi  x7, x7,   1    # increment loop counter 	
	  ble   x4, x7, clearMemLoop  
  jalr x0, 0(x1)      # ret

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
  lw   x3, 0(x4)                   # read IOIn(31:0) switches
  andi x7, x3,  4                  # mask to keep IOIn(2) 
  beq  x7, x0,  waitUntilIOIn2Eq1  # chk / progress if IOIn(2) = 0
  beq  x0, x0,  waitUntilIOIn2Eq0  # unconditional loop (else keep checking)
 
 waitUntilIOIn2Eq1: 
  lw   x3, 0(x4)                   # read IOIn(31:0) switches
  andi x7, x3,  4                  # mask to keep IOIn(2) 
  beq  x7, x8,  waitUntilIOIn2Eq0b # chk / progress if IOIn(2) = 1
  beq  x0, x0,  waitUntilIOIn2Eq1  # unconditional loop (else keep checking)

 waitUntilIOIn2Eq0b: 
  lw   x3, 0(x4)                   # read IOIn(31:0) switches
  andi x7, x3,  4                  # mask to keep IOIn(2) 
  beq  x7, x0,  ret_waitForGameGo  # chk / progress if IOIn(2) = 0
  beq  x0, x0,  waitUntilIOIn2Eq0b # unconditional loop (else keep checking)

 ret_waitForGameGo:
  jalr x0, 0(x1)                  # ret


# ======================   EndGame Image START  ======================
endGame:           
  # Row 0 unchanged (we wish to preserve the score on the screen)
  
  # Row 1
  addi  x4, x0, 0	# Clear Program Variable
  addi  x5, x0, 4	# Load address into memory address register
  lui   x4, 0x1c21d	# Loading 0x1c21d200 into program variable (pixel data)
  addi  x4, x4, 0x200
  sw    x4, 0(x5)		# Storing into memory
  
  # Row 2
  addi  x4, x0, 0	
  addi  x5, x0, 8	# 	x22521200
  lui   x4, 0x22521	
  addi  x4, x4, 0x200
  sw    x4, 0(x5)		
  
  # Row 3
  addi  x4, x0, 0	
  addi  x5, x0, 12	# 	x229B9C00
  lui   x4, 0x229BA	
  addi  x4, x4, 0xC00
  sw    x4, 0(x5)	  
  
  # Row 4
  addi  x4, x0, 0	
  addi  x5, x0, 16	# 	x228A1200
  lui   x4, 0x228A1	
  addi  x4, x4, 0x200
  sw    x4, 0(x5)	
  
  # Row 5			- Also x228A1200
  addi  x5, x0, 20	 
  sw    x4, 0(x5)	
  
  # Row 6
  addi  x4, x0, 0	
  addi  x5, x0, 24	# 	1c89dc00
  lui   x4, 0x1C89E	
  addi  x4, x4, 0xC00
  sw    x4, 0(x5)	
  
  # Row 7
  addi  x4, x0, 0	
  addi  x5, x0, 28	# 	x00000000
  sw    x4, 0(x5)	
  
  # Row 8
  addi  x5, x0, 32	# 	x00000000
  sw    x4, 0(x5)	
  
  # Row 9
  addi  x4, x0, 0	
  addi  x5, x0, 36	# 	x1caa9c00
  lui   x4, 0x1CAAA	
  addi  x4, x4, 0xC00
  sw    x4, 0(x5)	
  
  # Row 10
  addi  x4, x0, 0	
  addi  x5, x0, 40	# 	x22aaa000
  lui   x4, 0x22AAA	
  addi  x4, x4, 0x000
  sw    x4, 0(x5)	
    
  # Row 11
  addi  x4, x0, 0	
  addi  x5, x0, 44	# 	x2EEAB800
  lui   x4, 0x2EEAC	
  addi  x4, x4, 0x800
  sw    x4, 0(x5)	
  
  # Row 12
  addi  x4, x0, 0	
  addi  x5, x0, 48	# 	20AAA000
  lui   x4, 0x20AAA	
  addi  x4, x4, 0x000
  sw    x4, 0(x5)	
  
  # Row 13	- Also x22521200
  addi  x5, x0, 52	
  sw    x4, 0(x5)	
  
  # Row 14
  addi  x4, x0, 0	
  addi  x5, x0, 56	# 	x1c451c00
  lui   x4, 0x1C452
  addi  x4, x4, 0xc00
  sw    x4, 0(x5)	
  
  # Row 15
  addi  x4, x0, 0	
  addi  x5, x0, 60	# 	x22521200
  sw    x4, 0(x5)	

  
  1b: jal x0, 1b  # loop until reset asserted
  
  
  jalr x0, 0(x1)                  # ret
# ======================   EndGame Image END  ======================

# ======================   WinGame Image START  ======================
winGame:           
  # Row 0 unchanged (we wish to preserve the score on the screen)
  # Row 1 unchanged (we wish to preserve the number of lives remaining)
  
  # Row 3-6 are all empty
  addi  x5, x0, 12	
  sw    x0, 0(x5)		
  addi  x5, x0, 16	
  sw    x0, 0(x5)		
  addi  x5, x0, 20	
  sw    x0, 0(x5)		
  addi  x5, x0, 24	
  sw    x0, 0(x5)		
  
  # ROW 7
  addi  x4, x0, 0
  addi  x5, x0, 28
  lui   x4, 0x36556
  addi  x4, x4, 0xd0a
  sw    x4, 0(x5)
  
  
  # Row 8
  addi  x4, x0, 0	
  addi  x5, x0, 32	
  lui   x4, 0x49555	
  addi  x4, x4, 0x100
  sw    x4, 0(x5)	  
  
  # Row 9
  addi  x4, x0, 0	
  addi  x5, x0, 36	
  lui   x4, 0x49556	
  addi  x4, x4, 0xD0A
  sw    x4, 0(x5)	

  # Row 10
  addi  x4, x0, 0	
  addi  x5, x0, 40	
  lui   x4, 0x49555	
  addi  x4, x4, 0x52A
  sw    x4, 0(x5)	
  
  # Row 11
  addi  x4, x0, 0	
  addi  x5, x0, 44	
  lui   x4, 0x4959a	
  addi  x4, x4, 0x9eA
  sw    x4, 0(x5)	
  
  # Row 12
  addi  x4, x0, 0	
  addi  x5, x0, 48	
  lui   x4, 0x41000	
  addi  x4, x4, 0xA
  sw    x4, 0(x5)
  
  # Row 13
  addi  x4, x0, 0	
  addi  x5, x0, 52	
  lui   x4, 0x41400	
  addi  x4, x4, 0xA
  sw    x4, 0(x5)
  
  # Row 14
  addi  x4, x0, 0	
  addi  x5, x0, 56	
  lui   x4, 0x41000	
  sw    x4, 0(x5)
  
  # Row 15
  addi  x4, x0, 0	
  addi  x5, x0, 60	
  sw    x4, 0(x5)
  
  1c: jal x0, 1c           # loop until reset asserted
  
  
  jalr x0, 0(x1)                  # ret
  
  
# ======================   WinGame Image END  ====================== 
# ====== Other functions END ======


# ======================   Test Benches Start ====================== #

# =================================== Test 0 Description ============================= #
# Test Number:				0
# Description:				Bounce ball off the LHS side of the paddle
#                     Ball will deflect in the NW direction.
# =================================== End of Description ============================= #

testbench0:  
	lui   x15,  0x98968     # 0x98968000 
  srli  x15,  x15,  9	    # 0x00098968 
  addi x15, x0, 2         # low count delay, for testing 
  
  # Wall
  xori  x16,  x0,   -1    # wall x16 = 0xffffffff
  
  # Ball
  lui   x17,  0x00010     # ballVec 0b0000 0000 0000 0001 0000 0000 0000 0000
  addi  x18,  x0,   18    # CSBallXAdd (4:0)
  addi  x19,  x0,   18    # NSBallXAdd (4:0)
  addi  x20,  x0,   20    # CSBallYAdd (4:0)		(Address 20 = Row 6)	
  addi  x21,  x0,   20    # NSBallYAdd (4:0)		(Address 20 = Row 6)		 
  addi  x22,  x0,   0     # CSBallDir  (2:0) = 000 = South
  addi  x23,  x0,   0 	  # NSBallDir  (2:0) = 000 = South
  addi  x24,  x0,   1     # ballNumDlyCount (4:0)
  
  # Paddle
  lui   x25,  0x0007c     # paddleVec 0b0000 0000 0000 0111 1100 0000 0000 0000 = 0x0007c000
  addi  x26,  x0,   5     # paddleSize
  addi  x27,  x0,   14    # paddleXAddLSB
  addi  x28,  x0,   1     # paddleNumDlyCount 
  
  # BONUS: Static Paddles
  lui   x31,  0x1fc00
  addi  x31,  x31,  0x3f8
  addi  x5,   x0,   0
  sw    x31,  44(x5)
  
  # Score
  addi  x29,  x0,   0     # score
  addi x30,   x0,   3     # lives 
  jalr  x0,   0(x1)       # ret

# =================================== Test 1 Description ============================= #
# Test Number:				1
# Description:				Bounce ball off the RHS side of the paddle
#                     Ball will deflect in the NE direction.
# =================================== End of Description ============================= #

testbench1:  
	lui   x15,  0x98968     # 0x98968000 
  srli  x15,  x15,  9	    # 0x00098968 
  addi x15, x0, 2         # low count delay, for testing 
  
  # Wall
  xori  x16,  x0,   -1    # wall x16 = 0xffffffff
  
  # Ball
  lui   x17,  0x00010     # ballVec 
  addi  x18,  x0,   14    # CSBallXAdd (4:0)
  addi  x19,  x0,   14    # NSBallXAdd (4:0)
  addi  x20,  x0,   20    # CSBallYAdd (4:0)		(Address 20 = Row 6)	
  addi  x21,  x0,   20    # NSBallYAdd (4:0)		(Address 20 = Row 6)
  addi  x22,  x0,   0     # CSBallDir  (2:0) = 000 = South
  addi  x23,  x0,   0 	  # NSBallDir  (2:0) = 000 = South
  addi  x24,  x0,   1     # ballNumDlyCount (4:0)
  
  # Paddle
  lui   x25,  0x0007c     # paddleVec 0b0000 0000 0000 0111 1100 0000 0000 0000 = 0x0007c000
  addi  x26,  x0,   5     # paddleSize
  addi  x27,  x0,   14    # paddleXAddLSB
  addi  x28,  x0,   1     # paddleNumDlyCount 
  
  # BONUS: Static Paddles
  lui   x31,  0x1fc00
  addi  x31,  x31,  0x3f8
  addi  x5,   x0,   0
  sw    x31,  44(x5)
  
  # Score
  addi  x29,  x0,   0     # score
  addi x30,   x0,   3     # lives 
  jalr  x0,   0(x1)       # ret

# =================================== Test 2 Description ============================= #
# Test Number:				2
# Description:				Bounce ball off the centre of the paddle
#                     Ball will deflect in the north direction (No change in X component)
# =================================== End of Description ============================= #

testbench2:  
	lui   x15,  0x98968     # 0x98968000 
  srli  x15,  x15,  9	    # 0x00098968 
  addi x15, x0, 2         # low count delay, for testing 
  
  # Wall
  xori  x16,  x0,   -1    # wall x16 = 0xffffffff
  
  # Ball
  lui   x17,  0x00010     # ballVec 
  addi  x18,  x0,   16    # CSBallXAdd (4:0)
  addi  x19,  x0,   16    # NSBallXAdd (4:0)
  addi  x20,  x0,   20    # CSBallYAdd (4:0)		(Address 20 = Row 6)	
  addi  x21,  x0,   20    # NSBallYAdd (4:0)		(Address 20 = Row 6)
  addi  x22,  x0,   0     # CSBallDir  (2:0) = 000 = South
  addi  x23,  x0,   0 	  # NSBallDir  (2:0) = 000 = South
  addi  x24,  x0,   1     # ballNumDlyCount (4:0)
  
  # Paddle
  lui   x25,  0x0007c     # paddleVec 0b0000 0000 0000 0111 1100 0000 0000 0000 = 0x0007c000
  addi  x26,  x0,   5     # paddleSize
  addi  x27,  x0,   14    # paddleXAddLSB
  addi  x28,  x0,   1     # paddleNumDlyCount 
  
  # BONUS: Static Paddles
  lui   x31,  0x1fc00
  addi  x31,  x31,  0x3f8
  addi  x5,   x0,   0
  sw    x31,  44(x5)
  
  # Score
  addi  x29,  x0,   0     # score
  addi x30,   x0,   3     # lives 
  jalr  x0,   0(x1)       # ret

# =================================== Test 3 Description ============================= #
# Test Number:				3
# Description:				Bounce ball off in the NW corner of the arena (Zone X edge case)
#                     Ball will bounce from NW movement to SE movement.
# =================================== End of Description ============================= #

testbench3: 
	lui   x15,  0x98968     # 0x98968000 
  srli  x15,  x15,  9	    # 0x00098968 
  addi x15, x0, 2         # low count delay, for testing 
  
  # Wall
  xori  x16,  x0,   -1    # wall x16 = 0xffffffff
  
  # Ball
  lui   x17,  0x00010     # ballVec 
  addi  x18,  x0,   28    # CSBallXAdd (4:0)
  addi  x19,  x0,   28    # NSBallXAdd (4:0)
  addi  x20,  x0,   44    # CSBallYAdd (4:0)		(Address 44 = Row 11)	
  addi  x21,  x0,   44    # NSBallYAdd (4:0)		(Address 44 = Row 11)
  addi  x22,  x0,   6     # CSBallDir  (2:0) = 110 = NW 
  addi  x23,  x0,   6 	  # NSBallDir  (2:0) = 110 = NW
  addi  x24,  x0,   1     # ballNumDlyCount (4:0)
  
  # Paddle
  lui   x25,  0x0007c     # paddleVec 0b0000 0000 0000 0111 1100 0000 0000 0000 = 0x0007c000
  addi  x26,  x0,   5     # paddleSize
  addi  x27,  x0,   14    # paddleXAddLSB
  addi  x28,  x0,   1     # paddleNumDlyCount 
  
  # BONUS: Static Paddles
  lui   x31,  0x1fc00
  addi  x31,  x31,  0x3f8
  addi  x5,   x0,   0
  sw    x31,  44(x5)
  
  # Score
  addi  x29,  x0,   0     # score
  addi x30,   x0,   3     # lives 
  jalr  x0,   0(x1)       # ret

# =================================== Test 4 Description ============================= #
# Test Number:				4
# Description:				Bounce ball off in the SW corner of the arena (Zone X edge case)
#                     Paddle is not present - Live is lost and ball will respawn
#                     Ball will not bounce, it will reset.
# =================================== End of Description ============================= #

testbench4:  
	lui   x15,  0x98968     # 0x98968000 
  srli  x15,  x15,  9	    # 0x00098968 
  addi x15, x0, 2         # low count delay, for testing 
  
  # Wall
  xori  x16,  x0,   -1    # wall x16 = 0xffffffff
  
  # Ball
  lui   x17,  0x00010     # ballVec 
  addi  x18,  x0,   28    # CSBallXAdd (4:0)
  addi  x19,  x0,   28    # NSBallXAdd (4:0)
  addi  x20,  x0,   24    # CSBallYAdd (4:0)		(Address 24 = Row 6)	
  addi  x21,  x0,   24    # NSBallYAdd (4:0)		(Address 24 = Row 6)
  addi  x22,  x0,   2     # CSBallDir  (2:0) = 010 = SW 
  addi  x23,  x0,   2 	  # NSBallDir  (2:0) = 010 = SW
  addi  x24,  x0,   1     # ballNumDlyCount (4:0)
  
  # Paddle
  lui   x25,  0x0007c     # paddleVec 0b0000 0000 0000 0111 1100 0000 0000 0000 = 0x0007c000
  addi  x26,  x0,   5     # paddleSize
  addi  x27,  x0,   27    # paddleXAddLSB
  addi  x28,  x0,   1     # paddleNumDlyCount 
  
  # BONUS: Static Paddles
  lui   x31,  0x1fc00
  addi  x31,  x31,  0x3f8
  addi  x5,   x0,   0
  sw    x31,  44(x5)
  
  # Score
  addi  x29,  x0,   0     # score
  addi x30,   x0,   3     # lives 
  jalr  x0,   0(x1)       # ret

# =================================== Test 5 Description ============================= #
# Test Number:				5
# Description:				Bounce ball off in the NW corner of the arena (Zone X edge case)
#                     Ball will bounce from NW movement to SE movement.
# =================================== End of Description ============================= #

testbench3:  # X=28, Y = 11	
	lui   x15,  0x98968     # 0x98968000 
  srli  x15,  x15,  9	    # 0x00098968 
  addi x15, x0, 2         # low count delay, for testing 
  
  # Wall
  xori  x16,  x0,   -1    # wall x16 = 0xffffffff
  
  # Ball
  lui   x17,  0x00010     # ballVec 0b0000 0000 0000 0001 0000 0000 0000 0000 = 0x0007c000
  addi  x18,  x0,   28    # CSBallXAdd (4:0)
  addi  x19,  x0,   28    # NSBallXAdd (4:0)
  addi  x20,  x0,   44    # CSBallYAdd (4:0)		(Address 44 = Row 11)	
  addi  x21,  x0,   44    # NSBallYAdd (4:0)		(Address 44 = Row 11)
  addi  x22,  x0,   6     # CSBallDir  (2:0) = 110 = NW 
  addi  x23,  x0,   6 	  # NSBallDir  (2:0) = 110 = NW
  addi  x24,  x0,   1     # ballNumDlyCount (4:0)
  
  # Paddle
  lui   x25,  0x0007c     # paddleVec 0b0000 0000 0000 0111 1100 0000 0000 0000 = 0x0007c000
  addi  x26,  x0,   5     # paddleSize
  addi  x27,  x0,   14    # paddleXAddLSB
  addi  x28,  x0,   1     # paddleNumDlyCount 
  
  # BONUS: Static Paddles
  lui   x31,  0x1fc00
  addi  x31,  x31,  0x3f8
  addi  x5,   x0,   0
  sw    x31,  44(x5)
  
  # Score
  addi  x29,  x0,   0     # score
  addi x30,   x0,   3     # lives 
  jalr  x0,   0(x1)       # ret