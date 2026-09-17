.686
.model flat, stdcall
.stack 4096

INCLUDE Irvine32.inc
INCLUDE des_shell.inc

.code

; -----------------------------------------------------------------------------
; StrCompareI (Case-Insensitive String Compare)
; Output: EAX = 0 เมื่อตรงกัน
; -----------------------------------------------------------------------------
StrCompareI PROC, pStr1:PTR BYTE, pStr2:PTR BYTE
    push    ebx
    push    esi
    push    edi

    mov     esi, pStr1
    mov     edi, pStr2

L_Cmp:
    mov     al, BYTE PTR [esi]
    mov     bl, BYTE PTR [edi]

    cmp     al, 'a'
    jb      L_S1
    cmp     al, 'z'
    ja      L_S1
    sub     al, 20h
L_S1:
    cmp     bl, 'a'
    jb      L_S2
    cmp     bl, 'z'
    ja      L_S2
    sub     bl, 20h
L_S2:
    cmp     al, bl
    jne     L_Diff
    cmp     al, 0
    je      L_Same
    inc     esi
    inc     edi
    jmp     L_Cmp

L_Diff:
    mov     eax, 1
    jmp     L_Exit
L_Same:
    mov     eax, 0
L_Exit:
    pop     edi
    pop     esi
    pop     ebx
    ret
StrCompareI ENDP

; -----------------------------------------------------------------------------
; ExtractFilename (FSM สกัดชื่อไฟล์ ตัดเครื่องหมายคำพูด "")
; Input:  ESI = input pointer
; Output: EDI = filename output, ESI = เลื่อนไปยัง argument ถัดไป
; -----------------------------------------------------------------------------
ExtractFilename PROC, pIn:PTR BYTE, pOut:PTR BYTE
    push    ebx
    push    esi
    push    edi

    mov     esi, pIn
    mov     edi, pOut

L_SkipSp:
    mov     al, BYTE PTR [esi]
    cmp     al, ' '
    jne     L_CheckQuote
    inc     esi
    jmp     L_SkipSp

L_CheckQuote:
    cmp     al, '"'
    jne     L_NormalName
    inc     esi                 ; ข้ามเครื่องหมาย " เปิด

L_QuoteLoop:
    mov     al, BYTE PTR [esi]
    cmp     al, 0
    je      L_EndExtract
    cmp     al, '"'
    je      L_CloseQuote
    mov     BYTE PTR [edi], al
    inc     esi
    inc     edi
    jmp     L_QuoteLoop

L_CloseQuote:
    inc     esi                 ; ข้ามเครื่องหมาย " ปิด
    jmp     L_EndExtract

L_NormalName:
    mov     al, BYTE PTR [esi]
    cmp     al, 0
    je      L_EndExtract
    cmp     al, ' '
    je      L_EndExtract
    mov     BYTE PTR [edi], al
    inc     esi
    inc     edi
    jmp     L_NormalName

L_EndExtract:
    mov     BYTE PTR [edi], 0
    mov     eax, esi            ; คืนตำแหน่ง ESI ปัจจุบันผ่าน EAX

    pop     edi
    pop     esi
    pop     ebx
    ret
ExtractFilename ENDP

; -----------------------------------------------------------------------------
; ParseHex64 (แปลง 16-hex characters เป็น 8 ไบต์)
; -----------------------------------------------------------------------------
ParseHex64 PROC, pHexStr:PTR BYTE, pOutBuf:PTR BYTE
    push    ebx
    push    ecx
    push    edx
    push    esi
    push    edi

    mov     esi, pHexStr
    mov     edi, pOutBuf

L_SkipHexSpace:
    mov     al, BYTE PTR [esi]
    cmp     al, ' '
    jne     L_Check0x
    inc     esi
    jmp     L_SkipHexSpace

L_Check0x:
    mov     al, BYTE PTR [esi]
    cmp     al, '0'
    jne     L_DoBytes
    mov     al, BYTE PTR [esi+1]
    cmp     al, 'x'
    je      L_Pass0x
    cmp     al, 'X'
    jne     L_DoBytes
L_Pass0x:
    add     esi, 2

L_DoBytes:
    mov     ecx, 0
L_Nibbles:
    cmp     ecx, 8
    jge     L_Success

    ; High nibble
    mov     al, BYTE PTR [esi]
    call    CharToNibble
    cmp     al, 0FFh
    je      L_Fail
    shl     al, 4
    mov     bl, al
    inc     esi

    ; Low nibble
    mov     al, BYTE PTR [esi]
    call    CharToNibble
    cmp     al, 0FFh
    je      L_Fail
    or      bl, al
    inc     esi

    mov     BYTE PTR [edi + ecx], bl
    inc     ecx
    jmp     L_Nibbles

L_Success:
    mov     eax, 0
    jmp     L_ExitHex
L_Fail:
    mov     eax, 1
L_ExitHex:
    pop     edi
    pop     esi
    pop     edx
    pop     ecx
    pop     ebx
    ret
ParseHex64 ENDP

CharToNibble PROC
    cmp     al, '0'
    jb      L_N_Err
    cmp     al, '9'
    jbe     L_N_Digit
    cmp     al, 'a'
    jb      L_N_Up
    cmp     al, 'f'
    ja      L_N_Err
    sub     al, 'a'
    add     al, 10
    ret
L_N_Up:
    cmp     al, 'A'
    jb      L_N_Err
    cmp     al, 'F'
    ja      L_N_Err
    sub     al, 'A'
    add     al, 10
    ret
L_N_Digit:
    sub     al, '0'
    ret
L_N_Err:
    mov     al, 0FFh
    ret
CharToNibble ENDP

END