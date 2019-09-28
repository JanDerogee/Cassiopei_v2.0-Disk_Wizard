;===============================================================================
;                              MAIN PROGRAM
;===============================================================================

INIT            JSR PREVENT_CASE_CHANGE ;prevent the user from using shift+CBM to change the case into lower or upper case

MAIN_MENU       JSR NEW_SCREEN          ;clear screen and set cursor to topleft

 ;debug for key value info
 ;          JSR SCAN_INPUTS
 ;          JSR PRINT_HEX           ;
 ;          JMP MAIN_MENU

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef MAKEDISK AND MAKEIMAGE
;-------------------------------------------------------------------------------
                LDA #<SCREEN_MAIN       ;set pointer to the text that defines the main-screen
                LDY #>SCREEN_MAIN       ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen         
                JSR SHOW_VERSION        ;show version info

                JSR CHOOSE              ;
                CMP #USER_INPUT_CHA     ;compare with choice A value
                BNE NOT_MAIN_CHA        ;
                JMP MAKE_DISK           ;
NOT_MAIN_CHA    CMP #USER_INPUT_CHB     ;compare with choice B value
                BNE NOT_MAIN_CHB        ;
                JMP MAKE_IMAGE          ;
NOT_MAIN_CHB    JMP MAIN_MENU           ;if the user pressed an invalid value, do nothing, just keep waiting for the proper key to be pressed
;-------------------------------------------------------------------------------
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef MAKEDISK and not MAKEIMAGE
                JMP MAKE_DISK
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef MAKEIMAGE and not MAKEDISK
                JMP MAKE_IMAGE
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;code belwo doesn not seem to compile, computer says "[Error  ] Line "xx:Invalid Label "ifdef not MAKEIMAGE and not MAKEDISK" 
;ifdef not MAKEIMAGE and not MAKEDISK
;                RTS     ;useless situation... exit immediately
;endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<



;###############################################################################
;                  M A K E   D I S K   f r o m   a  f i l e 
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef MAKEDISK
;-------------------------------------------------------------------------------
MAKE_DISK       JSR CPIO_INIT           ;initialize IO for use of CPIO protocol on the CBM's cassetteport
                JSR BROWSE_RESET        ;force the cassiopei menu to a default state

MDSK_SCREEN     JSR NEW_SCREEN          ;clear screen and set cursor to topleft
                LDA #<SCREEN_MAKE_DISK  ;set pointer to the text that defines the main-screen
                LDY #>SCREEN_MAKE_DISK  ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen         
                JSR BROWSE_REFRESH      ;get the current available menu screen and print it to the screen
                JSR ERROR_MESSAGE       ;get the drive status/error message, this is usefull as we read the code 73 when it has been reset, so the next read will be 00 if all is OK, thereforer we do not need to worry about 73, as it only shows after reset once.

                ;allow user to select a file
MDSK_MENU       LDA BROWSE_STATUS       ;check if we should exit
                CMP #BROWSE_EXIT        ;exit menu (meaning that a selection has been made)
                BNE MDSK_SCANKEY        ;
                JSR RESET_DISK          ;
                JSR CREATE_DISK         ;file was selected, now create the disk
                JMP MDSK_SCREEN         ;when finished, go back to the menu to allow user to select another file

MDSK_SCANKEY
MDSK_SCANKEY_01 JSR SCAN_INPUTS         ;check keyboard and/ joysticks (if applicable)
                CMP #USER_INPUT_SELECT  ;and jump to the requested action
                BNE MDSK_SCANKEY_02     ;
                JSR BROWSE_SELECT       ;select current file
                JMP MDSK_MENU           ;

MDSK_SCANKEY_02 CMP #USER_INPUT_PREVIOUS;
                BNE MDSK_SCANKEY_03     ;
                JSR BROWSE_PREVIOUS     ;go to previous file
                JMP MDSK_MENU           ;

MDSK_SCANKEY_03 CMP #USER_INPUT_NEXT    ;
                BNE MDSK_SCANKEY_04     ;
                JSR BROWSE_NEXT         ;go to next file
                JMP MDSK_MENU           ;

MDSK_SCANKEY_04 CMP #USER_INPUT_DIR     ;
                BNE MDSK_SCANKEY_05     ;
                JSR RESET_DISK          ;
                JSR DIRECTORY           ;show directory
                JSR WAIT_FOR_KEY        ;keep screen visible until user presses key
                JMP MDSK_SCREEN         ;redraw make-disk-screen

MDSK_SCANKEY_05 CMP #USER_INPUT_EXIT    ;
                BNE MDSK_SCANKEY_06     ;
                JMP MAIN_MENU           ;exit the current screen by returning to the main screen

MDSK_SCANKEY_06 JMP MDSK_SCANKEY        ;when the pressed key has no function then continue the key scanning

                ;.......................

CREATE_DISK     ;convert the selected file into a disk
CR_DISK_TRNSFR  LDA #0                  ;reset track sector
                STA TABLE_PNTR          ;
                LDA #1                  ;
                STA TRACK               ;
                LDA #0                  ;
                STA SECTOR              ;
                LDY TABLE_PNTR          ;
                LDA TABLE_MAXSEC,Y      ;
                STA SECTOR_MAX          ;
                LDA #$0                 ;reset byte counter
                STA CNT_BYTE            ;
                LDA #CPIO_DATAFILE_OPEN ;the mode we want to operate in
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                LDA #0                  ;0=read from file
                JSR CPIO_SEND           ;
                JSR CPIO_RECIEVE        ;the cassiopei responds with a 0=file-not-found, 1=file-found, do not drop attention as we want to continue loading data
                STA FILE_OPEN_STATUS    ;
                JSR CPIO_RECIEVE        ;filesize (MSB) of the opened file
                STA FILE_SIZE_03        ;
                JSR CPIO_RECIEVE        ;filesize of the opened file    
                STA FILE_SIZE_02        ;
                JSR CPIO_RECIEVE        ;filesize of the opened file
                STA FILE_SIZE_01        ;
                JSR CPIO_REC_LAST       ;filesize (LSB) of the opened file
                STA FILE_SIZE_00        ;

                LDA FILE_OPEN_STATUS    ;
                BNE CR_DISK_TRN_00      ;0=file-not-found, 1=file found
                JMP CR_DISK_EXIT        ;no sense in carying on, exit                

CR_DISK_TRN_00  LDA FILE_SIZE_02          ;
                CMP FILE_SIZE_02_EXPECTED ;compare with the expected value
                BEQ CONFIRM_YN          ;request if user is sure (because we are about to format a disk)
                LDX #X_POS_STATUS       ;if the disk isn't what we expect
                LDY #Y_POS_STATUS       ;then we must show an error message
                JSR SET_CURSOR          ;
                LDA #<TXT_NOTSUPP       ;
                LDY #>TXT_NOTSUPP       ;
                JSR PRINT_STRING        ;
                JSR WAIT_FOR_KEY        ;keep screen visible until user presses key
                JMP CR_DISK_EXIT        ;no sense in carying on, exit

CONFIRM_YN      LDX #X_POS_STATUS       ;write the text message
                LDY #Y_POS_STATUS       ;
                JSR SET_CURSOR          ;
                LDA #<TXT_CONFIRM_YN    ;
                LDY #>TXT_CONFIRM_YN    ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen   
CONFIRM_YN_LP   JSR SCAN_INPUTS         ;check keyboard and/ joysticks (if applicable)
                CMP #USER_INPUT_NO      ;
                BNE CONFIRM_YN_01       ;
                JMP CR_DISK_EXIT        ;when No, so we exit
CONFIRM_YN_01   CMP #USER_INPUT_YES     ;
                BEQ CR_DISK_FORMAT      ;when Yes, we continue
                JMP CONFIRM_YN_LP       ;


CR_DISK_FORMAT  LDX #X_POS_STATUS       ;write the text message
                LDY #Y_POS_STATUS       ;
                JSR SET_CURSOR          ;
                LDA #<TXT_FORMATTING    ;
                LDY #>TXT_FORMATTING    ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen  
                JSR SLOW_FORMAT_DISK    ;before doing anything, format the disk, because otherwise it might all fail!

                JSR ERROR_MESSAGE       ;get the error message, to determine if format has finished and if it was succesful
                LDA DRIVE_STATUS        ;
                BEQ CR_DISK_FRMT_OK     ;we expect the value to be 0 and nothing else!!
                LDX #X_POS_STATUS       ;write the text message
                LDY #Y_POS_STATUS       ;
                JSR SET_CURSOR          ;
                LDA #<TXT_FORMAT_ERR    ;
                LDY #>TXT_FORMAT_ERR    ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen  
                JSR WAIT_FOR_KEY        ;allow message to remain visible until keypress
                JMP CR_DISK_EXIT        ;no sense in carying on, exit

CR_DISK_FRMT_OK JSR NEW_SCREEN          ;clear screen and set cursor to topleft
                LDA #<SCREEN_DATA       ;
                LDY #>SCREEN_DATA       ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen  

                LDA TABLE_PP_BLOCK  ;this value is the stepsize for the progressbar, it is increased by this amount each time we call UPDATE_PROGRBAR
                JSR INIT_PROGRBAR       ;reset and initialize the progressbar
          
CR_DISK_TRN_01  JSR CHECK_FOR_KEY       ;allow user to abort safely
                BNE CR_DISK_EXIT        ;key pressed? then exit

                LDA #$0                 ;reset byte counter
                STA CNT_BYTE            ;
                LDA #CPIO_DATAFILE_READ ;prepare for reading
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode

                ;get data from Cassiopei
CR_DISK_TRN_02  JSR CPIO_RECIEVE        ;get byte from the selected file
CR_DISK_TRN_03  LDY CNT_BYTE            ;
                STA DATA_AREA,Y         ;read byte from memory
                INC CNT_BYTE            ;
                LDA CNT_BYTE            ;
                CMP #$FF                ;
                BNE CR_DISK_TRN_02      ;load next byte untill 255 bytes are read
                JSR CPIO_REC_LAST       ;read the 256th byte and end communication
                LDY CNT_BYTE            ;
                STA DATA_AREA,Y         ;read byte from memory

                ;send data to drive
CR_DISK_TRN_10  LDX TRACK               ;send track
                LDY SECTOR              ;and sector information
                JSR WRITE_BLOCK         ;write data to disk
                INC SECTOR              ;increment sector counter, so that we know what to do next

                JSR UPDATE_PROGRBAR     ;increment the progressbar by the appropriate amount

                LDA SECTOR              ;
                CMP SECTOR_MAX          ;
                BNE CR_DISK_TRN_01      ;process the next sector
                
                INC TABLE_PNTR          ;all sectors processed, continue with next track
                LDY TABLE_PNTR          ;
                LDA TABLE_MAXSEC,Y      ;get max number of sector for this track
                STA SECTOR_MAX          ;

                LDA #$00                ;reset sector
                STA SECTOR              ;
                INC TRACK               ;inc. track

                ;are we ready?
                LDA TRACK_MAX           ;
                CLC                     ;
                ADC #1                  ;
                CMP TRACK               ;check if last track is processed
                BNE CR_DISK_TRN_01      ;process the next sector


CR_DISK_EXIT    LDA #CPIO_DATAFILE_CLOSE;close the file, we are done using it
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                LDA #0                  ;
                JSR CPIO_SEND_LAST      ;send a dummy to close CPIO communication in a normal manor
                CLI                     ;enable interrupts again (required for keyboard readout)
                RTS                     ;



TXT_CLEAR       TEXT '                                      ';
                BYTE 0

TXT_CONFIRM_YN  TEXT 'are you sure? y/n                     ';
                BYTE 0

TXT_NOTSUPP     TEXT 'error:file not supported              ';
                BYTE 0

TXT_FORMATTING  TEXT 'formatting...                         ';
                BYTE 0

TXT_FORMAT_ERR  TEXT 'error:format failed,check disk & drive';
                BYTE 0

endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<





;###############################################################################
;           M A K E   a  f i l e   f r o m   a  r e a l   d i s k
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef MAKEIMAGE
;-------------------------------------------------------------------------------
MAKE_IMAGE      JSR CPIO_INIT           ;initialize IO for use of CPIO protocol on the CBM's cassetteport

MIMG_SCREEN     JSR NEW_SCREEN          ;clear screen and set cursor to topleft
                LDA #<SCREEN_MAKE_IMAGE ;set pointer to the text that defines the main-screen
                LDY #>SCREEN_MAKE_IMAGE ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen         
                JSR SHOW_FILENAME       ;allow user to enter a filename

MIMG_MENU       
MIMG_SCANKEY
MIMG_SCANKEY_01 JSR SCAN_INPUTS         ;check keyboard and/ joysticks (if applicable)
MIMG_SCANKEY_02 CMP #USER_INPUT_DIR     ;
                BNE MIMG_SCANKEY_03     ;
                JSR DIRECTORY           ;show directory
                JSR WAIT_FOR_KEY        ;keep screen visible until user presses key
                JMP MIMG_SCREEN         ;redraw make-image-screen

MIMG_SCANKEY_03 CMP #USER_INPUT_CREATE  ;
                BNE MIMG_SCANKEY_04     ;
                JSR CREATE_IMAGE        ;
                JSR DIRECTORY           ;show directory (just a command to check if the drive is still alive)
                JMP MIMG_SCREEN         ;redraw make-image-screen

MIMG_SCANKEY_04 CMP #USER_INPUT_EXIT    ;
                BNE MIMG_SCANKEY_05     ;
                JMP MAIN_MENU           ;exit the current screen by returning to the main screen

MIMG_SCANKEY_05 CMP #USER_INPUT_FILENAME;
                BNE MIMG_SCANKEY_06     ;
                JSR ENTER_FILENAME      ;allow user to enter a filename
                JMP MIMG_SCREEN         ;redraw make-image-screen

MIMG_SCANKEY_06 JMP MIMG_SCANKEY_01     ;when the pressed key has no function then continue the key scanning

                ;........................

CREATE_IMAGE    ;create a D64 image from a real disk
                LDA TABLE_PP_BLOCK  ;this value is the stepsize for the progressbar, it is increased by this amount each time we call UPDATE_PROGRBAR
                JSR INIT_PROGRBAR       ;reset and initialize the progressbar

                ;send the filename
                LDA #CPIO_PARAMETER     ;the mode we want to operate in
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                LDA #0                  ;
                STA STR_POS             ;
CR_IMAGE_00     LDY STR_POS             ;
                LDA STR_MEM,Y           ;
                BEQ CR_IMAGE_02         ;end of string detected?
                JSR CPIO_SEND           ;
                INC STR_POS             ;
                LDY STR_POS             ;
                CPY #STR_POS_MAX        ;
                BEQ CR_IMAGE_02         ;max length of string reached?
                JMP CR_IMAGE_00         ;
CR_IMAGE_02     LDA #0                  ;send end of string terminator
                JSR CPIO_SEND_LAST      ;

CR_IMAGE_03     LDA #CPIO_DATAFILE_OPEN ;the mode we want to operate in
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                LDA #1                  ;1=write to file
                JSR CPIO_SEND           ;
                JSR CPIO_RECIEVE        ;the cassiopei responds with a 0=file-not-found, 1=file-found, do not drop attention as we want to continue loading data
                STA FILE_OPEN_STATUS    ;
                JSR CPIO_RECIEVE        ;filesize (MSB) of the opened file (although we are not even using it, it doesn't hurt to read it)
                STA FILE_SIZE_03        ;
                JSR CPIO_RECIEVE        ;filesize of the opened file
                STA FILE_SIZE_02        ;
                JSR CPIO_RECIEVE        ;filesize of the opened file
                STA FILE_SIZE_01        ;
                JSR CPIO_REC_LAST       ;filesize (LSB) of the opened file
                STA FILE_SIZE_00        ;
                CLI                     ;enable interrupts again (required for keyboard readout) (this may come in handy when asking Y/N to overwrite)

                LDA FILE_OPEN_STATUS    ;
                CMP #1                  ;
                BEQ CR_IMAGE_07         ;1=file opened, ready for writing
                CMP #2                  ;
                BEQ CR_IMAGE_04         ;2=file opened, ready to overwrite existing file
               ;CMP #0                  ;when 0 (or anything else, there is a real problem)
               ;BNE ...                 ;0=could not open file for writing
                LDX #X_POS_STATUS       ;write the text message
                LDY #Y_POS_STATUS       ;
                JSR SET_CURSOR          ;
                LDA #<TXT_FOPEN_ERROR   ;
                LDY #>TXT_FOPEN_ERROR   ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen   
                JSR WAIT_FOR_KEY        ;keep screen visible until user presses key
                JMP CR_IMAGE_EXIT       ;no sense in carying on, exit           

CR_IMAGE_04     LDX #X_POS_STATUS       ;write the text message
                LDY #Y_POS_STATUS       ;
                JSR SET_CURSOR          ;
                LDA #<TXT_OVERWRITE_YN  ;
                LDY #>TXT_OVERWRITE_YN  ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen   

CR_IMAGE_05     JSR SCAN_INPUTS         ;check keyboard and/ joysticks (if applicable)
                CMP #USER_INPUT_YES     ;
                BEQ CR_IMAGE_07         ;when Yes, we continue
                CMP #USER_INPUT_NO      ;
                BNE CR_IMAGE_05         ;
                JMP CR_IMAGE_EXIT       ;no sense in carying on, exit 
                
CR_IMAGE_07     JSR NEW_SCREEN          ;clear screen and set cursor to topleft
                LDA #<SCREEN_DATA       ;
                LDY #>SCREEN_DATA       ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen  

                LDA #0                  ;reset track sector
                STA TABLE_PNTR          ;
                LDA #1                  ;
                STA TRACK               ;
                LDA #0                  ;
                STA SECTOR              ;
                LDY TABLE_PNTR          ;
                LDA TABLE_MAXSEC,Y      ;
                STA SECTOR_MAX          ;             

                ;get data from the drive
CR_IMAGE_10     JSR CHECK_FOR_KEY       ;allow user to abort safely
                BNE CR_IMAGE_EXIT       ;key pressed? then exit

                LDX TRACK               ;send track
                LDY SECTOR              ;and sector information
                JSR READ_BLOCK          ;read data from disk

                ;send the data to the Cassiopei
CR_IMAGE_20     LDA #$0                 ;reset byte counter
                STA CNT_BYTE            ;
                LDA #CPIO_DATAFILE_WRITE;the mode we want to operate in
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
CR_IMAGE_21     LDY CNT_BYTE            ;
                LDA DATA_AREA,Y         ;read byte from memory
                JSR CPIO_SEND           ;send data to Cassiopei
                INC CNT_BYTE            ;
                LDA CNT_BYTE            ;
                CMP #$FF                ;
                BNE CR_IMAGE_21         ;       
                LDY CNT_BYTE            ;
                LDA DATA_AREA,Y         ;read byte from memory
                JSR CPIO_SEND_LAST      ;send last byte (of this data block) to the Cassiopei

                JSR UPDATE_PROGRBAR     ;increment the progressbar by the appropriate amount

                INC SECTOR              ;increment sector counter, so that we know what to do next
                LDA SECTOR              ;
                CMP SECTOR_MAX          ;
                BNE CR_IMAGE_10         ;process the next sector                
                INC TABLE_PNTR          ;all sectors processed, continue with next track
                LDY TABLE_PNTR          ;
                LDA TABLE_MAXSEC,Y      ;get max number of sector for this track
                STA SECTOR_MAX          ;

                LDA #$00                ;reset sector
                STA SECTOR              ;
                INC TRACK               ;inc. track

                LDA TRACK_MAX           ;
                CLC                     ;
                ADC #1                  ;
                CMP TRACK               ;check if last track is processed
                BNE CR_IMAGE_10         ;process the next sector

CR_IMAGE_EXIT
CR_IMAGE_30     LDA #CPIO_DATAFILE_CLOSE;close the file, we are done using it
                JSR CPIO_START          ;send this command so the connected device knows we now start working in this mode
                LDA #0                  ;
                JSR CPIO_SEND_LAST      ;send a dummy to close CPIO communication in a normal manor
                CLI                     ;enable interrupts again (required for keyboard readout)
                RTS                     ;



TXT_OVERWRITE_YN        TEXT 'file exists, overwrite file? y/n      ';
                        BYTE 0

TXT_FOPEN_ERROR         TEXT 'sd-error, could not create file       ';
                        BYTE 0

endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;===============================================================================
;                             - = SUBROUTINES = -
;===============================================================================

;this routine will print the current filename string to screen
SHOW_FILENAME   LDA #STR_POS_MAX                ;
                STA STR_POS                     ;
SHOW_FNAME_01   LDY STR_POS                     ;
                LDA STR_MEM,Y                   ;
                JSR CONVERT_TO_SCREENCODES      ;convert ASCII to screencodes otherwise it looks like #@#$@$#
                LDY STR_POS                     ;
                STA SCR_POS,Y                   ;print value to screen
                DEC STR_POS                     ;
                LDA STR_POS                     ;
                CMP #$FF                        ;
                BNE SHOW_FNAME_01               ;                
                RTS                             ;
                
;. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

;this routine allows the user to input a filename
;it is shows on screen (SCR_POS) using the screencodes but stored in memory (STR_MEM) as ASCII

ENTER_FILENAME  
                
STRING_SEEK_END LDY #$FF                ;position cursor at the end of the text
STRING_SEEK_01  INY                     ;the end of the string is value 0
                LDA STR_MEM,Y           ;so in a loop we scan through the
                BNE STRING_SEEK_01      ;string searching for value 0
                STY STR_POS             ;

;STRING_CLEAR    LDY #STR_POS_MAX        ;reset the string
;STRING_CLEAR_01 LDA #' '                ;
;                STA SCR_POS,Y           ;
;                LDA #0                  ;by filling the string with terminator characters we do no need to worry about it when we detect a <cr> on input
;                STA STR_MEM,Y           ;
;                DEY                     ;
;                CPY #$FF                ;
;                BNE STRING_CLEAR_01     ;                
;                LDA #0                  ;
;                STA STR_POS             ;

STRING_INPUT    LDY STR_POS             ;
                LDA #100                ;show a cursor like character on the screen
                STA SCR_POS,Y           ;
                JSR WAIT_KEY_RELEASE    ;prevent key repeat by waiting for release
                JSR WAIT_FOR_KEY        ;
                AND #%01111111          ;only use the lowest 7 bits (we must discard all possible inverted char nonsens)
                CMP #13                 ;check for cr (a.k.a. "enter", a.k.a. "return")
                BEQ STRING_INP_DONE     ;
                CMP #20                 ;check for delete (a.k.a. "backspace")
                BEQ STRING_INP_DEL      ;

                LDY STR_POS             ;
                STA STR_MEM,Y           ;

                JSR CONVERT_TO_SCREENCODES    ;convert ASCII to screencodes otherwise it looks like #@#$@$#
                LDY STR_POS             ;
                STA SCR_POS,Y           ;

                LDY STR_POS             ;
                CPY #STR_POS_MAX        ;
                BEQ STRING_INPUT        ;max position reached (so skip increment)
                INC STR_POS             ;MAX not reached, "cursor" to next char pos
                JMP STRING_INPUT        ;

STRING_INP_DEL  LDY STR_POS             ;
                LDA #' '                ;replace the cursor by a space, otherwise we leave a trail of cursors
                STA SCR_POS,Y           ;
                LDA STR_POS             ;
                BEQ STRING_INP_D02      ;string cannot be deleletd any further
STRING_INP_D01  DEC STR_POS             ;MAX not reached, "cursor" to next char pos
                LDY STR_POS             ;
                LDA #' '                ;remove character by printing a space
                STA SCR_POS,Y           ;
                LDA #0                  ;by filling the string with terminator characters we do no need to worry about it when we detect a <cr> on input
                STA STR_MEM,Y           ;                
STRING_INP_D02  JMP STRING_INPUT        ;

STRING_INP_DONE RTS                     ;return to caller

;-------------------------------------------------------------------------------
;Call the corresponding menu function below and it will be printed to the screen
;-------------------------------------------------------------------------------

BROWSE_REFRESH  LDA #CPIO_BROWSE_REFRESH;Refresh: will only get the menu information from the Cassiopei's screen buffer
                STA BROWSE_ACTION       ;store the menu action to memory
                JMP BROWSE_00           ;

BROWSE_PREVIOUS LDA #CPIO_BROWSE_PREVIOUS;Previous: will perform a previous action in the menu, scolling the items down (or moving the indicator up)
                STA BROWSE_ACTION       ;store the menu action to memory
                JMP BROWSE_00           ;

BROWSE_SELECT   LDA #CPIO_BROWSE_SELECT ;Select: will perform a selection of the currently selected menu item
                STA BROWSE_ACTION       ;store the menu action to memory
                JMP BROWSE_00           ;

BROWSE_NEXT     LDA #CPIO_BROWSE_NEXT   ;Next: will perform a next action in the menu, scolling the items up (or moving the indicator down)
                STA BROWSE_ACTION       ;store the menu action to memory
                JMP BROWSE_00           ;

BROWSE_RESET    LDA #CPIO_BROWSE_RESET  ;Reset the menu, forcing it to the beginning state
                STA BROWSE_ACTION       ;store the menu action to memory
                LDA #CPIO_BROWSE        ;send directory read command
                JSR CPIO_START          ;
                LDA BROWSE_ACTION       ;get the menu action from memory                
                JSR CPIO_SEND           ;send the menu action to the Cassiopei
                LDA #WINDOW_X_SIZE      ;send the size of the visble screen area
                JSR CPIO_SEND           ;on the CBM computer
                LDA #WINDOW_Y_SIZE      ;
                JSR CPIO_SEND           ;
                JSR CPIO_REC_LAST       ;get the menu status byte
                STA BROWSE_STATUS       ;the status byte indicates wheter or not the menu is still active, because the user might have select exit
                CLI                     ;allow interrupts (usefull for keyboard and other things)
                RTS                     ;

;...............................................................................

BROWSE_00       LDA #WINDOW_X_POS       ;the location of the first character of the info on the screen
                STA BROWSE_CURX         ;
                LDA #WINDOW_Y_POS       ;
                STA BROWSE_CURY         ;

                LDA #WINDOW_Y_SIZE      ;the number of characters we will (may) display on a single line
                STA BROWSE_MAXY         ;
                LDA #CPIO_BROWSE        ;send directory read command
                JSR CPIO_START          ;
                LDA BROWSE_ACTION       ;get the menu action from memory
                JSR CPIO_SEND           ;send the menu action to the Cassiopei
                LDA #WINDOW_X_SIZE      ;send the size of the visble screen area
                JSR CPIO_SEND           ;on the CBM computer
                LDA #WINDOW_Y_SIZE      ;
                JSR CPIO_SEND           ;
                JSR CPIO_RECIEVE        ;get the menu status byte
                STA BROWSE_STATUS       ;the status byte indicates whether or not the menu is still active, because the user might have select exit

BROWSE_03       LDA #WINDOW_X_SIZE      ;the max length of a file name
                STA BROWSE_MAXX         ;
                LDX BROWSE_CURX         ;
                LDY BROWSE_CURY         ;
                JSR SET_CURSOR          ;

BROWSE_04       LDA BROWSE_MAXX         ;check if this is the last byte that should be drawn on this line
                CMP #1                  ;
                BEQ BROWSE_05           ;
                JSR CPIO_RECIEVE        ;get byte from Cassiopei containing the screen data
                JMP BROWSE_07           ;
BROWSE_05       LDA BROWSE_MAXY         ;check if this REALLY is the last byte we will be reading (regarding this command)
                CMP #1                  ;
                BEQ BROWSE_06           ;
                JSR CPIO_RECIEVE        ;get byte from Cassiopei containing the screen data
                JMP BROWSE_07           ;
BROWSE_06       JSR CPIO_REC_LAST       ;last byte before communication stops

BROWSE_07       JSR PRINT_CHAR          ;character is printed to screen, cursor is incremented by one
                DEC BROWSE_MAXX         ;keep looping untill we have processed the full width of the text area
                BNE BROWSE_04           ;

BROWSE_08       INC BROWSE_CURY         ;the next entry will be written on the next line in the directory text area
                DEC BROWSE_MAXY         ;keep looping untill we have processed the full length of the text area
                BNE BROWSE_03           ;
                
BROWSE_END      CLI                     ;CPIO communication has disabled interrupts, so we must enable interrupts again. Otherwise the keyboard is not scanned etc.
                RTS                     ;

;===============================================================================

;-------------------------------------------------------------------------------
;call this routine as described below:
;
;        LDA #<label                ;set pointer to the text that defines the main-screen
;        LDY #>label                ;
;        JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen
;
; JSR PRINT_CUR_STR ;print the string as indicated by the current string pointer
;...............................................................................
PRINT_STRING    STA STR_ADDR            ;
                STY STR_ADDR+1          ;
PRINT_CUR_STR   LDY #$00                ;
                LDA (STR_ADDR),Y        ;read character from string
                BEQ PR_STR_END          ;when the character was 0, then the end of string marker was detected and we must exit
                JSR PRINT_CHAR          ;print char to screen
                                     
                CLC                     ;
                LDA #$01                ;add 1
                ADC STR_ADDR            ;
                STA STR_ADDR            ;string address pointer
                LDA #$00                ;
                ADC STR_ADDR+1          ;add carry...
                STA STR_ADDR+1          ;                            

                JMP PRINT_CUR_STR       ;repeat...

PR_STR_END      RTS                     ;


;-------------------------------------------------------------------------------
;call this routine as described below:
;
;       LDA #<label             ;set pointer to the first string in a table of strings
;       LDY #>label             ;set pointer to the first string in a table of strings
;       LDX #string_number      ;select the Xth string from the table of strings
;       JSR PRINT_XTH_STR       ;sets the address pointer to the adress of Xth string after the string as pointed to as indicated
;
;
;the table consists of string that all end with 0
;example:
;  BYTE 'MENU OPTION-A                 ',0      ;
;  BYTE 'MENU OPTION-B                 ',0      ;
;  BYTE 'MENU OPTION-C                 ',0      ;
;-------------------------------------------------------------------------------
PRINT_XTH_STR   STA STR_ADDR            ;
                STY STR_ADDR+1          ;
                TXA                     ;check if X=0
                BEQ SET_PR_STR_END      ;when X=0 then we've allready have the correct pointer value and we're done
SET_PR_STR_01   JSR PRINT_XTH_INCA      ;increment address by one
                LDY #$00                ;
                LDA (STR_ADDR),Y        ;read character from string
                BEQ SET_PR_STR_02       ;when the character was 0, then the end of string marker was detected          
                JMP SET_PR_STR_01       ;repeat until end of string reached
SET_PR_STR_02   DEX                     ;decrement string index counter
                BNE SET_PR_STR_01       ;keep looping until we reached the string we want
                JSR PRINT_XTH_INCA      ;increment address by one (we want to point to the first character of the next table entry, we are now pointing to the end of line marker)
SET_PR_STR_END  JMP PRINT_CUR_STR       ;print the string

PRINT_XTH_INCA  CLC                     ;
                LDA #$01                ;increment the pointer to the string by one in order to get the next char/value
                ADC STR_ADDR            ;add 1
                STA STR_ADDR            ;string address pointer
                LDA #$00                ;add 0 + carry of the previous result
                ADC STR_ADDR+1          ;meaning that if we have an overflow, the must increment the high byte
                STA STR_ADDR+1          ;  
                RTS

;the code below is commented out to save program space
;this is possible as the code below is only required for debugging
;;-------------------------------------------------------------------------------
;; this routine will print the value in A as a 2 digit hexadecimal value
;;        LDA #value                      ;A-register must contain value to be printed
;;        JSR PRINT_HEX     ;the print routine is called
;;...............................................................................
;PRINT_HEX       PHA                     ;save A to stack
;                AND #$F0                ;mask out low nibble
;                LSR A                   ;shift to the right
;                LSR A                   ;
;                LSR A                   ;
;                LSR A                   ;
;                TAX                     ;
;                LDA HEXTABLE,X          ;convert using table                                 
;                JSR PRINT_CHAR          ;print character to screen

;                PLA                     ;retrieve A from stack
;                AND #$0F                ;mask out high nibble
;                TAX                     ;
;                LDA HEXTABLE,X          ;convert using table                                 
;                JSR PRINT_CHAR          ;print character to screen
; 
;                RTS                     ;

;HEXTABLE        TEXT '0123456789abcdef'                 

;;-------------------------------------------------------------------------------
;; this routine will print the value in A as a 3 digit decimal value
;;        LDA #value        ;Y-register must contain value to be printed
;;        JSR PRINT_DEC     ;the print routine is called
;;
;;Converts .A to 3 ASCII/PETSCII digits: .Y = hundreds, .X = tens, .A = ones
;;...............................................................................
;PRINT_DEC       LDY #$2f                ;
;                LDX #$3a                ;
;                SEC                     ;
;DEC_01          INY                     ;
;                SBC #100                ;
;                BCS DEC_01              ;

;DEC_02          DEX                     ;
;                ADC #10                 ;
;                BMI DEC_02              ;
;        
;                ADC #$2f                ;
;                PHA                     ;save A to stack

;                TYA                     ;transfer value to A for printing
;                JSR PRINT_CHAR          ;print 100's

;                TXA                     ;transfer value to A for printing
;                JSR PRINT_CHAR          ;print 10's

;                PLA                     ;retrieve saved A from stack for printing
;                JSR PRINT_CHAR          ;print 1's

;                RTS                     ;


;===============================================================================
;Force to drive to reset the disk related info, because otherwise the old info
;from RAM is used, meaning we see the worng disk header after we written a new
;image to the disk. Or formatting will be skipped because the disk is already
;formated or whatever
;The BASIC equiv: OPEN15,8,15,"IO":CLOSE15
;-------------------------------------------------------------------------------
RESET_DISK      LDA #resetdisk_end-resetdisk
                LDX #<resetdisk
                LDY #>resetdisk
                JSR KERN_SETNAM         ;call SETNAM

                LDA #1                  ;filenumber
                LDX #DEVICE             ;the device number of the drive
                LDY #15                 ;secondary address 15 (required for formatting?)
                JSR KERN_SETLFS         ;call SETLFS

                JSR KERN_OPEN           ;call OPEN
                BCS RESET_DISK_ERR      ;quit if OPEN failed
                JMP RESET_DISK_EXIT     ;


RESET_DISK_ERR  ; Akkumulator contains BASIC error code. Most likely error: A = $05 (DEVICE NOT PRESENT)
                ;add you error handling code here

RESET_DISK_EXIT LDA #1                  ;filenumber
                JSR KERN_CLOSE          ;call CLOSE
                JSR KERN_CLRCHN         ;call CLRCHN
                RTS                     ;

resetdisk       BYTE $49,$30    ; "I0"
resetdisk_end   BYTE 0          ; end of table marker

;===============================================================================
;Format a disk using the standard Commodore routines, slow but effective
;and very likely to work on all the different kind of commodore drives
;The BASIC equiv: OPEN15,8,15,"N:EMPTY,00":CLOSE15
;-------------------------------------------------------------------------------
SLOW_FORMAT_DISK

;                LDX #$00                ;a small text printing loop to show what we are sending to the drive, for debugging purposes only
;FORMAT_DBG_LOOP LDA formatname,X        ;
;                BEQ FORMAT_DBG_EXIT     ;exit when end-of-table marker is found
;                JSR KERN_CHROUT         ;call CHROUT
;                INX                     ;
;                JMP FORMAT_DBG_LOOP     ;
;FORMAT_DBG_EXIT
 
                LDA #formatname_end-formatname
                LDX #<formatname
                LDY #>formatname
                JSR KERN_SETNAM         ;call SETNAM

                LDA #1                  ;filenumber
                LDX #DEVICE             ;the device number of the drive
                LDY #15                 ;secondary address 15 (required for formatting?)
                JSR KERN_SETLFS         ;call SETLFS

                JSR KERN_OPEN           ;call OPEN
                BCS FORMAT_ERROR        ;quit if OPEN failed
                JMP FORMAT_EXIT         ;

FORMAT_ERROR    ; Akkumulator contains BASIC error code. Most likely error: A = $05 (DEVICE NOT PRESENT)
                ;add you error handling code here

FORMAT_EXIT     LDA #1                  ;filenumber
                JSR KERN_CLOSE          ;call CLOSE
                JSR KERN_CLRCHN         ;call CLRCHN
                RTS                     ;

formatname      BYTE $4E,$30,$3A,$45,$4D,$50,$54,$59,$2C,$30,$30    ; "N0:EMPTY,00"
formatname_end  BYTE 0                                          ; end of table marker

;===============================================================================
;Read the directory (and print to screen)
;
;source: http://codebase64.org/doku.php?id=base:reading_the_directory
;-------------------------------------------------------------------------------
DIRECTORY       JSR CLEAR_SCREEN ;clear the screen so there is room for the directory

                LDX #0                  ;
                LDY #0                  ;
                CLC                     ;set cursor position
                JSR KERN_PLOT           ;set the X and Y coordinate for CHROUT
                LDA #01                 ;white
                STA KVAR_CCCC           ;Current Character Color Code
                LDA #00                 ;black
                STA KVAR_BCUC           ;Background Color Under Cursor

                LDA #dirname_end-dirname;
                LDX #<dirname           ;
                LDY #>dirname           ;
                JSR KERN_SETNAM         ;call SETNAM

                LDA #2                  ;filenumber 2
                LDX #DEVICE             ;the device number of the drive
                LDY #0                  ;secondary address 0 (required for dir reading!)
                JSR KERN_SETLFS         ;call SETLFS

                JSR KERN_OPEN           ;call OPEN(open the directory)
                BCS DIR_ERROR           ;quit if OPEN failed

                LDX #2                  ;filenumber 2
                JSR KERN_CHKIN          ;call CHKIN

                LDY #4                  ;skip 4 bytes on the first dir line
                BNE DIR_SKIP            ;
DIR_NEXT        LDY #2                  ;skip 2 bytes on all other lines
DIR_SKIP        JSR DIR_GETBYTE         ;get a byte from dir and ignore it
                DEY                     ;
                BNE DIR_SKIP            ;

                JSR DIR_GETBYTE         ;get low byte of basic line number
                TAY                     ;
                JSR DIR_GETBYTE         ;get high byte of basic line number
                PHA                     ;
                TYA                     ;transfer Y to X without changing Akku
                TAX                     ;
                PLA                     ;
                JSR KERN_LINPRT         ;print basic line number
                LDA #$20                ;print a space first

DIR_GETCHAR     JSR KERN_CHROUT             ;call CHROUT (print character)
                JSR DIR_GETBYTE         ;
                BNE DIR_GETCHAR         ;continue until end of line

                LDA #$0D                ;
                JSR KERN_CHROUT         ;call CHROUT print RETURN
     JSR KERN_RUNSTOP        ;RUN/STOP pressed?
     BNE DIR_NEXT            ;no RUN/STOP -> continue
 ;JMP DIR_NEXT

DIR_ERROR       ; Akkumulator contains BASIC error code. Most likely error: A = $05 (DEVICE NOT PRESENT)
DIR_EXIT        LDA #2                  ;filenumber 2
                JSR KERN_CLOSE          ;call CLOSE
                JSR KERN_CLRCHN         ;call CLRCHN
                RTS                     ;

DIR_GETBYTE     JSR KERN_READST         ;call READST (read status byte)
                BNE DIR_END             ;read error or end of file
                JMP KERN_CHRIN          ;call CHRIN (read byte from directory)

DIR_END         PLA                     ;don't return to dir reading loop
                PLA                     ;

                JMP DIR_EXIT            ;

dirname         BYTE $24                ; $24 = $ (filename used to access directory)
dirname_end     BYTE 0                  ; end of table marker


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




;===============================================================================
;Read the error code (and print message to screen)
;
;source: http://codebase64.org/doku.php?id=base:reading_the_error_channel_of_a_disk_drive
;-------------------------------------------------------------------------------
ERROR_MESSAGE   LDA #$FF         ;set drive status to failure value
                STA DRIVE_STATUS ;usefull in case we exit early because of, for example, drive not found       

                LDY #X_POS_STATUS       ;Y holds the column value
                LDX #Y_POS_STATUS       ;X holds the row value
                CLC                     ;set cursor position to row & columnm
                JSR KERN_PLOT   ;set the X and Y coordinate for CHROUT
                LDA #01         ;white
                STA KVAR_CCCC   ;Current Character Color Code
                LDA #00         ;black
                STA KVAR_BCUC   ;Background Color Under Cursor

                LDA #$00        ;
                STA $90         ;clear STATUS flags

                LDA #DEVICE     ;the device number of the drive
                JSR KERN_LISTEN ;call LISTEN
                LDA #$6F        ;secondary address 15 (command channel) (Note:$6F is not a typo, this is correct)
                JSR KERN_SECLSN ;call SECLSN (SECOND)
                JSR KERN_UNLISTEN ;call UNLSN
                LDA $90         ;get STATUS flags
                BNE ER_ERROR    ;device not present

                LDA #DEVICE     ;the device number of the drive
                JSR KERN_TALK   ;call TALK
                LDA #$6F        ;secondary address 15 (error channel) (Note:$6F is not a typo, this is correct)
                JSR KERN_SECTALK;call SECTLK (TKSA)

ER_1ST_CHAR     LDA $90         ;get STATUS flags
                BNE ER_MSG_END  ;either EOF or error
                JSR KERN_IECIN  ;call IECIN (get byte from IEC bus)
                PHA             ;save value
                JSR KERN_CHROUT ;call CHROUT (print character) (print byte to screen)
                PLA             ;
                SEC             ;set carry for subtraction
                SBC #'0'        ;by removing the offset i the charset, we get the value of the character (though we must be sure we are working with a number)
                STA DRIVE_STATUS;
;                ASL DRIVE_STATUS;move the value to the left nibble
;                ASL DRIVE_STATUS;
;                ASL DRIVE_STATUS;
;                ASL DRIVE_STATUS;
;
;ER_2ND_CHAR     LDA $90         ;get STATUS flags
;                BNE ER_MSG_END  ;either EOF or error
;                JSR KERN_IECIN  ;call IECIN (get byte from IEC bus)
;                JSR KERN_CHROUT ;call CHROUT (print byte to screen)

ER_MSGLP        LDA $90         ;get STATUS flags
                BNE ER_MSG_END  ;either EOF or error
                JSR KERN_IECIN  ;call IECIN (get byte from IEC bus)
                JSR KERN_CHROUT ;call CHROUT (print byte to screen)
                JMP ER_MSGLP    ;next byte

ER_MSG_END      JSR KERN_UNTALK                 ;call UNTLK
                RTS                             ;

ER_ERROR        LDX #0                          ;
ER_ERROR_LP     LDA TXT_DEV_NOT_PRESENT,X       ;
                BEQ ER_ERROR_EXIT               ;
                JSR KERN_CHROUT                 ;call CHROUT (print byte to screen)                
                INX                             ;
                JMP ER_ERROR_LP                 ;
ER_ERROR_EXIT   RTS                             ;... device not present handling ...



TXT_DEV_NOT_PRESENT     TEXT "drive #8 not found" ;we use " because we are printing with CHROUT, if we'd use our own print routine we would be using ' to mark the text
                        BYTE 0

DRIVE_STATUS    BYTE $00        



;-------------------------------------------------------------------------------
;this routine will initialize the progressbar
;example:
;               LDA TABLE_PP_BLOCK      ;increment bar by the appropriate amount
;               JSR INIT_PROGRBAR       ;reset and initialize the progressbar
;...............................................................................

INIT_PROGRBAR   STA PRGBAR_STEP         ;
                LDA TABLE_PP_BLOCK_EH   ;the highbyte of the error
                STA PRGBAR_H            ;
                LDA TABLE_PP_BLOCK_EH   ;the low byte of the error
                STA PRGBAR_L            ;
                RTS                     ;return to caller

;-------------------------------------------------------------------------------
;this routine will update the progressbar
;example:
;               JSR UPDATE_PROGRBAR     ;increment the progressbar by the appropriate amount
;...............................................................................

UPDATE_PROGRBAR STA PRGBAR_TMP          ;save requested bar value
                JSR SET_CURSOR          ;set cursor to first position of the bar (user has specified the position using X and Y registers)
                ;update progressbar
                CLC                     ;clear carry, so that we can use it later for the low-byte overflow
                LDA PRGBAR_STEP         ;increment bar by the appropriate amount
                ADC PRGBAR_L            ;
                STA PRGBAR_L            ;
                LDA #0                  ;add the carry caused by the overflow of the low byte
                ADC PRGBAR_H            ;
                STA PRGBAR_H            ;
                ;LDA PRGBAR_H           ;we send the value in the high byte
                LDX #X_POS_PROGBAR      ;the first position of the bar on the screen (row)
                LDY #Y_POS_PROGBAR      ;the first position of the bar on the screen (column)
                ;from here we roll straight into DRAW_PROGRBAR

;-------------------------------------------------------------------------------
;this routine will draw a progressbar made up entirely from PETSCII characters
;example:
;               LDA PRGBAR              ;the value of the progressbar ($00=0%, $FF=100%)
;               LDX #5                  ;the first position of the bar on the screen (row)
;               LDY #9                  ;the first position of the bar on the screen (column)
;               JSR DRAW_PROGRBAR       ;
;...............................................................................

DRAW_PROGRBAR   STA PRGBAR_TMP          ;save requested bar value
                JSR SET_CURSOR          ;set cursor to first position of the bar (user has specified the position using X and Y registers)

;debug only (show the high and low byte before printing)
;        LDX #0                  ;build the screen
;        LDY #0                  ;
;        JSR SET_CURSOR          ;
;        LDA PRGBAR_H            ;
;        JSR PRINT_HEX           ;the print routine is called
;        LDA PRGBAR_L            ;
;        JSR PRINT_HEX           ;the print routine is called

;        LDX #6                  ;build the screen
;        LDY #0                  ;
;        JSR SET_CURSOR          ;
;        LDA PRGBAR_TMP          ;
;        JSR PRINT_HEX           ;the print routine is called


                LDA #19                 ;the bar consists of ..+1 chars
                STA PRGBAR_CLR          ;

        ;the we fill it with full chars
                LDA PRGBAR_TMP          ;calculate the number of chars that need to be completely filled
                LSR                     ;
                LSR                     ;
                LSR                     ;
                STA PRGBAR_FILL         ;
                BEQ DRAW_BAR_FILLED     ;

DRAW_BAR_FILL   LDY #7                  ;#7 is the "completely filled char", perfect for filling a progress bar
                LDA PRGBAR_CHARS,Y      ;get the appropriate char from the table
                JSR PRINT_CHAR          ;character is printed to screen, cursor is incremented by one
                DEC PRGBAR_CLR          ;decrement the number of CLR characters we need to draw afterwards
                DEC PRGBAR_FILL         ;
                BNE DRAW_BAR_FILL       ;

        ;then finally we fill it with the detailed char for the last 8 pixels of the bars position
DRAW_BAR_FILLED LDA PRGBAR_TMP          ;
                AND #$7                 ;
                TAY                     ;
                LDA PRGBAR_CHARS,Y      ;get the appropriate char from the table
                JSR PRINT_CHAR          ;character is printed to screen, cursor is incremented by one


         ;clear all the chars for the remaining part of the bar
                LDA PRGBAR_CLR          ;
                BEQ DRAW_BAR_CLRD       ;
DRAW_BAR_CLR    LDY #0                  ;#0 is the "completely cleared char", perfect for clearing a progress bar
                LDA PRGBAR_CHARS,Y      ;get the appropriate char from the table
                JSR PRINT_CHAR          ;character is printed to screen, cursor is incremented by one
                DEC PRGBAR_CLR          ;
                BNE DRAW_BAR_CLR        ;

DRAW_BAR_CLRD   RTS                     ;return to caller


PRGBAR_TMP      byte 0
PRGBAR_FILL     byte 0
PRGBAR_CLR      byte 0
PRGBAR_CHARS    ;text'01234567' ;useful for debug
                BYTE    $20,$74,$65,$75,$61,$F6,$EA,$E0 ;the definiton of the individual pixels of the bar

PRGBAR_STEP     byte 0  ;this value is added each time the update_progrbar is called
PRGBAR_L        byte 0
PRGBAR_H        byte 0

;===============================================================================
;Writing a sector to disk
;------------------------
;For writing a sector to disk, the Commodore DOS offers the block write command.
;Due to heavy bugs in the B-W command, Commodore has sacrificed one of the user
;commands as a bugfix replacement. So instead of B-W you simply use U2.
;The format of this DOS command is: U2 <channel> <drive> <track> <sector>
;The drive parameter is only used for dual disk drives, so for all common 
;C64/C128/C16 drives this parameter will always be 0.
;Parameters track and sector explain themselves. They are sent in PETSCII
;format, so in assembler often a binary to PETSCII conversion is needed.
;A speciality of this command is the channel parameter. Actually you can't
;simply send this command to the drive and then start to send sector bytes.
;For the sending of the bytes you have to open another file which is adressed
;by this parameter. Before you send bytes into the channel buffer, it is
;neccessary to set the buffer pointer to 0 via the B-P command. 
;
;source: http://codebase64.org/doku.php?id=base:writing_a_sector_to_disk
;
;BASIC code:
;-----------
;10 SA=8192
;20 OPEN 2,8,2,"#"
;30 OPEN 15,8,15,"B-P 2 0"
;40 FOR I=0 TO 255
;50 A=PEEK(SA):SA=SA+1
;60 PRINT#2,CHR$(A);
;70 NEXT I
;80 PRINT#15,"U2 2 0 18 0"
;90 CLOSE 15:CLOSE 2
;
;Call example:
;               LDX TRACK               ;
;               LDY SECTOR              ;
;               JSR WRITE_BLOCK         ;
;               data is stored in screen mem. so you see what is happening
;-------------------------------------------------------------------------------
WRITE_BLOCK     TYA                     ;save Y value to stack, because the next routine will destroy it
                PHA                     ;if we do not save it first

                TXA                     ;
                JSR W_TRACK             ;use sector value 
                PLA                     ;recall saved valeu from stack
                JSR W_SECTOR            ;use sector value 

        ;RTS ;for debugging purposes, it may be usefull to exit early

                ; open the channel file
                LDA #1                  ;length of the table (cname_end-cname)
                LDX #<cname             ;
                LDY #>cname             ;
                JSR KERN_SETNAM         ;call SETNAM
                LDA #2                  ;file number 2
                LDX #DEVICE     ;the device number of the drive
                LDY #2                  ;secondary address 2
                JSR KERN_SETLFS         ;call SETLFS
                JSR KERN_OPEN           ;call OPEN
                BCS WB_ERROR            ;if carry set, the file could not be opened


                ; open the command channel
                LDA #7                  ;length of the table (bpcmd_end-bpcmd)
                LDX #<bpcmd             ;
                LDY #>bpcmd             ;
                JSR KERN_SETNAM         ;call SETNAM
                LDA #15                 ;file number 15
                LDX #DEVICE             ;the device number of the drive
                LDY #15                 ;secondary address 15
                JSR KERN_SETLFS         ;call SETLFS

                JSR KERN_OPEN           ;call OPEN (open command channel and send B-P command)
                BCS WB_ERROR            ;if carry set, the file could not be opened

                ;check drive error channel here to test for
                ;FILE NOT FOUND error etc.
                LDX #2                  ;filenumber 2
                JSR KERN_CHKOUT         ;call CHKOUT (file 2 now used as output)

                LDY #$00                ;
WB_LOOP1        LDA DATA_AREA,Y         ;read byte from memory
                JSR KERN_CHROUT         ;call CHROUT (write byte to channel buffer)
                INY                     ;
                BNE WB_LOOP1            ;next byte, end when 256 bytes are read

                LDX #15                 ;filenumber 15
                JSR KERN_CHKOUT         ;call CHKOUT (file 2 now used as output)

                LDY #$00                ;
WB_LOOP2        LDA bwcmd,Y             ;read byte from command string
                BEQ WB_CLOSE            ;keep reading table until end-of-table marker
                JSR KERN_CHROUT         ;call CHROUT (write byte to command channel)
               ;STA $0500,Y  ; for debug purposes only
                INY                     ;
                JMP WB_LOOP2            ;next byte, end when 256 bytes are read

WB_ERROR        ;Akkumulator contains BASIC error code
                ;most likely errors: A=5 (DEVICE NOT PRESENT)
                ;... error handling for open errors ...
                ;even if OPEN failed, the file has to be closed

WB_CLOSE        JSR KERN_CLRCHN         ;call CLRCHN
                LDA #15                 ;filenumber 15
                JSR KERN_CLOSE          ;call CLOSE

                LDA #2                  ;filenumber 2
                JSR KERN_CLOSE          ;call CLOSE

                JSR KERN_CLRCHN         ;call CLRCHN
                RTS                     ;

;===============================================================================
;Reading a sector from disk
;--------------------------
;For reading a sector from disk, the Commodore DOS offers the block read command.
;Due to heavy bugs in the B-R command, Commodore has sacrificed one of the user
;commands as a bugfix replacement. So instead of B-R you simply use U1.
;The format of this DOS command is: U1 <channel> <drive> <track> <sector>
;The drive parameter is only used for dual disk drives, so for all common C64/C128/C16
;drives this parameter will always be 0. Parameters track and sector explain themselves.
;They are sent in PETSCII format, so in assembler often a binary to PETSCII conversion is needed.
;A speciality of this command is the channel parameter. Actually you can't simply
;send this command to the drive and then start to receive sector bytes. For the
;receiving of the bytes you have to open another file which is adressed by this parameter.

;BASIC code:
;-----------
;10 SA=1024
;20 OPEN 2,8,2,"#"
;30 OPEN 15,8,15,"U1 2 0 18 0"
;40 FOR I=0 TO 255
;50 GET#2,A$:IF A$="" THEN A$=CHR$(0)
;60 POKE SA,ASC(A$):SA=SA+1
;70 NEXT I
;80 CLOSE 15:CLOSE 2
;
;source: http://codebase64.org/doku.php?id=base:reading_a_sector_from_disk
;
;
;Call example:
;               LDX TRACK               ;
;               LDY SECTOR              ;
;               JSR READ_BLOCK          ;
;               data is stored in screen mem. so you see what is happening
;===============================================================================

READ_BLOCK      TYA                     ;save Y value to stack, because the next routine will destroy it
                PHA                     ;if we do not save it first

                TXA                     ;
                JSR R_TRACK             ;use sector value 
                PLA                     ;recall saved value from stack
                JSR R_SECTOR            ;use sector value 

                ; open the channel file
                LDA #1                  ;length of the table (cname_end-cname)
                LDX #<cname             ;
                LDY #>cname             ;
                JSR KERN_SETNAM         ;call SETNAM
                LDA #2                  ;file number 2
                LDX #DEVICE             ;the device number of the drive
                LDY #2                  ;secondary address 2
                JSR KERN_SETLFS         ;call SETLFS
                JSR KERN_OPEN           ;call OPEN
                BCS RB_ERROR            ;if carry set, the file could not be opened

                ;open the command channel
                LDA #12                 ;length of the table (brcmd_end-brcmd)
                LDX #<brcmd             ;
                LDY #>brcmd             ;
                JSR KERN_SETNAM         ;call SETNAM
                LDA #15                 ;file number 15
                LDX #DEVICE             ;the device number of the drive
                LDY #15                 ;secondary address 15
                JSR KERN_SETLFS         ;call SETLFS
                JSR KERN_OPEN           ;call OPEN (open command channel and send U1 command)
                BCS RB_ERROR            ;if carry set, the file could not be opened

                ; check drive error channel here to test for
                ; FILE NOT FOUND error etc.
                LDX #2                  ;filenumber 2
                JSR KERN_CHKIN          ;call CHKIN (file 2 now used as input)

                LDY #$0                 ;set to FF for a speed test (this is useless (because it discards 254 bytes) but more fun to watch)
RB_LP           JSR KERN_CHRIN          ;call CHRIN (get a byte from file)
                STA DATA_AREA,Y         ;write byte to memory (which happens to be also screen memory,
                INY                     ;which is a good thing because we can see the data)
                BNE RB_LP               ;next byte, end when 256 bytes are read

RB_ERROR        ; Akkumulator contains BASIC error code
                ; most likely errors: A=5 (DEVICE NOT PRESENT)
                ;... error handling for open errors ...
                ;even if OPEN failed, the file has to be closed

RB_CLOSE        LDA #15                 ;filenumber 15
                JSR KERN_CLOSE          ;call CLOSE

                LDA #2                  ;filenumber 2
                JSR KERN_CLOSE          ;call CLOSE
                JSR KERN_CLRCHN         ;call CLRCHN
                RTS                     ;

;===============================================================================
;show track and sector info on screen
;SCR_POS_TRACK should hold the value of the screen memory location of the first char
;SCR_POS_SECTOR should hold the value of the screen memory location of the first char
;-------------------------------------------------------------------------------

R_TRACK         JSR CONV_HEX2DEC        ;
                STA SCR_POS_TRACK+1,Y   ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)
                STA R_TRCK+1,Y          ;also modify/update the string, holding the track value, that is send to the drive
                TXA                     ;transfer value to A for printing
                STA SCR_POS_TRACK,Y     ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)
                STA R_TRCK,Y            ;
                RTS                     ;

R_SECTOR        JSR CONV_HEX2DEC        ;
                STA SCR_POS_SECTOR+1,Y  ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)
                STA R_SECT+1,Y          ;also modify/update the string, holding the sector value, that is send to the drive
                TXA                     ;transfer value to A for printing
                STA SCR_POS_SECTOR,Y    ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)
                STA R_SECT,Y            ;
                RTS                     ;

;-------------------------------------------------------------------------------
W_TRACK         JSR CONV_HEX2DEC        ;
                STA SCR_POS_TRACK+1,Y   ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)
                STA W_TRCK+1,Y          ;also modify/update the string, holding the track value,  that is send to the drive
                TXA                     ;transfer value to A for printing
                LDY #00                 ;
                STA SCR_POS_TRACK,Y     ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)
                STA W_TRCK,Y            ;
                RTS                     ;

W_SECTOR        JSR CONV_HEX2DEC        ;
                STA SCR_POS_SECTOR+1,Y  ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)
                STA W_SECT+1,Y          ;also modify/update the string, holding the sector value, that is send to the drive
                TXA                     ;transfer value to A for printing
                LDY #00                 ;
                STA SCR_POS_SECTOR,Y    ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)
                STA W_SECT,Y            ;
                RTS                     ;


     ;------------------
;This little routine does a simplified conversion from HEX to a two digit DEC value.
;It convert the value in A, and outputs the 10's in X and the 1's in A

CONV_HEX2DEC    LDY #$2f                ;
                LDX #$3a                ;
                SEC                     ;
D_01            INY                     ;
                SBC #100                ;
                BCS D_01                ;

D_02            DEX                     ;
                ADC #10                 ;
                BMI D_02                ;
        
                ADC #$2f                ;

            LDY #00                 ;we set Y to zero, usefull for the routine that prints the value to screen
                RTS
        ;------------------


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef TYPE_D64

;===============================================================================
;This table describes the number of sectors per track, please keep in mind that
;normal disks consist of only 35 tracks, therefore tracks 36-40 will only apply
;to 40-track images only.
;
; source: http://unusedino.de/ec64/technical/formats/d64.html
;-------------------------------------------------------------------------------
TABLE_MAXSEC
        ;      Track  #Sect  #Sec adr   D64 adr   
        ;      -----  -----  --------   -------   
        BYTE           21;       0       $00000    = track 1  
        BYTE           21;      21       $01500    = track 2  
        BYTE           21;      42       $02A00    = track 3     
        BYTE           21;      63       $03F00    = track 4  
        BYTE           21;      84       $05400    = track 5     
        BYTE           21;     105       $06900    = track 6  
        BYTE           21;     126       $07E00    = track 7     
        BYTE           21;     147       $09300    = track 8     
        BYTE           21;     168       $0A800    = track 9  
        BYTE           21;     189       $0BD00    = track 10     
        BYTE           21;     210       $0D200    = track 11    
        BYTE           21;     231       $0E700    = track 12     
        BYTE           21;     252       $0FC00    = track 13    
        BYTE           21;     273       $11100    = track 14      
        BYTE           21;     294       $12600    = track 15     
        BYTE           21;     315       $13B00    = track 16     
        BYTE           21;     336       $15000    = track 17     
        BYTE           19;     357       $16500    = track 18      
        BYTE           19;     376       $17800    = track 19      
        BYTE           19;     395       $18B00    = track 20      
        BYTE           19;     414       $19E00    = track 21  
        BYTE           19;     433       $1B100    = track 22  
        BYTE           19;     452       $1C400    = track 23  
        BYTE           19;     471       $1D700    = track 24  
        BYTE           18;     490       $1EA00    = track 25  
        BYTE           18;     508       $1FC00    = track 26  
        BYTE           18;     526       $20E00    = track 27  
        BYTE           18;     544       $22000    = track 28  
        BYTE           18;     562       $23200    = track 29  
        BYTE           18;     580       $24400    = track 30  
        BYTE           17;     598       $25600    = track 31  
        BYTE           17;     615       $26700    = track 32  
        BYTE           17;     632       $27800    = track 33  
        BYTE           17;     649       $28900    = track 34  
        BYTE           17;     666       $29A00    = track 35  
        BYTE           17;     683       $2AB00    = track 36  
        BYTE           17;     700       $2BC00    = track 37  
        BYTE           17;     717       $2CD00    = track 38  
        BYTE           17;     734       $2DE00    = track 39  
        BYTE           17;     751       $2EF00    = track 40  

;The number of pixels we have available is 20 characters (the available size of the limitting system, which is a vic20)
;This means that a 100% full progressbar is equal to 20 chars*8pixels = 160 pixels
;a 35track disc, has 683 blocks
;To make fractional number possible, we first multiply by 256 and then discard the least 8 bits afterwards.
;so (160*256)/683 = 59,97 (we round that down to 59) so each block (of a 35 track disc) should increase the counter by that value
TABLE_PP_BLOCK   byte    59
;This unfortunately has an error, of (160*256)-(59*683) = 663 (which is $297), the easiest way to compensate for this error is to increase the bar
;to this value on start, the user doesn't care, only thinks it will be going faster then expected. This is more ensuring then a bar that never reaches the end.
TABLE_PP_BLOCK_EH       byte    $2    ;the highbyte of the error
TABLE_PP_BLOCK_EL       byte    $97   ;the low byte of the error

;so (160*256)/767 = 53,40 (we round that down to 53) so each block (of a 40 track disc) should increase the counter by that value
;TABLE_PP_BLOCK_40T   byte    53


;-------------------------------------------------------------------------------
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef TYPE_D81
;-------------------------------------------------------------------------------
;===============================================================================
;This table describes the number of sectors per track, please keep in mind that
;normal disks consist of only 35 tracks, therefore tracks 36-40 will only apply
;to 40-track images only.
;
; source: http://unusedino.de/ec64/technical/formats/d64.html
;-------------------------------------------------------------------------------
TABLE_MAXSEC
             ;Track #Sect #SectorsIn D81 Offset 
             ;----- ----- ---------- ---------- 
        BYTE          40;       0       $00000   = track 1
        BYTE          40;      40       $02800   = track 2
        BYTE          40;      80       $05000   = track 3
        BYTE          40;     120       $07800   = track 4
        BYTE          40;     160       $0A000   = track 5
        BYTE          40;     200       $0C800   = track 6
        BYTE          40;     240       $0F000   = track 7
        BYTE          40;     280       $11800   = track 8
        BYTE          40;     320       $14000   = track 9
        BYTE          40;     360       $16800   = track 10
        BYTE          40;     400       $19000   = track 11
        BYTE          40;     440       $1B800   = track 12
        BYTE          40;     480       $1E000   = track 13
        BYTE          40;     520       $20800   = track 14
        BYTE          40;     560       $23000   = track 15
        BYTE          40;     600       $25800   = track 16
        BYTE          40;     640       $28000   = track 17
        BYTE          40;     680       $2A800   = track 18
        BYTE          40;     720       $2D000   = track 19
        BYTE          40;     760       $2F800   = track 20
        BYTE          40;     800       $32000   = track 21
        BYTE          40;     840       $34800   = track 22
        BYTE          40;     880       $37000   = track 23
        BYTE          40;     920       $39800   = track 24
        BYTE          40;     960       $3C000   = track 25
        BYTE          40;    1000       $3E800   = track 26
        BYTE          40;    1040       $41000   = track 27
        BYTE          40;    1080       $43800   = track 28
        BYTE          40;    1120       $46000   = track 29
        BYTE          40;    1160       $48800   = track 30
        BYTE          40;    1200       $4B000   = track 31
        BYTE          40;    1240       $4D800   = track 32
        BYTE          40;    1280       $50000   = track 33
        BYTE          40;    1320       $52800   = track 34
        BYTE          40;    1360       $55000   = track 35
        BYTE          40;    1400       $57800   = track 36
        BYTE          40;    1440       $5A000   = track 37
        BYTE          40;    1480       $5C800   = track 38
        BYTE          40;    1520       $5F000   = track 39
        BYTE          40;    1560       $61800   = track 40
        BYTE          40;    1600       $64000   = track 41
        BYTE          40;    1640       $66800   = track 42
        BYTE          40;    1680       $69000   = track 43
        BYTE          40;    1720       $6B800   = track 44
        BYTE          40;    1760       $6E000   = track 45
        BYTE          40;    1800       $70800   = track 46
        BYTE          40;    1840       $73000   = track 47
        BYTE          40;    1880       $75800   = track 48
        BYTE          40;    1920       $78000   = track 49
        BYTE          40;    1960       $7A800   = track 50
        BYTE          40;    2000       $7D000   = track 51
        BYTE          40;    2040       $7F800   = track 52
        BYTE          40;    2080       $82000   = track 53
        BYTE          40;    2120       $84800   = track 54
        BYTE          40;    2160       $87000   = track 55
        BYTE          40;    2200       $89800   = track 56
        BYTE          40;    2240       $8C000   = track 57
        BYTE          40;    2280       $8E800   = track 58
        BYTE          40;    2320       $91000   = track 59
        BYTE          40;    2360       $93800   = track 60
        BYTE          40;    2400       $96000   = track 61
        BYTE          40;    2440       $98800   = track 62
        BYTE          40;    2480       $9B000   = track 63
        BYTE          40;    2520       $9D800   = track 64
        BYTE          40;    2560       $A0000   = track 65
        BYTE          40;    2600       $A2B00   = track 66
        BYTE          40;    2640       $A5000   = track 67
        BYTE          40;    2680       $A7800   = track 68
        BYTE          40;    2720       $AA000   = track 69
        BYTE          40;    2760       $AC800   = track 70
        BYTE          40;    2800       $AF000   = track 71
        BYTE          40;    2840       $B1800   = track 72
        BYTE          40;    2880       $B4000   = track 73
        BYTE          40;    2920       $B6800   = track 74
        BYTE          40;    2960       $B9000   = track 75
        BYTE          40;    3000       $BB800   = track 76
        BYTE          40;    3040       $BE000   = track 77
        BYTE          40;    3080       $C0800   = track 78
        BYTE          40;    3120       $C3000   = track 79
        BYTE          40;    3160       $C5800   = track 80

;The number of pixels we have available is 20 characters (the available size of the limitting system, which is a vic20)
;This means that a 100% full progressbar is equal to 20 chars*8pixels = 160 pixels
;an 80track disc, has 3200 blocks
;To make fractional number possible, we first multiply by 256 and then discard the least 8 bits afterwards.
;so (160*256)/3200 = 12,8 (we round that down to 12) so each block (of a 80 track disc) should increase the counter by that value
TABLE_PP_BLOCK   byte    12
;This unfortunately has an error, of (160*256)-(12*3200) = 2560 (which is $A00), the easiest way to compensate for this error is to increase the bar
;to this value on start, the user doesn't care, only thinks it will be going faster then expected. This is more ensuring then a bar that never reaches the end.
TABLE_PP_BLOCK_EH       byte    $A    ;the highbyte of the error
TABLE_PP_BLOCK_EL       byte    $0    ;the low byte of the error

;-------------------------------------------------------------------------------
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


;Now there is one problem, due to the inaccuracy, the bar will never reach 100%, so it seems to finish early, but this will be too short to notice in most cases

;-------------------------------------------------------------------------------
;these tables are for the kernal routines to communicate with the drive

cname           BYTE $23                ; $23 = #
cname_end       BYTE 0                  ;end of table marker

brcmd           BYTE $55                ; $55 = U
                BYTE $31                ; $31 = 1
                BYTE $20                ; $20 = SPACE
                BYTE $32                ; $31 = 2
                BYTE $20                ; $20 = SPACE
                BYTE $30                ; $31 = 0
                BYTE $20                ; $20 = SPACE
R_TRCK          BYTE $31                ; $31 = 1
                BYTE $38                ; $31 = 8
                BYTE $20                ; $20 = SPACE
R_SECT          BYTE $30                ; $30 = 0
                BYTE $31                ; $31 = 1
brcmd_end       BYTE 0                  ;end of table marker

bpcmd           BYTE $42                ; $42 = B
                BYTE $2D                ; $45 = -
                BYTE $50                ; $50 = P
                BYTE $20                ; $20 = SPACE
                BYTE $32                ; $31 = 2
                BYTE $20                ; $20 = SPACE
                BYTE $30                ; $31 = 0
bpcmd_end       BYTE 0                  ;end of table marker

bwcmd           BYTE $55                ; $55 = U
                BYTE $32                ; $32 = 2
                BYTE $20                ; $20 = SPACE
                BYTE $32                ; $31 = 2
                BYTE $20                ; $20 = SPACE
                BYTE $30                ; $31 = 0
                BYTE $20                ; $20 = SPACE
W_TRCK          BYTE $31                ; $31 = 1
                BYTE $38                ; $31 = 8
                BYTE $20                ; $20 = SPACE
W_SECT          BYTE $30                ; $30 = 0
                BYTE $31                ; $31 = 1
                BYTE $0D                ;carriage return, required to start command
bwcmd_end       BYTE 0                  ;end of table marker


;-------------------------------------------------------------------------------
;simple routine to save a few lines of code
;example:       JSR NEW_SCREEN          ;clear screen and set cursor to topleft
;...............................................................................
NEW_SCREEN      JSR CLEAR_SCREEN        ;clear screen before printing a whole new (or partially new) screen
                LDX #0                  ;set cursor to top left of screen
                LDY #0                  ;before we start to print
                JSR SET_CURSOR          ;
                RTS                     ;

;-------------------------------------------------------------------------------
; convert ascii to petscii
;(the keyboard gives out ASCII but the screen can't print these directly)
;-------------------------------------------------------------------------------

CONVERT_TO_SCREENCODES
        AND #%01111111                          ;only use the lowest 7 bits
        TAY                                     ;copy value in ACCU to Y (we use it as the index in our conversion table)
        LDA ASCII_TO_SCREENDISPLAYCODE_SET1,Y   ;in order to get the smoothest bar
        RTS                                     ;return with the coneverted value

        ;the table below converts an ASCII value to the SCREEN DISPLAY CODE (Prog ref guide page 376)
        ;make sure that you are displaying in set-1 (you can toggle between set by pressing shift+commodore on your C64)
        ;we need this table in order to display the filenames which are in ASCII (otherwise the PC needs to convert to PETSCII, which makes no sense as ASCII is the one and only real standard)
ASCII_TO_SCREENDISPLAYCODE_SET1
        ;this table is most likely not perfect... under construction!!!         (this table uses the INDEX values of the charset)
    BYTE $20,$81,$82,$83,$84,$85,$86,$87,$88,$89,$8a,$8b,$8c,$8d,$8e,$8f
    BYTE $90,$91,$92,$93,$94,$95,$96,$97,$98,$99,$9a,$9b,$9c,$9d,$9e,$9f
    BYTE $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2e,$2f
    BYTE $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3a,$3b,$3c,$3d,$3e,$3f
    BYTE $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f
    BYTE $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1d,$1e,$46
    BYTE $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f
    BYTE $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1d,$1e,$1f

;===============================================================================
;  
;                                V A R I A B L E S 
;
;===============================================================================
;a small list of variables that do not require storage in the zero-page

CNT_BYTE        BYTE $0         ;
TABLE_PNTR      BYTE $0         ;
TRACK           BYTE $0         ;
SECTOR          BYTE $0         ;


;base of path is determined by the computermodel
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODOREPET20XX
STR_MEM         TEXT "pet20xx/" ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODOREPET30XX
STR_MEM         TEXT "pet30xx/" ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODOREPET40XX
STR_MEM         TEXT "pet40xx/" ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODOREPET80XX
STR_MEM         TEXT "pet80xx/" ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODOREVIC20
STR_MEM         TEXT "vic20/" ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODORE64
STR_MEM         TEXT "c64/"   ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODORE128
STR_MEM         TEXT "c128/"  ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODORE16
STR_MEM         TEXT "c16/"  ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODOREPLUS4
STR_MEM         TEXT "plus4/"  ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


;file folder and file extension are determined by the image type
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef TYPE_D64
                TEXT "d64/d001.d64"   ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
                BYTE $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0  ;some addtional bytes to allign it all properly in memory

TRACK_MAX               BYTE 35         ;35 tracks
FILE_SIZE_02_EXPECTED   BYTE $02        ;$02 for 35T disks without errors, $02 for 35T disks with errors
;FILE_SIZE_02_EXPECTED  BYTE $03        ;$03 for 40T disks                
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef TYPE_D81
                TEXT "d81/d001.d81"   ;filename or to be more precise, the filepath for the image file as stored on the Cassiopei SD-card
                BYTE $0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0  ;some addtional bytes to allign it all properly in memory

TRACK_MAX               BYTE 80         ;80 tracks
FILE_SIZE_02_EXPECTED   BYTE $0C        ;this value is $0C for 80T disks without errors, $0C for 80T disks with errors
endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


SECTOR_MAX              BYTE $0         ;

BROWSE_ACTION           BYTE $0         ;
BROWSE_STATUS           BYTE $0         ;
BROWSE_CURX             BYTE $0         ;
BROWSE_CURY             BYTE $0         ;
BROWSE_MAXX             BYTE $0         ;
BROWSE_MAXY             BYTE $0         ;

STR_POS                 BYTE $0         ;the position in the string


FILE_OPEN_STATUS        BYTE $0         ;the response to the fileopen request
FILE_SIZE_03            BYTE $0         ;the MSB of the 4 byte filesize value
FILE_SIZE_02            BYTE $0
FILE_SIZE_01            BYTE $0
FILE_SIZE_00            BYTE $0
