======================================================================
รายวิชา 01476105 Computer Organization and Assembly Language
งาน: Command-Line Shell & File Encryption Engine (Classical DES)
======================================================================

[ รายชื่อสมาชิกในกลุ่ม ]
1. นายศรัณย์ คงดำ     รหัสนักศึกษา: 68011813
2. นายฆฤณ มาสง      รหัสนักศึกษา: 68010126
3. นายศุภกร แพฟื้น     รหัสนักศึกษา: 68011820
4. นายพชร มะโน       รหัสนักศึกษา: 68010736

[ หน้าที่ความรับผิดชอบ ]
- Module A (Shell Core & FSM Parser):
  ผู้รับผิดชอบ: นายศรัณย์ คงดำ
  ไฟล์ที่พัฒนา: main.asm, parser.asm, des_shell.inc, build.bat

- Module B (DES Key Schedule Generator):
  ผู้รับผิดชอบ: นายฆฤณ มาสง
  ไฟล์ที่พัฒนา: key_schedule.asm, des_tables.inc

- Module C (DES 16-Round Feistel Core Engine & PKCS#7 Padding):
  ผู้รับผิดชอบ: นายศุภกร แพฟื้น
  ไฟล์ที่พัฒนา: des_engine.asm, file_io.asm

- Module D (Hex Dumper & Buffer Statistics Analytics):
  ผู้รับผิดชอบ: นายพชร มะโน
  ไฟล์ที่พัฒนา: dumper.asm, readme.txt, Data_Test.txt
======================================================================

[ Test Procedures - ขั้นตอนการทดสอบระบบ ]

1. ตรวจสอบและคอมไพล์ระบบ
   คำสั่ง: .\build.bat
   ผลลัพธ์: คอมไพล์ผ่านสมบูรณ์ ไม่เกิด Link Error แสดงแบนเนอร์และขึ้นหน้าจอพร้อมต์ DES-SHELL>

2. ทดสอบสร้าง Round Keys (KEYGEN)
   คำสั่ง: KEYGEN 0x133457799BBCDFF1
   ผลลัพธ์: ระบบพิมพ์ Subkeys ออกมาครบทั้ง 16 รอบ (K1 ถึง K16) แต่ละรอบมีขนาด 6 ไบต์ (48 บิต)

3. ตรวจสอบไฟล์ต้นฉบับ (DUMP)
   คำสั่ง: DUMP "Data_Test.txt"
   ผลลัพธ์: แสดงโครงสร้าง Hex Dump 16 ไบต์/บรรทัด พร้อม Address และคอลัมน์ ASCII ของข้อความต้นฉบับ

4. ทดสอบการเข้ารหัสไฟล์ (ENCRYPT)
   คำสั่ง: ENCRYPT "Data_Test.txt" 0x133457799BBCDFF1
   ผลลัพธ์: แสดงข้อความ "File encrypted successfully -> Data_Test.txt.enc"
            สร้างไฟล์ใหม่ชื่อ Data_Test.txt.enc บนดิสก์ โดยขนาดไฟล์จะเพิ่มขึ้นตาม PKCS#7 Padding

5. ตรวจสอบไฟล์ที่เข้ารหัสและดูสถิติ (DUMP & STATS)
   คำสั่ง: DUMP "Data_Test.txt.enc"
           STATS "Data_Test.txt.enc"
   ผลลัพธ์: คำสั่ง DUMP แสดงไบต์ที่กลายเป็น Ciphertext อ่านไม่ออก
            คำสั่ง STATS คำนวณการกระจายตัวของไบต์ลงใน 256 Bins และรายงาน Top Byte 3 อันดับแรก

6. ทดสอบการถอดรหัสไฟล์ (DECRYPT)
   คำสั่ง: DECRYPT "Data_Test.txt.enc" 0x133457799BBCDFF1
   ผลลัพธ์: แสดงข้อความ "File decrypted successfully -> Data_Test.txt.enc.dec"
            สร้างไฟล์ใหม่ชื่อ Data_Test.txt.enc.dec และถอด PKCS#7 Padding สำเร็จโดยไม่ฟ้อง Error

7. ยืนยันความถูกต้องของข้อมูล
   คำสั่ง: DUMP "Data_Test.txt.enc.dec"
   ผลลัพธ์: ตัวอักษร ASCII ในคอลัมน์ขวาสุดตรงกับเนื้อหาดั้งเดิมใน Data_Test.txt ทุกประการ

8. ออกจากโปรแกรม
   คำสั่ง: EXIT
   ผลลัพธ์: แสดงข้อความ "Exiting DES Command-Line Shell..." ปิดโปรแกรมและคืนค่า Exit Code อย่างปลอดภัย

======================================================================
[ ขั้นตอนการพัฒนา Classical DES ]
======================================================================

Step 1: วางโครงสร้างและเตรียมตารางข้อมูล
1. สร้างไฟล์ des_tables.inc: รวมตารางค่าคงที่ตามมาตรฐาน FIPS PUB 46-3 ไว้ทั้งหมด
2. สร้างไฟล์ des_shell.inc: กำหนด Interface ส่วนกลางโดยประกาศ PROTO ของทุกฟังก์ชันที่จะเรียกข้ามโมดูล

Step 2: พัฒนาโมดูลย่อย
- Module B (key_schedule.asm):
  - เขียนฟังก์ชันดึงบิตแบบ 1-based index (GetBitFromBuffer)
  - เขียนฟังก์ชันหมุนบิตซ้ายเฉพาะ 28 บิต (RotL28)
  - รวมลูป 16 รอบเพื่อสร้าง K1-K16 ขนาดรวม 96 ไบต์

- Module C (des_engine.asm & file_io.asm):
  - เขียนการแทนค่า S-Box และการขยายบิต E-Table/P-Table ใน FeistelFunction
  - รวม Feistel เข้ากับลูป IP และ IP^-1 ใน ProcessBlock รองรับทั้ง Encrypt และ Decrypt
  - เขียนฟังก์ชันคำนวณและตรวจสอบ PKCS#7 Padding
  - สร้างฟังก์ชัน Win32 I/O ใน file_io.asm สำหรับอ่านและเขียนไฟล์ไบนารีขนาด 4KB

- Module D (dumper.asm):
  - เขียนลูปวนอ่านบัฟเฟอร์แสดงผล Hex Viewer 16 ไบต์ พร้อมคอลัมน์ ASCII และกรองช่วง 20h - 7Eh
  - จัดสรร Memory Array ขนาด 256 DWORD เพื่อทำ Histogram นับความถี่ไบต์ และค้นหา Top 3

Step 3: พัฒนาระบบ Shell และ FSM Parser (Module A)
  - เขียน FSM ใน parser.asm เพื่อแยกสตริงจาก inputLine รองรับชื่อไฟล์ในเครื่องหมายคำพูด เช่น "data.txt"
  - เขียนฟังก์ชัน ParseHex64 แปลงสตริง Hex 16 ตัว ให้เป็นข้อมูล 8 ไบต์จริงในหน่วยความจำ
  - เขียนฟังก์ชัน StrCompareI สำหรับเปรียบเทียบคำสั่งแบบ Case-Insensitive

Step 4: เชื่อมต่อระบบ (Integration ใน main.asm) และเขียน build.bat
  - นำทุกโมดูลมารวมเข้ากับ REPL Loop ใน main.asm เพื่อ Dispatch คำสั่งทั้ง 7:
    - KEYGEN  -> ParseHex64 -> GenerateKeySchedule -> วนลูปพิมพ์ K1-K16
    - ENCRYPT -> อ่านไฟล์ -> ใส่ PKCS#7 -> วนลูปบล็อกละ 8 ไบต์ -> เขียนไฟล์ .enc
    - DECRYPT -> อ่านไฟล์ .enc -> วนลูปถอดรหัส -> ตัด PKCS#7 -> เขียนไฟล์ .dec
    - DUMP    -> อ่านไฟล์ -> เรียก DisplayHexDump
    - STATS   -> อ่านไฟล์ -> เรียก ComputeBufferStats
    - CLEAR   -> ล้างหน้าจอด้วย Clrscr
    - EXIT    -> คืนค่าและออกจากโปรแกรมอย่างปลอดภัย
  - ทำสคริปต์ build.bat สั่งคอมไพล์ทุกไฟล์และวาง main.obj ไว้หน้าสุดในคำสั่ง link.exe

Step 5: ทดสอบความถูกต้อง
  - ใช้ไฟล์ Data_Test.txt รันกระบวนการเข้ารหัสและถอดรหัส ตรวจสอบว่าไฟล์ .dec ตรงกับต้นฉบับไบต์ต่อไบต์
======================================================================
