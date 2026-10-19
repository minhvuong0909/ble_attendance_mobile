# Trạng thái dự án (cập nhật khi hoàn thành mỗi plan)

Đọc file này đầu tiên khi tiếp tục công việc. Thiết kế đầy đủ: `specs/2026-10-18-ble-attendance-expansion-design.md`. Mỗi plan nằm ở `plans/`.

## Đã xong và đã merge vào `main` (chưa push lên GitHub)

| Plan | Nội dung | Kết quả |
|---|---|---|
| Backend core | Alembic, 3 vai trò, môn/lớp/GV, buổi học theo lớp, HMAC beacon, presence theo cửa sổ 30 giây, chốt, override | pytest xanh |
| Backend extras | Thông báo, thống kê SV, báo cáo + Excel, xin phép, import CSV/XLSX | 223 test backend xanh |
| Flutter foundation | Riverpod + go_router, đăng nhập/đăng ký/đổi mật khẩu bắt buộc, cài đặt máy chủ, khung 3 vai trò | |
| Flutter student (4A) | Lớp dữ liệu dùng chung, thông báo + badge, màn hình sinh viên | 161 test Flutter xanh |
| Flutter teacher (4B) | Lớp + sinh viên + buổi học + báo cáo/Excel, buổi trực tiếp, chỉnh tay, duyệt xin phép | 213 test Flutter xanh |

## ĐANG LÀM DỞ (đọc mục này trước)

- Plan 4C (admin) đang làm trên nhánh `feature/flutter-admin` (`plans/2026-10-20-flutter-admin.md`): **Task 1–2 xong** (repository + tab Môn học; 238 test xanh). **Tiếp theo: Task 3** (tab Lớp học: danh sách, tạo lớp, chi tiết: cấu hình, gán giảng viên, xóa), rồi Task 4 (Giảng viên), 5 (Sinh viên), 6 (Import có xem trước), 7 (hoàn thiện/review/merge). Sau đó: **bản web** (build Flutter web, phục vụ từ backend) rồi BLE. Bản APK release mới nhất đã gửi người dùng; backend đang chạy ở cổng 8000.
- Lỗi nhỏ hoãn lại của Plan 4B: tab Buổi trực tiếp vẫn poll `/sessions/active` khi không hiển thị; kéo làm mới ở tab trực tiếp trả về sớm; đóng hộp thoại chỉnh tay khi đang lưu làm mất thông báo; tên file Excel chưa lọc ký tự `/` và chưa xóa file tạm; `DataTable` báo cáo chậm với lớp rất lớn (100 SV x 40 buổi) và chưa cố định cột MSSV/Họ tên; chưa có biểu đồ `fl_chart`; timeout 12 s cũng áp cho tải Excel.

## Việc còn lại (theo thứ tự)

1. **Plan 4C – admin:** môn, lớp, gán GV, giảng viên, import (xem trước), sinh viên, đặt lại mật khẩu.
2. **Plan BLE:** phát/quét BLE với tag HMAC (xem spec mục 5), chỉ báo gần/xa cho sinh viên, gửi lô detection từ máy GV, foreground service. Cần thử trên 2 điện thoại thật.
3. **Hoàn thiện:** release APK có ký, kịch bản demo, rà soát tài liệu, sửa các lỗi nhỏ đã hoãn.

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
