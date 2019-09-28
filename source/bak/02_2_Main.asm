;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODOREVIC20
;-------------------------------------------------------------------------------

SCNKEY          = $FF9F ;scans the keyboard and puts the matrix value in $C5
CHROUT          = $FFD2 ;

KEYCNT          = 198           ;the counter that keeps track of the number of key in the keyboard buffer       VIC-20
KEYBUF          = 631           ;the first position of the keyboard buffer                                      VIC-20
CURSORPOS_X     = 198           ;Cursor Column on Current Line                                                  PET/CBM (Upgrade and 4.0 BASIC)
CURSORPOS_Y     = 216           ;Current Cursor Physical Line Number                                            PET/CBM (Upgrade and 4.0 BASIC)

TODCLK          = $8D           ;Time-Of-Day clock register (MSB) BASIC>1 uses locations 141-143 ($8D-$8F)
;TODCLK+1       = $8E           ;Time-Of-Day clock register (.SB)
;TODCLK+2       = $8F           ;Time-Of-Day clock register (LSB)


;###############################################################################

;-- keycodes -- (VIC20 keyboard scanning values)

KEY_NOTHING     = $40           ;$40 = matrix value when no key is pressed
KEY_F1          = $27           ;$27 = F1
KEY_F3          = $2F           ;$2F = F3
KEY_F5          = $37           ;$37 = F5
KEY_F7          = $3F           ;$3F = F7

KEY_RETURN      = $0F           ;$0F = RETURN
KEY_1           = $0            ;$00 = 1 
KEY_2           = $38           ;$38 = 2
KEY_C           = $22           ;$22 = C
KEY_D           = $12           ;$12 = D
KEY_E           = $31           ;$31 = E
KEY_F           = $2A           ;$2A = F
KEY_N           = $1C           ;$1C = N
KEY_T           = $32           ;$32 = T
KEY_V           = $1B           ;$1B = V
KEY_Y           = $0B           ;$0B = Y
KEY_ESC         = $18           ;$18 = <-- (the key that is on the top left of the C64 keyboard (next to the '1'-key and above the 'control'-key))

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;the list below, showing keyboard scancodes, was taken from:
;http://www.zimmers.net/cbmpics/cbm/vic/memorymap.txt
;...............................................................
;#  key          #  key          #  key          #  key
;0  1            16 none         32 space        48 Q
;1  3            17 A            33 Z            49 E
;2  5            18 D            34 C            50 T
;3  7            19 G            35 B            51 U
;4  9            20 J            36 M            52 O
;5  +            21 L            37 .            53 @
;6  £ (pound)    22 ;            38 none         54 ^ (up arrow)
;7  DEL          23 crsr lt/rt   39 f1           55 f5
;8  <-           24 STOP         40 none         56 2
;9  W            25 none         41 S            57 4
;10 R            26 X            42 F            58 6
;11 Y            27 V            43 H            59 8
;12 I            28 N            44 K            60 0
;13 P            29 ,            45 :            61 -
;14 *            30 /            46 =            62 HOME
;15 RETURN       31 crsr up/dn   47 f3           63 f7
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;-------------------------------------------------------------------------------
;Read the keyboard, this routine converts the keycode to a control
;code that is easier to decode. This value is stored in A

;unfortunately the VIC20 keyboard does not always produce reliable results,
;therefore the matrix value is used with a simple consistency check algorithm
;that will filter out erronous values.
;...............................................................................
SCAN_INPUTS     LDA ALLOW_KEYREPEAT     ;some functions/keys have keyrepeat, this makes it easier to scroll
                BNE SCAN_KEYPRESS       ;through a long list of filenames

SCAN_KEYRELEASE JSR $EB1E               ;use kernal routine to scan VIC20 keyboard
                LDA $CB                 ;
                CMP #KEY_NOTHING        ;check for the "no key pressed" situation
                BNE SCAN_KEYRELEASE     ;when the keyboard isn't released, we may asume that the user is still pressing the same key, perhaps so we repeat the input (and by that we create key repeat functionality)

SCAN_KEYPRESS   LDA #8                  ;number of times the matrix value should be the same in order to detect a key as valid
                STA DEBOUNCE_CNT        ;
                JSR $EB1E               ;use kernal routine to scan VIC20 keyboard
                LDA $CB                 ;current matrix value
                STA DEBOUNCE_CURRENT    ;save current value
                CMP #KEY_NOTHING        ;check for the "no key pressed" situation
                BEQ SCAN_VAL_IDLE       ;no keyboard action

SCAN_KEY_LP     JSR $EB1E               ;use kernal routine to scan VIC20 keyboard
                LDA $CB                 ;current matrix value, compare this to the previous
                CMP DEBOUNCE_CURRENT    ;value, if this value stays the same for .. time in a row
                BNE SCAN_VAL_IDLE       ;then it must be correct and we may process that value
                DEC DEBOUNCE_CNT        ;
                LDA DEBOUNCE_CNT        ;
                BNE SCAN_KEY_LP         ;keep looping until counter reaches 0

                LDA DEBOUNCE_CURRENT    ;check if the current key value is one of the keys we are interested in
                CMP #KEY_F3             ;
                BEQ SCAN_VAL_PREV       ;
                CMP #KEY_F5             ;
                BEQ SCAN_VAL_SELECT     ;
                CMP #KEY_F7             ;
                BEQ SCAN_VAL_NEXT       ; 
                CMP #KEY_D              ;
                BEQ SCAN_VAL_DIR        ;
                CMP #KEY_C              ;
                BEQ SCAN_VAL_CREATE     ;
                CMP #KEY_ESC            ;
                BEQ SCAN_VAL_EXIT       ;
                CMP #KEY_F              ;
                BEQ SCAN_VAL_FNAME      ;
                CMP #KEY_N              ;
                BEQ SCAN_VAL_NO         ;
                CMP #KEY_Y              ;
                BEQ SCAN_VAL_YES        ;

SCAN_VAL_IDLE   LDA #1                  ;do not allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_IDLE    ;nothing happened, send idle value
                RTS

SCAN_VAL_SELECT LDA #0                  ;do not allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_SELECT  ;
                RTS

SCAN_VAL_PREV   LDA #1                  ;allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_PREVIOUS;
                RTS

SCAN_VAL_NEXT   LDA #1                  ;allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_NEXT    ;
                RTS

SCAN_VAL_CREATE LDA #0                  ;do not allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_CREATE  ;
                RTS

SCAN_VAL_DIR    LDA #0                  ;do not allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_DIR     ;
                RTS

SCAN_VAL_EXIT   LDA #0                  ;do not allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_EXIT    ;
                RTS

SCAN_VAL_FNAME  LDA #0                  ;do not allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_FILENAME;
                RTS

SCAN_VAL_NO     LDA #0                  ;do not allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_NO      ;
                RTS

SCAN_VAL_YES    LDA #0                  ;do not allow keyrepeat on this button
                STA ALLOW_KEYREPEAT     ;
                LDA #USER_INPUT_YES     ;
                RTS


ALLOW_KEYREPEAT         BYTE $0 ;this is a flag that indicates if keyrepeat is allowed (0=key repeat not alowed, 1=key repeat alowed)
DEBOUNCE_CNT            BYTE $0 ;use for debouncing
DEBOUNCE_CURRENT        BYTE $0 ;use for debouncing


;-------------------------------------------------------------------------------
;This routine will have the Z-flag set when no key is pressed
;call example   JSR CHECK_FOR_KEY
;               BNE <jump to wherever because a key was pressed>
;...............................................................................
CHECK_FOR_KEY   JSR SCNKEY              ;scan keyboard
                LDA $C5                 ;matrix value of last Key pressed
                CMP #KEY_NOTHING        ;check for key
                RTS                     ;

;-------------------------------------------------------------------------------
;This routine will wait until the user presses a key (it is a blocking routine)
;call example   JSR WAIT_FOR_KEY
;...............................................................................
WAIT_FOR_KEY    LDA #0                  ;clear keyboard buffer
                STA $C6                 ;by clearing pointer
WAIT_FOR_KEY_01 JSR $EB1E               ;use kernal routine to scan VIC20 keyboard
                LDA $C6                 ;
                BEQ WAIT_FOR_KEY_01     ;
                LDA $0277               ;first loc of keyboard buffer
                RTS                     ;return with ..SCII key value in A

;-------------------------------------------------------------------------------
;This routine will wait until the user releases the keyboard
;call example   WAIT_KEY_RELEASE
;...............................................................................
WAIT_KEY_RELEASE
                JSR CHECK_FOR_KEY       ;
                BNE WAIT_KEY_RELEASE    ;
                RTS                     ;

;-------------------------------------------------------------------------------
;Clear screen and set the color of the colorscreen
;Example:       JSR CLEAR_SCREEN
;...............................................................................
CLEAR_SCREEN    LDA #$08                ;make the screen and border black
                STA $900F               ;

                LDA #5                  ;PRINT CHR$(5) TO SET PRINTING COLOUR TO WHITE (this is the colour used with the KERNAL printing routine)
                JSR CHROUT              ;SCREEN
                LDA #147                ;PRINT CHR$(147) TO CLEAR
                JSR CHROUT              ;SCREEN
                RTS                     ;

;-------------------------------------------------------------------------------
; The first location of the charsecreen (topleft) is defined as coordinate 0,0
; Use this routine before calling a PRINT related routine
;               LDX CURSOR_Y;.. chars from the top of the defined screen area
;               LDY CURSOR_X;.. chars from the left of the defined screen area
;               JSR SET_CURSOR
;...............................................................................

SET_CURSOR      LDA #00                 ;
                STA CHAR_ADDR           ;store base address (low byte)
                LDA $0288               ;the location (high byte) of the screen as determined by the kernal
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
                CLC                     ;clear carry for the upcoming "ADC CHAR_ADDR"

                LDA #22                 ;add  22 (which is the number of characters per line for a VIC20) to calculate the new Y position of cursor
                ADC CHAR_ADDR           ;                        
                STA CHAR_ADDR           ;
                LDA #$00                ;
                ADC CHAR_ADDR+1         ;add carry... and viola, we have a new cursor position (memory location where next character will be printed)
                STA CHAR_ADDR+1         ;
                DEY                     ;
                JMP SET_CURS_CHR_LP     ;

SET_CURS_END    RTS                     ;

;-------------------------------------------------------------------------------
;call this routine as described below:
;
;               LDA #character          ;character is stored in Accumulator
;               JSR PRINT_CHAR          ;character is printed to screen, cursor is incremented by one
; also affects Y
; note: when the character value is 0 there is nothing printed but we do increment the cursor by one
;...............................................................................
PRINT_CHAR      BEQ PRINT_NOTHING       ;when the value = 0, we print nothing but we do increment the cursor by one
                ;CLC
                ;ADC CHAR_INVERT         ;invert character depending on the status of the  CHAR_INVERT-flag
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

;CHAR_INVERT     BYTE $0        ;flag to indicate whether or not the printed character should be inverted

;-------------------------------------------------------------------------------
;Prevent the use of shift+CBM to change the case of the screen.
;This must be prevented when screen are build with special characters.
;Example:       JSR PREVENT_CASE_CHANGE
;...............................................................................                
PREVENT_CASE_CHANGE
                LDA #128                ;disable shift+CBM
                STA $0291               ;

                RTS                     ;

;-------------------------------------------------------------------------------
;Allow the use of shift+CBM to change the case of the screen.
;Example:       JSR ALLOW_CASE_CHANGE
;...............................................................................                
ALLOW_CASE_CHANGE
                LDA #0                  ;enable shift+CBM
                STA $0291               ;
              
                RTS


;-------------------------------------------------------------------------------
;This routine will print extra computer specific information
;Example:       JSR SHOW_VERSION
;...............................................................................
SHOW_VERSION    LDX #0                  ;set cursor to top,left
                LDY #0                  ;
                JSR SET_CURSOR          ;
                LDA #<PRG_IDENTIFIER    ;set pointer to the text that defines the main-screen
                LDY #>PRG_IDENTIFIER    ;        
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen     
               
                LDX #0                  ;set cursor to top,left
                LDY #1                  ;
                JSR SET_CURSOR          ;
                LDA #<VERSION_INFO      ;set pointer to the text that defines the main-screen
                LDY #>VERSION_INFO      ;        
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen     

                RTS

;-------------------------------------------------------------------------------
endif   ;this endif belongs to "ifdef COMMODOREVIC20"
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
