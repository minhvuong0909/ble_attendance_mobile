# Kịch bản demo (khoảng 10 phút)

Chuẩn bị trước: backend chạy (`uvicorn ... --host 0.0.0.0`), đã `seed_demo.py` (in mã tham gia lớp SE1901), bản web build sẵn (`backend/scripts/build_web.sh`), APK cài trên điện thoại sinh viên (và điện thoại giảng viên nếu có), điện thoại và laptop cùng Wi-Fi, Bluetooth + Vị trí bật. Mật khẩu mọi tài khoản demo: `Pass@123`.

Nếu chỉ có **một điện thoại**: điện thoại làm sinh viên, laptop chạy `backend/scripts/ble_teacher_sim.py` thay cho máy giảng viên (bước 4); các bước giảng viên khác làm trên bản web.

## 1. Admin chuẩn bị dữ liệu (web, 2 phút)

1. Mở `http://<IP-máy>:8000/app/`, đăng nhập `A001`.
2. Tab **Môn học**: tạo một môn mới. Tab **Giảng viên**: tạo `T002` và nhấn mạnh mật khẩu tạm bằng mã đăng nhập.
3. Tab **Lớp học** → **Nhập môn/lớp từ file**: chọn file CSV, cho xem bảng xem trước (dòng lỗi chặn nút xác nhận), xác nhận nhập. Vào chi tiết lớp: gán giảng viên, import danh sách sinh viên.

## 2. Sinh viên vào lớp (điện thoại, 1 phút)

Đăng nhập `25CE099` → **Lớp của tôi** → tham gia lớp bằng mã (nếu chưa vào). Cho xem thống kê chuyên cần ban đầu.

## 3. Giảng viên bắt đầu buổi (2 phút)

Đăng nhập `T001` (web hoặc điện thoại thứ hai) → chi tiết lớp SE1901 → **Bắt đầu buổi**. Tab **Buổi trực tiếp** hiện thẻ "Đang phát và quét BLE" (trên điện thoại giảng viên).

## 4. BLE hoạt động (2 phút)

- Điện thoại sinh viên: trang chủ hiện buổi đang diễn ra, thẻ BLE "Bạn đang ở trong phạm vi lớp học" (đi ra xa thì chuyển "ở xa lớp học").
- Giảng viên: "Đã thấy 1 sinh viên", "đã gửi" tăng sau tối đa 30 giây. Với laptop giả giảng viên: chạy `.venv/bin/python scripts/ble_teacher_sim.py` và chỉ log `recorded: N, rejected: 0` (tag HMAC được server chấp nhận).
- Nêu bật: gói BLE chứa tag đổi mỗi 30 giây, không giả mạo được nếu không có khóa riêng của buổi học.

## 5. Chốt và kết thúc (2 phút)

1. Giảng viên bấm **Mở chốt điểm danh**.
2. Sinh viên bấm **Xác nhận điểm danh**, quét vân tay hoặc nhập khóa màn hình.
3. Giảng viên **Kết thúc buổi**: màn hình kết quả cả lớp (sinh viên không có mặt là Vắng).
4. Chỉnh tay một sinh viên (nhập lý do), minh họa quyền ưu tiên của giảng viên.

## 6. Xin phép, báo cáo, xuất file (1 phút)

- Sinh viên gửi đơn xin phép cho buổi sau; giảng viên duyệt ở tab **Xin phép** (sinh viên nhận thông báo, buổi đó thành "Có phép").
- Giảng viên: tab **Báo cáo** của lớp, **Xuất Excel** (làm trên web để tải file thật).

## Gỡ rối nhanh

| Hiện tượng | Cách xử lý |
|---|---|
| Không thấy sinh viên | Bật Bluetooth và Vị trí; cấp quyền Nearby devices; kiểm tra điện thoại có phát được BLE |
| Chốt báo "không ở trong phạm vi" | Cần detection hợp lệ trong 90 giây gần nhất: để hai máy gần nhau, đợi một lô gửi (≤ 30 giây) |
| Điện thoại không vào được máy chủ | Cùng Wi-Fi, mở firewall cổng 8000, kiểm tra địa chỉ ở biểu tượng bánh răng |
| Cài APK báo xung đột chữ ký | Gỡ bản cũ (ký khóa debug) trước khi cài bản đã ký |
