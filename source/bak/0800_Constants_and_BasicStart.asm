; 10 SYS (2080)

*=$801

        BYTE    $0E, $08, $0A, $00, $9E, $20, $28,  $32, $30, $38, $30, $29, $00, $00, $00


;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;                           BUILD RELATED SETTINGS
;-------------------------------------------------------------------------------

FALSE = 0
TRUE  = 1

;USE_USERPORT_DATATRANSFER = TRUE

;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;-------------------------------------------------------------------------------
;                            zeropage RAM regsiters
;-------------------------------------------------------------------------------
;we use only the 0-page locations that are marked as "unused" or "free 0-page space for user programs"


;common variables
;----------------

CPIO_DATA       = $02           ;this zeropage memory location is used to parse the CPIO data
CHRCNT          = $97


CURSOR_X        = $F7   ;buffer used for text printing routine
CURSOR_Y        = $F8   ;buffer used for text printing routine

CHAR_ADDR       = $F9
CHAR_ADDR+1     = $FA

STR_ADDR        = $FB  ;pointer to string
STR_ADDR+1      = $FC  ;           

ADDR            = $61  ;pointer
ADDR+1          = $62  ;     
 
ADDR_LAST_TILE  = $63  ;pointer (used in NORMAL mode, for detection of the last tile,
ADDR_LAST_TILE+1= $64  ;this way we don't have to keep a counter, we just compare two 16-bit values)
CNTR            = $63  ;pointer (used in DELTA mode, since the last tile is unpredictable, this counter just counts the number of tiles
CNTR+1          = $64  ;until it matches the "changed tiles" value of the image)      


COL_PRINT       = $6B  ;holds the color of the charaters printed with the PRINT_CHAR routine
COLOR_ADDR      = $6C  ;pointer to color memory
;COLOR_ADDR+1   = $6D


;we use only the 0-page locations that are marked as "unused" or "free 0-page space for user programs"
;variables used by wedge only
;----------------------------
POINTER_BUF     = $FB   ;and $FC
TABLE_ADR       = $FD   ;and $FE



;...............................................................................
;                         KERNAL ROUTINES AND ADDRESSES
;...............................................................................

;KEYCNT          = 158           ;the counter that keeps track of the number of key in the keyboard buffer       PET/CBM (Upgrade and 4.0 BASIC)
;KEYBUF          = 623           ;the first position of the keyboard buffer                                      PET/CBM (Upgrade and 4.0 BASIC)
;KEYMATRIX       = $97           ;key matrix value                                                               PET/CBM (Upgrade and 4.0 BASIC)




BORDER          = $D020         ;bordercolour
BACKGROUND      = $D021         ;background-0
CHARSCREEN      = $0400         ;location of the character screen memory
COLORSCREEN     = $D800         ;location of the color screen memory (this value cannot change)

TXTPTR          = $7A   ;this value is noted as 2 digits (no zeros are noted here, to use it as a zero-page address)
CHRGET          = $0073 ;this value is noted as 4 digits, because we want to jump to it and therefore it needs to be a 4 digit address ;get character from basic line (value corresponds to table in Appendix C of prog ref guid (page 379))
CHRGOT          = $0079 ;this value is noted as 4 digits, because we want to jump to it and therefore it needs to be a 4 digit address ;get the last character again
IGONE           = $0308         ;non function BASIC commands 
IEVAL           = $030A         ;functions in BASIC commands
NEWBASIC_DONE   = $A7E4         ;fetch new character from basic line and interpret (jump to this vector after !HELP which is a command that has no prarameters to be processed)
STNDRDBASICCMD  = $A7E7         ;interpret just fetched character from basic line as a command
STNDRDBASICFUNC = $AE8D         ;interpret just fetched character from basic line as a function
SYNTAXERROR     = $AF08         ;syntax error

SCAN_KEYBOARD   = $FF9F         ;scans the keyboard and puts the matrix value in $C5
CHROUT          = $FFD2         ;

CHKCOMANDGETVAL = $E200         ;check if last fetched char was a comma, if so get value (stores 8-bit value in X), if not syntax error
CHKCOM          = $AEFD         ;If it is not, a SYNTAX ERROR results.  If it is, the character is skipped and the next character is read.
FRMNUM          = $AD8A         ;
GETADR          = $B7F7         ;


DATA_DIR_6510   = $00           ;the MOS6510 data direction register of the peripheral IO pins (P7-0)
DATA_BIT_6510   = $01           ;the MOS6510 value f the bits of the peripheral IO pins (P7-0)

;-------------------------------------------------------------------------------
;                                   constants
;-------------------------------------------------------------------------------


DIRWINDOWHEIGTH = 10            ;the max. number of lines that we can display in our directory window
DIRWINDOWWIDTH  = 32            ;the max displayed length of the filename


; CPIO related constants
;------------------------

CPIO_DATALOAD           = %00000001    ;read fast from the cassiopei's filesystem from a data file
CPIO_DATALOAD_TURBO     = %00000011    ;read fast from the cassiopei's filesystem from a data file
CPIO_PARAMETER          = %11111111    ;prepare sample playback (with possible transfer of 4 bit AUDIO sample(s)

;-------------------------------------------------------------------------------
;C64 keyboard scanning values

KEY_NOTHING     = $40           ;when no key is pressed
KEY_F1          = $04           ;$04 = F1 
KEY_F3          = $05           ;$05 = F3
KEY_F5          = $06           ;$06 = F5 
KEY_F7          = $03           ;$03 = F7
KEY_RETURN      = $01           ;$01 = RETURN
KEY_1           = $38           ;$38 = 1 
KEY_2           = $3B           ;$3B = 2

