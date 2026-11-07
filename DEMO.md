# Kịch bản demo đầy đủ (1 điện thoại, khoảng 25 phút, có bản rút gọn 15 phút)

**Vai trò:** điện thoại = sinh viên (đổi tài khoản bằng Đăng xuất / Đăng nhập; mỗi tài khoản gắn với máy ở lần đăng nhập đầu, nhiều tài khoản dùng chung một máy vẫn được). Laptop = admin `admin` (web, cửa sổ thường) + giảng viên `gv1` (web, cửa sổ ẩn danh) + "máy giảng viên" giả `ble_teacher_sim.py` (quét BLE thay điện thoại giảng viên). Mật khẩu mọi tài khoản demo: `123456`.

> Lưu ý quan trọng khi chỉ có một điện thoại: laptop giả chỉ **quét** gói của sinh viên, không **phát** gói giảng viên. Vì vậy thẻ BLE trên điện thoại sẽ ở trạng thái "Đang tìm tín hiệu của giảng viên…" suốt buổi; đó là bình thường. Bằng chứng BLE hoạt động nằm ở **log của script** (`recorded: N, rejected: 0`) và ở trang **Buổi trực tiếp** trên web. Nút xác nhận trên điện thoại không phụ thuộc thẻ này, mà phụ thuộc server có detection hợp lệ của sinh viên trong 90 giây gần nhất.

## Bản đồ tính năng (mọi thứ trong kịch bản)

| Vai | Tính năng được trình bày | Mục |
|---|---|---|
| Admin | Tạo môn, giảng viên (mật khẩu tạm), lớp; gán giảng viên; đặt lại mật khẩu | 2 |
| Admin | Nhập giảng viên, lớp (kèm môn), sinh viên từ CSV/Excel; xem trước và chặn file lỗi | 3 |
| Admin | Duyệt đơn đổi thiết bị | 12 |
| Giảng viên | Đổi mật khẩu bắt buộc ở lần đầu; ngưỡng RSSI theo phòng | 4, 6 |
| Giảng viên | Bắt đầu buổi, buổi trực tiếp, mở chốt, kết thúc, kết quả cả lớp, chỉnh tay có lý do | 8, 9 |
| Giảng viên | Duyệt xin phép, báo cáo lớp, xuất Excel (báo cáo lớp và kết quả buổi) | 7, 9, 11 |
| Sinh viên | Đăng ký, đăng nhập (gắn máy), được admin xếp lớp, thống kê chuyên cần | 5 |
| Sinh viên | Phát BLE, xác nhận bằng vân tay, xin phép, thông báo (mở chốt, duyệt đơn, cảnh báo vắng) | 7, 8, 10 |
| Hệ thống | Tag HMAC đổi mỗi 30 giây, chống giả mạo, tính Có mặt / Có phép / Vắng, mỗi tài khoản một máy | 8, 9, 12 |

## A. Chuẩn bị (30 phút trước giờ demo)

1. **Server chạy:** mở `http://localhost:8000/app/` thấy trang đăng nhập. Nếu chưa chạy (PowerShell, trong thư mục `backend`):
   ```powershell
   $env:DATABASE_URL_OVERRIDE = "sqlite:///D:/Documents/code/ble_attendance_mobile/backend/demo.db"
   .\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
2. **DB sạch:** nếu đã chạy thử, tắt server rồi làm lại để không còn buổi học cũ và sinh viên chưa gắn máy:
   ```powershell
   Remove-Item demo.db
   .\.venv\Scripts\alembic.exe upgrade head
   .\.venv\Scripts\python.exe scripts\seed_demo.py
   ```
3. **Địa chỉ máy chủ:** `ipconfig` lấy IPv4 Wi-Fi của laptop (lần chuẩn bị gần nhất là `192.168.1.197`). Trong app, bấm bánh răng ở màn đăng nhập, nhập `http://<IP>:8000`. Mở sẵn firewall cổng 8000. Chuẩn bị hotspot điện thoại dự phòng nếu Wi-Fi nơi demo chặn kết nối giữa các máy.
4. **Điện thoại:** cài APK mới nhất; bật Bluetooth, Vị trí, quyền Nearby devices; tắt tiết kiệm pin cho app; tắt tự khóa màn hình; **bật giờ tự động** (laptop cũng vậy): lệch đồng hồ quá vài chục giây làm tag HMAC bị từ chối.
5. **Laptop:** bật Bluetooth. `bleak` đã cài trong venv. Gõ sẵn lệnh script ở một terminal, **chưa nhấn Enter** (xem mục 8):
   ```powershell
   .\.venv\Scripts\python.exe scripts\ble_teacher_sim.py --url http://localhost:8000 --teacher gv1
   ```
6. **Cửa sổ trình duyệt:** cửa sổ 1 đăng nhập `admin` (Admin), cửa sổ ẩn danh đăng nhập `gv1` (Giảng viên). Mở sẵn thư mục `docs/demo-import/`.
7. **Dự phòng:** quay trước một video chạy thử toàn bộ luồng.

## B. Kịch bản

### 1. Giới thiệu (1,5 phút)
Ba thành phần: app Flutter (sinh viên), web React (admin, giảng viên), backend FastAPI. Ý tưởng cốt lõi: điện thoại sinh viên phát mã **tag đổi mỗi 30 giây**, ký bằng khóa riêng của từng sinh viên trong từng buổi; máy giảng viên nghe được rồi báo lên server; server kiểm tra chữ ký nên không thể giả. Dùng sơ đồ luồng điểm danh.

### 2. Admin tạo dữ liệu bằng tay (2 phút, web `admin`)
1. **Môn học** → Thêm môn (ví dụ `PRJ301`, "Lập trình Java web", 3 tín chỉ). Sửa tên một môn để cho thấy chỉnh sửa.
2. **Giảng viên** → Thêm giảng viên (ví dụ `T008`): hộp thoại hiện **mật khẩu tạm = mã đăng nhập**. Bấm biểu tượng chìa khóa để **đặt lại mật khẩu** một giảng viên.
3. **Lớp học** → Thêm lớp (chọn môn, mã lớp, học kỳ, giảng viên, vắng tối đa %, ngưỡng RSSI). Vào chi tiết lớp: **gán giảng viên**, xem danh sách sinh viên (sinh viên không tự tham gia, do admin xếp lớp).

### 3. Admin nhập danh sách bằng file (3 phút, web `admin`)
Mục **Nhập danh sách** (file ở `docs/demo-import/`, xem README trong thư mục đó):
1. **Giảng viên:** `01_giang_vien.csv` → xem trước → xác nhận (4 giảng viên).
2. **Lớp học:** `02_lop_hoc.csv` → bảng xem trước ghi "Tạo lớp mới và môn học mới" → xác nhận (5 lớp, môn mới được tạo cùng lúc).
3. **Sinh viên:** chọn lớp **SWP391 · SE1920**. Trước tiên tải `99_loi_demo.csv`: 3 dòng lỗi, nút xác nhận bị khóa, không ghi gì. Sau đó `03_sv_SWP391_SE1920.csv` → xác nhận (14 sinh viên). Tuỳ thời gian: `03_sv_PRN232_SE1921.xlsx` để minh họa Excel.

### 4. Tài khoản mới phải đổi mật khẩu (1 phút)
Cửa sổ ẩn danh thứ hai: đăng nhập `gv4` / `gv4` (mật khẩu tạm là mã). Hệ thống buộc **đổi mật khẩu** ngay ở lần đầu; đổi xong vào được trang giảng viên (thấy lớp SWP391 và PRM393 vừa nhập). Đóng cửa sổ này.

### 5. Sinh viên trên điện thoại: đăng ký, được xếp lớp, thống kê (3 phút)
1. Màn đăng nhập → **Đăng ký (sinh viên)**: tạo `26CE777` ("Sinh viên Mới"), vào được ngay (máy gắn với tài khoản này). **Lớp của tôi** hiện "Bạn chưa được xếp lớp nào": **sinh viên không tự tham gia lớp**.
2. Web `admin`: Nhập danh sách → Sinh viên → chọn lớp **MLN131 · Half2_EL1902** → `04_xep_lop_sv_moi.csv` (dòng hiện "Thêm vào lớp") → xác nhận. Điện thoại kéo xuống làm mới: lớp MLN131 xuất hiện. Đăng xuất.
3. Đăng nhập `sv1`: **Lớp của tôi** có lớp SE1901 (đã được xếp sẵn), cho xem **thống kê chuyên cần** của lớp. Đăng xuất.

### 6. Giảng viên chỉnh ngưỡng RSSI theo phòng (1 phút, web `gv1`)
Lớp học → **PRM393 SE1901**, ô **Ngưỡng RSSI của lớp**: giải thích "phòng nhỏ −70, phòng lớn −85, mặc định −75". Bấm **Vừa (-75)** hoặc đổi sang **Lớn (-85)** rồi **Lưu ngưỡng**. Chỉnh trước khi bắt đầu buổi.

### 7. Xin phép trước buổi (2 phút)
1. Điện thoại: đăng nhập `sv3` → tab **Xin phép** → gửi đơn cho **hôm nay**, lớp SE1901, kèm lý do. Đăng xuất.
2. Web `gv1`: lớp SE1901 → tab **Xin phép** → **Duyệt**. (Giảng viên nhận thông báo đơn mới.) Đơn được duyệt cho đúng ngày của buổi nên kết quả cuối buổi của sinh viên này sẽ là **Có phép**, không phải Vắng.

### 8. Buổi học: phần chính (4 phút)
Giữ buổi **ngắn (khoảng 2–3 phút từ lúc bắt đầu đến lúc kết thúc)**: tỷ lệ hiện diện tính theo các ô 30 giây của cả buổi, bắt đầu script muộn hoặc để buổi kéo dài sẽ làm sinh viên bị Vắng oan.

1. Điện thoại: đăng nhập `sv1`, mở sẵn trang chủ. Web `gv1`, tab **Buổi học** → **Bắt đầu buổi học**. **Ngay sau đó** (trong vòng 20 giây): nhấn Enter chạy script ở terminal, và kéo xuống làm mới trang chủ điện thoại nếu chưa thấy buổi.
2. Điện thoại: thẻ "Đang diễn ra" của buổi. Terminal: các dòng `Thấy 25CE099 tag=... rssi=-5x` và `Gửi N -> 200 {'recorded': N, 'rejected': 0}`. Chỉ cho khán giả thấy **tag đổi sau mỗi 30 giây** và RSSI khoảng −50 (rất gần).
3. Web, trang **Buổi trực tiếp**: "Đã thấy 1 sinh viên", số "đã gửi" tăng.
4. Trong lúc đợi (~1,5 phút), trình bày cách chống giả mạo (HMAC, ±1 bucket, replay chỉ dùng được 30–60 giây).
5. Web: **Mở chốt điểm danh**. Điện thoại: dòng "Giảng viên đã mở chốt" và nút **Xác nhận điểm danh** sáng lên (tối đa khoảng 15 giây). Bấm, quét vân tay hoặc nhập khóa màn hình. Hiện "Đã xác nhận điểm danh".
6. Web: **Kết thúc buổi**, rồi Ctrl+C dừng script.

### 9. Kết quả, chỉnh tay, xuất Excel buổi (2 phút, web `gv1`)
Màn hình kết quả cả lớp: `sv1` **Có mặt** (kèm tỷ lệ), `sv3` **Có phép**, `sv2` **Vắng**. Chỉnh tay `sv2` → Có mặt, nhập lý do ("Quên điện thoại, giảng viên xác nhận trực tiếp"): hiện nhãn đã chỉnh tay, quyền ưu tiên của giảng viên và có lưu lý do. Bấm **Xuất Excel** của buổi, mở file.

### 10. Thông báo cho sinh viên (1,5 phút, điện thoại)
Đăng xuất, đăng nhập `sv2`: tab **Thông báo** có "Mở chốt điểm danh" và **"Cảnh báo vắng học"** (vắng 100% buổi, vượt mức 20%): hệ thống cảnh báo ngay khi buổi kết thúc, trước khi giảng viên chỉnh tay. Tuỳ thời gian, đăng nhập `sv3` để xem thông báo "đơn xin phép được duyệt".

### 11. Báo cáo lớp và xuất Excel (1 phút, web `gv1`)
Tab **Báo cáo**: bảng chuyên cần theo từng buổi (P/A/E), sinh viên vượt mức vắng có biểu tượng cảnh báo. **Xuất Excel**, mở file.

### 12. Kết: mỗi tài khoản một thiết bị (2 phút)
1. Điện thoại: Cài đặt → Ứng dụng → Điểm danh BLE → Bộ nhớ → **Xóa dữ liệu**. Mở app, nhập lại địa chỉ máy chủ ở bánh răng (xóa dữ liệu làm mất cài đặt này).
2. Đăng nhập `sv1`: báo "Tài khoản đã gắn với một thiết bị khác". Bấm **Gửi đơn đổi thiết bị**, nhập lý do, gửi.
3. Web `admin`: mục **Đổi thiết bị** → **Duyệt**.
4. Điện thoại: đăng nhập lại thành công (sinh viên nhận thông báo đơn được duyệt).

## Bản rút gọn 15 phút
Bỏ các mục **2** (tạo tay), **4** (đổi mật khẩu bắt buộc), **5.1 và 5.2** (đăng ký và xếp lớp cho sinh viên mới), **10** (thông báo cảnh báo), và chỉ nhập hai file đầu ở mục 3. Giữ nguyên các mục 1, 3, 5.3, 6, 7, 8, 9, 11, 12.

## C. Hỏi đáp thường gặp
| Câu hỏi | Trả lời ngắn |
|---|---|
| Sinh viên nhờ bạn điểm danh hộ? | Phải có đúng điện thoại đã gắn với tài khoản (chống dùng nhiều máy), và có bước vân tay. Chưa chặn được việc đưa hẳn máy cho bạn cầm hộ; đã ghi trong giới hạn. |
| Sao không dùng GPS? | Trong nhà sai số lớn. BLE cho độ gần ước lượng trong vài mét. |
| RSSI có chính xác không? | Chỉ ước lượng độ gần: dùng trung vị trong ô 30 giây, và ngưỡng chỉnh được theo kích thước phòng. |
| Giảng viên có gian lận được không? | Chỉnh tay đều có lý do và được lưu. Giảng viên dùng client giả vẫn gửi được detection sai nếu có khóa; đó là giới hạn đã biết. |
| Vân tay có an toàn không? | Là xác nhận phía máy, server không tự kiểm chứng được. |

## D. Gỡ rối nhanh
| Hiện tượng | Cách xử lý |
|---|---|
| Thẻ BLE trên điện thoại cứ "Đang tìm tín hiệu của giảng viên…" | Bình thường khi dùng laptop giả (xem lưu ý đầu trang); nhìn log script và trang Buổi trực tiếp. |
| Log script thỉnh thoảng có `rejected` | Gói rơi đúng ranh giới 30 giây hoặc đồng hồ lệch; không ảnh hưởng kết quả vì mỗi ô 30 giây có nhiều lần ghi nhận. Nếu rejected liên tục, kiểm tra giờ tự động. |
| Chốt báo "không ở trong phạm vi" | Cần detection hợp lệ trong 90 giây gần nhất: để điện thoại sát laptop, script đang chạy, đợi một lô gửi (≤ 30 giây). |
| Cuối buổi sinh viên bị Vắng dù có mặt | Buổi quá dài hoặc bật script muộn (tỷ lệ chưa đạt 0,6). Làm lại buổi ngắn hơn. |
| Điện thoại không vào được máy chủ | Cùng Wi-Fi, mở firewall cổng 8000, kiểm tra địa chỉ ở bánh răng, hoặc dùng hotspot. |
| Đăng nhập báo "gắn với một thiết bị khác" | Gửi đơn đổi thiết bị trong app, admin duyệt ở web (mục Đổi thiết bị). |
| Cài APK báo xung đột chữ ký | Gỡ bản cũ (ký khóa debug) trước khi cài bản đã ký. |

## E. Phương án B nếu BLE trục trặc
Chiếu video quay sẵn; hoặc bỏ qua bước BLE và dùng **chỉnh tay** của giảng viên để minh họa phần còn lại của luồng (kết quả, báo cáo, xin phép).
