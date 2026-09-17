.686
.model flat, stdcall
.stack 4096
ExitProcess PROTO, dwExitCode:DWORD

INCLUDE Irvine32.inc
INCLUDE des_shell.inc

; Prototype จาก parser.asm
StrCompareI      PROTO, pStr1:PTR BYTE, pStr2:PTR BYTE
ExtractFilename  PROTO, pIn:PTR BYTE, pOut:PTR BYTE
ParseHex64       PROTO, pHexStr:PTR BYTE, pOutBuf:PTR BYTE

.data
    promptStr       BYTE "DES-SHELL> ", 0
    welcomeMsg      BYTE "=================================================", 0Dh, 0Ah
                    BYTE "   DES Command-Line Shell & Encryption Engine    ", 0Dh, 0Ah
                    BYTE "   Commands: KEYGEN, ENCRYPT, DECRYPT, DUMP,     ", 0Dh, 0Ah
                    BYTE "             STATS, CLEAR, EXIT                  ", 0Dh, 0Ah
                    BYTE "=================================================", 0Dh, 0Ah, 0
    exitMsg         BYTE "Exiting DES Command-Line Shell...", 0Dh, 0Ah, 0
    errCmdMsg       BYTE "Error: Unknown command.", 0Dh, 0Ah, 0
    errKeyMsg       BYTE "Error: Invalid key format. Expected 16-hex digits.", 0Dh, 0Ah, 0
    errFileMsg      BYTE "Error: Cannot open or read file.", 0Dh, 0Ah, 0
    encSuccessMsg   BYTE "File encrypted successfully -> ", 0
    decSuccessMsg   BYTE "File decrypted successfully -> ", 0
    dotEncExt       BYTE ".enc", 0
    dotDecExt       BYTE ".dec", 0

    ; Command Strings
    cmdExit         BYTE "EXIT", 0
    cmdClear        BYTE "CLEAR", 0
    cmdKeygen       BYTE "KEYGEN", 0
    cmdEncrypt      BYTE "ENCRYPT", 0
    cmdDecrypt      BYTE "DECRYPT", 0
    cmdDump         BYTE "DUMP", 0
    cmdStats        BYTE "STATS", 0

    kPrefix         BYTE "K", 0
    colonSpace      BYTE ": ", 0

    ; Buffers
    inputLine       BYTE 256 DUP(0)
    tokenCmd        BYTE 32 DUP(0)
    paramFile       BYTE 128 DUP(0)
    outFileName     BYTE 132 DUP(0)
    masterKey       BYTE 8 DUP(0)
    RoundKeys       BYTE 96 DUP(0)

    ; File Data Buffer (4KB)
    fileBuffer      BYTE 4096 DUP(0)

.code

; -----------------------------------------------------------------------------
; AppendExtension Helper
; -----------------------------------------------------------------------------
AppendExtension PROC, pSrc:PTR BYTE, pExt:PTR BYTE, pDst:PTR BYTE
    push    esi
    push    edi

    mov     esi, pSrc
    mov     edi, pDst
L_CopySrc:
    mov     al, BYTE PTR [esi]
    cmp     al, 0
    je      L_CopyExt
    mov     BYTE PTR [edi], al
    inc     esi
    inc     edi
    jmp     L_CopySrc

L_CopyExt:
    mov     esi, pExt
L_CopyExtLoop:
    mov     al, BYTE PTR [esi]
    mov     BYTE PTR [edi], al
    cmp     al, 0
    je      L_ExtDone
    inc     esi
    inc     edi
    jmp     L_CopyExtLoop

L_ExtDone:
    pop     edi
    pop     esi
    ret
AppendExtension ENDP

; -----------------------------------------------------------------------------
; Shell Loop
; -----------------------------------------------------------------------------
ShellLoop PROC
    push    ebp
    mov     ebp, esp

    mov     edx, OFFSET welcomeMsg
    call    WriteString

L_PromptLoop:
    mov     edx, OFFSET promptStr
    call    WriteString

    mov     edx, OFFSET inputLine
    mov     ecx, SIZEOF inputLine
    call    ReadString
    cmp     eax, 0
    je      L_PromptLoop

    ; แยก Token คำสั่งแรก
    mov     esi, OFFSET inputLine
    mov     edi, OFFSET tokenCmd

L_SkipSpace:
    mov     al, BYTE PTR [esi]
    cmp     al, ' '
    jne     L_ReadCmd
    inc     esi
    jmp     L_SkipSpace

L_ReadCmd:
    mov     al, BYTE PTR [esi]
    cmp     al, 0
    je      L_CmdTerm
    cmp     al, ' '
    je      L_CmdTerm
    mov     BYTE PTR [edi], al
    inc     esi
    inc     edi
    jmp     L_ReadCmd
L_CmdTerm:
    mov     BYTE PTR [edi], 0

    ; Dispatcher
    INVOKE  StrCompareI, OFFSET tokenCmd, OFFSET cmdExit
    cmp     eax, 0
    je      L_ExecExit

    INVOKE  StrCompareI, OFFSET tokenCmd, OFFSET cmdClear
    cmp     eax, 0
    je      L_ExecClear

    INVOKE  StrCompareI, OFFSET tokenCmd, OFFSET cmdKeygen
    cmp     eax, 0
    je      L_ExecKeygen

    INVOKE  StrCompareI, OFFSET tokenCmd, OFFSET cmdDump
    cmp     eax, 0
    je      L_ExecDump

    INVOKE  StrCompareI, OFFSET tokenCmd, OFFSET cmdStats
    cmp     eax, 0
    je      L_ExecStats

    INVOKE  StrCompareI, OFFSET tokenCmd, OFFSET cmdEncrypt
    cmp     eax, 0
    je      L_ExecEncrypt

    INVOKE  StrCompareI, OFFSET tokenCmd, OFFSET cmdDecrypt
    cmp     eax, 0
    je      L_ExecDecrypt

    mov     edx, OFFSET errCmdMsg
    call    WriteString
    jmp     L_PromptLoop

L_ExecClear:
    call    Clrscr
    jmp     L_PromptLoop

L_ExecKeygen:
    INVOKE  ParseHex64, esi, OFFSET masterKey
    cmp     eax, 0
    jne     L_KeyErr

    INVOKE  GenerateKeySchedule, OFFSET masterKey, OFFSET RoundKeys

    mov     esi, OFFSET RoundKeys
    mov     ebx, 1
L_PrnKeys:
    cmp     ebx, 16
    jg      L_PromptLoop
    mov     edx, OFFSET kPrefix
    call    WriteString
    mov     eax, ebx
    call    WriteDec
    mov     edx, OFFSET colonSpace
    call    WriteString

    mov     ecx, 6
L_PrnSub:
    movzx   eax, BYTE PTR [esi]
    call    PrintByteHex
    mov     al, ' '
    call    WriteChar
    inc     esi
    dec     ecx
    jnz     L_PrnSub
    call    Crlf
    inc     ebx
    jmp     L_PrnKeys

L_KeyErr:
    mov     edx, OFFSET errKeyMsg
    call    WriteString
    jmp     L_PromptLoop

L_ExecDump:
    INVOKE  ExtractFilename, esi, OFFSET paramFile
    INVOKE  ReadFileToBuffer, OFFSET paramFile, OFFSET fileBuffer, SIZEOF fileBuffer
    cmp     eax, -1
    je      L_FileErr
    INVOKE  DisplayHexDump, OFFSET fileBuffer, eax
    jmp     L_PromptLoop

L_ExecStats:
    INVOKE  ExtractFilename, esi, OFFSET paramFile
    INVOKE  ReadFileToBuffer, OFFSET paramFile, OFFSET fileBuffer, SIZEOF fileBuffer
    cmp     eax, -1
    je      L_FileErr
    INVOKE  ComputeBufferStats, OFFSET fileBuffer, eax
    jmp     L_PromptLoop

L_ExecEncrypt:
    INVOKE  ExtractFilename, esi, OFFSET paramFile
    mov     esi, eax            ; ตำแหน่ง Key
    INVOKE  ParseHex64, esi, OFFSET masterKey
    cmp     eax, 0
    jne     L_KeyErr

    INVOKE  ReadFileToBuffer, OFFSET paramFile, OFFSET fileBuffer, 4000
    cmp     eax, -1
    je      L_FileErr

    ; Apply PKCS#7 Padding
    INVOKE  ApplyPKCS7, OFFSET fileBuffer, eax
    mov     ebx, eax            ; ขนาดใหม่

    ; Key Schedule
    INVOKE  GenerateKeySchedule, OFFSET masterKey, OFFSET RoundKeys

    ; วนลูป ECB ทีละ 8 ไบต์
    mov     ecx, 0
L_ECB_Enc:
    cmp     ecx, ebx
    jge     L_ECB_EncDone
    push    ecx
    push    ebx
    lea     eax, [fileBuffer + ecx]
    INVOKE  ProcessBlock, eax, OFFSET RoundKeys, 0
    pop     ebx
    pop     ecx
    add     ecx, 8
    jmp     L_ECB_Enc
L_ECB_EncDone:

    ; เขียนลงไฟล์ .enc
    INVOKE  AppendExtension, OFFSET paramFile, OFFSET dotEncExt, OFFSET outFileName
    INVOKE  WriteBufferToFile, OFFSET outFileName, OFFSET fileBuffer, ebx

    mov     edx, OFFSET encSuccessMsg
    call    WriteString
    mov     edx, OFFSET outFileName
    call    WriteString
    call    Crlf
    jmp     L_PromptLoop

L_ExecDecrypt:
    INVOKE  ExtractFilename, esi, OFFSET paramFile
    mov     esi, eax
    INVOKE  ParseHex64, esi, OFFSET masterKey
    cmp     eax, 0
    jne     L_KeyErr

    INVOKE  ReadFileToBuffer, OFFSET paramFile, OFFSET fileBuffer, SIZEOF fileBuffer
    cmp     eax, -1
    je      L_FileErr
    mov     ebx, eax

    INVOKE  GenerateKeySchedule, OFFSET masterKey, OFFSET RoundKeys

    mov     ecx, 0
L_ECB_Dec:
    cmp     ecx, ebx
    jge     L_ECB_DecDone
    push    ecx
    push    ebx
    lea     eax, [fileBuffer + ecx]
    INVOKE  ProcessBlock, eax, OFFSET RoundKeys, 1
    pop     ebx
    pop     ecx
    add     ecx, 8
    jmp     L_ECB_Dec
L_ECB_DecDone:

    ; ลบ PKCS#7 Padding
    INVOKE  RemovePKCS7, OFFSET fileBuffer, ebx
    cmp     eax, -1
    je      L_FileErr
    mov     ebx, eax

    ; เขียนลงไฟล์ .dec
    INVOKE  AppendExtension, OFFSET paramFile, OFFSET dotDecExt, OFFSET outFileName
    INVOKE  WriteBufferToFile, OFFSET outFileName, OFFSET fileBuffer, ebx

    mov     edx, OFFSET decSuccessMsg
    call    WriteString
    mov     edx, OFFSET outFileName
    call    WriteString
    call    Crlf
    jmp     L_PromptLoop

L_FileErr:
    mov     edx, OFFSET errFileMsg
    call    WriteString
    jmp     L_PromptLoop

L_ExecExit:
    mov     edx, OFFSET exitMsg
    call    WriteString

    mov     esp, ebp
    pop     ebp
    ret
ShellLoop ENDP

main PROC
    call    ShellLoop
    INVOKE  ExitProcess, 0
main ENDP
END main