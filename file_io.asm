.686
.model flat, stdcall
.stack 4096

INCLUDE Irvine32.inc
INCLUDE des_shell.inc

.code

; -----------------------------------------------------------------------------
; ReadFileToBuffer
; Output: EAX = จำนวนไบต์ที่อ่านได้ (หรือ -1 ถ้าล้มเหลว)
; -----------------------------------------------------------------------------
ReadFileToBuffer PROC, pFileName:PTR BYTE, pBuffer:PTR BYTE, maxLen:DWORD
    LOCAL   fileHandle:DWORD

    push    edx
    push    esi

    mov     edx, pFileName
    call    OpenInputFile
    mov     fileHandle, eax
    cmp     eax, INVALID_HANDLE_VALUE
    je      L_ReadErr

    mov     eax, fileHandle
    mov     edx, pBuffer
    mov     ecx, maxLen
    call    ReadFromFile
    push    eax                 ; เก็บจำนวนไบต์ที่อ่านได้

    mov     eax, fileHandle
    call    CloseFile

    pop     eax
    jmp     L_ReadExit

L_ReadErr:
    mov     eax, -1

L_ReadExit:
    pop     esi
    pop     edx
    ret
ReadFileToBuffer ENDP

; -----------------------------------------------------------------------------
; WriteBufferToFile
; Output: EAX = จำนวนไบต์ที่เขียน (หรือ -1 ถ้าล้มเหลว)
; -----------------------------------------------------------------------------
WriteBufferToFile PROC, pFileName:PTR BYTE, pBuffer:PTR BYTE, writeLen:DWORD
    LOCAL   fileHandle:DWORD

    push    edx

    mov     edx, pFileName
    call    CreateOutputFile
    mov     fileHandle, eax
    cmp     eax, INVALID_HANDLE_VALUE
    je      L_WriteErr

    mov     eax, fileHandle
    mov     edx, pBuffer
    mov     ecx, writeLen
    call    WriteToFile
    push    eax

    mov     eax, fileHandle
    call    CloseFile

    pop     eax
    jmp     L_WriteExit

L_WriteErr:
    mov     eax, -1

L_WriteExit:
    pop     edx
    ret
WriteBufferToFile ENDP

END