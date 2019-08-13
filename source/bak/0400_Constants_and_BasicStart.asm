; 10 SYS1056
*=$401

        BYTE    $0B, $04, $0A, $00, $9E, $31, $30, $35, $36, $00, $00, $00
               
endif


;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;-------------------------------------------------------------------------------
;                            zeropage RAM regsiters
;-------------------------------------------------------------------------------
;we use only the 0-page locations that are marked as "unused" or "free 0-page space for user programs"


;common variables
;----------------

CPIO_DATA       = $ED           ;this zeropage memory location is used to parse the CPIO data
CHRCNT          = $EF


;variables used by menu program only
;-----------------------------------
;$54-$58               Temporary storage for FLPT value.
;$59-$5D               Temporary storage for FLPT value.
;$A2, $ED-$F7, $FF are unused


CURSOR_X        = $54   ;buffer used for text printing routine
CURSOR_Y        = $55   ;buffer used for text printing routine

CHAR_ADDR       = $56
;CHAR_ADDR+1    = $57

STR_ADDR        = $58  ;pointer to string
;STR_ADDR+1     = $59  ;           

ADDR            = $5A  ;pointer
;ADDR+1         = $5B  ;      
CNTR            = $5C  ;pointer
;CNTR+1         = $5D  ;      



;we use only the 0-page locations that are marked as "unused" or "free 0-page space for user programs"
;variables used by wedge only
;----------------------------
;POINTER_BUF     = $54   ;and $55
;TABLE_ADR       = $56   ;and $57


;...............................................................................
;                         KERNAL ROUTINES AND ADDRESSES
;...............................................................................

KEYCNT          = 158           ;the counter that keeps track of the number of key in the keyboard buffer       PET/CBM (Upgrade and 4.0 BASIC)
KEYBUF          = 623           ;the first position of the keyboard buffer                                      PET/CBM (Upgrade and 4.0 BASIC)
KEYMATRIX       = $97           ;key matrix value                                                               PET/CBM (Upgrade and 4.0 BASIC)

CHARSCREEN      = $8000         ;location of the character screen memory

;TXTPTR          = $7A   ;this value is noted as 2 digits (no zeros are noted here, to use it as a zero-page address)
;CHRGET          = $0073 ;this value is noted as 4 digits, because we want to jump to it and therefore it needs to be a 4 digit address ;get character from basic line (value corresponds to table in Appendix C of prog ref guid (page 379))
;CHRGOT          = $0079 ;this value is noted as 4 digits, because we want to jump to it and therefore it needs to be a 4 digit address ;get the last character again
;IGONE           = $0308         ;non function BASIC commands 
;IEVAL           = $030A         ;functions in BASIC commands
;NEWBASIC_DONE   = $A7E4         ;fetch new character from basic line and interpret (jump to this vector after !HELP which is a command that has no prarameters to be processed)
;STNDRDBASICCMD  = $A7E7         ;interpret just fetched character from basic line as a command
;STNDRDBASICFUNC = $AE8D         ;interpret just fetched character from basic line as a function
;SYNTAXERROR     = $AF08         ;syntax error

;CHROUT          = $FFD2         ;

;CHKCOMANDGETVAL = $E200         ;check if last fetched char was a comma, if so get value (stores 8-bit value in X), if not syntax error
;CHKCOM          = $AEFD         ;If it is not, a SYNTAX ERROR results.  If it is, the character is skipped and the next character is read.
;FRMNUM          = $AD8A         ;
;GETADR          = $B7F7         ;

DATA_DIR_6510   = $00           ;the MOS6510 data direction register of the peripheral IO pins (P7-0)
DATA_BIT_6510   = $01           ;the MOS6510 value f the bits of the peripheral IO pins (P7-0)

;-------------------------------------------------------------------------------
;                                   constants
;-------------------------------------------------------------------------------

;DIRWINDOWSIZE   = 16            ;the max. number of lines that we can display in our directory window
;MODE_ADR        = $00           ;the register address of the location where the CPIO's can sotre settings
;INDEX_ADR       = $01           ;the register address of the location where the CPIO's can sotre settings


;------------------------

;MODE_KERNALLOADER_FROM_FLASH    = $00
;MODE_CPIOLOADER_FROM_FLASH      = $01
;MODE_CPIOLOADER_FROM_USB        = $02
;MODE_PLAYTAPFILE_FROM_FLASH     = $03
;MODE_PLAYTAPFILE_FROM_USB       = $04


; CPIO related constants
;------------------------

CPIO_LOAD               = #%00000000    ;read fast from the cassiopei's filesystem
CPIO_DATALOAD           = #%00000001    ;read fast from the cassiopei's filesystem from a data file
;CPIO_SAVEFAST           = #%00000000    ;save fast from the cassiopei's filesystem

CPIO_R_DIRECTORY_FLASH  = #%00000100    ;read diretory info from flash        
CPIO_SIMULATE_BUTTON    = #%00000111    ;simulate press on play
CPIO_R_EEPROM           = #%00001111    ;read from slave, EEPROM
CPIO_W_EEPROM           = #%10001111    ;write to slave, EEPROM

CPIO_ADC                = #%00001001    ;get ADC value
CPIO_EEPROM_RD          = #%00001111    ;read from slave, EEPROM
CPIO_PARAMETER          = #%00001101    ;prepare sample playback (with possible transfer of 4 bit AUDIO sample(s)) or other kinds of data
CPIO_PLAYSAMPLE         = #%00001110    ;start sample playback
CPIO_SPEECH             = #%10001110    ;start speech generator


CPIO_EEPROM_WR          = #%10001111    ;write to slave, EEPROM
CPIO_SINEWAVE           = #%10001000    ;write to slave, audio: type pure sine
CPIO_DTMF               = #%10001001    ;write to slave, audio: type DTMF


CPIO_KAKU13             = #%10001011    ;write to slave, klik aan klik uit code 13 bits
CPIO_KAKU32             = #%10001100    ;write to slave, klik aan klik uit code 32 bits

CPIO_SERVOINIT          = #%10010001    ;init PCA9685 PWEM controller for servo mode
CPIO_SERVOPOS           = #%10010010    ;send servo postioning command

CPIO_I2C                = #%10010000    ;I2C data
CPIO_I2C_STOP           = #$00          ;write I2C data to slave
CPIO_I2C_ADR_W          = #$01          ;write I2C address to slave and indicate that we are sending data TO the I2C slave
CPIO_I2C_ADR_R          = #$02          ;write I2C address to slave and indicate that we are going to read data FROM the I2C slave
CPIO_I2C_PUT            = #$10          ;write I2C data to slave
CPIO_I2C_GET            = #$20          ;read I2C data from slave and acknowledge
CPIO_I2C_GETLAST        = #$21          ;read I2C data from slave, but do not acknowledge to indicate this is the last byte we want to read

;-------------------------------------------------------------------------------


