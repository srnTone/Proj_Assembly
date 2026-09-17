; =============================================================================
; des_shell.inc - Shared Prototypes and Externals
; =============================================================================

; Module B: Key Schedule
GenerateKeySchedule PROTO, pMasterKey:PTR BYTE, pSubkeys:PTR BYTE
PrintByteHex        PROTO

; Module C: Feistel Engine & ECB
ProcessBlock        PROTO, pBlock:PTR BYTE, pSubkeys:PTR BYTE, isDecrypt:DWORD
ApplyPKCS7          PROTO, pBuffer:PTR BYTE, dataLen:DWORD
RemovePKCS7         PROTO, pBuffer:PTR BYTE, dataLen:DWORD

; Module D: Analytics
DisplayHexDump      PROTO, pBuffer:PTR BYTE, bufferLen:DWORD
ComputeBufferStats  PROTO, pBuffer:PTR BYTE, bufferLen:DWORD

; File I/O Helpers
ReadFileToBuffer    PROTO, pFileName:PTR BYTE, pBuffer:PTR BYTE, maxLen:DWORD
WriteBufferToFile   PROTO, pFileName:PTR BYTE, pBuffer:PTR BYTE, writeLen:DWORD