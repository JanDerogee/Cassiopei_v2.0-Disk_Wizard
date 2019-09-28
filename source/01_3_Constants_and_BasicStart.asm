;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ifdef COMMODORE64
;-------------------------------------------------------------------------------
*=$0801
        BYTE    $0B, $08, $0A, $00, $9E, $32, $30, $39, $36, $00, $00, $00      ; 10 SYS2096


*=$0810
PRG_IDENTIFIER
            ;'0123456789ABCDEF'
        TEXT 'disk wizard c64 ' ;this message could be valuable hint in solving a problem
        BYTE 0;end of table marker
        ;also usefull for debugging on vice, then the screen is no longer completely empty and you know that something has happened

*=$0830
PRG_START       JMP INIT        ;start the program

;-------------------------------------------------------------------------------

;-- zeropage RAM registers--
CPIO_DATA       = $02  ;this zeropage memory location is used to parse the CPIO data

ADDR            = $61  ;pointer
;ADDR+1         = $62  ;     
 
ADDR_LAST_TILE  = $63  ;pointer (used in NORMAL mode, for detection of the last tile,
;ADDR_LAST_TILE+1= $64  ;this way we don't have to keep a counter, we just compare two 16-bit values)
CNTR            = $63  ;pointer (used in DELTA mode, since the last tile is unpredictable, this counter just counts the number of tiles
;CNTR+1         = $64  ;until it matches the "changed tiles" value of the image)      

STR_ADDR        = $6E  ;pointer to string
;STR_ADDR+1     = $6F  ;           
CHAR_ADDR       = $FA
;CHAR_ADDR+1    = $FB


;-- build related settings --
WINDOW_X_POS    = 1             ;the X-distance from top-left
WINDOW_Y_POS    = 4             ;the Y-distance from top-left
WINDOW_X_SIZE   = 28            ;the X-size of the window to be scrolled
WINDOW_Y_SIZE   = 16            ;the Y-size of the window to be scrolled

SUPPORTED_X_SIZE = 40           ;screen width of a C64 is 40 columns
SUPPORTED_Y_SIZE = 25           ;screen width of a C64 is 25 rows


;location of the status line
X_POS_STATUS    = 1
Y_POS_STATUS    = 23
X_POS_PROGBAR   = 5
Y_POS_PROGBAR   = 9
SCR_POS_TRACK   = $0661
SCR_POS_SECTOR  = $0689

DEVICE          = 8             ;the device number of the disk drive
DATA_AREA       = $06D0         ;store data here (when using $0400+ for a C64, it will be in the video memory and clearly visible, usefull for debugging)

SCR_POS         = $0681         ;the location on the screen where the string will be printed
STR_POS_MAX     = 37            ;the max size of the filename (the practical limit is determined by the screen size)

;kernal variables
KVAR_CCCC       = $0286       ;Current Character Color Code
KVAR_BCUC       = $0287       ;Background Color Under Cursor

;kernal routines
KERN_LINPRT     = $BDCD         ;print basic line number for C64
KERN_PLOT       = $FFF0         ;cursor position
KERN_SETNAM     = $FFBD       ;call SETNAM
KERN_SETLFS     = $FFBA       ;call SETLFS
KERN_OPEN       = $FFC0       ;call OPEN
KERN_CLOSE      = $FFC3       ;call CLOSE
KERN_CHKIN      = $FFC6       ;call CHKIN
KERN_CHKOUT     = $FFC9       ;call CHKOUT (file 2 now used as output)
KERN_CHROUT     = $FFD2       ;call CHROUT
KERN_CLRCHN     = $FFCC       ;call CLRCHN
KERN_READST     = $FFB7       ;call READST
KERN_CHRIN      = $FFCF       ;call CHRIN
KERN_RUNSTOP    = $FFE1       ;RUN/STOP pressed?
KERN_LISTEN     = $FFB1       ;call LISTEN
KERN_UNLISTEN   = $FFAE       ;call UNLSN
KERN_TALK       = $FFB4       ;call TALK
KERN_UNTALK     = $FFAB       ;call UNTLK
KERN_SECLSN     = $FF93       ;call SECLSN (SECOND)
KERN_SECTALK    = $FF96       ;call SECTLK (TKSA)
KERN_IECIN      = $FFA5       ;call IECIN (get byte from IEC bus)

;-------------------------------------------------------------------------------
endif   ;this endif belongs to "ifdef COMMODORE64"
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<