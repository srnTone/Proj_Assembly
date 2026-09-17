.686
.model flat, stdcall
.stack 4096

INCLUDE Irvine32.inc
INCLUDE des_shell.inc
INCLUDE des_tables.inc

.code

; -----------------------------------------------------------------------------
; Helper: PrintByteHex (พิมพ์ Hex 1 ไบต์แบบ 2 หลัก)
; -----------------------------------------------------------------------------
PrintByteHex PROC
    push    ebp
    mov     ebp, esp
    push    eax
    push    ebx

    mov     bl, al
    shr     al, 4
    and     al, 0Fh
    cmp     al, 9
    jbe     L_H1
    add     al, 7
L_H1:
    add     al, '0'
    call    WriteChar

    mov     al, bl
    and     al, 0Fh
    cmp     al, 9
    jbe     L_H2
    add     al, 7
L_H2:
    add     al, '0'
    call    WriteChar

    pop     ebx
    pop     eax
    mov     esp, ebp
    pop     ebp
    ret
PrintByteHex ENDP

; -----------------------------------------------------------------------------
; Helper: GetBitFromBuffer
; ESI = buffer pointer, EAX = 1-based bit position (1..N)
; Output: AL = bit (0 หรือ 1)
; -----------------------------------------------------------------------------
GetBitFromBuffer PROC
    push    ebp
    mov     ebp, esp
    push    ebx
    push    ecx
    push    edx

    dec     eax
    mov     edx, eax
    shr     eax, 3
    and     edx, 7

    movzx   ebx, BYTE PTR [esi + eax]
    mov     ecx, 7
    sub     ecx, edx
    shr     ebx, cl
    and     ebx, 1
    mov     al, bl

    pop     edx
    pop     ecx
    pop     ebx
    mov     esp, ebp
    pop     ebp
    ret
GetBitFromBuffer ENDP

; -----------------------------------------------------------------------------
; Helper: RotL28 (หมุนบิตซ้าย 28 บิต)
; -----------------------------------------------------------------------------
RotL28 PROC
    push    ebp
    mov     ebp, esp
    push    ebx

    shl     eax, cl
    mov     ebx, eax
    shr     ebx, 28
    or      eax, ebx
    and     eax, 0FFFFFFFh

    pop     ebx
    mov     esp, ebp
    pop     ebp
    ret
RotL28 ENDP

; -----------------------------------------------------------------------------
; GenerateKeySchedule (Module B)
; Input:  pMasterKey (64-bit key buffer), pSubkeys (96-byte output buffer)
; Output: EAX = 0 (Success)
; -----------------------------------------------------------------------------
GenerateKeySchedule PROC, pMasterKey:PTR BYTE, pSubkeys:PTR BYTE
    LOCAL   cVal:DWORD, dVal:DWORD, rndIdx:DWORD
    LOCAL   cdBuf[8]:BYTE

    push    ebx
    push    ecx
    push    edx
    push    esi
    push    edi

    mov     cVal, 0
    mov     dVal, 0

    ; 1. สร้าง C0 (28 บิตแรกของ PC-1)
    mov     ecx, 0
L_PC1_C:
    cmp     ecx, 28
    jge     L_PC1_C_End
    movzx   eax, BYTE PTR [PC1_Table + ecx]
    mov     esi, pMasterKey
    call    GetBitFromBuffer
    movzx   eax, al
    mov     ebx, cVal
    shl     ebx, 1
    or      ebx, eax
    mov     cVal, ebx
    inc     ecx
    jmp     L_PC1_C
L_PC1_C_End:

    ; 2. สร้าง D0 (28 บิตหลังของ PC-1)
    mov     ecx, 28
L_PC1_D:
    cmp     ecx, 56
    jge     L_PC1_D_End
    movzx   eax, BYTE PTR [PC1_Table + ecx]
    mov     esi, pMasterKey
    call    GetBitFromBuffer
    movzx   eax, al
    mov     ebx, dVal
    shl     ebx, 1
    or      ebx, eax
    mov     dVal, ebx
    inc     ecx
    jmp     L_PC1_D
L_PC1_D_End:

    ; 3. วนลูป 16 รอบ สร้าง Subkeys K1 ถึง K16
    mov     rndIdx, 0
L_RoundLoop:
    cmp     rndIdx, 16
    jge     L_RoundLoop_End

    ; หมุนซ้าย Ci และ Di ตามตาราง Key_Shifts
    mov     edx, rndIdx
    movzx   ecx, BYTE PTR [Key_Shifts + edx]
    mov     eax, cVal
    call    RotL28
    mov     cVal, eax

    mov     eax, dVal
    call    RotL28
    mov     dVal, eax

    ; รวม C (28 บิต) และ D (28 บิต) ลงใน cdBuf (56 บิต)
    lea     edi, cdBuf
    mov     ecx, 8
    xor     al, al
    cld
    rep     stosb

    mov     ecx, 0
L_BuildCD:
    cmp     ecx, 56
    jge     L_BuildCD_End
    cmp     ecx, 28
    jge     L_BuildFromD

    ; ดึงจาก C
    mov     edx, 27
    sub     edx, ecx
    mov     eax, cVal
    push    ecx
    mov     ecx, edx
    shr     eax, cl
    pop     ecx
    and     eax, 1
    jmp     L_PutBitCD

L_BuildFromD:
    ; ดึงจาก D
    mov     edx, 55
    sub     edx, ecx
    mov     eax, dVal
    push    ecx
    mov     ecx, edx
    shr     eax, cl
    pop     ecx
    and     eax, 1

L_PutBitCD:
    mov     edx, ecx
    shr     edx, 3
    mov     ebx, ecx
    and     ebx, 7
    push    ecx
    mov     ecx, 7
    sub     ecx, ebx
    shl     eax, cl
    pop     ecx
    lea     esi, cdBuf
    or      BYTE PTR [esi + edx], al

    inc     ecx
    jmp     L_BuildCD
L_BuildCD_End:

    ; กำหนดตำแหน่งปลายทาง Subkey Ki (6 ไบต์ต่อรอบ)
    mov     edi, pSubkeys
    mov     eax, rndIdx
    imul    eax, 6
    add     edi, eax

    mov     BYTE PTR [edi], 0
    mov     BYTE PTR [edi+1], 0
    mov     BYTE PTR [edi+2], 0
    mov     BYTE PTR [edi+3], 0
    mov     BYTE PTR [edi+4], 0
    mov     BYTE PTR [edi+5], 0

    ; ทำ PC-2 ดึง 48 บิต
    mov     ecx, 0
L_PC2_Loop:
    cmp     ecx, 48
    jge     L_PC2_End

    movzx   eax, BYTE PTR [PC2_Table + ecx]
    lea     esi, cdBuf
    call    GetBitFromBuffer
    movzx   ebx, al

    mov     edx, ecx
    shr     edx, 3
    mov     eax, ecx
    and     eax, 7
    push    ecx
    mov     ecx, 7
    sub     ecx, eax
    shl     ebx, cl
    pop     ecx
    or      BYTE PTR [edi + edx], bl

    inc     ecx
    jmp     L_PC2_Loop
L_PC2_End:

    inc     rndIdx
    jmp     L_RoundLoop
L_RoundLoop_End:

    pop     edi
    pop     esi
    pop     edx
    pop     ecx
    pop     ebx
    mov     eax, 0
    ret
GenerateKeySchedule ENDP

END