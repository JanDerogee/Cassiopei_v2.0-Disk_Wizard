*=$0420 ;start address      ;by keeping the start adress close to the basic line, we keep the compiled program small. This because the "gap" between the basic line and the assembly code is filled with padding bytes.
               


INIT            JMP MAIN                ;

;-------------------------------------------------------------------------------
;a small list of variables that do not require storage in the zero-page

NMBR_OF_FRAMES  BYTE $00        ;a variable to store the number of frames (low byte)
                BYTE $00        ;a variable to store the number of frames (high byte)

OFFSET_LSB      BYTE $00        ;variable used to hold the offset inside the file holding the data
OFFSET_XSB      BYTE $00        ;using this 3 byte offset value we can position ourselves through
OFFSET_MSB      BYTE $00        ;a file of 16 Mbytes (max) Since the Cassiopei can only hold 8Mbyte, this is perfect

X_SIZE          BYTE $00        ;the width of the screen in chars
Y_SIZE          BYTE $00        ;the height of the screen in chars

FILENAME        BYTE "IMAGE"    ;the filename must be in upper case (filename does not have to be complete filename, the first 5 chars is normally enough depending on the other files on the Cassiopei's flash
                BYTE 0          ;end of table marker

;===============================================================================
;                              MAIN PROGRAM
;===============================================================================


MAIN            JSR CLEAR_SCREEN        ;
                JSR CPIO_INIT           ;initialize IO for use of CPIO protocol on the PET's cassetteport
                LDA #$0C                ;we must force the PET to display a charset that ALL systems can use (according: http://www.atarimagazines.com/compute/issue26/171_1_ALL_ABOUT_PET_CBM_CHARACTER_SETS.php)
                STA $E84C               ;the charset layout we are using now would be identical to the C64 charset layout. NOTE:the 2001's do not have the option of a configurable charset :-(

LOOP            JSR LOAD_HEADER         ;open file and load the header containing the details of the file
                BCS EXIT_PROGRAM        ;carry set, then file not found and we exit the program

SHOW_FRAME      JSR LOAD_IMAGE          ;load and display image







SCAN_KEYREPEAT  LDA KEYMATRIX           ;
                LDA KEYCNT              ;
                BEQ SCAN_EXIT           ;
                LDA #$00                ;clear keyboard buffer
                STA KEYCNT              ;check number of chars in keyboard buffer

        ;<<<debug only (show last key-value information in the top-left corner of the screen)>>>
        LDX #1                  ;set X-coordinate of first character
        LDY #1                  ;set Y-coordinate of first character
        JSR SET_CURSOR          ;
        LDA KEYBUF              ;
        JSR PRINT_HEX           ;
        ;<<<debug only>>>

                LDA KEYBUF              ;keyvalue (not the matrix value, but the real PETSCII value)
                CMP #$0D                ;$0D = CARIAGE RETURN
                BEQ EXIT_PROGRAM        ;
SCAN_EXIT








DEC_FRAME_CNT   SEC                     ;set carry (required in order to detect an underflow)
                LDA NMBR_OF_FRAMES      ;low byte of remaining frame counter
                SBC #$01                ;decrement by one
                STA NMBR_OF_FRAMES      ;store result
                LDA NMBR_OF_FRAMES+1    ;high  byte of remaining frame counter
                SBC #$00                ;process the carry
                STA NMBR_OF_FRAMES+1    ;store result
                ;check if the number of frames is still not 0
                BNE SHOW_FRAME          ;remaining frames > 0, continue showing frames
                LDA NMBR_OF_FRAMES      ;check the low byte
                BNE SHOW_FRAME          ;remaining frames > 0, continue showing frames
                ;the file we've read contains no frames (or all frames are shown), so we exit!

        JMP LOOP

EXIT_PROGRAM    RTS                     ;

;-------------------------------------------------------------------------------
;this routine will loop until a keypress is stored in the keyboard buffer
;

WAIT_FOR_KEY
SCAN_KEYBOARD   LDA #$00                ;clear keyboard buffer
                STA KEYCNT              ;check number of chars in keyboard buffer
SCAN_KEY        LDA KEYCNT              ;check number of chars in keyboard buffer
                BEQ SCAN_KEY
                RTS


;-------------------------------------------------------------------------------
; this small routine will clear the (40x25 characters) screen
; call example: JSR CLEAR_SCREEN
;...............................................................................
CLEAR_SCREEN    LDA #$20        ;the space is used for clearing the screen
                LDY #$00
CLEAR_SCREEN_LP STA CHARSCREEN,Y
                STA CHARSCREEN+256,Y
                STA CHARSCREEN+512,Y
                STA CHARSCREEN+744,Y
                DEY
                BNE CLEAR_SCREEN_LP
                RTS 

;-------------------------------------------------------------------------------
;This routine will open the file to prepare it to read data in other routines
; When the opening of the file succeeded, the carry is cleared
; When the opening of the file failed, the carry is set
;
;when the file is found, it remains ready for data transfer, the CPIO connection
;is not closed and therefore interrupts remain disabled !
;...............................................................................
OPEN_FILE       LDA CPIO_PARAMETER      ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode               

                LDA OFFSET_MSB          ;MSB of offset in the file
                JSR CPIO_SEND           ;
                LDA OFFSET_XSB          ;
                JSR CPIO_SEND           ;
                LDA OFFSET_LSB          ;LSB of offset
                JSR CPIO_SEND           ;               

                LDA #<FILENAME          ;set pointer to the text
                STA STR_ADDR            ;
                LDA #>FILENAME          ;
                STA STR_ADDR+1          ;
                JSR SEND_STRING         ;sends a string to the cassiopei

                LDA CPIO_DATALOAD       ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                JSR CPIO_RECIEVE        ;the cassiopei responds with a 0=file-not-found, 1=file-found, do not drop attention as we want to continue loading data
                BNE FILE_FOUND          ;0=file-not-found !

FILE_NOT_FOUND  JSR CPIO_INIT           ;CPIO_INIT is used to raise the attention signal, and by doing so we indicate that we no longer require data from (or going to send data to) the cassiopei
                CLI                     ;enable interrupts
                SEC                     ;set the carry to indicate we could not open the requested file
                RTS                     ;return to caller

FILE_FOUND      CLC                     ;clear carry to indicate the file is found and opened
                RTS                     ;return to caller

;-------------------------------------------------------------------------------
;load the header of the image file
;When the opening of the file succeeded and the header is OK then the carry is cleared
;When the opening of the file failed or the header is not OK, then carry is set
;...............................................................................
LOAD_HEADER     LDA #$0                 ;reset the offset to the beginning of the file (because the header is at the beginning of the file)
                STA OFFSET_MSB          ;MSB of offset in the file
                STA OFFSET_XSB          ;
                STA OFFSET_LSB          ;LSB of offset

                JSR OPEN_FILE           ;open the data file
                BCS LD_HEADER_ERROR     ;carry set, then file not found and we exit the program
                
                JSR CPIO_RECIEVE        ;get the version of the VQImage file
                CMP #$00                ;we expect version 0, if it is anything else, we exit as failed
                BEQ LD_HEADER_OK        ;
                JSR CPIO_INIT           ;CPIO_INIT is used to raise the attention signal, and by doing so we indicate that we no longer require data from (or going to send data to) the cassiopei
                CLI                     ;enable interrupts
                SEC                     ;set the carry to indicate we could not open the requested file
                JMP LD_HEADER_ERROR     ;


LD_HEADER_OK    JSR CPIO_RECIEVE        ;get the number of images stored in this file high byte
                STA NMBR_OF_FRAMES+1    ;save to RAM
                JSR CPIO_RECIEVE        ;get the number of images stored in this file low byte
                STA NMBR_OF_FRAMES      ;save to RAM

                JSR CPIO_RECIEVE        ;get the number of colors used in this file
                ;ignore value as (most) PETs cannot show colors

                JSR CPIO_RECIEVE        ;get the X-size (in tiles)
                STA X_SIZE              ;

                JSR CPIO_RECIEVE        ;get the Y-size (in tiles)
                STA Y_SIZE              ;

                JSR CPIO_REC_LAST       ;get the codebook size (in tiles)
                ;ignore value

                ;change the offset, so the next time we do a file open we read past the header
                LDA #$07                ;the number of bytes we've just read from the file
                JSR ADD_SMALL_OFFSET    ;add these to the offset, so the next time we read we read past the data we've already read


LD_HEADER_EXIT  CLC                     ;clear carry to indicate everything is OK
LD_HEADER_ERROR RTS                     ;

;-------------------------------------------------------------------------------
;load an image from the file, when the file has just been opened we load the first
;when we call this routine again we load the next, etc.
;...............................................................................
LOAD_IMAGE      LDA #>CHARSCREEN        ;the destination of the data
                STA ADDR+1              ;high byte of destination address
                LDA #<CHARSCREEN        ;
                STA ADDR                ;low byte of destination address


                JSR OPEN_FILE           ;open the data file (the last read position is maintained)
                JSR CPIO_RECIEVE        ;get the mode, B7: 0=normal, 1=delta
     ;   JSR DEBUG_PRINT_ACC    ;DEBUG !!
                PHA                     ;save

                LDA #$01                ;
                JSR ADD_SMALL_OFFSET    ;add the number of byte we've read to the file-offset, so the next time when we read we read past this point

                PLA                     ;restore
                CMP #$00                ;
                BEQ NORMAL_MODE         ;
                JMP DELTA_MODE          ;
                ;JSR CPIO_RECIEVE        ;get the codebook data
                ;JSR CPIO_RECIEVE        ;get the number of colors

;------------
NORMAL_MODE     LDA #$00                ;
                STA CNTR+1              ;
                                        ;calculate the number of tiles to read
                LDY Y_SIZE              ;based on the information extracted from the 
                LDX X_SIZE              ;header of the image file. There is stored the
CALC_IMAGE_SIZE TXA                     ;
                CLC                     ;clear carry
                ADC CNTR                ;calculate
                STA CNTR                ;save
                LDA #$00                ;
                ADC CNTR+1              ;add carry (if there was one)
                STA CNTR+1              ;save
                DEY                     ;
                BNE CALC_IMAGE_SIZE     ;

                JSR ADD_BIG_OFFSET      ;add the number of byte we are going to read to the file-offset, so the next time we read we read past this point

                LDY #$00                ;we only need to load Y-reg once, because there is nothing else affecting it so it remains 0 for the duration of the loop
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

                JMP LOAD_IMAGE_EXIT     ;high- and low-byte are 0, we must exit the loop

;------------
DELTA_MODE      JSR CPIO_RECIEVE        ;get the number of changed tiles (high byte)
                STA CNTR+1              ;
                JSR CPIO_RECIEVE        ;get the number of changed tiles (low byte)
                STA CNTR                ;
                JSR ADD_BIG_OFFSET      ;add the number of byte we are going to read to the file-offset, so the next time we read we read past this point
                JSR ADD_BIG_OFFSET      ;add it again, because we are reading each tile is defined by 2 bytes

                LDA #$02                ;
                JSR ADD_SMALL_OFFSET    ;add the number of bytes we've read to the file-offset, so the next time when we read we read past this point


                LDA CNTR                ;check if there is any new data in this frame
                BNE CMD_LOAD_LP_11      ;because it could be possible that there are no changes
                LDA CNTR+1              ;so we must be able to handle that situation
                BNE CMD_LOAD_LP_11      ;
                JMP LOAD_IMAGE_EXIT     ;

CMD_LOAD_LP_11  

;                LDA CHAR_ADDR+1
;                CMP #$83
;                BNE NEE

;                LDA CHAR_ADDR
;                CMP #$E4
;                BNE NEE
;FOUT            JMP FOUT

;NEE             
                JSR CPIO_RECIEVE        ;get relative position of the changed tile
 ;JSR DEBUG_PRINT_ACC0    ;DEBUG !!
                CLC                     ;clear carry
                ADC ADDR                ;add the position to the current address
                STA ADDR                ;save result
                LDA #$00                ;
                ADC ADDR+1              ;
                STA ADDR+1              ;

        LDA ADDR+1
        CMP #$88
        BCC OK
        
        LDA ADDR+1
        JSR DEBUG_PRINT_ACC0
        LDA ADDR
        JSR DEBUG_PRINT_ACC

PROBLEM JMP LOAD_IMAGE_EXIT 
        
OK


                LDY #$00                ;
                JSR CPIO_RECIEVE        ;get the tile value
 ;JSR DEBUG_PRINT_ACC    ;DEBUG !!
                STA (ADDR),Y            ;store byte read from file to the requested memory location


CMD_LOAD_LP_12  SEC                     ;decrement counter
                LDA CNTR                ;
                SBC #$01                ;subtract 1
                STA CNTR                ;
                BCS CMD_LOAD_LP_13      ;check overflow
                DEC CNTR+1              ;decrement high-byte

CMD_LOAD_LP_13  LDA CNTR                ;
                BNE CMD_LOAD_LP_11      ;check if low-byte 0
                LDA CNTR+1              ;
                BNE CMD_LOAD_LP_11      ;check if high-byte 0


;--------------                         ;high- and low-byte are 0, we must exit the loop
LOAD_IMAGE_EXIT JSR CPIO_REC_LAST       ;the last load is just a dummy, we're done loading data
                CLI                     ;enable interrupts
                RTS                     ;return to caller

;...............................................................................
;increment offset by the value in the 2 byte register CNTR
ADD_BIG_OFFSET  CLC                     ;
                LDA CNTR                ;
                ADC OFFSET_LSB          ;
                STA OFFSET_LSB          ;

                LDA CNTR+1              ; 
                ADC OFFSET_XSB          ;
                STA OFFSET_XSB          ;
                BCC INC_OFFSET_1        ;
                INC OFFSET_MSB          ;

INC_OFFSET_1    RTS                     ;

;...............................................................................
;increment offset by value in A
;       LDA #$07                ;add 7
;       JSR ADD_SMALL_OFFSET    ;

ADD_SMALL_OFFSET
                CLC                     ;
                ADC OFFSET_LSB          ;
                STA OFFSET_LSB          ;
                LDA #$00                ;
                ADC OFFSET_XSB          ;
                STA OFFSET_XSB          ;
                LDA #$00                ;
                ADC OFFSET_MSB          ;
                STA OFFSET_MSB          ;
                RTS                     ;

;=================================================================================
; This routine will send a string to the Cassiopei
; call example:
; -------------
;
;   LDA #<FILENAME_1        ;set pointer to the text that defines the main-screen
;   STA STR_ADDR            ;
;   LDA #>FILENAME_1        ;
;   STA STR_ADDR+1          ;
;   JSR SEND_STRING         ;sends a string to the cassiopei
;
; Table example:
; --------------
;
;   BYTE "THE"              ;the filename must be in upper case
;   BYTE 0                  ;end of table marker
;
;---------------------------------------------------------------------------------
                
SEND_STRING     LDY #$00                ;
                LDA (STR_ADDR),Y        ;read character from string
                BEQ SEND_STR_END        ;when the character was 0, then the end of string marker was detected and we must exit

                JSR CPIO_SEND           ;send char to Cassiopei
                                     
                CLC                     ;
                LDA #$01                ;add 1
                ADC STR_ADDR            ;
                STA STR_ADDR            ;string address pointer
                LDA #$00                ;
                ADC STR_ADDR+1          ;add carry...
                STA STR_ADDR+1          ;                            

                JMP SEND_STRING         ;repeat...

SEND_STR_END    JSR CPIO_SEND_LAST      ;send last (end-of_string) char to Cassiopei
                RTS                     ;


;-------------------------------------------------------------------------------
; this small routine will clear the (40x25 characters) screen
; call example: JSR CLEAR_SCREEN
;...............................................................................
;CLEAR_SCREEN    LDA #$20        ;the space is used for clearing the screen
;                LDY #$00
;CLEAR_SCREEN_LP STA CHARSCREEN,Y
;                STA CHARSCREEN+256,Y
;                STA CHARSCREEN+512,Y
;                STA CHARSCREEN+744,Y
;                DEY
;                BNE CLEAR_SCREEN_LP
;                RTS 



;-------------------------------------------------------------------------------
;print accu value in hex to the top left of the screen
;
DEBUG_PRINT_ACC0

        STA A_BUF
        STX X_BUF
        STY Y_BUF

        LDX #$0         ;chars from the top of the defined screen area
        LDY #$0         ;chars from the left of the defined screen area
        JSR SET_CURSOR

        LDA A_BUF       ;A-register must contain value to be printed
        JSR PRINT_HEX   ;the print routine is called

        LDX X_BUF
        LDY Y_BUF
        LDA A_BUF
        RTS

A_BUF   BYTE $00
X_BUF   BYTE $00
Y_BUF   BYTE $00



DEBUG_PRINT_ACC

        STA A_BUF

        LDA A_BUF       ;A-register must contain value to be printed
        JSR PRINT_HEX   ;the print routine is called

        LDA A_BUF
        RTS

;-------------------------------------------------------------------------------
;call this routine as described below:
;
;               LDA #character          ;character is stored in Accumulator
;               JSR PRINT_CHAR          ;character is printed to screen, cursor is incremented by one
; also affects Y
; note: when the character value is 0 there is nothing printed but we do increment the cursor by one
;-------------------------------------------------------------------------------
PRINT_CHAR      BEQ PRINT_NOTHING       ;when the value = 0, we print nothing but we do increment the cursor by one
                CLC                     ;
                ;ADC CHAR_INVERT         ;perhaps the character printing mode is inverted? (inverting means seting the MSB of the charvalue)
                LDY #00                 ;
                STA (CHAR_ADDR),Y       ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)

                ;increment character pointer
PRINT_NOTHING   CLC                     ;
                LDA #$01                ;add 1
                ADC CHAR_ADDR           ;                        
                STA CHAR_ADDR           ;
                LDA #$00                ;
                ADC CHAR_ADDR+1         ;add carry... and viola, we have a new cursor position (memory location where next character will be printed)
                STA CHAR_ADDR+1         ;

                RTS                     ;      
              
;-------------------------------------------------------------------------------
; this routine will print the value in A as a 2 digit hexadecimal value
;        LDA #value                      ;A-register must contain value to be printed
;        JSR PRINT_HEX     ;the print routine is called
;-------------------------------------------------------------------------------
PRINT_HEX       PHA                     ;save A to stack
                AND #$F0                ;mask out low nibble
                LSR A                   ;shift to the right
                LSR A                   ;
                LSR A                   ;
                LSR A                   ;
                TAX                     ;
                LDA HEXTABLE,X          ;convert using table                                 
                JSR PRINT_CHAR          ;print character to screen

                PLA                     ;retrieve A from stack
                AND #$0F                ;mask out high nibble
                TAX                     ;
                LDA HEXTABLE,X          ;convert using table                                 
                JSR PRINT_CHAR          ;print character to screen
 
                RTS                     ;

HEXTABLE        TEXT '0123456789abcdef'               

;-------------------------------------------------------------------------------
; use this routine before calling a PRINT related routine
;                        LDX CURSOR_Y;.. chars from the top of the defined screen area
;                        LDY CURSOR_X;.. chars from the left of the defined screen area
;   JSR SET_CURSOR
;-------------------------------------------------------------------------------
;the first location is defined as coordinate 0,0 (which makes life so much easier)

SET_CURSOR      LDA #<CHARSCREEN        ;
                STA CHAR_ADDR           ;store base address (low byte)
                LDA #>CHARSCREEN        ;
                STA CHAR_ADDR+1         ;store base address (high byte)

                ;calculate exact value based on the requested X and Y coordinate
                CLC                     ;
                TXA                     ;add  value in X register (to calculate the new X position of cursor)
                ADC CHAR_ADDR           ;                        
                STA CHAR_ADDR           ;
                LDA #$00                ;
                ADC CHAR_ADDR+1         ;add carry
                STA CHAR_ADDR+1         ;

SET_CURS_CHR_LP CPY #00                 ;
                BEQ SET_CURS_END        ;when Y is zero, calculation is done

                CLC                     ;
                LDA #40                 ;add  40 (which is the number of characters per line) to calculate the new Y position of cursor
                ADC CHAR_ADDR           ;                        
                STA CHAR_ADDR           ;
                LDA #$00                ;
                ADC CHAR_ADDR+1         ;add carry... and viola, we have a new cursor position (memory location where next character will be printed)
                STA CHAR_ADDR+1         ;
                DEY                     ;
                JMP SET_CURS_CHR_LP     ;

SET_CURS_END    RTS                     ;
  










