;This program was written by Jan Derogee
;do not alter use or spread this program without his permission


;---------------------------------------------------------------------------------------------------------
;ATTENTION: This code has been developed to be used with the CBM Program Studio compiler
;---------------------------------------------------------------------------------------------------------

;When using CBM prog studio to compile this program, make sure that you
;compile the entire project (Build -> Project -> And Run (CTRL+F5) )

;All files in this program have a ORG address (indicated by *=$xxxx)
;When this program is to be compiled with another program then CBM prog studio
;simply append all files in ascending order and all will be fine



;regarding the CBM program studio assembler mind the following settings:
;disable the option : optimize absolute modes to zero page


;note regarding video formats
;----------------------------
;Although it would be possible to create video files that are smaller then the screen
;of the computer it is being played, the extra calculation to allign the video to the
;video memory would make it very complex and that would reduce the playback rate.
;Considering that there are only 3 different screen sizes it make no sense to support
;an infinite ammount of sizes. So a video made for a C64 can't beplayed on a VIC20 or an 80col PET.
;And an 80col video can only be played on an 80 kol pet because the 80col mode of the C128 simply sucks,
;is has no speed whatsoever and is not suited for video playback of this kind.