;bug in menu code? or perhaps a C64 feature?: the joystick in PORT-1 might
;trigger a selection when moving wildly with the joystick AND when the last
;item in the list has been selected, the list of items does not need to be
;long, a 4 item list in de TAP file section is enough

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODORE64
;-------------------------------------------------------------------------------
BORDER          = $D020         ;bordercolour
BACKGROUND      = $D021         ;background-0
COLORSCREEN     = $D800         ;location of the color screen memory (this value is fixed)
CHARSCREEN      = $0400         ;location of the character screen memory
SCAN_KEYBOARD   = $FF9F         ;scans the keyboard and puts the matrix value in $C5

KEYCNT          = 198           ;the counter that keeps track of the number of key in the keyboard buffer
KEYBUF          = 631           ;the first position of the keyboard buffer
CURSORPOS_X     = 211           ;Cursor Column on Current Line (be aware that on a C64, position the cursor does not take effect immediately, only when a CR on the keyboard is send it will go there)
CURSORPOS_Y     = 214           ;Current Cursor Physical Line Number

TODCLK          = $A0           ;Time-Of-Day clock register (MSB)
;TODCLK+1       = $A1           ;Time-Of-Day clock register (.SB)
;TODCLK+2       = $A2           ;Time-Of-Day clock register (LSB)

;###############################################################################

;-- keycodes --
KEY_NOTHING     = $40           ;when no key is pressed
KEY_F1          = $04           ;$04 = F1 
KEY_F3          = $05           ;$05 = F3
KEY_F5          = $06           ;$06 = F5 
KEY_F7          = $03           ;$03 = F7
KEY_RETURN      = $01           ;$01 = RETURN
KEY_1           = $38           ;$38 = 1 
KEY_2           = $3B           ;$3B = 2
KEY_C           = $14           ;$14 = C
KEY_D           = $12           ;$12 = D
KEY_E           = $0E           ;$0E = E
KEY_F           = $15           ;$15 = F
KEY_N           = $27           ;$27 = N
KEY_T           = $16           ;$16 = T
KEY_V           = $1F           ;$1F = V
KEY_Y           = $19           ;$19 = Y
KEY_ESC         = $39           ;$39 = <-- (the key that is on the top left of the C64 keyboard (next to the '1'-key and above the 'control'-key))

;-------------------------------------------------------------------------------
;Read the keyboard, this routine converts the keycode to a control
;code that is easier to decode. This value is stored in A
;...............................................................................
SCAN_INPUTS     LDA ALLOW_KEYREPEAT     ;some functions/keys have keyrepeat, this makes it easier to scroll
                BNE SCAN_KEYPRESS       ;through a long list of filenames

SCAN_KEYRELEASE ;JSR SCAN_KEYBOARD       ;this line is only required when the interrups are switched off
                LDA $C5                 ;matrix value of last Key pressed
                CMP #KEY_NOTHING        ;check for key
                BNE SCAN_KEYRELEASE     ;continue loop when no key is detected
SCAN_KEYPRESS   JSR SCAN_KEYBOARD       ;because the interrupts are disabled during communication with the Cassiopei, the keyboard might not be updated and therefore the buffer value remains the same, which in real life is not correct, so we execute a manual keyboard scan
                LDA $C5                 ;matrix value of last Key pressed
                CMP #KEY_F3             ;and jump to the requested action
                BEQ SCAN_VAL_PREV       ;
                CMP #KEY_F5             ;
                BEQ SCAN_VAL_SELECT     ;
                CMP #KEY_F7             ;
                BEQ SCAN_VAL_NEXT       ; 
                CMP #KEY_D              ;
                BEQ SCAN_VAL_DIR        ;
                CMP #KEY_C              ;
                BEQ SCAN_VAL_CREATE
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


ALLOW_KEYREPEAT BYTE $0 ;this is a flag that indicates if keyrepeat is allowed (0=key repeat not alowed, 1=key repeat alowed)


;-------------------------------------------------------------------------------
;This routine will have the Z-flag set when no key is pressed
;call example   JSR CHECK_FOR_KEY
;               BNE <jump to wherever because a key was pressed>
;...............................................................................
CHECK_FOR_KEY   JSR SCAN_KEYBOARD       ;scan keyboard
                LDA $C5                 ;matrix value of last Key pressed
                CMP #KEY_NOTHING        ;check for key
                RTS                     ;

;-------------------------------------------------------------------------------
;This routine will wait until the user presses a key
;call example   JSR WAIT_FOR_KEY
;               key value in A
;...............................................................................
WAIT_FOR_KEY    LDA #0                  ;clear keyboard buffer
                STA KEYCNT              ;
WAIT_FOR_KEY_01 JSR SCAN_KEYBOARD       ;because the interrupts are disabled during communication with the Cassiopei, the keyboard might not be updated and therefore the buffer value remains the same, which in real life is not correct, so we execute a manual keyboard scan
                LDA $C5                 ;matrix value of last Key pressed
                CMP #KEY_NOTHING        ;check for key
                BEQ WAIT_FOR_KEY_01     ;continue loop when no key is detected
                LDA KEYBUF              ;
                RTS                     ;

;-------------------------------------------------------------------------------
;This routine will wait until the user releases the keyboard
;call example   WAIT_KEY_RELEASE
;...............................................................................
WAIT_KEY_RELEASE
                LDA #0                  ;clear keyboard buffer
                STA KEYCNT              ;
WAIT_KEY_REL_01 JSR SCAN_KEYBOARD       ;because the interrupts are disabled during communication with the Cassiopei, the keyboard might not be updated and therefore the buffer value remains the same, which in real life is not correct, so we execute a manual keyboard scan
                LDA $C5                 ;matrix value of last Key pressed
                CMP #KEY_NOTHING        ;check for key
                BNE WAIT_KEY_REL_01     ;continue loop when no key is detected
                RTS                     ;


;-------------------------------------------------------------------------------
;This routine will wait until the user presses a key (which must be one of the possible choices)
;...............................................................................
CHOOSE
CHOOSE_RELEASE  LDA $C5                 ;matrix value of last Key pressed
                CMP #KEY_NOTHING        ;check for key
                BNE CHOOSE_RELEASE      ;continue loop when no key is detected

CHOOSE_LP       JSR SCAN_KEYBOARD       ;because the interrupts are disabled during communication with the Cassiopei, the keyboard might not be updated and therefore the buffer value remains the same, which in real life is not correct, so we execute a manual keyboard scan
                LDA $C5                 ;matrix value of last Key pressed
                CMP #KEY_NOTHING        ;check for key
                BEQ CHOOSE_LP           ;continue loop when no key is detected

                CMP #KEY_F1             ;and jump to the requested action
                BEQ SCAN_VAL_CHA        ;
                CMP #KEY_F3             ;
                BEQ SCAN_VAL_CHB        ;                
                JMP CHOOSE_LP           ;not a valid key, keep scanning

SCAN_VAL_CHA    LDA #USER_INPUT_CHA     ;
                RTS

SCAN_VAL_CHB    LDA #USER_INPUT_CHB     ;
                RTS

;-------------------------------------------------------------------------------
;Clear screen and set the color of the colorscreen
;Example:       JSR CLEAR_SCREEN
;...............................................................................
CLEAR_SCREEN    LDA #0                  ;make the screen and border black
                STA BORDER              ;
                STA BACKGROUND          ;

                LDY #0 
                LDA #$20                ;fill the screen with spaces
SETCHARACTER    STA CHARSCREEN+0,y      ;
                STA CHARSCREEN+256,y    ;
                STA CHARSCREEN+512,y    ;
                STA CHARSCREEN+745,y    ;            
                INY                     ;
                BNE SETCHARACTER        ;

                LDY #0                  ;
                LDA #1                  ;make all the characterpositions white
SETTEXTCOLOR    STA COLORSCREEN+0,y     ;
                STA COLORSCREEN+256,y   ;
                STA COLORSCREEN+512,y   ;
                STA COLORSCREEN+745,y   ;            
                INY                     ;
                BNE SETTEXTCOLOR        ;
                RTS                     ;

;-------------------------------------------------------------------------------
; The first location of the charsecreen (topleft) is defined as coordinate 0,0
; Use this routine before calling a PRINT related routine
;               LDX CURSOR_Y;.. chars from the top of the defined screen area
;               LDY CURSOR_X;.. chars from the left of the defined screen area
;               JSR SET_CURSOR
;...............................................................................

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
                CLC                     ;clear carry for the upcoming "ADC CHAR_ADDR"

                LDA #40                 ;add  40 (which is the number of characters per line for most commodore computers) to calculate the new Y position of cursor
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
SHOW_VERSION    LDX #1                  ;set cursor to top,left
                LDY #1                  ;
                JSR SET_CURSOR          ;
                LDA #<PRG_IDENTIFIER    ;set pointer to the text that defines the main-screen
                LDY #>PRG_IDENTIFIER    ;        
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen     
               
                LDX #1                  ;set cursor to top,left
                LDY #2                  ;
                JSR SET_CURSOR          ;
                LDA #<VERSION_INFO      ;set pointer to the text that defines the main-screen
                LDY #>VERSION_INFO      ;        
                JSR PRINT_STRING        ;the print routine is called, so the pointed text is now printed to screen     

                RTS


;-------------------------------------------------------------------------------
endif   ;this endif belongs to "ifdef COMMODORE64"
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
