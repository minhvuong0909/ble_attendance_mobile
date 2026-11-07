# File nhập mẫu cho demo

Dùng với tài khoản admin `admin` (mật khẩu `123456`) trên web (`/app/` → mục **Nhập danh sách**). Dữ liệu mới, không trùng với dữ liệu seed, nên nhập được ngay trên DB demo đã seed. Mật khẩu ban đầu của tài khoản tạo mới là chính mã đăng nhập, và bắt buộc đổi ở lần đăng nhập đầu.

## Thứ tự nhập

| Bước | File | Chọn loại nhập | Kết quả |
|---|---|---|---|
| 1 | `01_giang_vien.csv` | Giảng viên | 4 giảng viên: GV4, GV5, GV6, GV7 |
| 2 | `02_lop_hoc.csv` | Lớp học (kèm môn) | 5 lớp, tạo thêm môn SWP391, SWT301, MLN122 (PRM393 và PRN232 đã có) |
| 3 | `03_sv_*.csv/.xlsx` | Sinh viên, chọn đúng lớp | 12-14 sinh viên mỗi lớp |

Phải nhập giảng viên **trước** lớp học (file lớp tham chiếu mã giảng viên), và lớp học **trước** danh sách sinh viên. Không có file riêng cho môn học: môn mới được tạo ngay khi nhập file lớp học (cột `course_code`, `course_name`).

## File danh sách sinh viên (bước 3)

| File | Chọn lớp | Ghi chú |
|---|---|---|
| `03_sv_SWP391_SE1920.csv` | SWP391 · SE1920 | 14 sinh viên |
| `03_sv_SWT301_SE1920.csv` | SWT301 · SE1920 | 14 sinh viên, trùng 6 người với lớp SWP391 nên các dòng này hiện "Thêm vào lớp" thay vì "Tạo tài khoản" |
| `03_sv_PRM393_SE1920.csv` | PRM393 · SE1920 | 14 sinh viên |
| `03_sv_PRN232_SE1921.xlsx` | PRN232 · SE1921 | 12 sinh viên, định dạng Excel để minh họa nhập `.xlsx` |
| `03_sv_MLN122_EL1903.csv` | MLN122 · EL1903 | 12 sinh viên |

## Xếp lớp cho sinh viên mới đăng ký: `04_xep_lop_sv_moi.csv`

Sinh viên **không tự tham gia lớp**: chỉ admin xếp lớp (nhập danh sách). Trong demo, sinh viên tự đăng ký tài khoản `26CE777` trên app sẽ thấy "Bạn chưa được xếp lớp nào". Admin nhập file này vào lớp **MLN131 · Half2_EL1902** (dòng hiện "Thêm vào lớp" vì tài khoản đã có), sinh viên làm mới app là thấy lớp.

## File cố ý sai: `99_loi_demo.csv`

Dùng để minh họa bảng xem trước chặn nhập khi có lỗi. Nhập vào một lớp bất kỳ: 3 dòng lỗi (mã sai định dạng, thiếu họ tên, mã trùng trong file), nút xác nhận bị khóa, không có gì được ghi.

## Cột và quy tắc

- `teacher_id`: 3-16 ký tự. `student_id`: dạng `25CE099` hoặc `D26CE045`.
- File CSV lưu UTF-8 (có BOM để Excel hiển thị đúng tiếng Việt). Tối đa 2 MB.
- Nhập lại cùng một file không tạo trùng: các dòng đã có hiện trạng thái "Bỏ qua".

Mọi file trong thư mục được kiểm tra tự động bởi `backend/tests/test_demo_import_files.py`.
