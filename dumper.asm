.686
.model flat, stdcall
.stack 4096

INCLUDE Irvine32.inc
INCLUDE des_shell.inc

.data
    hdrDump     BYTE "[Address] 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F | ASCII", 0Dh, 0Ah, 0
    sepDump     BYTE " | ", 0
    hdrStats    BYTE "Entropy Statistics: Buffer Byte Distribution (256 bins)", 0Dh, 0Ah, 0
    topMsg      BYTE "Top Byte Occurrences:", 0Dh, 0Ah, 0
    dotChar     BYTE ".", 0
    histTable   DWORD 256 DUP(0)

.code

; -----------------------------------------------------------------------------
; DisplayHexDump (Module D)
; -----------------------------------------------------------------------------
DisplayHexDump PROC, pBuffer:PTR BYTE, bufferLen:DWORD
    LOCAL   curOffset:DWORD, lineBytes:DWORD

    push    ebx
    push    ecx
    push    edx
    push    esi
    push    edi

    mov     edx, OFFSET hdrDump
    call    WriteString

    mov     curOffset, 0

L_LineLoop:
    mov     eax, curOffset
    cmp     eax, bufferLen
    jge     L_DumpEnd

    ; แสดง Address (8 digits)
    mov     eax, curOffset
    call    WriteHex
    mov     al, ' '
    call    WriteChar

    ; คำนวณจำนวนไบต์ในบรรทัดนี้ (สูงสุด 16 ไบต์)
    mov     eax, bufferLen
    sub     eax, curOffset
    cmp     eax, 16
    jbe     L_SetLineBytes
    mov     eax, 16
L_SetLineBytes:
    mov     lineBytes, eax

    ; แสดง Hex
    mov     ecx, 0
L_HexLoop:
    cmp     ecx, 16
    jge     L_HexEnd
    cmp     ecx, lineBytes
    jge     L_PadHexSpace

    mov     esi, pBuffer
    add     esi, curOffset
    movzx   eax, BYTE PTR [esi + ecx]
    call    PrintByteHex
    mov     al, ' '
    call    WriteChar
    jmp     L_NextHex

L_PadHexSpace:
    mov     al, ' '
    call    WriteChar
    call    WriteChar
    call    WriteChar

L_NextHex:
    inc     ecx
    jmp     L_HexLoop
L_HexEnd:

    mov     edx, OFFSET sepDump
    call    WriteString

    ; แสดง ASCII
    mov     ecx, 0
L_AsciiLoop:
    cmp     ecx, lineBytes
    jge     L_AsciiEnd

    mov     esi, pBuffer
    add     esi, curOffset
    mov     al, BYTE PTR [esi + ecx]

    ; กรอง Non-printable (น้อยกว่า 20h หรือมากกว่า 7Eh ให้แสดงเป็น '.')
    cmp     al, 20h
    jb      L_ShowDot
    cmp     al, 7Eh
    ja      L_ShowDot
    call    WriteChar
    jmp     L_NextAscii

L_ShowDot:
    mov     al, '.'
    call    WriteChar

L_NextAscii:
    inc     ecx
    jmp     L_AsciiLoop
L_AsciiEnd:

    call    Crlf
    add     curOffset, 16
    jmp     L_LineLoop

L_DumpEnd:
    pop     edi
    pop     esi
    pop     edx
    pop     ecx
    pop     ebx
    mov     eax, 0
    ret
DisplayHexDump ENDP

; -----------------------------------------------------------------------------
; ComputeBufferStats (Module D)
; -----------------------------------------------------------------------------
ComputeBufferStats PROC, pBuffer:PTR BYTE, bufferLen:DWORD
    push    ebx
    push    ecx
    push    edx
    push    esi
    push    edi

    ; ล้าง Histogram
    lea     edi, histTable
    mov     ecx, 256
    xor     eax, eax
    cld
    rep     stosd

    ; นับความถี่ไบต์
    mov     esi, pBuffer
    mov     ecx, bufferLen
    cmp     ecx, 0
    je      L_StatsDone

L_CountLoop:
    movzx   eax, BYTE PTR [esi]
    inc     DWORD PTR [histTable + eax*4]
    inc     esi
    dec     ecx
    jnz     L_CountLoop

    mov     edx, OFFSET hdrStats
    call    WriteString
    mov     edx, OFFSET topMsg
    call    WriteString

    ; ค้นหา Top Occurrences สูงสุด 3 อันดับ
    mov     ecx, 3              ; หา 3 อันดับแรก
L_FindTop:
    push    ecx
    mov     edx, 0              ; Max count
    mov     ebx, 0              ; Best byte
    mov     ecx, 0              ; Index 0..255

L_Scan:
    cmp     ecx, 256
    jge     L_ScanEnd
    mov     eax, DWORD PTR [histTable + ecx*4]
    cmp     eax, edx
    jbe     L_NextScan
    mov     edx, eax
    mov     ebx, ecx
L_NextScan:
    inc     ecx
    jmp     L_Scan
L_ScanEnd:

    cmp     edx, 0
    je      L_SkipPrintTop

    ; แสดงผลตัวอย่าง: [0xXX]: Count occurrences
    mov     al, '['
    call    WriteChar
    mov     al, '0'
    call    WriteChar
    mov     al, 'x'
    call    WriteChar
    mov     al, bl
    call    PrintByteHex
    mov     al, ']'
    call    WriteChar
    mov     al, ':'
    call    WriteChar
    mov     al, ' '
    call    WriteChar
    mov     eax, edx
    call    WriteDec
    call    Crlf

    ; เคลียร์ตำแหน่งเดิมเพื่อหาอันดับถัดไป
    mov     DWORD PTR [histTable + ebx*4], 0

L_SkipPrintTop:
    pop     ecx
    dec     ecx
    jnz     L_FindTop

L_StatsDone:
    pop     edi
    pop     esi
    pop     edx
    pop     ecx
    pop     ebx
    mov     eax, 0
    ret
ComputeBufferStats ENDP

END