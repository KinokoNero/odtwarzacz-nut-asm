Progr           segment
                assume  cs:Progr, ds:dane, ss:stosik

start:
                ;store file name in es
                mov     cl,ds:[80h]       ;load file name length
                cmp     cl,0              ;check if file name was provided
                jne     filenamenotnull
                call    errorcall
filenamenotnull:
                dec     cl          ;don't include ENTER at the end
                mov     ch,0
                mov     si,82h      ;begin from file name at 82h (skip space)
                mov     di,0
                mov     es:[di],cl  ;store file name length in es
                inc     di
getfilename:
                mov     dl,[si]
                mov     dh,0
                mov     es:[di],dl  ;store filename chars in es
                inc     si
                inc     di
                dec     cl
                jnz     getfilename
                ;end of file name storing

                mov     ax,dane
                mov     ds,ax
                mov     ax,stosik
                mov     ss,ax
                mov     sp,offset szczyt
;----------------------------------------------------------------------------

                ;load file name from es
                mov     si,offset filename
                mov     di,0
                mov     cl,es:[di]         ;load file name length
                mov     ch,0
                inc     di
loadfilename:
                mov     dl,es:[di]         ;load file name chars
                mov     dh,0
                mov     ds:[si],dl         ;load file name into filename
                inc     si
                inc     di
                dec     cl
                jnz     loadfilename
                mov     bl,0
                mov     ds:[si],bl         ;terminate file name
                ;end of loading file name from es

                ;open a file
                mov     ah,3Dh       ;open file int 21h subroutine
                mov     al,0         ;filehandler read only mode
                lea     dx,filename  ;filename to read from
                int     21h
                jnc     ok
                call    errorcall
ok:
                mov     bx,ax        ;save file handler

                ;read from opened file
                mov     ah,3Fh       ;read from file int 21h subroutine
                mov     cx,1024       ;CX is buffer size
                lea     dx,notes     ;send read text into 'notes'
                int     21h
                jnc     ok2
                call    errorcall
ok2:
                ;convert read text from file into sound frequencies
                call    convert
                mov     fiterator,0     ;clear freqs iterator for future use
                mov     leniterator,0   ;clear length iterator for future use


play:
                ;visuals
                mov ax,3
                int 10h
                mov dx,notecolumn
                and dx,1
                call notewrite

                lea     si,freqs
                mov     al,fiterator
                mov     ah,0
                add     si,ax
                in      al,61h     ;read speaker controller status
                or      al,11b     ;set bits to open speaker gate (0th bit)
                                   ;and allow for data
                                   ;transfer to speaker (1st bit)
                out     61h,al     ;update speaker controller status
                mov     dx,12h     ;counter frequency (1193181 Hz) upper part
                mov     ax,34DDh   ;counter frequency lower part
                mov     cx,[si]
                div     cx         ;div counter freq by sound freq

                out     42h,al     ;send lower part of note counter
                mov     al,ah      ;must be in AL or AX to send
                out     42h,al     ;send upper part of note counter

                ;play sound for set num of microseconds
                lea     si,lengths
                mov     bl,leniterator
                mov     bh,0
                add     si,bx
                mov     cx,[si]   ;upper part of microseconds
                add     si,2
                mov     dx,[si]   ;lower part of microseconds
                mov     ah,86h       ;init elapsed time wait of int 15h
                int     15h          ;pause for CX:DX microseconds

                ;turn speaker off
                in      al,61h       ;read controller status
                and     al,not 11b   ;set 0th & 1st bit of speaker to 0
                out     61h,al       ;update controller status

                ;pause for 100 ms
                mov     cx,1h   ;upper part of microseconds
                add     si,2
                mov     dx,86A0h   ;lower part of microseconds
                mov     ah,86h      ;init elapsed time wait of int 15h
                int     15h         ;pause for CX:DX microseconds

                add     leniterator,4
                add     fiterator,2

                ;check if whole track was played
                lea     si,freqs
                mov     bl,fiterator
                mov     bh,0
                add     si,bx
                mov     ax,[si]
                cmp     ax,'$$'
                jne     play         ;if last note wasn't played, play more
endplay:
                mov     ax,3
                int     10h
;----------------------------------------------------------------------------
                mov     ah,4ch
                mov     al,0
                int     21h

;---------------------------v Functions v------------------------------------
convert: ;converts text read from file into frequencies
                lea     si,notes
                mov     bl,iterator
                mov     bh,0
                add     si,bx     ;go to note marked by iterator
                mov     ax,[si]
                mov     ah,0
                cmp     ax,'$'
                je      converted
                call    tone            ;convert text to frequency
                                        ;and put it in freqs array
                call    len             ;determine play length for each note
                add     iterator,4      ;increase iterator for next note
                jmp     convert
converted:
                ret
tone:
                lea     si,notes
                mov     bl,iterator
                mov     bh,0
                add     si,bx
                inc     si       ;evaluate if it is semitone
                mov     ax,[si]
                mov     ah,0     ;clear upper AX
                cmp     ax,'$'
                je      converted
                cmp     ax,'#'   ;there is a '#' if seminote
                je      seminote
                call    note
                ret
note:
                lea     si,notes
                mov     bl,iterator
                mov     bh,0
                add     si,bx
                mov     ax,ds:[si]
                mov     ah,0
                cmp     ax,'C'
                jne     isD
                ;it is C
                mov     ax,33
                call    octave
                ret
isD:
                cmp     ax,'D'
                jne     isE
                ;it is D
                mov     ax,37
                call    octave
                ret
isE:
                cmp     ax,'E'
                jne     isF
                ;it is E
                mov     ax,41
                call    octave
                ret
isF:
                cmp     ax,'F'
                jne     isG
                ;it is F
                mov     ax,44
                call    octave
                ret
isG:
                cmp     ax,'G'
                jne     isA
                ;it is G
                mov     ax,49
                call    octave
                ret
isA:
                cmp     ax,'A'
                jne     isH
                ;it is A
                mov     ax,55
                call    octave
                ret
isH:
                cmp     ax,'H'
                jne     toneerror
                ;it is H
                mov     ax,62
                call    octave
                ret
toneerror:
                call    errorcall
seminote:
                lea     si,notes
                mov     bl,iterator
                mov     bh,0
                add     si,bx
                mov     ax,ds:[si]
                mov     ah,0
                cmp     ax,'C'
                jne     isDs
                ;it is C
                mov     ax,35
                call    octave
                ret
isDs:
                cmp     ax,'D'
                jne     isEs
                ;it is D
                mov     ax,39
                call    octave
                ret
isEs:
                cmp     ax,'E'
                jne     isFs
                ;it is E
                mov     ax,42
                call    octave
                ret
isFs:
                cmp     ax,'F'
                jne     isGs
                ;it is F
                mov     ax,46
                call    octave
                ret
isGs:
                cmp     ax,'G'
                jne     isAs
                ;it is G
                mov     ax,52
                call    octave
                ret
isAs:
                cmp     ax,'A'
                jne     toneerror
                ;it is A
                mov     ax,58
                call    octave
                ret
octave:
                lea     si,notes
                mov     bl,iterator
                mov     bh,0
                add     si,bx
                add     si,2              ;evaluate octave
                mov     cl,ds:[si]        ;CX stores octave value
                mov     ch,0
                cmp     cx,31h
                jl      toneerror         ;jump if lesser
                cmp     cx,37h
                jg      toneerror         ;jump if greater
                sub     cx,31h            ;convert ASCII octave to number
                shl     ax,cl             ;multiply base note freq
                                          ;by octave CL times
                lea     si,freqs
                mov     bl,fiterator
                mov     bh,0
                add     si,bx
                mov     ds:[si],ax        ;save note freq to 'freqs'
                add     fiterator,2
                ret
len:
                lea     si,notes
                mov     bl,iterator
                mov     bh,0
                add     si,bx
                add     si,3
                mov     al,ds:[si]
                mov     ah,0

                cmp     ax,31h       ;check if whole note
                jne     ishalfnote
                ;it is whole note
                lea     si,lengths
                mov     bl,leniterator
                mov     bh,0
                add     si,bx
                mov     ax,0021h
                mov     ds:[si],ax
                add     si,2
                mov     ds:[si],0E7B0h
                add     leniterator,4
                ret
ishalfnote:
                cmp     ax,32h       ;check if halfnote
                jne     isquarternote
                ;it is halfnote
                lea     si,lengths
                mov     bl,leniterator
                mov     bh,0
                add     si,bx
                mov     ax,0010h
                mov     ds:[si],ax
                add     si,2
                mov     ds:[si],0F3D8h
                add     leniterator,4
                ret
isquarternote:
                cmp     ax,34h       ;check if quarternote
                jne     iseight
                ;it is quarternote
                lea     si,lengths
                mov     bl,leniterator
                mov     bh,0
                add     si,bx
                mov     ax,0008h
                mov     ds:[si],ax
                add     si,2
                mov     ds:[si],07BE0h
                add     leniterator,4
                ret
iseight:
                cmp     ax,38h       ;check if 1/8 of a note
                jne     lenerror
                ;it is 1/8 of a note
                lea     si,lengths
                mov     bl,leniterator
                mov     bh,0
                add     si,bx
                mov     ax,0004h
                mov     ds:[si],ax
                add     si,2
                mov     ds:[si],03DF0h
                add     leniterator,4
                ret
lenerror:
                call    errorcall
errorcall:
                ;display error message
                mov     ah,9h
                lea     dx,errortxt
                int     21h
                ;terminate program
                mov     ah,4ch
                mov     al,0
                int     21h

notewrite:
                mov     ax,1301h
                mov     bl,notecolor
                mov     bp,0
                push    14   ;note symbol ASCII code
                pop     es:[bp]
                mov     cx,1
                int     10h
                add     dx,2
                dec     notecount
                jnz     notewrite
                mov     notecount,3039 ;restore note count to display
                mov     dx,0
                inc     notecolor
                and     notecolor,0Fh
                or      notecolor,1
                inc     notecolumn
                ret

Progr           ends

dane            segment

                filename    db     ?
                notes       db     512 dup('$')   ;text file contents
                freqs       dw     256 dup('$$')  ;frequencies of notes from file
                lengths     dd     512 dup(0)     ;play length in microseconds
                iterator    db     0    ;notes iterator
                leniterator db     0    ;len iterator
                fiterator   db     0    ;freqs iterator
                errortxt    db     "Cos jest nie tak z plikiem z nutami lub podano zla nazwe pliku!",'$'

                notecount   dw     3039
                notecolumn  dw     0
                notecolor   db     1

dane            ends

stosik          segment
                dw    100h dup(0)
szczyt          Label word
stosik          ends

end start