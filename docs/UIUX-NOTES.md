# Ghi chú UI/UX và điểm cần sửa (rà trên emulator 720×1560, ngày 06/11/2026)

Rà bằng bản debug trên emulator, dữ liệu là bản demo (`backend/demo.db`). Đánh dấu: **[Dữ liệu]** là lỗi dữ liệu thử, **[UI]** là giao diện, **[Nghiệp vụ]** là hành vi hệ thống.

## Đã xem và thấy ổn
- Đăng nhập (sinh viên, giảng viên), bàn phím ảo không che ô nhập.
- Sinh viên: Trang chủ (trạng thái trống), Lớp của tôi, Xin phép (trống), Thông báo, menu hồ sơ.
- Giảng viên: Lớp học, chi tiết lớp (3 tab), hộp thoại Ngưỡng RSSI, đơn đổi thiết bị (báo lỗi, nút gửi đơn, hộp thoại, xác nhận). Đơn tới được server (đã kiểm tra).

## Trạng thái sửa (07/11/2026)
Đã sửa: 1 (DB demo làm mới bằng seed mới), 2, 3, 4, 5, 6, 8. Chưa làm: 7 (cần quyết định nghiệp vụ). Mỗi điểm sửa có test trong `test/ui_polish_test.dart` và `backend/tests`.

## Cần sửa, theo mức ưu tiên

### Trước buổi demo
1. **[Dữ liệu] Dữ liệu thử còn lại làm cả lớp bị "Vắng".** Có buổi học ngày 06/11 kéo dài 213 phút (bắt đầu 19:34, kết thúc 23:07). Kết quả: cả ba sinh viên Vắng, báo cáo "Trung bình lớp 0%", sinh viên nhận "Cảnh báo vắng học" và thấy "Vượt mức vắng cho phép". Làm sạch DB (xóa `backend/demo.db`, chạy lại `alembic upgrade head` và `scripts/seed_demo.py`) trước khi demo.
2. **[UI] Định dạng phần trăm không nhất quán.** Thông báo ghi "vắng 100.0%", còn vòng tròn ghi "0%". Nguyên nhân: câu thông báo ghép thẳng số thực ở `backend/app/services/attendance.py` (hàm `notify_absence_warnings`). Nên làm tròn: `100%`, `33%`.

### Nên sửa nếu còn thời gian
3. **[UI] Báo cáo giảng viên: cột cuối sát mép phải.** Ở màn 720px cột "Vắng" dính vào mép, các cột sau nó (nếu có) phải cuộn ngang mới thấy. Thêm lề phải, và cố định cột MSSV/Họ tên khi cuộn (đã ghi trong STATUS.md là việc hoãn).
4. **[UI] Ô "Lý do đổi máy" không tự focus** khi hộp thoại mở, phải bấm vào ô mới gõ được. Thêm `autofocus: true` ở `lib/screens/auth/login_screen.dart` (`_DeviceChangeDialogState`).
5. **[UI] Ba nút chọn nhanh RSSI xuống hàng** ("Phòng lớn (-85)" nằm hàng hai). Rút gọn nhãn ("Nhỏ -70", "Vừa -75", "Lớn -85") để cùng một hàng; đoạn mô tả có thể ngắn lại.
6. **[UI] Thẻ lớp của giảng viên không có dấu ">"** như thẻ của sinh viên, nên không rõ là bấm được. Thêm biểu tượng mũi tên cho nhất quán.

### Ý tưởng cho nghiệp vụ
7. **[Nghiệp vụ] Buổi học mở quá lâu không có cảnh báo.** Một buổi để mở hàng giờ làm mọi sinh viên có tỷ lệ gần 0 (ô 30 giây tăng theo thời gian). Có thể: cảnh báo khi giảng viên mở buổi quá lâu, hoặc tự đóng sau một giới hạn (ví dụ 4 giờ).
8. **[UI] Sau khi gửi đơn đổi thiết bị**, dòng xác nhận chỉ là chữ xanh, dễ bỏ sót. Có thể thêm biểu tượng dấu tích hoặc một khung nền như khung báo lỗi.

## Chưa rà (cần làm tiếp)
- Giảng viên: tab Buổi trực tiếp (đang có buổi), Xin phép, Thông báo, màn hình chi tiết buổi và hộp thoại chỉnh tay.
- Sinh viên: trang chủ khi đang có buổi, nút Xác nhận điểm danh, form xin phép, tham gia lớp.
- Admin trong app Flutter và toàn bộ giao diện web React.
- Chế độ tối, chữ lớn (accessibility), màn hình ngang.
