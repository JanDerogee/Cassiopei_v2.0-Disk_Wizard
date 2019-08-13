;this program is written using: CBM Program Studio


;regarding the CBM program studio assembler mind the following settings: disable the option : optimize absolute modes to zero page


;THIS WEDGE MAY INTERFERE WITH OTHER WEDGES:
;For instance do not use it while the Final Cartidge III is placed (or otherwise type KILL (shutdown FC3) before loading this wedge)


ifdef WEDGEAVAILABLE

*=$7100        ; START ADDRESS 

;============================================================
;                    INIT & SCREEN SETUP
;============================================================

WEDGE_INIT                 ;execute a variation to the NEW command, to prevent the "?OUT OF MEMORY ERROR "message which is required as there is a basic program that started this assembly program, that is causing problems and needs to be cleared which normally would be done using the NEW command... but...
                           ;we can't call the original new command as it messes with the stack, preventing us from calling it without hanging the computer
                LDA #$00
                TAY
                STA ($2B),Y
                INY
                STA ($2B),Y
                LDA $2B
                CLC
                ADC #$02
                STA $2D
                
                LDA $2C
                ADC #$00
                STA $2E
                JSR $A68E       ;CHRGET pointer to the beginning of basic program


                LDA #$15            ;set screen memory pointers to use default charset
                STA $D018           ;

                LDA #$0E            ;set border to default colors
                STA BORDER          ;
                LDA #$06            ;set background to default colors
                STA BACKGROUND      ;

                LDA #147            ;PRINT CHR$(147) TO CLEAR
                JSR CHROUT          ;SCREEN
                LDY #$00            ;print a small credits screen
W_CREDITS       LDA TITLE_TXT,Y     ;
                BEQ W_CREDITS_DONE  ;stop printing when end-marker has been detected
                JSR CHROUT          ;
                INY                 ;
                JMP W_CREDITS       ;
W_CREDITS_DONE  JMP WEDGE_ENABLE    ;



*=$7148        ; START ADDRESS  ($7148=SYS 29000)
 
WEDGE_ENABLE    SEI                 ;disable interrupts during pointer adjustment
                LDX #<NEWCOMMANDS   ;CHANGE BASIC COMMAND POINTERS
                LDY #>NEWCOMMANDS   ;in order to handle the new commands
                STX IGONE           ;
                STY IGONE+1         ;

                LDX #<NEWFUNCTION   ;CHANGE BASIC FUNCTION POINTERS
                LDY #>NEWFUNCTION   ;in order to handle the new commands
                STX IEVAL           ;
                STY IEVAL+1         ;
                CLI                 ;release interrupts

                JSR CPIO_INIT       ;initialize CPIO settings and registers
                RTS                 ;

;-------------------------------------------------------------
;CHECK FOR NEW COMMANDS/FUNCTIONS (which all start with a '!')
;-------------------------------------------------------------
NEWCOMMANDS     JSR CHRGET              ; GET CHARACTER
                CMP '!'                 ; IS IT A '!' ?
                BEQ SEARCH_COMMAND      ; YES, continue to our own command interpreter
                JMP STNDRDBASICCMD      ; NO, return to the standard BASIC interpreter

NEWFUNCTION     LDA #00                 ;0x00=numeric, 0xFF=string
                STA $0D                 ;set type flag to numeric 
                JSR CHRGET              ; GET CHARACTER
                PHP                     ;save status to stack (status reg holds crucial info that may be required for JMP STNDRDBASICFUNC)
                PHA                     ;save accumulator to stack
                CMP '!'                 ; IS IT A '!' ?
                BEQ SEARCH_CMD          ; YES, continue to our own command interpreter
                PLA                     ;retrieve accumulator from stack
                PLP                     ;retrieve status from stack
                JMP STNDRDBASICFUNC     ; NO, return to the standard BASIC interpreter

SEARCH_CMD      PLA                     ;get accumulator value from the stack, which we may discard as it is not of use here (it was saved for the situation where we needed to go back to the standard function routine)
                PLA                     ;get status from stack, which we also discard as it is not of use here (it was saved for the situation where we needed to go back to the standard function routine)
SEARCH_COMMAND  LDA TXTPTR              ;copy textpointer to buffer
                STA POINTER_BUF         ;
                LDA TXTPTR+1            ;
                STA POINTER_BUF+1       ;

                LDA #<WEDGE_TABLE       ;copy the start adress of the lookup table in which the wedge commands are stored to the zero page
                STA TABLE_ADR           ;store low byte                
                LDA #>WEDGE_TABLE       ;
                STA TABLE_ADR+1         ;store high byte
               
SCMD_00         LDA #$00                ;each table entry holds .. chars
                STA CHRCNT              ;counter to keep track of the number of characters we have processed
                
SCMD_01         LDY CHRCNT              ;Y holds the pointer within the current line of the table
                LDA (TABLE_ADR),Y       ;compare with the char from the table
                BEQ SCMD_EXECUTE        ;check if 00, yes? then jump to the address in the table

                CMP #$FF                ;check for end of table
                BEQ SCMD_ERROR          ;the end of the table has been reached, we must exit

                CMP #$20                ;check for the "space" (the character that is only used to fill the table to 8 bytes per line)
                BEQ SCMD_02             ;when found, ignore it and get next value from table

                JSR CHRGET              ;get (next) char
                LDY CHRCNT              ;Y holds the pointer within the current line of the table
                CMP (TABLE_ADR),Y       ;compare with the char from the table
                BNE SCMD_03             ;when not equal break loop                

SCMD_02         INC CHRCNT              ;we did not exit therefore the character stil matches, decrement counter and process next char
                JMP SCMD_01             ;

                
                ;go to the next line in the wedge command table
SCMD_03         LDA #$08                ;by adding the lenght of a table line to the table pointer, we go the the next line in the table
                CLC                     ;
                ADC TABLE_ADR           ;increment table pointer in order to set the table_adr to the beginning of the next line in the table
                STA TABLE_ADR           ;save the result of the caluclation to the pointer
                BCC SCMD_04             ;
                INC TABLE_ADR+1         ;

SCMD_04         LDA POINTER_BUF         ;restore textpointer from buffer so that we can use CHRGET as if we were using it for the first time
                STA TXTPTR              ;
                LDA POINTER_BUF+1       ;
                STA TXTPTR+1            ;
                JMP SCMD_00             ;go back to the loop

                ;get the address from the table and jump
SCMD_EXECUTE    INC CHRCNT              ;
                LDY CHRCNT              ;
                LDA (TABLE_ADR),Y       ;get the low byte of the jump vector from the wedge command table
                STA POINTER_BUF         ;save to buffer
                INY                     ;
                LDA (TABLE_ADR),Y       ;get high byte of the jump vector from the wedge command table
                STA POINTER_BUF+1       ;save to buffer
                JMP (POINTER_BUF)       ;jump indirect to the address we've just copied

SCMD_ERROR      JMP SYNTAXERROR         ;instruction unknown, exit with error


;===============================================================================
;  !ADC,channel       request an ADC measurement
;===============================================================================

CMD_ADC         LDA CPIO_ADC            ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                JSR SEND_8BIT_VAL       ;send the channel value to the Cassiopei
                JSR CPIO_RECIEVE        ;get the 2 MSB's of the AD conversion
                PHA                     ;
                JSR CPIO_REC_LAST       ;get the 8 LSB's of the AD conversion, this also the last byte
                PHA                     ;save value to stack
                CLI                     ;enable interrupts again
 
                JSR CHRGET              ;discard char (don't know why, but otherwise the entire command fails, we seem to have a character in the buffer)

                PLA                     ;get the 8 LSB's from the ADC value back from the stack
                STA $63                 ;low byte in $63 (FAC related register)
                PLA                     ;get the 2 MSB's from the ADC value back from the stack
                STA $62                 ;high byte in $62 (FAC related register)
                LDX #$90                ;set exponent to a value of 16 bits
                SEC                     ;don't invert mantissa
                JMP $BC49               ;convert to FAC and exit

;===============================================================================
;  !DTMF,value       this command sends a value to the DTMF generator

;The following example program plays the number from the data statement:
;10 READ A
;20 IF A>15 THEN 40
;30 !DTMF,A:PRINT A:GOTO 10
;40 PRINT "number dialed":END
;50 DATA 0,6,1,2,3,4,5,6,7,8,255
;===============================================================================   
CMD_DTMF        LDA #15                 ;set volume to max
                STA $D418               ;otherwise the tone could not be heard, because it is passed through the SID chip using ext-in of the SID chip

                LDA CPIO_DTMF           ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                JSR SEND_8BIT_VAL       ;send the DTMF-key value to the Cassiopei
                LDA #$00                ;dummy byte to close the communication
                JSR CPIO_SEND_LAST      ;send the data over CPIO, this is also the last byte
                CLI                     ;enable interrupts again
                JMP NEWBASIC_DONE       ;      

;===============================================================================
;   !I2CST          stop I2C communication
;===============================================================================
CMD_I2CST       LDA CPIO_I2C           ;the mode we want to operate in   
                JSR CPIO_START         ;send this command so the connected device knows we now start working in this mode
                LDA CPIO_I2C_STOP      ;I2C stop command
                JSR CPIO_SEND_LAST     ;send the value over CPIO, this is also the last byte

                CLI                     ;enable interrupts again
                JMP NEWBASIC_DONE       ; 

;===============================================================================
;  !I2CAW,adress    this addresses the I2C device for WRITE
;===============================================================================   
CMD_I2CAW       JSR CHRGET              ;GET THE ,
                JSR CHKCOM              ;SKIP THE COMMA
                JSR FRMNUM              ;EVALUATE NUMBER (duration)
                JSR GETADR              ;CONVERT TO A 2-BYTE INTEGER
               ;PHA                     ;A HAS HI BYTE, save to stack
                TYA                     ;Y HAS LO BYTE, move to a
                PHA                     ;so we can save it to the stack               

                LDA CPIO_I2C           ;the mode we want to operate in   
                JSR CPIO_START         ;send this command so the connected device knows we now start working in this mode
                LDA CPIO_I2C_ADR_W     ;I2C address write command
                JSR CPIO_SEND          ;
                PLA                     ;retrieve the address value from stack
                JSR CPIO_SEND_LAST     ;send the value over CPIO, this is also the last byte

                CLI                     ;enable interrupts again
                JSR RESTORE_TXTPNTR     ;required because we'd processed a parameter
                JMP NEWBASIC_DONE       ;      

;===============================================================================
;  !I2CAR,adress    this address the I2C device for READ
;===============================================================================   
CMD_I2CAR       JSR CHRGET              ;GET THE ,
                JSR CHKCOM              ;SKIP THE COMMA
                JSR FRMNUM              ;EVALUATE NUMBER (duration)
                JSR GETADR              ;CONVERT TO A 2-BYTE INTEGER
               ;PHA                     ;A HAS HI BYTE, save to stack
                TYA                     ;Y HAS LO BYTE, move to a
                PHA                     ;so we can save it to the stack               

                LDA CPIO_I2C           ;the mode we want to operate in   
                JSR CPIO_START         ;send this command so the connected device knows we now start working in this mode
                LDA CPIO_I2C_ADR_R     ;I2C address read command
                JSR CPIO_SEND          ;
                PLA                     ;retrieve the address value from stack
                JSR CPIO_SEND_LAST     ;send the value over CPIO, this is also the last byte

                CLI                     ;enable interrupts again
                JSR RESTORE_TXTPNTR     ;required because we'd processed a parameter
                JMP NEWBASIC_DONE       ;      

;===============================================================================
;  !I2CPU,adress    this address the I2C device for READ
;===============================================================================   
CMD_I2CPU       JSR CHRGET              ;GET THE ,
                JSR CHKCOM              ;SKIP THE COMMA
                JSR FRMNUM              ;EVALUATE NUMBER (duration)
                JSR GETADR              ;CONVERT TO A 2-BYTE INTEGER
               ;PHA                     ;A HAS HI BYTE, save to stack
                TYA                     ;Y HAS LO BYTE, move to a
                PHA                     ;so we can save it to the stack               

                LDA CPIO_I2C           ;the mode we want to operate in   
                JSR CPIO_START         ;send this command so the connected device knows we now start working in this mode
                LDA CPIO_I2C_PUT       ;I2C data write command
                JSR CPIO_SEND          ;
                PLA                     ;retrieve the data value from stack
                JSR CPIO_SEND_LAST     ;send the value over CPIO, this is also the last byte

                CLI                     ;enable interrupts again
                JSR RESTORE_TXTPNTR     ;required because we'd processed a parameter
                JMP NEWBASIC_DONE       ;      

;===============================================================================
;  !I2CGE       GET data from I2C device
;===============================================================================   
CMD_I2CGE       LDA CPIO_I2C           ;the mode we want to operate in
                JSR CPIO_START         ;send this command so the connected device knows we now start working in this mode
                LDA CPIO_I2C_GET       ;read I2C data from slave and acknowledge
                JSR CPIO_SEND          ;

                JSR CPIO_REC_LAST      ;read the value from the requested location
                PHA                     ;save value to stack
        
                CLI                     ;enable interrupts again

                JSR CHRGET              ;discard char (don't know why)
               
                PLA                     ;get ADC value back from the stack
                TAY                     ;transfer to Y in order to parse it to the next routine
                JMP $B3A2               ;Y to real and exit


;===============================================================================
;  !I2CGL       GET data from I2C device (indicate that this is the last byte)
;===============================================================================   
CMD_I2CGL       LDA CPIO_I2C           ;the mode we want to operate in
                JSR CPIO_START         ;send this command so the connected device knows we now start working in this mode
                LDA CPIO_I2C_GETLAST   ;read I2C data from slave but do not acknowledge to indicate last byte
                JSR CPIO_SEND          ;

                JSR CPIO_REC_LAST      ;read the value from the requested location
                PHA                     ;save value to stack
        
                CLI                     ;enable interrupts again

                JSR CHRGET              ;discard char (don't know why)
               
                PLA                     ;get ADC value back from the stack
                TAY                     ;transfer to Y in order to parse it to the next routine
                JMP $B3A2               ;Y to real and exit

;===============================================================================
;  !KLI13,H,G,B,S     this command sends a klik-aan-klik-uit signal
;===============================================================================   
CMD_KLI13       LDA CPIO_KAKU13         ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode

                JSR SEND_8BIT_VAL       ;send the HOUSE value to the Cassiopei
                JSR SEND_8BIT_VAL       ;send the GROUP value to the Cassiopei
                JSR SEND_8BIT_VAL       ;send the BUTTON value to the Cassiopei
                JSR SEND_8BIT_VAL       ;send the STATE value to the Cassiopei
                LDA #$00                ;dummy byte to close the communication
                JSR CPIO_SEND_LAST      ;send the data over CPIO, this is also the last byte
                CLI                     ;enable interrupts again
                JMP NEWBASIC_DONE       ;      

;===============================================================================
;  !KLI32,H,B,S     this command sends a klik-aan-klik-uit signal
;===============================================================================   
CMD_KLI32       LDA CPIO_KAKU32         ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode

                JSR SEND_8BIT_VAL       ;send the HOUSE value to the Cassiopei
                JSR SEND_8BIT_VAL       ;send the BUTTON value to the Cassiopei
                JSR SEND_8BIT_VAL       ;send the STATE value to the Cassiopei
                LDA #$00                ;dummy byte to close the communication
                JSR CPIO_SEND_LAST      ;send the data over CPIO, this is also the last byte
                CLI                     ;enable interrupts again
                JMP NEWBASIC_DONE       ;      

;===============================================================================
;  !DATLO,destinationaddress,quantity,filetype,MSBoffset,...offset,LSBOffset,"..."        load a file (of any type) from the cassiopei


;   in case the user want to show a monochrome HIRES image the screen muist be set up like this (a monochrome hires screen takes approx 2 seconds to load)
;    
;                lda #$00                ;
;                sta $d020               ;Border Color
;                sta $d021               ;Screen Color
;                lda #$3b                ;Bitmap Mode On
;                sta $d011               ;
;                lda #$18                ;When bitmap adress is $2000, Screen at $0400 then the value of $d018 is $18
;                sta $d018


;===============================================================================
CMD_DATLO  
                ;get the (16-bit) address of the memory location to put the data
                ;get the (16-bit) number of bytes to load

                LDA CPIO_PARAMETER      ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode

                JSR CHRGET              ;GET THE ,
                JSR CHKCOM              ;SKIP THE COMMA
                JSR FRMNUM              ;EVALUATE NUMBER (duration)
                JSR GETADR              ;CONVERT TO A 2-BYTE INTEGER
                STA ADDR+1              ;A HAS HI BYTE, save...
                STY ADDR                ;Y HAS LO BYTE, move to a
                JSR RESTORE_TXTPNTR     ;required because we'd just processed a parameter

                JSR CHRGET              ;GET THE ,
                JSR CHKCOM              ;SKIP THE COMMA
                JSR FRMNUM              ;EVALUATE NUMBER (duration)
                JSR GETADR              ;CONVERT TO A 2-BYTE INTEGER
                STA CNTR+1              ;A HAS HI BYTE, save...
                STY CNTR                ;Y HAS LO BYTE, move to a
                JSR RESTORE_TXTPNTR     ;required because we'd just processed a parameter

                JSR SEND_8BIT_VAL       ;MSB of offset byte
                JSR SEND_8BIT_VAL       ;... of offset byte
                JSR SEND_8BIT_VAL       ;LSB of offset byte
                JSR SEND_STRING         ;copy all character of the string from the user input to the Cassiopei

                ;finally the playing command, let the sound start...
                LDA CPIO_DATALOAD       ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                JSR CPIO_RECIEVE        ;the cassiopei responds with a 0=file-not-found, 1=file-found-starting-playback (although this is the last byte, we do not drop the ATTENTION line as we want to continue with the async protocol, which also uses the attention line)
                BNE CMD_LOAD_LP_00      ;
                JSR CPIO_INIT           ;CPIO_INIT is used to raise the attention signal, an by doing so we indicate that we no longer require data from (or going to send data to) the cassiopei
                JMP CMD_LOAD_EXIT       ;0=file-not-found, so we exit!


CMD_LOAD_LP_00  LDY #$00                ;we only need to load Y-reg once, because there is nothing else affecting it so it remains 0 for the duration of the loop
CMD_LOAD_LP_01  JSR CPIO_RECIEVE        ;
                STA (ADDR),Y            ;store byte read from file to the requested memory location

                INC ADDR                ;increment address pointer
                BNE CMD_LOAD_LP_02      ;
                INC ADDR+1              ;

CMD_LOAD_LP_02  SEC                     ;decrement counter
                LDA CNTR                ;
                SBC #$01                ;subtract 1
                STA CNTR                ;
                BCS CMD_LOAD_LP_03      ;check overflow
                DEC CNTR+1              ;decrement high-byte

CMD_LOAD_LP_03  LDA CNTR                ;
                BNE CMD_LOAD_LP_01      ;check if low-byte 0
                LDA CNTR+1              ;
                BNE CMD_LOAD_LP_01      ;check if high-byte 0
                                        ;high- and low-byte are 0, we must exit the loop
                JSR CPIO_REC_LAST       ;the last load is just a dummy, we're done loading data

CMD_LOAD_EXIT   CLI                     ;enable interrupts
      
                JMP NEWBASIC_DONE       ;


;;===============================================================================
;;  !SAVE"...",First address,Last address  this command saves the requested memory area the fast way (to a file of type .PRG)
;;===============================================================================
;CMD_SAVE  
;                JSR CHRGET              ;get next char
;                CMP #34                 ;is it a " ?
;                BNE CMD_SAVE_ERROR      ;

;                ;get the filename
;                LDA#$EA                 ;modify CHRGET to accept spaces (replace compare instruction that causes the space to be ignored by a NOP instruction)
;                STA $0082               ;modify CHRGET to accept spaces
;                STA $0083               ;modify CHRGET to accept spaces

;                LDA CPIO_SAVEFAST       ;the mode we want to operate in   
;                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode

;CMD_SAVE_LP     JSR CHRGET              ;get next char
;                BEQ CMD_SAVE_END        ;keep looping until we find the : or an end marker 0x00
;                CMP #34                 ;is it a " ?
;                BEQ CMD_SAVE_END        ;keep looping until we find the "     

;                JSR CPIO_SEND           ;send the value
;                JMP CMD_SAVE_LP         ;

;CMD_SAVE_END    LDA #$00                ;0x00 marks the end of the string
;                JSR CPIO_SEND           ;send the value

;                LDA#$F0                 ;restore CHRGET function to original state (which ignore spaces)        ;#$F0 = original value
;                STA $0082               ;restore CHRGET function to original state (which ignore spaces)        ;
;                LDA#$EF                 ;restore CHRGET function to original state (which ignore spaces)        ;#$FE = original value
;                STA $0083               ;restore CHRGET function to original state (which ignore spaces)        ;

;                ;get the startaddress
;                
;                ;get the last address


;                ;transfer the data
;CMD_SAVING_LP
;                INC BORDER              ;

;                DEC BORDER              ;

;                JMP CMD_SAVING_LP       ;keep looping until all data is saved                


;                JSR CPIO_SEND_LAST      ;send the value over CPIO, this is also the last byte
;        

;                CLI                     ;enable interrupts again
;                JMP NEWBASIC_DONE
;CMD_SAVE_ERROR  JMP SYNTAXERROR         ;instruction unknown, exit with error


;===============================================================================
;  !SAY,0,"..."        this command sends a string to the speech synthesizer
; 0=CBM, 1=PWM (2=both) (on a C64 the data goes through the SID (as a digi))
; for more information about handling BASIC variables from assembly, read the
; following document: transactor volume 5, issue 2, page 76
;===============================================================================

CMD_SAY         LDA CPIO_PARAMETER      ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode

                JSR SEND_8BIT_VAL       ;destination (0=CBM, 1=PWM, 2=CBM and PWM)
                STA MODE                ;save the retrieved value (destination mode) to use it later
                JSR SEND_STRING         ;copy all character of the string from the user input to the Cassiopei

                ;finally the playing command, let the sound start...
CMD_SAY_START   LDA CPIO_SPEECH         ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                JSR CPIO_RECIEVE        ;the cassiopei responds with a 0=file-not-found, 1=file-found-starting-playback (although this is the last byte, we do not drop the ATTENTION line as we want to continue with the async protocol, which also uses the attention line)
                BEQ CMD_SAY_EX_01       ;0=file-not-found, so we exit!

                JSR PLAYSAMPLE          ;convert the incoming data to an audible sound
CMD_SAY_EXIT    JSR CPIO_INIT           ;CPIO_INIT is used to raise the attention signal, an by doing so we indicate that we no longer require data from the cassiopei
CMD_SAY_EX_01   CLI                     ;enable interrupts
                JMP NEWBASIC_DONE       ;

CMD_SAY_ERROR   JSR CPIO_INIT           ;CPIO_INIT is used to raise the attention signal, an by doing so we indicate that we no longer require data from (or going to send data to) the cassiopei
                JMP SYNTAXERROR         ;instruction unknown, exit with error  

;===============================================================================
;  !SAMPL       Sample play routine
;===============================================================================

CMD_SAMPL       LDA CPIO_PARAMETER      ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode

                JSR SEND_16BIT_VAL      ;offset*256 in bytes to start of sample (0000=play sample from the start)
                JSR SEND_16BIT_VAL      ;duration*256 in bytes (0000=play the sample to the end)
                JSR SEND_8BIT_VAL       ;destination (0=CBM, 1=PWM, 2=CBM and PWM)
                STA MODE                ;save the retrieved value (destination mode) to use it later
                JSR SEND_STRING         ;copy all character of the string from the user input to the Cassiopei

                ;finally the playing command, let the sound start...
                LDA CPIO_PLAYSAMPLE     ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                JSR CPIO_RECIEVE        ;the cassiopei responds with a 0=file-not-found, 1=file-found-starting-playback (although this is the last byte, we do not drop the ATTENTION line as we want to continue with the async protocol, which also uses the attention line)
                BEQ CMD_SAMPL_EX_01     ;0=file-not-found, so we exit!

                JSR PLAYSAMPLE          ;convert the incoming data to an audible sound
CMD_SAMPL_EXIT  JSR CPIO_INIT           ;CPIO_INIT is used to raise the attention signal, an by doing so we indicate that we no longer require data from the cassiopei
CMD_SAMPL_EX_01 CLI                     ;enable interrupts
                JMP NEWBASIC_DONE       ;

CMD_SAMPL_ERROR JSR CPIO_INIT           ;CPIO_INIT is used to raise the attention signal, an by doing so we indicate that we no longer require data from (or going to send data to) the cassiopei
                JMP SYNTAXERROR         ;instruction unknown, exit with error  

;===============================================================================
;  !SERIN,A     this command initializes the PCA9685 servo controller
;===============================================================================   

CMD_SERIN       LDA CPIO_SERVOINIT      ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                JSR SEND_8BIT_VAL       ;send the I2C-ADDRESS value to the Cassiopei
                LDA #$00                ;dummy byte to close the communication
                JSR CPIO_SEND_LAST      ;send the data over CPIO, this is also the last byte
                CLI                     ;enable interrupts again
                JMP NEWBASIC_DONE       ;      

;===============================================================================
;  !SERVO,A,C,O,P     this command initializes the PCA9685 servo controller
;====================================================================

CMD_SERVO       LDA CPIO_SERVOPOS       ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                JSR SEND_8BIT_VAL       ;send the I2C-ADDRESS value to the Cassiopei
                JSR SEND_8BIT_VAL       ;send the SERVO-CHANNEL value to the Cassiopei
                JSR SEND_8BIT_VAL       ;send the POSITION OFFSET value to the Cassiopei
                JSR SEND_8BIT_VAL       ;send the POSITION value to the Cassiopei
                LDA #$00                ;dummy byte to close the communication
                JSR CPIO_SEND_LAST      ;send the data over CPIO, this is also the last byte
                CLI                     ;enable interrupts again
                JMP NEWBASIC_DONE       ;      

;===============================================================================
;  !SINE,value,value       this command sends a value to the SINE generator
;
;example:
;
;1 REM SIMPLE FREQUENCY SWEEP
;10 FOR X=0 TO 100
;20 Y=Y+100
;30 !SINE,100,y
;40 NEXT X
;===============================================================================   
CMD_SINE        LDA #15                 ;set volume to max
                STA $D418               ;otherwise the tone could not be heard if it would be passed through the SID chip using ext-in of the SID chip

                LDA CPIO_SINEWAVE       ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                JSR SEND_16BIT_VAL      ;send the duration value to the Cassiopei
                JSR SEND_16BIT_VAL      ;send the frequency value to the Cassiopei
                LDA #$00                ;dummy byte to close the communication
                JSR CPIO_SEND_LAST      ;send the data over CPIO, this is also the last byte
                CLI                     ;enable interrupts again
                JMP NEWBASIC_DONE       ;      

;===============================================================================
;   !HELP           this command displays all extra commands
;===============================================================================
CMD_HELP        LDA #147                ;PRINT CHR$(147) TO CLEAR
                JSR CHROUT              ;SCREEN
                LDY #$00                ;

                LDA #<HELP_TXT          ;copy the start adress of the lookup table in which the wedge commands are stored to the zero page
                STA TABLE_ADR           ;store low byte                
                LDA #>HELP_TXT          ;
                STA TABLE_ADR+1         ;store high byte

CMD_HELP_LP_1   LDY #$00                ;
                LDA (TABLE_ADR),Y       ;
                BEQ CMD_HELP_DONE       ;stop printing when end-marker has been detected
                JSR CHROUT              ;

                LDA #$01                ;increment table pointer by 1
                CLC                     ;
                ADC TABLE_ADR           ;
                STA TABLE_ADR           ;
                BCC CMD_HELP_LP_2       ;
                INC TABLE_ADR+1         ;
CMD_HELP_LP_2   JMP CMD_HELP_LP_1       ;

CMD_HELP_DONE   JMP NEWBASIC_DONE       ;       

;===============================================================================
;use this after processing a command that had paramaters
;for instance !DTMF,value or !OUT,value
;this routine will actually set the textpointer one byte/char back
;===============================================================================

RESTORE_TXTPNTR SEC             ;clear carry
                LDA TXTPTR      ;load text pointer (low byte)
                SBC #$01        ;subtract 1 and subtract carry (notice that carry has been set to 0 earlier)
                STA TXTPTR      ;store result
                LDA TXTPTR+1    ;load the text pointer (high byte)
                SBC #$00        ;subtract 0 and subtract carry (carry is created by previous subtraction result)
                STA TXTPTR+1    ;store result
                RTS             ;return


;===============================================================================
; This routine will copy a value (16bit) from the BASIC commandline (or program
; line) to the cassiopei. The value must be proceeded by a comma-character

SEND_16BIT_VAL  JSR CHRGET              ;GET THE ,
                JSR CHKCOM              ;SKIP THE COMMA
                JSR FRMNUM              ;EVALUATE NUMBER (duration)
                JSR GETADR              ;CONVERT TO A 2-BYTE INTEGER
                TAX                     ;A HAS HI BYTE, save to X
                TYA                     ;Y HAS LO BYTE, move to a
                PHA                     ;so we can save it to the stack     

                TXA                     ;sample duration in bytes*256 (MSB)
                JSR CPIO_SEND           ;
                PLA                     ;sample duration in bytes*256 (LSB)
                JSR CPIO_SEND           ;
                JSR RESTORE_TXTPNTR     ;required because we'd just processed a parameter
                RTS                     ;

;===============================================================================
; This routine will copy a value (8bit) from the BASIC commandline (or program
; line) to the cassiopei. The value must be proceeded by a comma-character
; the retrieved value is also available in accu when the routine returns

SEND_8BIT_VAL   JSR CHRGET              ;GET THE ,
                JSR CHKCOM              ;SKIP THE COMMA
                JSR FRMNUM              ;EVALUATE NUMBER (duration)
                JSR GETADR              ;CONVERT TO A 2-BYTE INTEGER
                TYA                     ;Y HAS LO BYTE, move to a
                PHA                     ;
                JSR CPIO_SEND           ;send the value (third char of filename)
                JSR RESTORE_TXTPNTR     ;required because we'd just processed a parameter
                PLA                     ;
                RTS                     ;

;===============================================================================
; This routine will copy the characters from the BASIC commandline (or program line)
; to the cassiopei.

SEND_STR_ERROR  JMP SYNTAXERROR         ;
 
SEND_STRING     JSR CHRGET              ;GET THE ,
                JSR CHKCOM              ;SKIP THE COMMA (syntax error if not comma) and get the next char 
                CMP #$22                ;is it a " ?
                BEQ SEND_STR_CONST      ;text in the format  "..." found, start data transfer to Cassiopei

                ;-----------------------;hmmm the text is not in the  "..." format, perhaps it is a string? (so we search for a string name A$-Z$)
SEND_STR_VAR    STA $45                 ;save first char of variable name as it is stored in memory (MSB=0 because this is a string variable)
                JSR CHRGET              ;get next char

                CMP #$24                ;the second char of the string variable should be the $-sign, if not then we have an error situation
                BNE SEND_STR_ERROR      ;

                LDA #$80                ;this variable has no second character, but the MSB=1 because this is a string variable, so the value $80 is stored as the second char in the variable table
                STA $46                 ;save second char of variable name as it is stored in memory
                JSR $B0E7               ;use kernal routine to search for variable
                LDY #$02                ;load Y with the index of the length field of the string (field0=1st char, field1=2nd char, field2=length, field3=string adr low, field4=string adr high)
                LDA ($5F),Y             ;get the length of the string
                BEQ SEND_STR_ERROR      ;when the length is 0 we have a syntax error!!
                TAX                     ;save the length of the string to the X-reg
                INY                     ;
                LDA ($5F),Y             ;get the low address of the start of the string
                STA STR_ADDR            ;save to zero-page register
                INY                     ;
                LDA ($5F),Y             ;get the high address of the start of the string
                STA STR_ADDR+1          ;save to zero-page register

SEND_STR_VAR_01 LDY #$00                ;
                LDA (STR_ADDR),Y        ;read character from string
                JSR CPIO_SEND           ;send the value
                CLC                     ;
                LDA #$01                ;increment the pointer to the string by one in order to get the next char/value
                ADC STR_ADDR            ;add 1
                STA STR_ADDR            ;string address pointer
                LDA #$00                ;add 0 + carry of the previous result
                ADC STR_ADDR+1          ;meaning that if we have an overflow, the must increment the high byte
                STA STR_ADDR+1          ;
                DEX                     ;decrement string character count
                BNE SEND_STR_VAR_01     ;when we reached 0, we've processed the entire char
                JMP SEND_STRING_END     ;

;---------------

SEND_STR_CONST  LDA#$EA                 ;modify CHRGET to accept spaces (replace compare instruction that causes the space to be ignored by a NOP instruction)
                STA $0082               ;modify CHRGET to accept spaces
                STA $0083               ;modify CHRGET to accept spaces

SEND_STRING_01  JSR CHRGET              ;get next char
                BEQ SEND_STRING_END     ;keep looping until we find the : or an end marker 0x00
                CMP #$22                ;is it a " ?
                BEQ SEND_STRING_END     ;keep looping until we find the "     

                JSR CPIO_SEND           ;send the value
                JMP SEND_STRING_01      ;

SEND_STRING_END LDA #$00                ;each string end with a end of string marker which has the value 0
                JSR CPIO_SEND_LAST      ;The string is the last parameter in the CPIO-command, the Cassiopei detects the end of the string because the Attention signal drops. This makes it possible to have a string with a variable length (very practical)

SEND_STRING_EXT LDA#$F0                 ;restore CHRGET function to original state (which ignore spaces), see NOTE        ;#$F0 = original value
                STA $0082               ;restore CHRGET function to original state (which ignore spaces), see NOTE        ;
                LDA#$EF                 ;restore CHRGET function to original state (which ignore spaces), see NOTE        ;#$FE = original value
                STA $0083               ;restore CHRGET function to original state (which ignore spaces), see NOTE        ;
                RTS

;NOTE:
;=====
;original kernal routine of CHRGET
;---------------------------------
;CHRGET       0073   INC   $7A      ;ADDS 1 TO CURRENT ADDRESS
;             0075   BNE   $0079    ;ADDS 1 TO CURRENT ADDRESS
;             0077   INC   $7B      ;INCREMENT
;CHRGOT       0079   LDA   CURRENT  ;$7A=low byte of textpointer, $7B=high byte of text pointer
;             007C   CMP   #$3A     ;COLON (OR GREATER) EXITS
;             007E   BCS   $008A    ;
;             0080   CMP   #$20     ;SKIPS SPACE CHARACTERS
;             0082   BEQ   $0073    ;                             <----= disabling this jump (by replacing it with NOP's) makes CHRGET return spaces (if detected)
;             0084   SEC            ;ANYTHING FROM $30 to $39
;             0085   SBC   #$30     ;CLEARS C FLAG;
;             0087   SEC            ;ELS C IS SET
;             0088   SBC   #$D0     ;
;             008A   RTS            ;


;===============================================================================
;this small routine will retrieve 4 bit sample from the Casiopei and converts them into audible sound
;using the SID's volume register. Which effectively is the easiest way to produce sound.
;===============================================================================
PLAYSAMPLE      LDA BORDER              ;save border color
                PHA                     ;to stack        
                SEI                     ;disable interrupts

                LDA #15                 ;set volume to max
                STA $D418               ;otherwise the tone could not be heard if it would be routed through the SID (usings SID's analog input)
                LDA MODE                ;
                CMP #$01                ;when destination is 1 (PWM), the CBM does not have to do anything any more, just load the response byte and it's done
                BEQ PLAY_EXIT           ;

                LDA #$FF                ;we must boost the digi... (so it works on both types of SID chips (old and new)
                STA $D406               ;
                LDA #$49                ;
                STA $D404               ;
                LDA #$FF                ;Setting more voices gives the digi a substantial extra boost:
                STA $D406               ;
                STA $D40D               ;
                STA $D414               ;
                LDA #$49                ;
                STA $D404               ;
                STA $D40B               ;
                STA $D412               ;
;...............................................................................
;this routine will produce sound without disabling the screen
;by avoiding a the "bad lines" the samplerate cannot be affected

PLAYSAMPLE_LP   LDA #%00000001          ;the bit pattern we are interested in
PLAY_LP0        BIT $D012               ;we wait for a line (that could be a bad line)
                BEQ PLAY_LP0            ;        

                LDA CPIO_DATA           ;
                STA BORDER              ;change color (very usefull for debugging)

                ;check the CPIO "READY" signal which indicates the end of sample
                LDA $DC0D               ;read CIA connected to the cassetteport (reading clears the state of the bits)
                AND #%00010000          ;mask out bit 4
                BEQ PLAY_LP1            ;loop until the slave lowers the read signal              
                JMP PLAY_EXIT           ;the ready signal has been activated by the cassiopei, this means that the sample has ended!!! Exit playing routine!!!

                ;check for user pressing space
PLAY_LP1        LDA $DC01               ;check keyboard inputs
                CMP #$EF                ;SPACE ?
                BNE PLAY_LP2            ;if not, keep polling
                JMP PLAY_EXIT           ;space pressed, Exit playing routine!!!


PLAY_LP2        LDA #%00000111          ;lower clock change state of write line to '0'
                STA DATA_BIT_6510       ;the cassiopei triggers on the falling edge before it starts to send the data of the sample, so making this signal is not time critical

                LDA #%00000001          ;the bit pattern we are interested in
PLAY_LP3        BIT $D012               ;we wait for a line that isn't for sure a bad line (and it stays an OK line as long as we don't touch the scroll-Y register)
                BNE PLAY_LP3            ;        

                LDA #%00001111          ;raise clock by changing state of write line to '1'
                STA DATA_BIT_6510       ;

                LDA #$00                ;clear the data register (the upper nibble MUST be all 0, because these are shifted into the Carry with every ROL instruction) 
                STA CPIO_DATA           ;

                CLC                     ;the Carry must be set to 0 because the ADC relies on the carry to be 0    
                LDA DATA_BIT_6510       ;the data is on the sense line of the cassette port we know the state of the other IO-lines (as we also control these during the clock/startdata pulse) 
                ADC #%11110000          ;when our input is a '1' it will cause the carry bit to be set
                ROL CPIO_DATA           ;shift all the bits one position to the right and add the LSB which is located in the carry

                                        ;CLC instruction is not needed here as we know that the carry is zero, due to the ROL instruction which shifted the MSB of CPIO_DATA into the carry
                LDA DATA_BIT_6510       ;
                ADC #%11110000          ;when our input is a '1' it will cause the carry bit to be set
                ROL CPIO_DATA           ;shift all the bits one position to the right and add the LSB which is located in the carry

                                        ;CLC instruction is not needed here as we know that the carry is zero, due to the ROL instruction which shifted the MSB of CPIO_DATA into the carry
                LDA DATA_BIT_6510       ;
                ADC #%11110000          ;when our input is a '1' it will cause the carry bit to be set
                ROL CPIO_DATA           ;shift all the bits one position to the right and add the LSB which is located in the carry

                                        ;CLC instruction is not needed here as we know that the carry is zero, due to the ROL instruction which shifted the MSB of CPIO_DATA into the carry
                LDA DATA_BIT_6510       ;
                ADC #%11110000          ;when our input is a '1' it will cause the carry bit to be set
                ROL CPIO_DATA           ;shift all the bits one position to the right and add the LSB which is located in the carry

                LDA CPIO_DATA           ;the sample we've just read from the Cassiopei, will now be send to the DAC (volume register of the SID)
                STA $D418               ;change volume of the SID to create the analog voltage level

                JMP PLAYSAMPLE_LP       ;keep looping...

PLAY_EXIT       PLA                     ;get from stack
                STA BORDER              ;the saves border color
                RTS                     ;


;===============================================================================
;   WEDGE TABLE (holds the new BASIC commands that are added by this wedge)
; Note:
; For some reason the command cannot have a name that looks like a real a basic
; command. For instance !LOAD doesn't work and FGET doesn't work either (they
; hold the BASIC commands LOAD and GET)
;===============================================================================

                ;    definition of command      high byte               low byte                ;comments
                ;----------------------------------------------------------------------------------------
WEDGE_TABLE     BYTE "A","D","C"," "," ",$00,   <CMD_ADC,               >CMD_ADC                ;!ADC   (Analog Ditigal Converter)
                BYTE "D","T","M","F"," ",$00,   <CMD_DTMF,              >CMD_DTMF               ;!DTMF  (DTMF generator)
                BYTE "I","2","C","A","R",$00,   <CMD_I2CAR,             >CMD_I2CAR              ;!I2CAR (I2C addres read)
                BYTE "I","2","C","A","W",$00,   <CMD_I2CAW,             >CMD_I2CAW              ;!I2CAW (I2C address write)
                BYTE "I","2","C","G","E",$00,   <CMD_I2CGE,             >CMD_I2CGE              ;!I2CGE (I2C get)
                BYTE "I","2","C","G","L",$00,   <CMD_I2CGL,             >CMD_I2CGL              ;!I2CGL (I2C get last)
                BYTE "I","2","C","P","U",$00,   <CMD_I2CPU,             >CMD_I2CPU              ;!I2CPU (I2C put)
                BYTE "I","2","C","S","T",$00,   <CMD_I2CST,             >CMD_I2CST              ;!I2CST (I2C stop)
                BYTE "D","A","T","L","O",$00,   <CMD_DATLO,             >CMD_DATLO              ;!DATLO (data load)
               ;BYTE "D","A","T","S","A",$00,   <CMD_DATSA,             >CMD_DATSA              ;!DATSA (data save)
                BYTE "K","L","I","1","3",$00,   <CMD_KLI13,             >CMD_KLI13              ;!KLI13 (klik aan klik uit old 13bit system)          
                BYTE "K","L","I","3","2",$00,   <CMD_KLI32,             >CMD_KLI32              ;!KLI32 (klik aan klikuit new 32bit system)
                BYTE "S","A","Y"," "," ",$00,   <CMD_SAY,               >CMD_SAY                ;!SAY   (speech synthesizer)
                BYTE "S","A","M","P","L",$00,   <CMD_SAMPL,             >CMD_SAMPL              ;!SAMPL (sample)
                BYTE "S","E","R","I","N",$00,   <CMD_SERIN,             >CMD_SERIN              ;!SERIN (servo init)
                BYTE "S","E","R","V","O",$00,   <CMD_SERVO,             >CMD_SERVO              ;!SERVO (servo position)
                BYTE "S","I","N","E"," ",$00,   <CMD_SINE,              >CMD_SINE               ;!SINE  (sine wave generator)
                BYTE "H","E","L","P"," ",$00,   <CMD_HELP,              >CMD_HELP               ;!HELP  (help function)
                BYTE $FF                                                                        ;end of table

                ; $20 = space, this is just a padding character to fill the table to 8 bytes per line (it is not used for the compare)
                ; $00 = the next byte will be the address
                ; $FF = end of table

;===============================================================================
;   TEXT tables
;===============================================================================

TITLE_TXT       BYTE 017
                TEXT " **** CASSIOPEI C64 WEDGE  (JAN D) ****"
                BYTE $0D,017
                TEXT "    FOR MORE INFORMATION TYPE: !HELP"
                BYTE $0D,017
                BYTE 000

HELP_TXT        BYTE 017    ;send cursor to home position

                TEXT "!ADC,CHANNEL     :GET ANALOG CHAN=0-1"
                BYTE $0D

                TEXT "!DTMF,KEY        :DTMF TONE  KEY=0-15"
                BYTE $0D

                TEXT "!I2CAR,ADDR      :I2C ADDRESS READ"
                BYTE $0D

                TEXT "!I2CAW,ADDR      :I2C ADDRESS WRITE"
                BYTE $0D

                TEXT "!I2CGE           :I2C GET BYTE"
                BYTE $0D

                TEXT "!I2CGL           :I2C GET LAST BYTE"
                BYTE $0D

                TEXT "!I2CPU,DATA      :I2C PUT BYTE"
                BYTE $0D

                TEXT "!I2CST           :I2C STOP"
                BYTE $0D


                TEXT "!FILER,A,Q,O,O,O,"NAME"    :LOAD DATA"
                BYTE $0D
 
       ;        TEXT "!FILES,A,A,"NAME":SAVE FIRST-LAST ADR"
       ;        BYTE $0D


                TEXT "!KLI13,H,G,B,S   :SEND KAKU 13BIT CMD"
                BYTE $0D

                TEXT "!KLI32,H,B,S     :SEND KAKU 32BIT CMD"
                BYTE $0D

                TEXT "!SAY,D"
                BYTE 034
                TEXT "TEXT TEXT"
                BYTE 034
                TEXT ":SPEAK TEXT"
                BYTE $0D

                TEXT "!SAMPL,O,E,D, "
                BYTE 034
                TEXT "FILE"
                BYTE 034
                TEXT ":PLAY WAV"
                BYTE $0D

                TEXT "!SERIN,A         :INIT SERVOCONTROLLER"
                BYTE $0D

                TEXT "!SERVO,A,C,O,P   :POSITION SERVOMOTOR"
                BYTE $0D

                TEXT "!SINE,DUR,FRQ    :DURATION(MS),FREQ(HZ)"
                BYTE $0D
                BYTE $0D

       ;        TEXT "!HELP            :SHOW COMMANDS OVERVIEW"
                BYTE 000



;-------------------------------------------------------------------------------
;                                     I N F O 
;-------------------------------------------------------------------------------


;READING values from a basic command
;-----------------------------------
;reading 8 or 16-bit value form basic line that looks end with:  ,value
;                JSR CHKCOM              ; SKIP THE COMMA
;                JSR FRMNUM              ; EVALUATE NUMBER
;                JSR GETADR              ; CONVERT TO A 2-BYTE INTEGER
;                                        ; A HAS HI BYTE
;                                        ; Y HAS LO BYTE
;                STY CPIO_BUF_1         ;save to buffer for later use


;reading 8-bit value form basic line that looks end with:  ,value
;                JSR CHRGET              ;GET THE ,
;                JSR CHKCOMANDGETVAL     ;check if the last char was indedd a comma, if so get the value, if not syntax error
;                STX CPIO_BUF_1         ;save to buffer for later use

;note: after reading the last parameter, then restore the textpointer and exit to basic
;                JSR RESTORE_TXTPNTR     ;required because we'd processed a parameter
;                JMP NEWBASIC_DONE       ;      





              
SPRITE_INIT     LDA #%00000000          ;sprite 0-7 9th bit of X-coordinate
                STA $D010               ;
                LDA #%11111111          ;sprite 0-7 enable/disable register (1=enable)
                STA $D015               ;
                LDA #%00000000          ;sprite 0-7 expand in Y direction register (1=enable)
                STA $D017               ;
                LDA #%00000000          ;sprite 0-7 expand in X direction register (1=enable)
                STA $D01D               ;
                LDA #%00000000          ;sprite 0-7 MCM enable/disable register (1=MultiColorMode)
                STA $D01C               ;
     

SPR_COLOR       LDA #0                  ;sprite color-1 (bitpair '01' = color defined at $d025)
                STA $D025               ;
                LDA #15                 ;sprite color-2 (bitpair '10' = color defined at $d026)
                STA $D026               ;
                LDA #12                 ;sprite color-3 (bitpair '11' = the sprite's only individual color)
                STA $D027               ;sprite-0 color
                STA $D028               ;sprite-1 color
                STA $D029               ;sprite-2 color
                STA $D02A               ;sprite-3 color
                STA $D02B               ;sprite-4 color
                STA $D02C               ;sprite-5 color
                STA $D02D               ;sprite-6 color
                STA $D02E               ;sprite-7 color


SPRITE_POINTER  LDA #$A0                ;sprite pointer sprite-0 You can have a maximum of 256 sprite gfx definitions in one VIC bank. That which one is displayed in a given sprite is controlled by the last 8 bytes of the displayed screen memory. Each sprite definition takes up 64 bytes, so the formula to calculate the memory area holding the sprite gfx is: sprite pointer*64. ;      screenmem+$03f8 = sprite0's gfx pointer
                STA $07F8               ;sprite pointer sprite-0 (the location of the sprite data)
                LDA #$A1                ;
                STA $07F9               ;sprite pointer sprite-1
                LDA #$A2                ;
                STA $07FA               ;sprite pointer sprite-2
                LDA #$A3                ;
                STA $07FB               ;sprite pointer sprite-3
                LDA #$A4                ;
                STA $07FC               ;sprite pointer sprite-4
                LDA #$A5                ;
                STA $07FD               ;sprite pointer sprite-5
                LDA #$A6                ;
                STA $07FE               ;sprite pointer sprite-6
                LDA #$A7                ;
                STA $07FF               ;sprite pointer sprite-7


SPRITE_POSITION LDA #48                 ;
                STA $D000               ;sprite-0 position X  
                STA $D008               ;sprite-4 position X
                LDA #72                 ;
                STA $D002               ;sprite-1 position X
                STA $D00A               ;sprite-5 position X
                LDA #96                 ;
                STA $D004               ;sprite-2 position X
                STA $D00C               ;sprite-6 position X
                LDA #120                ;
                STA $D006               ;sprite-3 position X
                STA $D00E               ;sprite-7 position X
  

                LDA #50                 ;
                STA $D001               ;sprite-0 position Y
                STA $D003               ;sprite-1 position Y
                STA $D005               ;sprite-2 position Y
                STA $D007               ;sprite-3 position Y
                LDA #71                 ;
                STA $D009               ;sprite-4 position Y
                STA $D00B               ;sprite-5 position Y
                STA $D00D               ;sprite-6 position Y
                STA $D00F               ;sprite-7 position Y



                RTS

























endif
