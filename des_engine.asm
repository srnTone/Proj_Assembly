.686
.model flat, stdcall
.stack 4096

INCLUDE Irvine32.inc
INCLUDE des_shell.inc
INCLUDE des_tables.inc

.code

; -----------------------------------------------------------------------------
; Feistel Function f(R, Ki)
; -----------------------------------------------------------------------------
FeistelFunction PROC, rVal:DWORD, pSubkey:PTR BYTE
    LOCAL   expBuf[6]:BYTE

    push    ebx
    push    ecx
    push    edx
    push    esi
    push    edi

    lea     edi, expBuf
    mov     ecx, 6
    xor     al, al
    cld
    rep     stosb

    ; 1. Expansion (32 -> 48 bits)
    mov     ecx, 0
L_Exp:
    cmp     ecx, 48
    jge     L_Exp_End

    movzx   edx, BYTE PTR [E_Table + ecx]
    mov     eax, 32
    sub     eax, edx
    mov     ebx, rVal
    push    ecx
    mov     ecx, eax
    shr     ebx, cl
    pop     ecx
    and     ebx, 1

    mov     edx, ecx
    shr     edx, 3
    mov     eax, ecx
    and     eax, 7
    push    ecx
    mov     ecx, 7
    sub     ecx, eax
    shl     ebx, cl
    pop     ecx
    lea     edi, expBuf
    or      BYTE PTR [edi + edx], bl

    inc     ecx
    jmp     L_Exp
L_Exp_End:

    ; 2. XOR Subkey (6 bytes)
    mov     esi, pSubkey
    lea     edi, expBuf
    mov     ecx, 0
L_XorSub:
    cmp     ecx, 6
    jge     L_XorSub_End
    mov     al, BYTE PTR [esi + ecx]
    xor     BYTE PTR [edi + ecx], al
    inc     ecx
    jmp     L_XorSub
L_XorSub_End:

    ; 3. S-Boxes 1..8
    mov     ebx, 0              ; 32-bit output
    mov     ecx, 0              ; Box 0..7
L_SBox:
    cmp     ecx, 8
    jge     L_SBox_End

    ; ดึง 6 บิต
    push    ecx
    mov     edx, 0
    mov     edi, 0
L_Get6:
    cmp     edi, 6
    jge     L_Get6_Done

    mov     eax, ecx
    imul    eax, 6
    add     eax, edi            ; Bit index 0..47

    mov     esi, eax
    shr     esi, 3              ; Byte index 0..5
    and     eax, 7              ; Bit inside byte 0..7

    lea     edx, expBuf
    movzx   edx, BYTE PTR [edx + esi]
    push    ecx
    mov     ecx, 7
    sub     ecx, eax
    shr     edx, cl
    and     edx, 1
    pop     ecx

    ; เก็บเข้า stack ชั่วคราว
    push    edx
    inc     edi
    jmp     L_Get6

L_Get6_Done:
    ; รวมบิตจาก Stack ทั้ง 6 บิต
    pop     eax                 ; b0
    pop     esi                 ; b1
    shl     esi, 1
    or      eax, esi
    pop     esi                 ; b2
    shl     esi, 2
    or      eax, esi
    pop     esi                 ; b3
    shl     esi, 3
    or      eax, esi
    pop     esi                 ; b4
    shl     esi, 4
    or      eax, esi
    pop     esi                 ; b5
    shl     esi, 5
    or      eax, esi
    mov     edx, eax            ; edx = b5 b4 b3 b2 b1 b0
    pop     ecx                 ; คืนค่า Box index

    ; Row = (b5 << 1) | b0
    mov     eax, edx
    shr     eax, 4
    and     eax, 2
    mov     esi, edx
    and     esi, 1
    or      eax, esi            ; eax = Row (0..3)

    ; Col = (edx >> 1) & 0Fh
    mov     esi, edx
    shr     esi, 1
    and     esi, 0Fh            ; esi = Col (0..15)

    ; Offset = (ecx * 64) + (Row * 16) + Col
    shl     eax, 4
    add     eax, esi
    mov     edx, ecx
    shl     edx, 6
    add     eax, edx

    movzx   eax, BYTE PTR [S_Boxes + eax]
    shl     ebx, 4
    or      ebx, eax

    inc     ecx
    jmp     L_SBox
L_SBox_End:

    ; 4. Permutation P
    mov     edi, 0
    mov     ecx, 0
L_P:
    cmp     ecx, 32
    jge     L_P_End

    movzx   edx, BYTE PTR [P_Table + ecx]
    mov     eax, 32
    sub     eax, edx
    push    ecx
    mov     ecx, eax
    mov     eax, ebx
    shr     eax, cl
    and     eax, 1
    pop     ecx

    shl     edi, 1
    or      edi, eax

    inc     ecx
    jmp     L_P
L_P_End:

    mov     eax, edi

    pop     edi
    pop     esi
    pop     edx
    pop     ecx
    pop     ebx
    ret
FeistelFunction ENDP

; -----------------------------------------------------------------------------
; ProcessBlock (DES 64-bit Single Block Encrypt/Decrypt)
; -----------------------------------------------------------------------------
ProcessBlock PROC, pBlock:PTR BYTE, pSubkeys:PTR BYTE, isDecrypt:DWORD
    LOCAL   lVal:DWORD, rVal:DWORD, rndCount:DWORD

    push    ebx
    push    ecx
    push    edx
    push    esi
    push    edi

    ; 1. Initial Permutation (IP)
    mov     lVal, 0
    mov     rVal, 0

    mov     ecx, 0
L_IP_L:
    cmp     ecx, 32
    jge     L_IP_L_End
    movzx   eax, BYTE PTR [IP_Table + ecx]
    mov     esi, pBlock
    dec     eax
    mov     edx, eax
    shr     eax, 3
    and     edx, 7
    movzx   ebx, BYTE PTR [esi + eax]
    push    ecx
    mov     ecx, 7
    sub     ecx, edx
    shr     ebx, cl
    pop     ecx
    and     ebx, 1

    mov     eax, lVal
    shl     eax, 1
    or      eax, ebx
    mov     lVal, eax
    inc     ecx
    jmp     L_IP_L
L_IP_L_End:

    mov     ecx, 32
L_IP_R:
    cmp     ecx, 64
    jge     L_IP_R_End
    movzx   eax, BYTE PTR [IP_Table + ecx]
    mov     esi, pBlock
    dec     eax
    mov     edx, eax
    shr     eax, 3
    and     edx, 7
    movzx   ebx, BYTE PTR [esi + eax]
    push    ecx
    mov     ecx, 7
    sub     ecx, edx
    shr     ebx, cl
    pop     ecx
    and     ebx, 1

    mov     eax, rVal
    shl     eax, 1
    or      eax, ebx
    mov     rVal, eax
    inc     ecx
    jmp     L_IP_R
L_IP_R_End:

    ; 2. Feistel 16 Rounds
    mov     rndCount, 0
L_Rounds:
    cmp     rndCount, 16
    jge     L_Rounds_End

    mov     eax, rndCount
    cmp     isDecrypt, 0
    je      L_UseFwdKey
    mov     eax, 15
    sub     eax, rndCount
L_UseFwdKey:
    imul    eax, 6
    add     eax, pSubkeys

    INVOKE  FeistelFunction, rVal, eax

    mov     ebx, lVal
    xor     ebx, eax

    mov     eax, rVal
    mov     lVal, eax
    mov     rVal, ebx

    inc     rndCount
    jmp     L_Rounds
L_Rounds_End:

    ; Preoutput Swap (R16 : L16)
    mov     eax, rVal
    mov     ebx, lVal
    bswap   eax
    bswap   ebx
    mov     esi, pBlock
    mov     DWORD PTR [esi], eax
    mov     DWORD PTR [esi+4], ebx

    ; 3. Inverse Initial Permutation (IP^-1)
    mov     lVal, 0
    mov     rVal, 0

    mov     ecx, 0
L_IP_INV_1:
    cmp     ecx, 32
    jge     L_IP_INV_1_End
    movzx   eax, BYTE PTR [IP_INV_Table + ecx]
    mov     esi, pBlock
    dec     eax
    mov     edx, eax
    shr     eax, 3
    and     edx, 7
    movzx   ebx, BYTE PTR [esi + eax]
    push    ecx
    mov     ecx, 7
    sub     ecx, edx
    shr     ebx, cl
    pop     ecx
    and     ebx, 1

    mov     eax, lVal
    shl     eax, 1
    or      eax, ebx
    mov     lVal, eax
    inc     ecx
    jmp     L_IP_INV_1
L_IP_INV_1_End:

    mov     ecx, 32
L_IP_INV_2:
    cmp     ecx, 64
    jge     L_IP_INV_2_End
    movzx   eax, BYTE PTR [IP_INV_Table + ecx]
    mov     esi, pBlock
    dec     eax
    mov     edx, eax
    shr     eax, 3
    and     edx, 7
    movzx   ebx, BYTE PTR [esi + eax]
    push    ecx
    mov     ecx, 7
    sub     ecx, edx
    shr     ebx, cl
    pop     ecx
    and     ebx, 1

    mov     eax, rVal
    shl     eax, 1
    or      eax, ebx
    mov     rVal, eax
    inc     ecx
    jmp     L_IP_INV_2
L_IP_INV_2_End:

    mov     eax, lVal
    mov     ebx, rVal
    bswap   eax
    bswap   ebx
    mov     esi, pBlock
    mov     DWORD PTR [esi], eax
    mov     DWORD PTR [esi+4], ebx

    pop     edi
    pop     esi
    pop     edx
    pop     ecx
    pop     ebx
    mov     eax, 0
    ret
ProcessBlock ENDP

; -----------------------------------------------------------------------------
; ApplyPKCS7: เติม Padding ตามมาตรฐาน PKCS#7
; Return: EAX = ขนาดความยาวข้อมูลใหม่หลัง Pad
; -----------------------------------------------------------------------------
ApplyPKCS7 PROC, pBuffer:PTR BYTE, dataLen:DWORD
    push    ebx
    push    ecx
    push    edi

    mov     eax, dataLen
    mov     edx, 0
    mov     ebx, 8
    div     ebx                 ; edx = dataLen % 8
    mov     ecx, 8
    sub     ecx, edx            ; ecx = จำนวนไบต์ที่ต้อง Pad (1..8)

    mov     edi, pBuffer
    add     edi, dataLen
    mov     al, cl

L_PadLoop:
    mov     BYTE PTR [edi], al
    inc     edi
    dec     ecx
    jnz     L_PadLoop

    mov     eax, dataLen
    mov     edx, 0
    div     ebx
    inc     eax
    imul    eax, 8              ; EAX = ขนาดความยาวใหม่

    pop     edi
    pop     ecx
    pop     ebx
    ret
ApplyPKCS7 ENDP

; -----------------------------------------------------------------------------
; RemovePKCS7: ตัด Padding ออก
; Return: EAX = ขนาดความยาวข้อมูลจริง (หรือ -1 ถ้า Padding ไม่ถูกต้อง)
; -----------------------------------------------------------------------------
RemovePKCS7 PROC, pBuffer:PTR BYTE, dataLen:DWORD
    push    ebx
    push    ecx
    push    esi

    mov     esi, pBuffer
    add     esi, dataLen
    dec     esi
    movzx   eax, BYTE PTR [esi] ; ค่า Pad byte (เช่น 01h..08h)

    cmp     eax, 1
    jb      L_BadPad
    cmp     eax, 8
    ja      L_BadPad

    mov     ecx, eax
    mov     ebx, eax
L_CheckPad:
    cmp     BYTE PTR [esi], bl
    jne     L_BadPad
    dec     esi
    dec     ecx
    jnz     L_CheckPad

    mov     eax, dataLen
    sub     eax, ebx            ; คืนค่าความยาวที่แท้จริง
    jmp     L_PadDone

L_BadPad:
    mov     eax, -1

L_PadDone:
    pop     esi
    pop     ecx
    pop     ebx
    ret
RemovePKCS7 ENDP

END