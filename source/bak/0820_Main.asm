*=$0820 ;start address      ;by keeping the start adress close to the basic line, we keep the compiled program small. This because the "gap" between the basic line and the assembly code is filled with padding bytes.
               

INIT            JSR PREVENT_CASE_CHANGE ;prevent the user from using shift+CBM to change the case into lower or upper case
                JSR SPLASH_SCREEN       ;show a splash screen with version info (perhaps with an animation)
               
                JSR CPIO_INIT           ;initialize IO for use of CPIO protocol on the CBM's cassetteport
                JSR MENU_RESET          ;force the cassiopei menu to a default state

;. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

MAIN_MENU       LDX #0                  ;build the screen
                LDY #0                  ;
                JSR SET_CURSOR          ;
                LDA #<SCREEN_MENU       ;set pointer to the text that defines the main-screen
                LDY #>SCREEN_MENU       ;
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen         

                JSR MENU_REFRESH        ;get the current available menu screen and print it to the screen

SCAN_USER_INPUT LDA MENU_STATUS         ;check if we should exit
                CMP #MENU_EXIT          ;exit menu, but do not save or use the current settings
                BEQ EXECUTE_EXIT        ;

                JSR SCAN_INPUTS         ;check keyboard and/ joysticks (if applicable)
                CMP #USER_INPUT_SELECT  ;and jump to the requested action
                BEQ EXECUTE_SELECT      ;
                CMP #USER_INPUT_PREVIOUS;
                BEQ EXECUTE_PREV        ;
                CMP #USER_INPUT_NEXT    ;
                BEQ EXECUTE_NEXT        ;

                JMP SCAN_USER_INPUT     ;when the pressed key has no function then continue the key scanning

;. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

EXECUTE_SELECT  JSR MENU_SELECT         ;
                JMP SCAN_USER_INPUT     ;

EXECUTE_PREV    JSR MENU_PREVIOUS       ;
                JMP SCAN_USER_INPUT     ;

EXECUTE_NEXT    JSR MENU_NEXT           ;
                JMP SCAN_USER_INPUT     ;

EXECUTE_PLAY    ;start playback of the selected file

                LDA #1                  ;0=black
                STA BORDER              ;
                LDA #0
                STA BACKGROUND          ;

                LDA #1                  ;
                STA COL_PRINT           ;

                JSR CLEAR_SCREEN        ;

                JSR CPIO_INIT           ;initialize IO for use of CPIO protocol on the CBM cassetteport
                JSR PLAY_VQ_ANIM        ;play the animation/video
                JMP SCAN_USER_INPUT     ;
                RTS                     ;

;===============================================================================
;                             - = SUBROUTINES = -
;===============================================================================

;-------------------------------------------------------------------------------
;Call the corresponding menu function below and it will be printed to the screen
;-------------------------------------------------------------------------------

MENU_REFRESH    LDA #CPIO_MENU_REFRESH  ;Refresh: will only get the menu information from the Cassiopei's screen buffer
                STA MENU_ACTION         ;store the menu action to memory
                JMP MENU_00             ;

MENU_PREVIOUS   LDA #CPIO_MENU_PREVIOUS ;Previous: will perform a previous action in the menu, scolling the items down (or moving the indicator up)
                STA MENU_ACTION         ;store the menu action to memory
                JMP MENU_00             ;

MENU_SELECT     LDA #CPIO_MENU_SELECT   ;Select: will perform a selection of the currently selected menu item
                STA MENU_ACTION         ;store the menu action to memory
                JMP MENU_00             ;

MENU_NEXT       LDA #CPIO_MENU_NEXT     ;Next: will perform a next action in the menu, scolling the items up (or moving the indicator down)
                STA MENU_ACTION         ;store the menu action to memory
                JMP MENU_00             ;

MENU_RESET      LDA #CPIO_MENU_RESET    ;Reset the menu, forcing it to the beginning state
                STA MENU_ACTION         ;store the menu action to memory
                LDA #CPIO_MENU          ;send directory read command
                JSR CPIO_START          ;
                LDA MENU_ACTION         ;get the menu action from memory                
                JSR CPIO_SEND           ;send the menu action to the Cassiopei
                LDA #WINDOW_X_SIZE      ;send the size of the visble screen area
                JSR CPIO_SEND           ;on the CBM computer
                LDA #WINDOW_Y_SIZE      ;
                JSR CPIO_SEND           ;
                JSR CPIO_REC_LAST       ;get the menu status byte
                STA MENU_STATUS         ;the status byte indicates wheter or not the menu is still active, because the user might have select exit
                CLI                     ;CPIO communication has disabled interrupts, so we must enable interrupts again. Otherwise the keyboard is not scanned etc.
                RTS                     ;

;...............................................................................

MENU_00         LDA #WINDOW_X_POS       ;the location of the first character of the info on the screen
                STA MENU_CURX           ;
                LDA #WINDOW_Y_POS       ;
                STA MENU_CURY           ;

                LDA #WINDOW_Y_SIZE      ;the number of characters we will (may) display on a single line
                STA MENU_MAXY           ;
                LDA #CPIO_MENU          ;send directory read command
                JSR CPIO_START          ;
                LDA MENU_ACTION         ;get the menu action from memory
                JSR CPIO_SEND           ;send the menu action to the Cassiopei
                LDA #WINDOW_X_SIZE      ;send the size of the visble screen area
                JSR CPIO_SEND           ;on the CBM computer
                LDA #WINDOW_Y_SIZE      ;
                JSR CPIO_SEND           ;
                JSR CPIO_RECIEVE        ;get the menu status byte
                STA MENU_STATUS         ;the status byte indicates whether or not the menu is still active, because the user might have select exit

MENU_03         LDA #WINDOW_X_SIZE      ;the max length of a file name
                STA MENU_MAXX           ;
                LDX MENU_CURX           ;
                LDY MENU_CURY           ;
                JSR SET_CURSOR          ;

MENU_04         LDA MENU_MAXX           ;check if this is the last byte that should be drawn on this line
                CMP #1                  ;
                BEQ MENU_05             ;
                JSR CPIO_RECIEVE        ;get byte from Cassiopei containing the screen data
                JMP MENU_07             ;
MENU_05         LDA MENU_MAXY           ;check if this REALLY is the last byte we will be reading (regarding this command)
                CMP #1                  ;
                BEQ MENU_06             ;
                JSR CPIO_RECIEVE        ;get byte from Cassiopei containing the screen data
                JMP MENU_07             ;
MENU_06         JSR CPIO_REC_LAST       ;just a dummy read

MENU_07         JSR PRINT_CHAR          ;character is printed to screen, cursor is incremented by one
                DEC MENU_MAXX           ;keep looping untill we have processed the full width of the text area
                BNE MENU_04             ;

MENU_08         INC MENU_CURY           ;the next entry will be written on the next line in the directory text area
                DEC MENU_MAXY           ;keep looping untill we have processed the full length of the text area
                BNE MENU_03             ;
                
MENU_END        CLI                     ;CPIO communication has disabled interrupts, so we must enable interrupts again. Otherwise the keyboard is not scanned etc.
                RTS                     ;


MENU_ACTION     BYTE $0 ;
MENU_STATUS     BYTE $0 ;
MENU_CURX       BYTE $0 ;
MENU_CURY       BYTE $0 ;
MENU_MAXX       BYTE $0 ;
MENU_MAXY       BYTE $0 ;


;-------------------------------------------------------------------------------

CLEAR_SCREEN    LDY #0                  ;
                LDA #$01                ;
CLEAR_SC_01     STA COLORSCREEN+750,Y   ;
                STA COLORSCREEN+500,Y   ;
                STA COLORSCREEN+250,Y   ;
                STA COLORSCREEN+0,Y     ;
                INY                     ;
                CPY #250                ;
                BNE CLEAR_SC_01         ;


;-------------------------------------------------------------------------------
;call this routine as described below:
;
;               LDA #character          ;character is stored in Accumulator
;               JSR PRINT_CHAR          ;character is printed to screen, cursor is incremented by one
; also affects Y
; note: when the character value is 0 there is nothing printed but we do increment the cursor by one
;-------------------------------------------------------------------------------
PRINT_CHAR      BEQ PRINT_NOTHING       ;when the value = 0, we print nothing but we do increment the cursor by one
                LDY #00                 ;
                STA (CHAR_ADDR),Y       ;character read from string (stored in A) is now written to screen memory (see C64 manual appendix E for screen display codes)
                LDA COL_PRINT           ;
                STA (COLOR_ADDR),Y      ;write colorvalue to the corresponding color memory location

                ;increment character pointer
PRINT_NOTHING   CLC                     ;
                LDA #$01                ;add 1
                ADC CHAR_ADDR           ;                        
                STA CHAR_ADDR           ;
                LDA #$00                ;
                ADC CHAR_ADDR+1         ;add carry... and viola, we have a new cursor position (memory location where next character will be printed)
                STA CHAR_ADDR+1         ;

                ;also increment color memory pointer
                CLC                     ;
                LDA #$01                ;add 1
                ADC COLOR_ADDR          ;                        
                STA COLOR_ADDR          ;
                LDA #$00                ;
                ADC COLOR_ADDR+1        ;add carry... and viola, we have a new cursor position (memory location where next character will be printed)
                STA COLOR_ADDR+1        ;

                RTS                     ;      
              
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
;-------------------------------------------------------------------------------
;call this routine as described below:
;
;        LDA #<label                ;set pointer to the text that defines the main-screen
;        LDY #>label                ;
;        JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen
;
; JSR PRINT_CUR_STR ;print the string as indicated by the current string pointer
;-------------------------------------------------------------------------------
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
;        LDA #<label                ;set pointer to the text that defines the main-screen
;        LDY #>label                ;
;        JSR PRINT_ASCII_STRING     ;the print routine is called, so the pointed text is now printed to screen
;Only use this routine to print filenames for example, because these are required to be in ASCII because of the SD-card which requires ASCII
;-------------------------------------------------------------------------------
PRINT_ASCII_STRING
                STA STR_ADDR                    ;
                STY STR_ADDR+1                  ;
PRINT_ASCII     LDY #$00                        ;
                LDA (STR_ADDR),Y                ;read character from string
                BEQ PRINT_ASCII_END             ;when the character was 0, then the end of string marker was detected and we must exit

                JSR CONVERT_TO_SCREENCODES      ;convert ASCII to screencodes otherwise it looks like #@#$@$#
                JSR PRINT_CHAR                  ;print char to screen
                                     
                CLC                     ;
                LDA #$01                ;add 1
                ADC STR_ADDR            ;
                STA STR_ADDR            ;string address pointer
                LDA #$00                ;
                ADC STR_ADDR+1          ;add carry...
                STA STR_ADDR+1          ;                            

                JMP PRINT_ASCII         ;repeat...

PRINT_ASCII_END RTS                     ;

;-------------------------------------------------------------------------------
; convert ascii to petscii
;-------------------------------------------------------------------------------

CONVERT_TO_SCREENCODES
        AND #%01111111                          ;only use the lowest 7 bits
        TAY                                     ;copy value in ACCU to Y (we use it as the index in our conversion table)
        LDA ASCII_TO_SCREENDISPLAYCODE_SET1,Y   ;in order to get the smoothest bar
        RTS                                     ;return with the coneverted value

        ;the table below converts an ASCII value to the SCREEN DISPLAY CODE (Prog ref guide page 376)
        ;make sure that you are displaying in set-1 (you can toggle between set by pressing shift+commodore on your C64)
        ;we need this table in order to display the filenames which are in ASCII

ASCII_TO_SCREENDISPLAYCODE_SET1
        ;this table is most likely not perfect... under construction!!!         (this table uses the INDEX values of the charset)
    BYTE $80,$81,$82,$83,$84,$85,$86,$87,$88,$89,$8a,$8b,$8c,$8d,$8e,$8f
    BYTE $90,$91,$92,$93,$94,$95,$96,$97,$98,$99,$9a,$9b,$9c,$9d,$9e,$9f
    BYTE $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2a,$2b,$2c,$2d,$2e,$2f
    BYTE $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3a,$3b,$3c,$3d,$3e,$3f
    BYTE $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f
    BYTE $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1d,$1e,$46
    BYTE $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f
    BYTE $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$1b,$1c,$1d,$1e,$1f

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
;CHARSCREEN = $0400 (default char screen loc.) is the first visible char location within this program 
;the first location is defined as coordinate 0,0 (which makes life so much easier)

SET_CURSOR      LDA #<CHARSCREEN        ;
                STA CHAR_ADDR           ;store base address (low byte)
                LDA #>CHARSCREEN        ;
                STA CHAR_ADDR+1         ;store base address (high byte)

                LDA #<COLORSCREEN       ;
                STA COLOR_ADDR          ;store base address (low byte)
                LDA #>COLORSCREEN       ;
                STA COLOR_ADDR+1        ;store base address (high byte)

                ;calculate exact value based on the requested X and Y coordinate
                CLC                     ;
                TXA                     ;add  value in X register (to calculate the new X position of cursor)
                ADC CHAR_ADDR           ;                        
                STA CHAR_ADDR           ;
                LDA #$00                ;
                ADC CHAR_ADDR+1         ;add carry
                STA CHAR_ADDR+1         ;

                CLC                     ;
                TXA                     ;add  value in X register (to calculate the new X position of cursorcolor)
                ADC COLOR_ADDR          ;                        
                STA COLOR_ADDR          ;
                LDA #$00                ;
                ADC COLOR_ADDR+1        ;add carry
                STA COLOR_ADDR+1        ;

                TYA                     ;save Y for next calc
                PHA                     ;
SET_CURS_CHR_LP CPY #00                 ;
                BEQ SET_CURS_COL        ;when Y is zero, calculation is done

                CLC                     ;
                LDA #40                 ;add  40 (which is the number of characters per line) to calculate the new Y position of cursor
                ADC CHAR_ADDR           ;                        
                STA CHAR_ADDR           ;
                LDA #$00                ;
                ADC CHAR_ADDR+1         ;add carry... and viola, we have a new cursor position (memory location where next character will be printed)
                STA CHAR_ADDR+1         ;
                DEY                     ;
                JMP SET_CURS_CHR_LP     ;


SET_CURS_COL    PLA                     ;
                TAY                     ;restore Y for calc
SET_CURS_COL_LP CPY #00                 ;
                BEQ SET_CURS_END        ;when Y is zero calculation is done

                CLC                     ;
                LDA #40                 ;add  40 (which is the number of characters per line) to calculate the new Y position of cursor
                ADC COLOR_ADDR          ;                        
                STA COLOR_ADDR          ;
                LDA #$00                ;
                ADC COLOR_ADDR+1        ;add carry... and viola, we have a new cursor position (memory location where next character will be printed)
                STA COLOR_ADDR+1        ;
                DEY                     ;
                JMP SET_CURS_COL_LP     ;
SET_CURS_END    RTS                     ;
  
;===============================================================================
;  
;                                V A R I A B L E S 
;
;===============================================================================
;a small list of variables that do not require storage in the zero-page

FILETYPE        BYTE $00        ;the filetype indicator
NMBR_OF_FRAMES  BYTE $00        ;a variable to store the number of frames (low byte)
                BYTE $00        ;a variable to store the number of frames (high byte)
X_SIZE          BYTE $00        ;the width of the screen in chars
Y_SIZE          BYTE $00        ;the height of the screen in charset_init
MODE_BYTE       BYTE $00        ;the mode the encoded image uses
CODEBOOKSIZE    BYTE $00        ;reserved for future use        
RESERVED_01     BYTE $00        ;reserved for future use
RESERVED_02     BYTE $00        ;reserved for future use
RESERVED_03     BYTE $00        ;reserved for future use        
RESERVED_04     BYTE $00        ;reserved for future use

;FILENAME        ;Filename must be specified in ASCII characters, because the SD-card or to be more precise... THE WHOLE MODERN WORLD!!! uses ASCII
;                ;make sure that the filename is fully specified! Supported characters are:
;                ; 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()-+<>,.?
;                ; the / character is to used for entering (sub)directories
;                ; using other characters then above will lead to a file-not-found situation

;                ;the ' -character surrounding the string indicates that it will be using the PETSCII- or SCREEN-codes (DO NOT USE THAT HERE!!!)
;                ;the " -character surrounding the string indicates that it will be using the ASCII-codes (which usually do not properly display as they (non-numerical characters) differ from screencodes)*/
;                ;Attention: only use lower case characters, they will result in uppercase characters on the receiving end!!
;                ;fortunately the cassiopei itself isn't case sensitive and will load independent of the casetype

;                ;TEXT "normal.dat"
;                ;TEXT "delta.dat"
;                ;TEXT "animatie.dat"
;                TEXT "amiga-tribute.dat"
;                BYTE 0
