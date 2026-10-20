# Kiến trúc và quy tắc nghiệp vụ

Thiết kế đầy đủ và lý do chọn: `docs/superpowers/specs/2026-10-18-ble-attendance-expansion-design.md`.

## Tổng quan

```text
Flutter (Android)  ┐
Web React (/app/) ┴─HTTPS+JWT──> FastAPI ──> PostgreSQL
   │  ▲                                    ▲
   │  └── BLE: gói quảng cáo ──────────────┘ (máy giảng viên gửi lô detection)
```

- **Backend**: routers (`auth, admin, classes, sessions, detections, attendance, reports, leave, notifications, me, imports`) gọi services (`presence, beacon, attendance, stats, reports, leave, importer, notifier`). Lỗi trả `{detail, code}`; thời gian lưu UTC và trả kèm `Z`.
- **Flutter**: Riverpod + go_router; repository (`abstract` + `Api*`) để test bằng bản giả; `BleGateway` bọc phần cứng BLE; `StudentBeaconController` và `TeacherBeaconController` điều khiển phát/quét; app Android cho sinh viên và giảng viên di động.
- **Web React** (`web/`): SPA cho admin và giảng viên (môn/lớp/giảng viên, import có xem trước, báo cáo, xuất Excel, buổi trực tiếp, chỉnh tay, xin phép, thông báo). Kiểu API sinh từ `openapi.json`; TanStack Query quản lý dữ liệu; backend phục vụ bản build tại `/app/` (cùng origin, có fallback `index.html` cho đường dẫn sâu). Token lưu `localStorage` (chấp nhận cho bản demo).

## Mô hình dữ liệu

`users` (role admin/teacher/student) · `courses` · `classes` (thuộc môn, có giảng viên, `join_code`, `rssi_threshold`, `max_absence_percent`) · `enrollments` · `sessions` (buổi học, `token`, `finalization_open`) · `detections` (mẫu RSSI đã xác minh) · `attendance` (kết quả, `finalized`, override) · `leave_requests` · `notifications`.

## Luồng điểm danh

1. Admin tạo môn/lớp, import danh sách, gán giảng viên; sinh viên tham gia lớp.
2. Giảng viên bắt đầu buổi: server tạo buổi với mã 8 ký tự (`beacon_code`).
3. Điện thoại giảng viên phát `beacon_code`, quét gói sinh viên; điện thoại sinh viên phát `student_id` + tag, quét gói giảng viên để biết gần/xa.
4. Máy giảng viên gửi lô `{student_id, bucket, tag, rssi, observed_at}` mỗi 30 giây.
5. Giảng viên mở chốt; sinh viên xác thực vân tay/khóa màn hình rồi gọi chốt (cần detection hợp lệ trong 90 giây gần nhất).
6. Giảng viên kết thúc buổi: server tính kết quả cả lớp trong một transaction.

## Chống giả mạo

`student_secret = HMAC(server_key, session_id:student_id)` chỉ đi qua HTTPS cho đúng sinh viên. `tag = HMAC(secret, bucket)[:8]` với `bucket = epoch // 30`, server chấp nhận lệch ±1 bucket và `observed_at` trong 10 phút. Gói sai tag, sinh viên ngoài lớp hoặc buổi không active bị bỏ.

## Cách tính hiện diện

- Chia buổi thành cửa sổ 30 giây. Cửa sổ hợp lệ khi trung vị RSSI các detection trong đó lớn hơn ngưỡng của lớp (mặc định -75).
- `ratio = số cửa sổ hợp lệ / tổng số cửa sổ`.
- Khi kết thúc buổi: có chỉnh tay của giảng viên thì giữ nguyên; `ratio ≥ 0.6` **và** đã chốt thì `present`; có đơn xin phép được duyệt đúng ngày thì `excused`; còn lại `absent`.
- Đến trễ chỉ ghi giờ đến (`first_seen_at`), không có trạng thái riêng.
- Chuyên cần = (present + excused) / số buổi đã kết thúc; vắng vượt `max_absence_percent` thì cảnh báo sinh viên.

## Giới hạn

Xem mục "Giới hạn đã biết" trong `README.md`.
