# Flutter Admin Screens Implementation Plan (Plan 4C)


**Goal:** Hoàn thành các màn hình **admin** theo spec mục 2 và 7.3: quản lý môn học, lớp (tạo, sửa cấu hình, gán giảng viên, xóa), giảng viên (tạo, đặt lại mật khẩu), danh sách sinh viên theo lớp, và luồng **import CSV/Excel có xem trước** cho lớp/môn, giảng viên và sinh viên vào lớp.

**Architecture:** Như Plan 4A/4B: `abstract Repository` + `ApiXRepository`, provider Riverpod, `AsyncValueView`, fake trong `test/helpers`. Chọn file qua interface `FileChooser` (impl `file_picker`) để test không cần hệ điều hành; tải lên bằng `multipart/form-data` qua `ApiClient.postFile`.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, go_router 18, dio, file_picker, share_plus (đã có).

**Spec:** `docs/specs/2026-10-18-ble-attendance-expansion-design.md` (mục 2, 6.3, 7.3). **Backend:** đã merge vào `main` (`/admin/...`, import, `GET /classes/{id}/students`).

**Phạm vi:** không làm BLE. Plan viết gọn (hành vi + test) như các plan trước.

## Global Constraints

- Tiếng Việt, Material 3; mọi danh sách có đủ trạng thái tải / rỗng / lỗi có "Thử lại"; dữ liệu cũ vẫn hiển thị khi một lần làm mới lỗi; trạng thái rỗng kéo-làm-mới được (dùng `AsyncValueView` có `onRefresh`).
- Thao tác ghi (tạo/sửa/xóa/gán/đặt lại mật khẩu/import) khóa nút khi đang chạy và chỉ gọi API **một lần** dù bấm đúp; lỗi hiện bằng thông điệp server; thao tác phá hủy (xóa môn/lớp, đặt lại mật khẩu) **luôn hỏi xác nhận**.
- Chuẩn hóa như backend: mã môn/lớp viết hoa, cắt khoảng trắng; kiểm tra phía client chỉ để báo sớm (độ dài tối thiểu), server vẫn là nguồn sự thật.
- Quy tắc form: mã môn 2–32 ký tự; tên môn 2–120; tín chỉ 0–30 (tùy chọn); mã lớp 1–32; học kỳ 2–32; vắng tối đa 0–100 (%); ngưỡng RSSI từ -100 đến -30; mã giảng viên 3–16; họ tên 2–120.
- Import: chọn `.csv`/`.xlsx` (≤ 2 MB, kiểm tra trước khi tải lên), **luôn xem trước (`dry_run=true`) rồi mới xác nhận**; nút "Xác nhận nhập" chỉ bật khi báo cáo xem trước có `errors == 0` và `created > 0`; báo cáo hiển thị từng dòng (số dòng, trạng thái, thông điệp); có nút "Tải file mẫu" (chia sẻ CSV mẫu từ server).
- Mật khẩu tạm của tài khoản mới = chính mã định danh; hiển thị lời nhắc này sau khi tạo giảng viên / đặt lại mật khẩu (không hiển thị mật khẩu của người dùng khác ngoài quy tắc này).
- `flutter analyze` sạch; `flutter test` xanh sau mỗi task. Nhánh: `feature/flutter-admin`.

## Review Focus

1. Xóa môn còn lớp / xóa lớp còn sinh viên hiện đúng thông điệp server (`course_has_classes`, `class_not_empty`) và không làm mất mục khỏi danh sách (task 2, 3).
2. Import: file sai định dạng, quá lớn, thiếu cột (422) hiện lỗi rõ và không treo ở trạng thái "đang tải" (task 6).
3. Xác nhận import không bấm được khi xem trước còn lỗi, và bấm đúp chỉ nhập một lần (task 6).
4. Tạo lớp không thể gửi nếu chưa chọn môn; chọn giảng viên là tùy chọn (task 3).
5. Đặt lại mật khẩu có xác nhận và không lộ mật khẩu sai người (task 5).

## File Structure

```
lib/
├── models/{course,import_report}.dart
├── data/{admin_repository,file_chooser}.dart   (+ ApiClient.postFile, UserRepository trong admin_repository)
├── providers/admin_providers.dart
├── screens/admin/{admin_courses,course_form_dialog,admin_classes,class_form_screen,admin_class_detail,admin_teachers,admin_students,import_screen}_screen.dart
test/helpers/fakes.dart (mở rộng)
```

---

### Task 1: Models, repository, chọn file, tải multipart

**Files:** create `models/{course,import_report}.dart`, `data/admin_repository.dart`, `data/file_chooser.dart`, `providers/admin_providers.dart` (providers cơ bản); modify `data/api_client.dart` (+`postFile`), `providers/repositories.dart` (+`adminRepositoryProvider`, `fileChooserProvider`), `pubspec.yaml` (+`file_picker`), `test/helpers/fakes.dart`; tests `test/admin_models_test.dart`, `test/admin_repository_test.dart`.

**Interfaces:**
- `Course.fromJson` (`id, code, name, credits`).
- `ImportReport.fromJson` (`kind, dry_run, committed, total, created, skipped, errors, rows[{row,status,message}]`), `ImportRow(row, status: ImportRowStatus{created, skipped, error}, message)`, getter `canCommit` (= `errors == 0 && created > 0`).
- `ApiClient.postFile(String path, {required String filename, required List<int> bytes, Map<String, dynamic>? query}) -> Future<dynamic>` (multipart field `file`).
- `abstract class AdminRepository`: `courses()`, `createCourse({code,name,credits})`, `updateCourse(id,{name,credits})`, `deleteCourse(id)`, `allClasses()` (→ `List<ClassInfo>`), `createClass({courseId, classCode, semester, teacherUserId?, maxAbsencePercent, rssiThreshold})`, `updateClass(id,{classCode?,semester?,maxAbsencePercent?,rssiThreshold?})`, `deleteClass(id)`, `assignTeacher(classId, teacherUserId)`, `teachers()` (→ `List<AuthUser>`), `createTeacher({teacherId, fullName})`, `resetPassword(userId)`, `importStudents(classId, file, {dryRun})`, `importTeachers(file, {dryRun})`, `importClasses(file, {dryRun})`, `downloadTemplate(kind) -> ExportFile`.
- `PickedFile(name, bytes)`; `abstract class FileChooser { Future<PickedFile?> pick(); }` + `FilePickerChooser` (`file_picker`, `withData: true`, phần mở rộng `csv`/`xlsx`).

**Tests:** parse models (null credits; mọi trạng thái dòng import; `canCommit`); mỗi phương thức repository gọi đúng method/đường dẫn/body/query (`dry_run`), multipart có tên file và trường `file`; lỗi server thành `ApiException`; `downloadTemplate` trả tên file từ header.

### Task 2: Tab Môn học

**Files:** create `screens/admin/admin_courses_screen.dart`, `screens/admin/course_form_dialog.dart`; modify `tab_pages.dart`, `providers/admin_providers.dart`; tests `test/admin_courses_test.dart`.

**Behavior:** danh sách môn (mã, tên, "N tín chỉ" nếu có) sắp theo mã (thứ tự server); rỗng "Chưa có môn học nào"; nút nổi "Thêm môn" → hộp thoại (mã, tên, tín chỉ) với kiểm tra form; chạm một môn → hộp thoại sửa (mã chỉ đọc; sửa tên/tín chỉ) có nút "Xóa" (xác nhận); lỗi server giữ hộp thoại và hiện thông điệp; thành công làm mới danh sách + SnackBar.

**Tests:** danh sách/rỗng/lỗi+thử lại; thêm môn hợp lệ (mã được gửi viết hoa, trim), chặn khi thiếu/ngắn, lỗi trùng `course_exists` giữ hộp thoại; sửa chỉ gửi trường đổi; xóa có xác nhận (hủy → không gọi), `course_has_classes` hiện thông điệp và môn vẫn còn; bấm đúp chỉ gọi một lần.

### Task 3: Tab Lớp học, tạo lớp, chi tiết lớp (cấu hình, gán giảng viên, xóa)

**Files:** create `screens/admin/admin_classes_screen.dart`, `class_form_screen.dart`, `admin_class_detail_screen.dart`; modify `tab_pages.dart`, `app/router.dart` (`/admin/classes/new`, `/admin/classes/:id`); tests `test/admin_classes_test.dart`.

**Behavior:** danh sách lớp (môn, `mã lớp · học kỳ`, giảng viên hoặc "Chưa phân công", số sinh viên, chip mã tham gia); nút nổi "Tạo lớp" → form (môn bắt buộc từ danh sách, mã lớp, học kỳ, giảng viên tùy chọn, vắng tối đa mặc định 20, ngưỡng RSSI mặc định -75) → tạo → quay lại + làm mới. Chi tiết lớp: thông tin; "Cấu hình" (sửa mã lớp/học kỳ/vắng tối đa/RSSI); "Giảng viên" (chọn từ danh sách → `assignTeacher`; lỗi `class_has_active_session` hiện thông điệp); "Sinh viên" (danh sách + nút "Nhập danh sách sinh viên" → màn hình import, task 6); "Xóa lớp" có xác nhận (`class_not_empty` hiện thông điệp).

**Tests:** danh sách/rỗng/lỗi; tạo lớp (chặn khi chưa chọn môn, mặc định 20/-75, gửi đúng body, giảng viên tùy chọn); lỗi `class_exists`; chi tiết hiển thị đúng; sửa cấu hình chỉ gửi trường đổi và kiểm tra miền giá trị; gán giảng viên; xóa lớp có xác nhận và lỗi `class_not_empty`; bấm đúp chỉ gọi một lần.

### Task 4: Tab Giảng viên (tạo, đặt lại mật khẩu)

**Files:** create `screens/admin/admin_teachers_screen.dart`; modify `tab_pages.dart`; tests `test/admin_teachers_test.dart`.

**Behavior:** danh sách giảng viên (họ tên, mã); rỗng; nút nổi "Thêm giảng viên" (mã 3–16, họ tên) → sau khi tạo hiện hộp thoại "Mật khẩu tạm là mã giảng viên (viết hoa). Họ sẽ phải đổi mật khẩu khi đăng nhập lần đầu."; menu `⋮` trên mỗi dòng: "Đặt lại mật khẩu" (xác nhận → `resetPassword` → cùng lời nhắc); nút "Nhập từ file" mở màn hình import loại `teachers` (task 6).

**Tests:** danh sách/rỗng/lỗi; tạo hợp lệ (mã viết hoa/trim) → hộp thoại nhắc mật khẩu tạm; chặn form; lỗi `teacher_exists` giữ hộp thoại; đặt lại mật khẩu có xác nhận (hủy → không gọi), thành công hiện lời nhắc, bấm đúp chỉ một lần.

### Task 5: Tab Sinh viên (theo lớp, đặt lại mật khẩu)

**Files:** create `screens/admin/admin_students_screen.dart`; modify `tab_pages.dart`; tests `test/admin_students_test.dart`.

**Behavior:** chọn lớp bằng dropdown (từ `allClasses`; nhớ lựa chọn trong phiên); hiển thị sinh viên của lớp đó (MSSV · họ tên) với menu "Đặt lại mật khẩu" (xác nhận → `resetPassword(userId)` → lời nhắc mật khẩu tạm = MSSV); nút "Nhập danh sách sinh viên" → màn hình import `students` cho lớp đang chọn; chưa chọn lớp → lời nhắn "Chọn một lớp để xem sinh viên"; lớp không có sinh viên → "Lớp chưa có sinh viên".

**Tests:** chưa chọn lớp; chọn lớp tải đúng sinh viên (đúng `classId`); đổi lớp tải lại; rỗng/lỗi + thử lại; đặt lại mật khẩu (xác nhận, một lần, lời nhắc đúng với MSSV); nút import dẫn tới màn hình import đúng loại/lớp.

### Task 6: Màn hình import có xem trước

**Files:** create `screens/admin/import_screen.dart`; modify `app/router.dart` (`/admin/import/:kind?classId=`), liên kết từ task 3/4/5; tests `test/import_screen_test.dart`.

**Behavior:** `ImportScreen(kind: students|teachers|classes, classId?)`: nút "Tải file mẫu" (chia sẻ CSV từ server); nút "Chọn file" (`FileChooser`; hủy → không làm gì); kiểm tra tại chỗ (đuôi `.csv`/`.xlsx`, ≤ 2 000 000 byte) trước khi tải lên; tải lên với `dryRun: true` → hiển thị tóm tắt (tổng, tạo mới, bỏ qua, lỗi) và bảng từng dòng (số dòng, chip trạng thái, thông điệp); "Xác nhận nhập" chỉ bật khi `canCommit`, gọi lại với `dryRun: false` đúng một lần, rồi hiện kết quả "Đã nhập N dòng" (nếu `committed == false` hiện lỗi) và làm mới dữ liệu liên quan (danh sách lớp/giảng viên/sinh viên); lỗi tải lên (422 thiếu cột, 413 quá lớn, mất mạng) hiện `ErrorBanner` và cho chọn lại file.

**Tests:** hủy chọn file; file sai đuôi / quá lớn bị chặn không gọi API; xem trước hiển thị đúng số liệu và chip; có lỗi → nút xác nhận bị khóa; không có dòng "tạo mới" → khóa; xác nhận gọi đúng loại/lớp/`dryRun:false`, bấm đúp chỉ một lần; `committed:false` hiện lỗi; lỗi 422 `missing_columns` hiện thông điệp server; tải file mẫu gọi `downloadTemplate(kind)` và `fileSharer.share`; chọn lại file sau lỗi hoạt động.

### Task 7: Hoàn thiện

- [ ] `dart format`, `flutter analyze` sạch, `flutter test` xanh.
- [ ] README mobile + `docs/STATUS.md` cập nhật.
- [ ] `flutter build apk --debug` thành công.
- [ ] Review toàn nhánh bằng reviewer độc lập; sửa lỗi Critical/Important theo TDD.
- [ ] Merge `--no-ff` vào `main` (chỉ trên máy).

---

## Self-Review

- **Phủ spec mục 2/7.3 (admin):** Môn học (task 2), Lớp học + gán GV + cấu hình RSSI/vắng (task 3), Giảng viên + đặt lại mật khẩu (task 4), Sinh viên + import (task 5–6), Import xem trước lỗi từng dòng và file mẫu (task 6, spec 6.3).
- **Quét placeholder:** không có "TBD"; hành vi, miền giá trị, thông điệp và danh sách test nêu cụ thể.
- **Nhất quán tên:** `AdminRepository`, `FileChooser`/`PickedFile`, `ImportReport`/`ImportRow`/`canCommit`, `ImportScreen(kind, classId)` dùng thống nhất.
