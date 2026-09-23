# Kiến trúc hệ thống điểm danh BLE

## Phạm vi

- Một ứng dụng Flutter cho giảng viên và sinh viên
- Backend FastAPI kết nối PostgreSQL
- Ưu tiên Android và hỗ trợ thử nghiệm iOS
- Đăng nhập nội bộ, xác thực thiết bị khi chốt điểm danh

## Luồng hoạt động

1. Giảng viên đăng nhập và tạo buổi học.
2. Backend tạo session cùng token ngẫu nhiên.
3. Máy giảng viên phát token và tên môn qua BLE.
4. Máy sinh viên quét beacon giảng viên để hiển thị buổi học và RSSI.
5. Máy sinh viên đồng thời phát mã nhận diện qua BLE.
6. Máy giảng viên quét sinh viên và gửi detection lên backend theo lô.
7. Giảng viên mở giai đoạn chốt.
8. Sinh viên xác thực trên thiết bị và chốt điểm danh.
9. Giảng viên xem tổng kết, điều chỉnh hoặc xuất Excel.

## Mô hình dữ liệu

- `users`: tài khoản
- `sessions`: buổi học
- `detections`: mẫu RSSI theo thời gian
- `attendance`: kết quả điểm danh

## Cách tính hiện diện

- Cửa sổ dự kiến: 30 giây
- Ngưỡng có mặt: từ `0.6`
- Công thức hiện tại: số detection hợp lệ chia số cửa sổ đã trôi qua

> Cần tiếp tục sửa công thức để nhóm detection theo từng cửa sổ 30 giây, tránh nhiều gói BLE trong cùng cửa sổ làm tăng tỷ lệ sai.

## Giới hạn iOS

- Nên mở ứng dụng trước khi buổi học bắt đầu.
- Không bảo đảm BLE hoạt động sau khi force-close.
- Cần kiểm tra scan và advertising trên iPhone vật lý.
- Hoạt động nền phụ thuộc chính sách tiết kiệm pin của iOS.
