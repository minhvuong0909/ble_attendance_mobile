# Trạng thái dự án (cập nhật khi hoàn thành mỗi plan)

Đọc file này đầu tiên khi tiếp tục công việc. Thiết kế đầy đủ: `specs/2026-10-18-ble-attendance-expansion-design.md`. Mỗi plan nằm ở `plans/`.

## Đã xong và đã merge vào `main` (chưa push lên GitHub)

| Plan | Nội dung | Kết quả |
|---|---|---|
| Backend core | Alembic, 3 vai trò, môn/lớp/GV, buổi học theo lớp, HMAC beacon, presence theo cửa sổ 30 giây, chốt, override | pytest xanh |
| Backend extras | Thông báo, thống kê SV, báo cáo + Excel, xin phép, import CSV/XLSX | 223 test backend xanh |
| Flutter foundation | Riverpod + go_router, đăng nhập/đăng ký/đổi mật khẩu bắt buộc, cài đặt máy chủ, khung 3 vai trò | |
| Flutter student (4A) | Lớp dữ liệu dùng chung, thông báo + badge, màn hình sinh viên | 161 test Flutter xanh |

## ĐANG LÀM DỞ (đọc mục này trước)

- Nhánh `feature/flutter-teacher` (Plan 4B, `plans/2026-10-20-flutter-teacher.md`): **Task 1–3 xong** (repositories, lớp + chi tiết + bắt đầu buổi, báo cáo + Excel; 188 test xanh). **Tiếp theo: Task 4** (tab Buổi trực tiếp: mở chốt, kết thúc có xác nhận, danh sách điểm danh poll 10 giây, chỉnh tay, Excel buổi), Task 5 (duyệt đơn xin phép), Task 6 (hoàn thiện + review + merge).
- `main` sạch và xanh (backend 223, Flutter 161 test). Ghi chú: `AttendanceRepository.overrideStatus` (không đặt tên `override`).

## Việc còn lại (theo thứ tự)

1. **Plan 4B – giảng viên:** lớp được phân công + sinh viên + lịch sử buổi + báo cáo/Excel, tab Buổi trực tiếp (mở chốt, kết thúc, danh sách điểm danh, chỉnh tay), duyệt đơn xin phép.
2. **Plan 4C – admin:** môn, lớp, gán GV, giảng viên, import (xem trước), sinh viên, đặt lại mật khẩu.
3. **Plan BLE:** phát/quét BLE với tag HMAC (xem spec mục 5), chỉ báo gần/xa cho sinh viên, gửi lô detection từ máy GV, foreground service. Cần thử trên 2 điện thoại thật.
4. **Hoàn thiện:** release APK có ký, kịch bản demo, rà soát tài liệu, sửa các lỗi nhỏ đã hoãn.

## Quy trình đang dùng

Mỗi plan: viết plan gọn trong `plans/` → nhánh `feature/...` → TDD từng task (xem test fail trước) → commit từng task → review toàn nhánh bằng subagent → sửa lỗi Critical/Important theo TDD → merge `--no-ff` vào `main` trên máy. Không push lên remote nếu chưa được người dùng cho phép.

## Chạy thử nhanh

```bash
# Backend (Postgres chạy bằng docker compose trong backend/)
cd backend && .venv/bin/pytest -q
# Flutter
cd mobile/ble_attendance_mobile && flutter analyze && flutter test
flutter run --dart-define=API_BASE_URL=http://<IP-máy-tính>:8000
```

Tài khoản demo (mật khẩu `Pass@123`): admin `A001`, giảng viên `T001`, sinh viên `25CE099`, `25CE100`, `D26CE045`; `python scripts/seed_demo.py` in ra mã tham gia lớp SE1901.

## Ghi chú và việc hoãn

- `docker compose down -v` đã chạy một lần theo yêu cầu để bỏ schema cũ; DB hiện do Alembic quản lý.
- Hai thay đổi chưa commit của người dùng: `mobile/ble_attendance_mobile/android/gradle.properties` và `analysis_options.yaml` (Flutter tự thêm). Không đụng vào.
- Lỗi nhỏ hoãn lại của từng plan nằm trong tin nhắn tổng kết của plan đó (chưa lưu thành file): ví dụ trạng thái "đã chốt" của sinh viên chỉ lưu trong widget; polling vẫn chạy khi app ở nền; màu chip chưa đủ tương phản ở dark mode.
