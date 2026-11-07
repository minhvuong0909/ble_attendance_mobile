# Kịch bản demo 2 điện thoại (khoảng 20 phút, có bản rút gọn 12 phút)

**Vai trò:** điện thoại A = giảng viên `gv1` (app), điện thoại B = sinh viên (app, đổi tài khoản bằng Đăng xuất / Đăng nhập), laptop = admin `admin` (web) và, khi cần, giảng viên trên web để xuất Excel. Mật khẩu mọi tài khoản demo: `123456`.

**Khác bản 1 điện thoại:** không cần script `ble_teacher_sim.py`. Điện thoại giảng viên **vừa phát vừa quét** thật, nên thẻ BLE trên máy sinh viên chạy đúng ("trong phạm vi / ở xa lớp học"). App giảng viên gửi lô detection mỗi **30 giây** (script chỉ 10 giây).

> **Chưa kiểm chứng:** phần "điện thoại giảng viên quét sinh viên" và thẻ gần/xa trên máy sinh viên **chưa được thử trên hai máy thật** (đây là mục tồn đọng trong `docs/STATUS.md`). Hãy tập trước ít nhất một lần cả buổi học ở mục 8, và giữ phương án dự phòng ở mục E.

## A. Chuẩn bị (30 phút trước giờ demo)

1. **DB sạch với seed mới** (4 lớp: PRM393 SE1901 của `gv1` có sẵn `sv1`, `sv2`, `sv3`; PRN232 SE1918, MLN131 Half2_EL1902, EXE201 SE1919 để trống). Tắt server, rồi (PowerShell, trong thư mục `backend`):
   ```powershell
   Remove-Item demo.db
   $env:DATABASE_URL_OVERRIDE = "sqlite:///D:/Documents/code/ble_attendance_mobile/backend/demo.db"
   .\.venv\Scripts\alembic.exe upgrade head
   .\.venv\Scripts\python.exe scripts\seed_demo.py
   .\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
2. **Địa chỉ máy chủ:** `ipconfig` lấy IPv4 Wi-Fi của laptop. Trên **cả hai điện thoại**, bánh răng ở màn đăng nhập → nhập `http://<IP>:8000`. Mở firewall cổng 8000; chuẩn bị hotspot dự phòng.
3. **Hai điện thoại:** cài APK mới nhất; bật Bluetooth, Vị trí, quyền Nearby devices (Android 11 trở xuống bắt buộc bật Vị trí để quét); tắt tiết kiệm pin cho app; tắt tự khóa màn hình; **bật giờ tự động** (cả laptop).
4. **Điện thoại A** đăng nhập `gv1` sẵn. **Điện thoại B** để ở màn đăng nhập.
5. **Laptop:** cửa sổ 1 đăng nhập `admin`. Mở sẵn thư mục `docs/demo-import/`.
6. **Dự phòng:** quay trước video chạy thử; chuẩn bị `ble_teacher_sim.py` (mục E).

## B. Kịch bản

### 1. Giới thiệu (1,5 phút)
Ba thành phần: app Flutter, web React, backend FastAPI. Ý tưởng cốt lõi: điện thoại sinh viên phát **tag đổi mỗi 30 giây**, ký bằng khóa riêng của từng sinh viên trong từng buổi. Điện thoại giảng viên nghe được rồi báo lên server; server kiểm tra chữ ký nên không thể giả. Dùng sơ đồ luồng điểm danh.

### 2. Admin tạo dữ liệu bằng tay (2 phút, web `admin`)
1. **Môn học** → Thêm môn (ví dụ `PRJ301`, "Lập trình Java web", 3 tín chỉ). Sửa tên một môn.
2. **Giảng viên** → Thêm giảng viên (ví dụ `GV8`): hộp thoại hiện **mật khẩu tạm = mã đăng nhập**. Bấm biểu tượng chìa khóa để **đặt lại mật khẩu**.
3. **Lớp học** → Thêm lớp (môn, mã lớp, học kỳ, giảng viên, vắng tối đa %, ngưỡng RSSI). Vào chi tiết lớp: **gán giảng viên**, xem danh sách sinh viên.

### 3. Admin nhập danh sách bằng file (3 phút, web `admin`)
Mục **Nhập danh sách** (file trong `docs/demo-import/`):
1. **Giảng viên:** `01_giang_vien.csv` → xem trước → xác nhận (4 giảng viên GV4–GV7).
2. **Lớp học:** `02_lop_hoc.csv` → xem trước ghi "Tạo lớp mới và môn học mới" → xác nhận (5 lớp).
3. **Sinh viên:** chọn lớp **SWP391 · SE1920**. Tải `99_loi_demo.csv` trước: 3 dòng lỗi, nút xác nhận bị khóa. Sau đó `03_sv_SWP391_SE1920.csv` → xác nhận (14 sinh viên). Tuỳ thời gian: `03_sv_PRN232_SE1921.xlsx` (Excel).

### 4. Tài khoản mới phải đổi mật khẩu (1 phút)
Cửa sổ ẩn danh trên laptop: đăng nhập `gv4` / `gv4` (mật khẩu tạm là mã). Hệ thống buộc **đổi mật khẩu** ngay ở lần đầu; đổi xong thấy lớp SWP391 và PRM393 vừa nhập. Đóng cửa sổ.

### 5. Sinh viên đăng ký và được xếp lớp (3 phút)
1. Điện thoại B → **Đăng ký (sinh viên)**: tạo `26CE777` ("Sinh viên Mới"). **Lớp của tôi** hiện "Bạn chưa được xếp lớp nào": sinh viên **không tự tham gia lớp**.
2. Laptop: Nhập danh sách → Sinh viên → chọn lớp **MLN131 · Half2_EL1902** → `04_xep_lop_sv_moi.csv` (dòng hiện "Thêm vào lớp") → xác nhận. Điện thoại B kéo xuống làm mới: lớp MLN131 xuất hiện. Đăng xuất.
3. Điện thoại B đăng nhập `sv1`: **Lớp của tôi** có lớp SE1901, cho xem **thống kê chuyên cần**. Đăng xuất.

### 6. Giảng viên chỉnh ngưỡng RSSI theo phòng (1 phút, điện thoại A)
Lớp học → **PRM393 · SE1901** → biểu tượng chỉnh (góc trên phải): giải thích "phòng nhỏ −70, phòng lớn −85, mặc định −75". Chọn **Vừa -75** → **Lưu**. Chỉnh **trước** khi bắt đầu buổi (ngưỡng áp dụng từ buổi sau khi lưu).

### 7. Xin phép trước buổi (2 phút)
1. Điện thoại B đăng nhập `sv3` → tab **Xin phép** → gửi đơn cho **hôm nay**, lớp SE1901, kèm lý do. Đăng xuất.
2. Điện thoại A: tab **Xin phép** (hoặc thông báo "Đơn xin phép mới", cập nhật tối đa khoảng 30 giây) → **Duyệt**. Đơn được duyệt cho đúng ngày của buổi nên cuối buổi `sv3` ra **Có phép**, không phải Vắng.

### 8. Buổi học: phần chính (6 phút)
Giữ buổi **ngắn (3–4 phút từ lúc bắt đầu đến lúc kết thúc)**: tỷ lệ hiện diện tính theo các ô 30 giây của cả buổi.

1. Điện thoại B đăng nhập `sv1`, mở sẵn trang chủ.
2. Điện thoại A: SE1901 → tab **Buổi học** → **Bắt đầu buổi học** → sang tab **Buổi trực tiếp** (cấp quyền Bluetooth nếu hỏi). Thẻ hiện **"Đang phát và quét BLE"**. **Giữ app ở phía trước, không khóa màn hình.**
3. Điện thoại B: kéo xuống làm mới (tối đa khoảng 15 giây là tự thấy buổi). Thẻ BLE chuyển từ "Đang tìm tín hiệu của giảng viên…" sang **"Bạn đang ở trong phạm vi lớp học"** khi hai máy đặt cạnh nhau. Đây là chiều **giảng viên phát, sinh viên quét**.
4. Điện thoại A: dòng **"Đã thấy 1 sinh viên · chờ gửi N · đã gửi M"**, số "đã gửi" tăng sau tối đa 30 giây. Đây là chiều **sinh viên phát, giảng viên quét**, và là nguồn dữ liệu thật của điểm danh.
5. *(Nếu phòng đủ rộng)* Điện thoại B đi ra xa (khoảng 8–10 mét hoặc ra phòng khác) trong vài chục giây: thẻ chuyển **"Bạn đang ở xa lớp học. Hãy lại gần giảng viên."** sau khoảng 3 giây, quay lại thì trở về "trong phạm vi". Đừng ở xa quá lâu, vì mỗi ô 30 giây không có tín hiệu sẽ không tính vào độ hiện diện.
6. Trong lúc đợi, trình bày cách chống giả mạo (HMAC, tag đổi mỗi 30 giây, replay chỉ dùng được 30–60 giây).
7. Điện thoại A: **Mở chốt điểm danh**. Điện thoại B: dòng "Giảng viên đã mở chốt" và nút **Xác nhận điểm danh** sáng lên (tối đa khoảng 15 giây). Bấm, quét vân tay hoặc nhập khóa màn hình. Hiện "Đã xác nhận điểm danh".
8. **Trước khi kết thúc:** nhìn điện thoại A, đợi **"chờ gửi 0"** (lô cuối đã lên server, tối đa 30 giây). Chờ vậy để ô cuối không bị thiếu dữ liệu. Sau đó bấm **Kết thúc buổi** → **Kết thúc**.

### 9. Kết quả, chỉnh tay, xuất Excel buổi (2 phút)
Điện thoại A (hoặc web giảng viên): màn hình kết quả cả lớp: `sv1` **Có mặt** (kèm tỷ lệ), `sv3` **Có phép**, `sv2` **Vắng**. Chỉnh tay `sv2` → Có mặt, nhập lý do ("Quên điện thoại, giảng viên xác nhận trực tiếp"): hiện nhãn đã chỉnh tay. **Xuất Excel** của buổi (nên làm trên web để tải file thật): đăng nhập `gv1` trên cửa sổ ẩn danh của laptop.

### 10. Thông báo cho sinh viên (1,5 phút, điện thoại B)
Đăng xuất, đăng nhập `sv2`: tab **Thông báo** có "Mở chốt điểm danh" và **"Cảnh báo vắng học"** (vắng 100% buổi, vượt mức 20%): cảnh báo đến ngay khi buổi kết thúc, trước khi giảng viên chỉnh tay. Tuỳ thời gian, đăng nhập `sv3` để xem "đơn xin phép được duyệt".

### 11. Báo cáo lớp và xuất Excel (1 phút)
Điện thoại A hoặc web giảng viên: tab **Báo cáo**: bảng chuyên cần theo từng buổi (P/A/E), cột sinh viên đứng yên khi cuộn, sinh viên vượt mức vắng có cảnh báo. **Xuất Excel**, mở file.

### 12. Kết: mỗi tài khoản một thiết bị (2 phút)
1. Điện thoại B: Cài đặt → Ứng dụng → Điểm danh BLE → Bộ nhớ → **Xóa dữ liệu**. Mở app, nhập lại địa chỉ máy chủ ở bánh răng.
2. Đăng nhập `sv1`: báo "Tài khoản đã gắn với một thiết bị khác". Bấm **Gửi đơn đổi thiết bị**, nhập lý do, gửi.
3. Laptop `admin`: mục **Đổi thiết bị** → **Duyệt**.
4. Điện thoại B: đăng nhập lại thành công.

## Bản rút gọn 12 phút
Bỏ các mục **2**, **4**, **5.1 và 5.2**, **10**, và chỉ nhập hai file đầu ở mục 3. Giữ nguyên các mục 1, 3, 5.3, 6, 7, 8, 9, 11, 12.

## C. Hỏi đáp thường gặp
| Câu hỏi | Trả lời ngắn |
|---|---|
| Sao giảng viên vừa phát vừa quét? | Quét là để điểm danh (nguồn dữ liệu duy nhất). Phát là để máy sinh viên tự hiện gần/xa; con số đó không gửi lên server và không ảnh hưởng điểm danh. |
| Sinh viên nhờ bạn điểm danh hộ? | Phải có đúng điện thoại đã gắn với tài khoản, và có bước vân tay. Chưa chặn được việc đưa hẳn máy cho bạn cầm hộ; đã ghi trong giới hạn. |
| Sao không dùng GPS? | Trong nhà sai số lớn. BLE cho độ gần ước lượng trong vài mét. |
| RSSI có chính xác không? | Chỉ ước lượng độ gần: dùng trung vị trong ô 30 giây, ngưỡng chỉnh được theo kích thước phòng. |
| Giảng viên gian lận được không? | Chỉnh tay đều có lý do và được lưu. Giảng viên dùng chương trình giả vẫn gửi được detection sai nếu có khóa; đó là giới hạn đã biết. |
| Vì sao tỷ lệ không ra 100%? | Ô 30 giây cuối của buổi (ngắn hơn 30 giây) vẫn được tính vào mẫu số; buổi dài thì sai lệch không đáng kể. |

## D. Gỡ rối nhanh
| Hiện tượng | Cách xử lý |
|---|---|
| Thẻ BLE trên B không thành "trong phạm vi" | Kiểm tra Bluetooth, Vị trí, quyền Nearby devices trên **cả hai** máy; điện thoại A đang ở tab Buổi trực tiếp, app ở phía trước; hai máy đặt sát nhau. |
| A báo "Đã thấy 0 sinh viên" | Điện thoại B phải đăng nhập `sv1` và đang mở app có buổi diễn ra; thử đóng và mở lại app B. Sinh viên phải thuộc lớp. |
| A báo "Chưa gửi được dữ liệu lên máy chủ" | Kiểm tra Wi-Fi hoặc địa chỉ máy chủ trên A; giữ app mở, app tự thử lại. |
| Chốt báo "không ở trong phạm vi" | Cần detection hợp lệ trong 90 giây gần nhất: để hai máy sát nhau, đợi một lô gửi (≤ 30 giây). |
| Cuối buổi sinh viên bị Vắng dù có mặt | Buổi quá dài hoặc đi ra xa quá lâu (tỷ lệ chưa đạt 0,6). Làm lại buổi ngắn hơn. |
| Đăng nhập báo "gắn với một thiết bị khác" | Gửi đơn đổi thiết bị trong app, admin duyệt ở web (mục Đổi thiết bị). |
| Điện thoại không vào được máy chủ | Cùng Wi-Fi, mở firewall cổng 8000, kiểm tra địa chỉ ở bánh răng, hoặc dùng hotspot. |

## E. Phương án B nếu điện thoại giảng viên trục trặc
Điện thoại A chỉ làm giảng viên trên màn hình (bắt đầu buổi, mở chốt, kết thúc, kết quả), còn việc quét BLE giao cho laptop chạy `ble_teacher_sim.py` như bản 1 điện thoại (xem `DEMO.md`): bấm Bắt đầu buổi trên A rồi chạy ngay
```powershell
.\.venv\Scripts\python.exe scripts\ble_teacher_sim.py --url http://localhost:8000 --teacher gv1
```
Khi đó thẻ gần/xa trên B không chạy (không ai phát), nhưng điểm danh vẫn đúng. Hoặc chiếu video quay sẵn, hoặc dùng **chỉnh tay** để minh họa phần còn lại.
