;*=$1000


PLAY_VQ_ANIM    

SID_PLAY        LDA #$00                ;0=first tune, 1=second tune, 2=third tune, etc
                JSR $1000               ;initialise SID (this address depends on the SID being played)



                JSR OPEN_FILE           ;open the data file
                BCC PLAY_HEADER         ;all OK, continue to loading header
                LDX #$0                 ;chars from the top of the defined screen area
                LDY #$0                 ;chars from the left of the defined screen area
                JSR SET_CURSOR          ;
                LDA #<TXT_FILENAME      ;set pointer to the text
                LDY #>TXT_FILENAME      ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen
                LDA #<FILENAME          ;set pointer to the text variable
                LDY #>FILENAME          ;
                JSR PRINT_ASCII_STRING  ;the print routine is called, so the pointed text is now printed to screen
                LDA #<TXT_NOTFOUND      ;set pointer to the text
                LDY #>TXT_NOTFOUND      ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen
                RTS                     ;

PLAY_HEADER     JSR LOAD_HEADER         ;load the header containing the details of the file
                BCC PLAY_START          ;all OK, continue to info and playback
                LDX #$0                 ;chars from the top of the defined screen area
                LDY #$0                 ;chars from the left of the defined screen area
                JSR SET_CURSOR          ;
                LDA #<TXT_FILETYPE      ;set pointer to the text
                LDY #>TXT_FILETYPE      ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen
                LDA FILETYPE            ;
                JSR PRINT_HEX           ;
                LDA #<TXT_NOTSUPP       ;set pointer to the text
                LDY #>TXT_NOTSUPP       ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen
                RTS                     ;

PLAY_START                    
PLAY_FRAME      JSR LOAD_FRAME          ;load image to buffer

              ;  INC BORDER

                SEC                     ;set carry (required in order to detect an underflow)
                LDA NMBR_OF_FRAMES      ;low byte of remaining frame counter
                SBC #$01                ;decrement by one
                STA NMBR_OF_FRAMES      ;store result
                LDA NMBR_OF_FRAMES+1    ;high  byte of remaining frame counter
                SBC #$00                ;process the carry
                STA NMBR_OF_FRAMES+1    ;store result
                BNE PLAY_FRAME          ;remaining frames > 0, continue showing frames
                LDA NMBR_OF_FRAMES      ;check the low byte
                BNE PLAY_FRAME          ;remaining frames > 0, continue showing frames
                ;the file we've read contains no frames (or all frames have been shown), so we exit!

PLAY_EXIT       JSR CPIO_INIT           ;CPIO_INIT is used to raise the attention signal, and by doing so we indicate that we no longer require data from (or going to send data to) the cassiopei
                CLI                     ;enable interrupts

                LDA #$00                ;set volume to 0 (silence the SID tune residual tones)
                STA $D418               ;change volume of the SID to create the analog voltage level

                RTS

;-------------------------------------------------------------------------------
;This routine will open the file to prepare it to read data in other routines
; When the opening of the file succeeded, the carry is cleared
; When the opening of the file failed, the carry is set
;
;when the file is found, it remains ready for data transfer, the CPIO connection
;is not closed and therefore interrupts remain disabled !
;...............................................................................
OPEN_FILE       LDA #CPIO_PARAMETER     ;the mode we want to operate in   
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode               

                LDA #0                  ;MSB of offset in the file
                JSR CPIO_SEND           ;
                LDA #0                  ;
                JSR CPIO_SEND           ;
                LDA #0                  ;LSB of offset
                JSR CPIO_SEND           ;               

                LDA #<FILENAME          ;set pointer to the text
                STA STR_ADDR            ;
                LDA #>FILENAME          ;
                STA STR_ADDR+1          ;
                JSR SEND_STRING         ;sends a string to the cassiopei

                LDA #CPIO_DATALOAD      ;the mode we want to operate in

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>   
ifdef USE_USERPORT_DATATRANSFER
                ;if we want to use the userport for data transfer, we must let the Cassiopei know this by sending the CPIO_DATALOAD_TURBO command
                LDA #CPIO_DATALOAD_TURBO;the mode we want to operate in   
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

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
LOAD_HEADER     JSR CPIO_RECIEVE        ;get the version of the VQImage file
                STA FILETYPE            ;save to RAM
                CMP #$01                ;check for filetype, if anything else... exit!!
                BEQ LD_HEADER_OK        ;
LD_HEADER_FAIL  SEC                     ;carry set indicates that the filetype isn't supported
                JMP LD_HEADER_EXIT      ;exit immediately

LD_HEADER_OK    JSR CPIO_RECIEVE        ;get the number of images stored in this file high byte
                STA NMBR_OF_FRAMES+1    ;save to RAM
                JSR CPIO_RECIEVE        ;get the number of images stored in this file low byte
                STA NMBR_OF_FRAMES      ;save to RAM

                JSR CPIO_RECIEVE        ;get the X-size (in tiles)
                STA X_SIZE              ;

                JSR CPIO_RECIEVE        ;get the Y-size (in tiles)
                STA Y_SIZE              ;

                JSR CPIO_RECIEVE        ;
               ; STA CODEBOOKSIZE        ;-reserved for future use-

                JSR CPIO_RECIEVE        ;
               ; STA RESERVED_01         ;-reserved for future use-

                JSR CPIO_RECIEVE        ;
               ; STA RESERVED_02         ;-reserved for future use-

                JSR CPIO_RECIEVE        ;
               ; STA RESERVED_03         ;-reserved for future use-

                JSR CPIO_RECIEVE        ;
               ; STA RESERVED_04         ;-reserved for future use-

                CLC                     ;carry cleared indicates that all is OK
LD_HEADER_EXIT  RTS                     ;

;-------------------------------------------------------------------------------
;load an image (or frame) from the file, when the file has just been opened we load the first
;when we call this routine again we load the next, etc.
;...............................................................................
LOAD_FRAME      JSR CPIO_RECIEVE        ;get the mode byte
                STA MODE_BYTE           ;

                LDA MODE_BYTE           ;
                AND #%10000000          ;mask out bit-7 (0=normal mode, 1=delta mode)
                BEQ NORMAL_MODE         ;
                JMP DELTA_MODE          ;

;------------                           
NORMAL_MODE     LDA #<CHARSCREEN        ;the destination of the data
                STA ADDR                ;low byte of destination address
                STA ADDR_LAST_TILE      ;
                LDA #>CHARSCREEN        ;
                STA ADDR+1              ;high byte of destination address                
                STA ADDR_LAST_TILE+1    ;

                ;calculate the memory address of the last tile by adding the number of tiles to the start address
                LDY Y_SIZE              ;based on the information extracted from the 
                LDX X_SIZE              ;header of the image file.
NORM_CALC_TILES TXA                     ;
                CLC                     ;clear carry
                ADC ADDR_LAST_TILE      ;calculate
                STA ADDR_LAST_TILE      ;save
                LDA #$00                ;
                ADC ADDR_LAST_TILE+1    ;add carry (if there was one)
                STA ADDR_LAST_TILE+1    ;save
                DEY                     ;
                BNE NORM_CALC_TILES     ;

                
NORM_LOAD_LOOP  JSR CPIO_RECIEVE        ;
                LDY #$00                ;CPIO_RECEIVE affects the Y registers, so we need to set it to zero here
                STA (ADDR),Y            ;store byte read from file to the requested memory location

      ;playback sound sample
      ;        ADC #%11110000          ;when our input is a '1' it will cause the carry bit to be set
      ;        STA $D418               ;change volume of the SID to create the analog voltage level

                INC ADDR                ;
                BNE NORM_LOAD_LP_02     ;therefore we calculate using Y instead of ADDR in order to keep the loop time as short as possible
                INC ADDR+1              ;


NORM_LOAD_LP_02 LDA ADDR_LAST_TILE      ;check if the current tile address is also the last tile address
                CMP ADDR                ;because is this is the case, then we are done loading this frame
                BNE NORM_LOAD_LOOP      ;
                LDA ADDR_LAST_TILE+1    ;
                CMP ADDR+1              ;
                BNE NORM_LOAD_LOOP      ;

NORMAL_EXIT     RTS                     ;all frame data loaded, return to caller

;-------------------------------------------------------------------------------
DELTA_MODE      LDA #<CHARSCREEN        ;the destination of the data
                STA ADDR                ;low byte of destination address
                LDA #>CHARSCREEN        ;
                STA ADDR+1              ;high byte of destination address

CMD_LOAD_LP_10  JSR CPIO_RECIEVE        ;get relative position of the changed tile (this is the first changed tile in the frame, the position value could be 0)
                JMP CMD_LOAD_LP_13      ;therefore the first byte read in a new frame should not be checked for 0

CMD_LOAD_LP_11  
                ;call SID-player
                DEC DELCNT               ;wait for a specific raster (can be any value)
                BNE CMD_LOAD_LP_12      ;which is all that is required in playing the SID                
                LDA #$1E                ;
                STA DELCNT              ;
                JSR $1003               ;call the playing routine

CMD_LOAD_LP_12  JSR CPIO_RECIEVE        ;get relative position of the changed tile (this value is never 0, if it is, it indicates the end of the frame and we must stop loading data)
                BEQ CMD_LOAD_DELAY      ;end-of-frame detected, (almost) exit loop
CMD_LOAD_LP_13  CLC                     ;clear carry
                ADC ADDR                ;add the position to the current address
                STA ADDR                ;save result by adding the delta position in the screen/frame to
                LDA #$00                ;the current screen/frame position
                ADC ADDR+1              ;
                STA ADDR+1              ;

                JSR CPIO_RECIEVE        ;get the tile value
                LDY #$00                ;CPIO_RECEIVE affects the Y registers, so we need to set it to zero here
                STA (ADDR),Y            ;store byte read from file to the requested memory location                

                JMP CMD_LOAD_LP_11      ;keep looping

                
CMD_LOAD_DELAY  JSR CPIO_RECIEVE        ;get the delay value, because this frame might not be visible long enough if we don't
                STA FRAME_DELAY         ;
                BEQ DELTA_EXIT          ;test if there is a delay required (0 means no delay)

CMD_FRAME_DELAY LDX #$50                ;
CMD_FRAME_D_01  NOP                     ;
                NOP                     ;
                DEX                     ;
                BNE CMD_FRAME_D_01      ;

                ;call SID-player
                DEC DELCNT               ;wait for a specific raster (can be any value)
                BNE CMD_LOAD_LP_14      ;which is all that is required in playing the SID                
                LDA #$13                ;
                STA DELCNT              ;
                JSR $1003               ;call the playing routine
CMD_LOAD_LP_14
         
                DEC FRAME_DELAY         ;
                BNE CMD_FRAME_DELAY     ;

DELTA_EXIT      RTS                     ;


;-------------------------------------------------------------------------------

DELCNT          BYTE $1
FRAME_DELAY     BYTE $0

;===============================================================================
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
;   BYTE "THE A TEAM"       ;the filename must be in upper case
;   BYTE 0                  ;end of table marker
;
;-------------------------------------------------------------------------------
                
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


;===============================================================================
;this routine is to be called (or not) after the opening of the file and reading
;of the header
;...............................................................................
SHOW_INFO       PHP                     ;save status register to stack (so that we don't screw up the flags generated by the header-reading routine)
                LDX #$0                 ;chars from the top of the defined screen area
                LDY #$0                 ;chars from the left of the defined screen area
                JSR SET_CURSOR          ;
                LDA #<TXT_CREDITS       ;set pointer to the text
                LDY #>TXT_CREDITS       ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen

                LDX #$0                 ;chars from the top of the defined screen area
                LDY #$2                 ;chars from the left of the defined screen area
                JSR SET_CURSOR          ;
                LDA #<TXT_FILENAME      ;set pointer to the text
                LDY #>TXT_FILENAME      ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen
                LDA #<FILENAME          ;set pointer to the text variable
                LDY #>FILENAME          ;
                JSR PRINT_ASCII_STRING  ;the print routine is called, so the pointed text is now printed to screen

                LDX #$0                 ;chars from the top of the defined screen area
                LDY #$3                 ;chars from the left of the defined screen area
                JSR SET_CURSOR          ;
                LDA #<TXT_FILETYPE      ;set pointer to the text
                LDY #>TXT_FILETYPE      ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen
                LDA FILETYPE            ;
                JSR PRINT_HEX           ;

                LDX #$0                 ;chars from the top of the defined screen area
                LDY #$4                 ;chars from the left of the defined screen area
                JSR SET_CURSOR          ;
                LDA #<TXT_FILEFRAMES    ;set pointer to the text
                LDY #>TXT_FILEFRAMES    ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen
                LDA NMBR_OF_FRAMES+1    ;
                JSR PRINT_HEX           ;
                LDA NMBR_OF_FRAMES      ;
                JSR PRINT_HEX           ;

                LDX #$0                 ;chars from the top of the defined screen area
                LDY #$6                 ;chars from the left of the defined screen area
                JSR SET_CURSOR          ;
                LDA #<TXT_FILESTART     ;set pointer to the text
                LDY #>TXT_FILESTART     ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen

                PLP                     ;retrieve status register from stack (to get the generated by the header-reading routine)
                RTS
;...............................................................................

TXT_CREDITS     TEXT 'petscii anim player'
                BYTE 0

TXT_FILENAME    TEXT 'file:'
                BYTE 0

TXT_FILETYPE    TEXT 'type:$'
                BYTE 0

TXT_FILEFRAMES  TEXT 'frames:$'
                BYTE 0

TXT_FILESTART   TEXT 'press key to start'
                BYTE 0

TXT_NOTFOUND    TEXT ' not found'
                BYTE 0

TXT_NOTSUPP     TEXT ' not supp.'
                BYTE 0

;===============================================================================

