# Raspberry Pi Nyan Cat Internet meme in bare metal ARM assembly
# 16 bit color direct FB @ 1024x768 + DMA 11Khz audio
# Written by Mike Durso
# Nyan Cat belongs to the awesome prguitarman
# Some code borrowed from the folks in the RPI bare metal forum

.section .text
.code 32
.global start_asm
start_asm:
### Initalize stuff
		ldr     sp, =stackBottom		@ Set up the stack
		bl      InitLed         		@ Init LED pin
		ldr     r0, =21000000   		@ Wait a bit for the GPU to init
		bl      SmallDelay

GpuInitLoop:
		bl      InitFb					@ set up the framebuffer
		cmp     r0, #0
		bne     GpuInitLoop    	  		@ just in case FB Init didnt work, do it again
		bl      MemoryBarrier
		bl      DataCacheFlush
		
		bl      InitAudioOut        	@ set up audio out pins
		bl      InitPwmAudio        	@ set up PWM for audio
		mov     r1, #1
		bl      LedBlink

### Set up audio data and DMA, play Nyan audio
		
		# Convert 8 bit mono wave data to 32 bit stereo format needed for PWM
		ldr     r0, =297582         	@ loop counter (wave size minus header)
		ldr     r1, =SND_Sample     	@ source
		add     r1, r1, #44         	@ skip wave header
		ldr     r2, =sndDmaData     	@ dest
ConvertLoop:
		ldrb    r3, [r1], #1        	@ get one byte from wave data
		str     r3, [r2], #4        	@ write the byte twice as 32 bit int
		str     r3, [r2], #4
		subs    r0, r0, #1
		bne     ConvertLoop
		
		# Blink LED
		mov     r1, #1
		bl      LedBlink	    
		
		# set up DMA CB to repeatedly copy audio data to PWM FIFO
		ldr		r0, =0x04050148         @ NO_WIDE, PERMAP=5, SRC_INC, DEST_DREQ, WAIT_RESP
		ldr     r1, =dmaAudioCB
		str     r0, [r1]                @ set TI
		ldr     r0, =sndDmaData
		add     r0, r0, #0x40000000     @ translate to bus address
		str     r0, [r1, #0x4]          @ set source address
		ldr     r0, =0x7e20c018         @ PWM FIFO HW addr
		str     r0, [r1, #0x8]          @ set dest address
		ldr     r0, =0x245370
		str     r0, [r1, #0xC]          @ set length
		ldr     r0, =dmaAudioCB
		add     r0, r0, #0x40000000
		str     r0, [r1, #0x14]         @ set next to this DMA CB (create a loop)
		  
		# enable dma
		bl      MemoryBarrier
		bl      DataCacheFlush
		ldr	    r0, =dmaAudioCB
		add	    r0, r0, #0x40000000		@ translate to bus address
		ldr	    r1, =0x20007100
		str	    r0, [r1, #4]        	@ write location of dma cb to dma 1
		ldr	    r0, =0x10000001         @ WAIT_FOR_OUTSTANDING_WRITES, ACTIVE
		str	    r0, [r1]	            @ GO!!!           

### Animate Nyan graphics
# Screen size is 1024x768, anim is 50x50.  Each anim pixel is drawn as 14x14 solid box 
# with offset of 162x34 to center the graphic, an anim loop is 12 frames
		bl      MemoryBarrier
		bl      DataCacheFlush
		ldr     r1, =fbMem
		ldr     r6, [r1]        		@ r6 = base fb pointer
		ldr     r1, =picPallete 		@ r1 = base pallete pointer
Infloop:
		ldr     r2, =picData    		@ r2 = pic data pointer
		mov     r9, #12         		@ r9 = frame counter
.frameloop:        
		mov     r8, #50         		@ r8 = y pixel counter  50 - 1
.pixelyloop:
		# calc y offset
		mov     r7, #50		    		@ r0 = (50 - r8) * 1024 * 2 * 14
		sub     r7, r7, r8
		ldr     r3, =28672      		@ 1024 * 2 * 14
		mul     r0, r7, r3      
		add     r0, r0, r6      		@ r0 = fbmem address for current pixel
		ldr     r3, =69956      		@ (34816 + 162) * 2  offset to center
		add     r0, r0, r3
		mov     r7, #50         		@ r7 = x pixel counter  50 - 1
.pixelxloop:
		# get color index of next pic pixel
		mov     r4, #0
		ldrb    r4, [r2], #1    		@ r4 = color index
		# lookup RGB from pallete
		mov 	r4, r4, LSL #2			@ r4 * 4
		ldr     r3, [r1, r4]    		@ r3 = rgb val (RGGB0000)
		# draw a pixel box (14x14)
		push    {r1, r2}
		mov	    r1, #14
		mov	    r2, #14
		bl	    PixelBox
		pop     {r1, r2}
		add     r0, r0, #28  			@ move to next x fbmem location for box pixel (14*2)
		subs    r7, r7, #1   			@ dec x counter, did we complete the line?
		bne     .pixelxloop  			@ no, paint next pixel
		subs    r8, r8, #1   			@ yes dec y counter, did we complete the pic?
		bne     .pixelyloop  			@ no, go to next line
		ldr     r0, =500000    			@ yes, wait a little bit
		bl      SmallDelay
		subs    r9, r9, #1      		@ dec frame counter, did we complete a full loop
		bne     .frameloop      		@ no, paint next frame
		b       Infloop         		@ yes, do it all over again

/*** LIB ROUTINES ***/

SmallDelay:
		@ Set r0 to number of loops to wait approx 7000000 for a sec.
		subs    r0, r0, #1
		bne     SmallDelay
		mov     pc,lr

MemoryBarrier:
		push    {r0}
		mov     r0, #0x0000
		mcr     p15, #0, r0, c7, c10, #5
		pop     {r0}
		mov     pc, lr

SynchronisationBarrier:
		push    {r0}
		mov     r0, #0x0000
		mcr     p15, #0, r0, c7, c10, #4
		pop     {r0}
		mov     pc, lr
				
DataCacheFlush:
		push    {r0}
		mov     r0, #0x0000
		mcr     p15, #0, r0, c7, c14, #0
		pop     {r0}
		mov     pc, lr
								
DataSynchronisationBarrier:
		stmfd   sp!,{r0-r8,r12,lr}         	@ Store registers
		mcr     p15, 0, ip, c7, c5,  0      @ invalidate I cache
		mcr     p15, 0, ip, c7, c5,  6      @ invalidate BTB
		mcr     p15, 0, ip, c7, c10, 4      @ drain write buffer
		mcr     p15, 0, ip, c7, c10, 4      @ prefetch flush
		ldmfd   sp!,{r0-r8,r12,pc}          @ restore registers  and return


/*** FRAME BUFFER ***/

InitFb:
		@ r0 <= result, 0 is good
		
		@ set up values in framebuffer struct for 1024x768@16bit
		@ assume struct is already pre zeroed
		push    {r1, r2, r3, lr}
		ldr     r1, =fbStruct
		mov     r0, #1024
		str     r0, [r1]
		str     r0, [r1, #8]
		mov     r0, #768
		str     r0, [r1, #4]
		str     r0, [r1, #12]
		mov     r0, #16
		str     r0, [r1, #20]

		@ send address of fb struct to mailbox
		ldr     r0, =fbStruct
		add     r0, r0, #0x40000000
		lsr     r0, r0, #4
		mov     r1, #0x01              	@ The frame buffer uses channel 1
		bl      MailboxWrite

		@ Get confirmation of VC mailbox op
		mov     r0, #0x01               @ The frame buffer uses channel 1
		bl		MailboxRead

		@ Convert and save the Frame Buffer memory location
		ldr     r3, =fbVCPointer
		ldr     r2, [r3]
		sub     r0, r2, #0x40000000
		ldr     r3, =fbMem
		str     r0, [r3]
		
		@ Init is successful if mailbox result is 0 and pointer isnt 0
		mov     r0, #0
		cmp     r1, #0
		moveq   r1, #1
		cmp     r2, #0
		moveq   r1, #2
		pop     {r1, r2, r3, lr}
		mov     pc, lr

PixelBox:
		@ r0 => base position of frame buffer
		@ r1 => x size
		@ r2 => y size
		@ r3 => color  (RGGB0000)
		@ size must be even, assuming 1024x768

		push    {r4-r9}
		# build color 2 pixel half word regs
		mov     r4, r3, LSR #16
		orr     r3, r3, r4          	@ r3 = 2 pixels (RGGBRGGB)
		mov     r6,	r2		        	@ r6 = y counter
.pb_yloop:
		# calc y offset
		sub     r8, r2, r6 		    	@ r5 = (r2 - r6) * 1024 * 2 + r0
		mov     r9, #2048
		mul     r5, r8, r9
		add     r5, r5, r0          	@ r5 = fbmem pointer
		mov     r7, r1		        	@ r7 = x counter
.pb_xloop:
		# place 2 pixels
		str     r3, [r5], #4
		subs    r7, r7, #2
		bne     .pb_xloop
		subs    r6, r6, #1
		bne     .pb_yloop
		pop     {r4-r9}
		mov     pc, lr
		
/*** MAIL BOX ***/

MailboxWrite:
		@ r0 = value
		@ r1 = mailbox id

		push    {r2, r3, lr}
		@ wait for mailbox to be ready
.waitLoop:
		bl      MemoryBarrier
		bl      DataCacheFlush
		ldr     r2, =0x2000B898     	@ Mailbox status addr
		ldr     r3, [r2]
		cmp     r3, #0
		blt     .waitLoop
		ldr     r2, =0x2000B8A0     	@ Mailbox write addr
		and     r1, r1, #0xf        	@ Mask mailbox id
		orr     r3, r1, r0, lsl #4  	@ Combine value and id
		str     r3, [r2]
		pop     {r2, r3, lr}
		b       MemoryBarrier

MailboxRead:
		@ r0 => mailbox id
		@ r1 <= return value
		
		push    {r2, r3, lr}
		@ wait for mailbox to be ready
.loop2:
		bl      MemoryBarrier
		bl      DataCacheFlush
		ldr     r2, =0x2000B898
		ldr     r3, [r2]
		tst     r3, #0x40000000
		bne 	.loop2
		bl 		MemoryBarrier
		ldr 	r2, =0x2000B880
		ldr 	r1, [r2]
		and 	r2, r1, #0xf   			@ mask mailbox channel
		and 	r3, r0, #0xf
		cmp 	r2, r3
		bne 	.loop2
		bl 		MemoryBarrier
		lsr 	r1, r1, #4
		pop 	{r2, r3, lr}
		mov 	pc, lr

/*** GPIO ***/
InitLed:
		push 	{lr}
		bl 		MemoryBarrier
		bl 		DataCacheFlush
		ldr     r0, =0x20200004
		ldr     r1, [r0]
		bic     r1, r1, #0x1c0000
		orr     r1, r1, #0x40000
		str     r1, [r0]
		bl 		MemoryBarrier
		pop 	{lr}
		mov     pc, lr
		
LedBlink:
		@ r1 => number of times to blink
		push    {r0, r2, r3, lr}
		bl      MemoryBarrier
		bl      DataCacheFlush
.blinkloop:
		ldr     r2, =0x20200028
		mov     r3, #0x10000
		str     r3, [r2]
		ldr     r0, =7000000
		bl      SmallDelay
		ldr     r2, =0x2020001C
		mov     r3, #0x10000
		str     r3, [r2]
		ldr     r0, =7000000
		bl      SmallDelay
		subs    r1, r1, #1
		bne     .blinkloop
		ldr     r0, =7000000
		bl      SmallDelay
		pop     {r0, r2, r3, lr}
		mov     pc, lr

InitAudioOut:        
		# set pins 40 and 45 to pwm function (alt0)
		push    {r0, r1, r2, lr}
		bl 		MemoryBarrier
		bl 		DataCacheFlush
		ldr     r0, =0x20200010        	@ GPIO pins bank 4
		ldr     r1, [r0]
		ldr     r2, =0x00038007        	@ clear bits 0-2,15-17
		bic     r1, r1, r2
		ldr     r2, =0x00020004        	@ set bits 2,17
		orr     r1, r1, r2
		str     r1, [r0]
		bl 		MemoryBarrier
		pop     {r0, r1, r2, lr}
		mov     pc, lr
		
InitPwmAudio:
		# sets up the pwm clock and pwm module for 11025hz pcm audio using dma fifo
		push    {r0, r1}
		ldr     r0, =0x201010a0         @ CLOCK_BASE + 4*BCM2835_PWMCLK_CNTL
		ldr     r1, =0x5a000020         @ PM_PASSWORD | BCM2835_PWMCLK_CNTL_KILL
		str	    r1, [r0]			    @ store r1 value, to r0 value address
						   
		ldr     r0, =0x2020c000			@ PWM_BASE + 4*BCM2835_PWM_CONTROL
		mov	    r1, #0
		str	    r1, [r0]			    @ store r1 value, to r0 value address
		
		ldr     r0, =0x201010a4			@ CLOCK_BASE + 4*BCM2835_PWMCLK_DIV
		ldr     r1, =0x5a003000			@ PM_PASSWORD | (idiv<<12)
		str	    r1, [r0]			    @ store r1 value, to r0 value address
		
		ldr     r0, =0x201010a0			@ CLOCK_BASE + 4*BCM2835_PWMCLK_CNTL
		ldr     r1, =0x5a000011			@ PM_PASSWORD | BCM2835_PWMCLK_CNTL_ENABLE | BCM2835_PWMCLK_CNTL_OSCILLATOR
		str	    r1, [r0]			    @ store r1 value, to r0 value address   	

		ldr     r0, =0x2020c010			@ PWM_BASE + 4*BCM2835_PWM0_RANGE
		ldr     r1, =0x244			    @ range (11025hz = 0x244 Stereo) (11025hz = 0x488 Mono)
		str	    r1, [r0]			    @ store r1 value, to r0 value address
						   
		ldr     r0, =0x2020c020			@ PWM_BASE + 4*BCM2835_PWM1_RANGE
		ldr     r1, =0x244			    @ range (11025hz = 0x244 Stereo)(11025hz = 0x488 Mono)
		str	    r1, [r0]			    @ store r1 value, to r0 value address

		ldr     r0, =0x2020c000			@ PWM_BASE + 4*BCM2835_PWM_CONTROL
		mov	    r1, #0x40			    @ PWMCTL_CLRF
		str	    r1, [r0]			   

		ldr     r1, =0x80000707         @ enable dma, panic=7, dreq=7
		str     r1, [r0, #8]            @ PWM_BASE + DMAC

		ldr     r1, =0x2161			    @ BCM2835_PWM1_USEFIFO | BCM2835_PWM1_ENABLE | BCM2835_PWM0_USEFIFO | BCM2835_PWM0_ENABLE | 1<<6)@
		str	    r1,[r0]
		pop     {r0, r1}
		mov     pc, lr
		
/*** DATA ***/
litpool:
.ltorg
				.space	1020    @ STACK
stackBottom:	.space 4
.p2align 4
fbStruct:
fbWidth:    	.space 4		@ pixels (0)
fbHeight:   	.space 4		@ (4)
fbVWidth:   	.space 4  		@ (8)
fbVHeight:   	.space 4  		@ (12)
fbPitch:     	.space 4   		@ from GPU (16)
fbDepth:     	.space 4   		@ 24 (20)
fbX:         	.space 4  		@ offset, set to 0 (24)
fbY:         	.space 4   		@ (28)
fbVCPointer:   	.space 4   		@ from GPU (32)
fbSize:      	.space 4   		@ from GPU (36)
fbCMap:      	.space 512

fbMem:      	.space 4    	@ VAR for storing VC FB location

.p2align 5
dmaAudioCB:     .space 32   	@ DMA CB for audio

.section .bss
picPallete:     .space  1024    @ 32 bit int 16 bit RGB color 256 pallete table
picData:        .space  30000   @ byte indexed pic animation data 50x50 x 12 frames 
SND_Sample:     .space 297626   @ Music loop data 8 bit 11025Hz WAVE file
.p2align 2 
sndDmaData:     .space 2380656  @ Converted music data for DMA loop
.end
