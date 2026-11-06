# Flutter Teacher Screens Implementation Plan (Plan 4B)


**Goal:** Hoàn thành các màn hình **giảng viên** theo spec mục 7.3: lớp được phân công (sinh viên, lịch sử buổi, báo cáo cả kỳ + xuất Excel), tab **Buổi trực tiếp** (mở chốt, kết thúc buổi, danh sách điểm danh theo thời gian thực, chỉnh tay có lý do, xuất Excel buổi), và duyệt **đơn xin phép**.

**Architecture:** Như Plan 4A: `abstract Repository` + `ApiXRepository`, provider Riverpod, `AsyncValueView`, fake trong `test/helpers`. Thêm tải file nhị phân qua `ApiClient.download` và `FileSharer` (share sheet) để xuất Excel mà test không cần thiết bị.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, go_router 18, dio, intl, share_plus, path_provider.

**Spec:** `docs/specs/2026-10-18-ble-attendance-expansion-design.md` (mục 4.2, 4.4, 6.2, 7.3). **Backend:** đã merge vào `main`.

**Phạm vi:** *không* làm BLE (phát/quét, gửi lô detection) — thuộc plan BLE. Màn hình "Buổi trực tiếp" vì vậy chỉ điều khiển buổi học và hiển thị dữ liệu server; danh sách điểm danh sẽ có số liệu khi plan BLE hoàn tất. Plan viết gọn (hành vi + test) như các plan trước.

## Global Constraints

- Tiếng Việt, Material 3, mọi danh sách có đủ trạng thái tải / rỗng / lỗi có "Thử lại" (dùng `AsyncValueView`; dữ liệu cũ vẫn hiển thị khi một lần làm mới lỗi).
- Thời gian server là UTC `Z`, hiển thị giờ máy (`parseApiTime`, `formatDateTime`).
- Thao tác thay đổi dữ liệu (bắt đầu/kết thúc buổi, mở chốt, chỉnh tay, duyệt đơn) khóa nút khi đang chạy và chỉ gọi API **một lần** dù bấm nhiều lần; lỗi hiển thị bằng thông điệp server.
- **Kết thúc buổi học luôn hỏi xác nhận** (hộp thoại) vì không hoàn tác được.
- Chỉnh tay bắt buộc lý do ≥ 3 ký tự (khớp backend) và chọn 1 trong 3 trạng thái.
- Duyệt/từ chối đơn: ghi chú tùy chọn (≤ 255 ký tự); đơn đã xử lý (`already_reviewed`) báo lỗi và tự làm mới danh sách.
- Xuất Excel qua share sheet; tên file lấy từ `Content-Disposition`, nếu thiếu dùng tên mặc định.
- Polling: danh sách điểm danh trực tiếp mỗi 10 giây khi tab Buổi trực tiếp đang hiện.
- `flutter analyze` sạch; `flutter test` xanh sau mỗi task.
- Nhánh: `feature/flutter-teacher`.

## Review Focus

1. Bấm "Kết thúc buổi" / "Mở chốt" / "Duyệt" hai lần liên tiếp chỉ gọi API một lần (task 4, 5).
2. Chỉnh tay với lý do ngắn hoặc chưa chọn trạng thái bị chặn trước khi gọi API (task 4).
3. Báo cáo lớp có sinh viên không có dữ liệu ở một số buổi (ô trống) và lớp chưa có buổi nào / chưa có sinh viên hiển thị đúng, không crash (task 3).
4. Một lần làm mới điểm danh trực tiếp bị lỗi mạng không làm mất danh sách đang xem (task 4).
5. Xuất Excel lỗi (mất mạng/403) hiện thông báo và không để nút bị khóa mãi (task 3, 4).

## File Structure

```
lib/
├── models/{student_info,attendance_record,class_report,export_file}.dart
├── data/{attendance_repository,report_repository,file_sharer}.dart   (+ mở rộng class/session/leave repository, ApiClient.download)
├── providers/{teacher_providers}.dart
├── screens/teacher/{teacher_classes,teacher_class_detail,class_students_tab,class_sessions_tab,class_report_tab,teacher_live,override_dialog,teacher_leave}_screen.dart
test/helpers/fakes.dart (mở rộng)
```

---

### Task 1: Models, repositories, tải file, chia sẻ file

**Files:** create the models/repos above; modify `data/api_client.dart` (+`download`), `data/class_repository.dart` (+`classStudents`), `data/session_repository.dart` (+`startSession`, `endSession`, `openFinalization`, `classSessions`), `data/leave_repository.dart` (+`classRequests`, `review`), `providers/repositories.dart`; modify `test/helpers/fakes.dart`; `pubspec.yaml` (+`share_plus`, `path_provider`); tests `test/teacher_models_test.dart`, `test/teacher_repositories_test.dart`.

**Interfaces:**
- `StudentInfo.fromJson` (`id, student_id, full_name`).
- `AttendanceRecord.fromJson` (khớp `AttendanceRecordOut`: `student_user_id, student_id, student_name, detection_count, presence_ratio, status, finalized, first_seen_at, overridden, override_reason`); `SessionAttendance.fromJson` (`session_id, class_id, total_students, present_students, records`).
- `ClassReport.fromJson` (khớp `ClassReportOut`: `sessions[{id, starts_at}]`, `students[{…, cells (status|null), present, absent, excused, attendance_percent, absent_percent, warning}]`, `average_attendance_percent`).
- `ExportFile(filename, bytes)`.
- `ApiClient.download(String path) -> Future<({List<int> bytes, String? contentDisposition})>`; lỗi → `ApiException` (lỗi nhị phân của server là JSON, cần giải mã để lấy `{detail, code}`).
- `ClassRepository.classStudents(String classId) -> List<StudentInfo>` (`GET /classes/{id}/students`).
- `SessionRepository`: `startSession(classId)` (`POST /classes/{id}/sessions`), `endSession(id)` (`POST /sessions/{id}/end`), `openFinalization(id)` (`POST /sessions/{id}/open-finalization`) đều trả `SessionInfo`; `classSessions(classId) -> List<SessionInfo>` (`GET /classes/{id}/sessions`).
- `AttendanceRepository`: `sessionAttendance(sessionId) -> SessionAttendance` (`GET /sessions/{id}/attendance`), `override({sessionId, studentUserId, status, reason})` (`POST /sessions/{id}/attendance/override`).
- `ReportRepository`: `classReport(classId) -> ClassReport`, `exportClass(classId) -> ExportFile`, `exportSession(sessionId) -> ExportFile`.
- `LeaveRepository`: `classRequests(classId, {LeaveStatus? status}) -> List<LeaveRequest>`, `review({leaveId, decision ('approved'|'rejected'), note}) -> LeaveRequest`.
- `abstract class FileSharer { Future<void> share(String filename, List<int> bytes); }` + `SharePlusFileSharer` (ghi file tạm rồi mở share sheet).
- Providers mới: `attendanceRepositoryProvider`, `reportRepositoryProvider`, `fileSharerProvider`.

**Tests:** parse từng model với JSON giống backend (null, ô báo cáo `null`); mỗi repository gọi đúng method/đường dẫn/body/query; `download` trả bytes và header, tên file lấy đúng từ `Content-Disposition: attachment; filename="x.xlsx"` (hàm `filenameFromDisposition`, có trường hợp thiếu header → tên mặc định); lỗi JSON của server khi tải nhị phân thành `ApiException` đúng `code`.

### Task 2: Lớp của giảng viên, danh sách sinh viên, lịch sử buổi, bắt đầu buổi

**Files:** create `screens/teacher/teacher_classes_screen.dart`, `teacher_class_detail_screen.dart`, `class_students_tab.dart`, `class_sessions_tab.dart`; modify `providers/teacher_providers.dart`, `screens/shell/tab_pages.dart`, `app/router.dart` (route `/teacher/classes/:id`); tests `test/teacher_classes_test.dart`.

**Behavior:**
- Tab Lớp học: thẻ mỗi lớp (tên môn, `title · học kỳ`, "N sinh viên", chip mã tham gia `join_code` có nút sao chép → SnackBar "Đã sao chép mã lớp"); rỗng "Bạn chưa được phân công lớp nào"; kéo để làm mới.
- Chi tiết lớp (toàn màn hình, `TabBar` 3 tab: Sinh viên, Buổi học, Báo cáo — tab Báo cáo làm ở task 3, tạm là `PlaceholderTab`): Sinh viên = danh sách "MSSV · họ tên" sắp theo MSSV, rỗng "Chưa có sinh viên nào trong lớp"; Buổi học = nút "Bắt đầu buổi học" + lịch sử (giờ bắt đầu, "Đang diễn ra"/"Đã kết thúc", thời lượng).
- "Bắt đầu buổi học": gọi `startSession`; thành công → `context.go('/teacher/live')` và làm mới `activeSessionProvider`; lỗi `session_already_active` và mọi lỗi khác hiện SnackBar thông điệp server; nút khóa khi đang chạy; ẩn/khóa nếu lớp đang có buổi đang diễn ra.

**Tests:** danh sách lớp + số sinh viên + sao chép mã (kiểm tra clipboard); rỗng/lỗi + thử lại; điều hướng vào chi tiết; tab sinh viên (đúng thứ tự, rỗng); tab buổi học (lịch sử, trạng thái); bắt đầu buổi thành công → sang tab Buổi trực tiếp và gọi đúng `classId` một lần dù bấm đúp; lỗi 409 hiện thông điệp và ở lại.

### Task 3: Báo cáo lớp và xuất Excel

**Files:** create `screens/teacher/class_report_tab.dart`; modify `teacher_class_detail_screen.dart`, `providers/teacher_providers.dart`; tests `test/class_report_test.dart`.

**Behavior:** bảng cuộn ngang: cột cố định MSSV + Họ tên, mỗi buổi một cột (`dd/MM`), rồi Có mặt / Vắng / Có phép / % ; ô trạng thái hiển thị chữ cái P/A/E kèm màu, ô `null` để trống ("–"); hàng có `warning` được đánh dấu (biểu tượng cảnh báo + chữ "Vượt mức vắng"); đầu bảng hiện "Trung bình lớp: X%" và số buổi/sinh viên; rỗng ("Lớp chưa có buổi học nào kết thúc" / "Chưa có sinh viên"); nút "Xuất Excel" → `exportClass` → `fileSharer.share`; khóa nút khi đang tải; lỗi hiện SnackBar và mở khóa nút.

**Tests:** bảng hiển thị đúng chữ cái/ô trống/tổng/%; cảnh báo; trung bình; lớp không buổi / không sinh viên; xuất Excel gọi repository đúng `classId` và `fileSharer.share` đúng tên + bytes; xuất lỗi hiện thông điệp và nút dùng lại được; bấm đúp chỉ xuất một lần.

### Task 4: Buổi trực tiếp (điều khiển buổi, điểm danh trực tiếp, chỉnh tay)

**Files:** create `screens/teacher/teacher_live_screen.dart`, `screens/teacher/override_dialog.dart`; modify `tab_pages.dart`, `providers/teacher_providers.dart`; tests `test/teacher_live_test.dart`.

**Behavior:**
- Không có buổi: "Bạn chưa bắt đầu buổi học nào" + gợi ý vào tab Lớp học.
- Có buổi: thẻ (môn, lớp, giờ bắt đầu, "Đang diễn ra"), tóm tắt "Có mặt X / Y sinh viên", nút **Mở chốt điểm danh** (đổi thành chip "Đã mở chốt" và khóa sau khi mở), nút **Kết thúc buổi** (hộp thoại xác nhận "Kết thúc buổi học? Hệ thống sẽ chốt kết quả cả lớp." → `endSession` → SnackBar "Đã kết thúc buổi học", làm mới), nút "Xuất Excel buổi này" (như task 3), ghi chú "Phát/quét BLE sẽ có ở bản cập nhật BLE".
- Danh sách điểm danh (poll 10 giây, kéo để làm mới): mỗi sinh viên MSSV + tên, chip trạng thái, "Hiện diện N%", số lần phát hiện, "Đã chốt" nếu `finalized`, "Trễ X phút" nếu có `first_seen_at` (dùng `late_minutes` tính ở client = phút giữa `starts_at` buổi và `first_seen_at`), nhãn "Đã chỉnh tay" kèm lý do nếu `overridden`.
- Chạm một sinh viên → `OverrideDialog`: 3 lựa chọn trạng thái (Có mặt/Vắng/Có phép, chọn sẵn trạng thái hiện tại), ô lý do (≥ 3 ký tự, ≤ 255), nút Lưu → `override`; lỗi hiện trong hộp thoại và giữ mở; thành công đóng hộp thoại, làm mới danh sách, SnackBar "Đã cập nhật điểm danh".
- Lỗi làm mới giữa chừng không làm mất danh sách đang hiển thị (hiện cảnh báo nhỏ).

**Tests:** không có buổi; có buổi + tóm tắt + danh sách; mở chốt gọi đúng một lần dù bấm đúp và đổi sang "Đã mở chốt"; kết thúc buổi có hộp thoại xác nhận (hủy → không gọi API; đồng ý → gọi đúng một lần dù bấm đúp); chỉnh tay: chặn lý do ngắn/không chọn, gửi đúng `studentUserId/status/reason (trim)`, lỗi giữ hộp thoại, thành công làm mới; "Đã chỉnh tay" và "Trễ X phút" hiển thị; poll 10 giây gọi lại repository; lỗi làm mới giữa chừng vẫn giữ danh sách + cảnh báo; xuất Excel buổi.

### Task 5: Duyệt đơn xin phép

**Files:** create `screens/teacher/teacher_leave_screen.dart`; modify `tab_pages.dart`, `providers/teacher_providers.dart`; tests `test/teacher_leave_test.dart`.

**Behavior:** gom đơn của mọi lớp được phân công (gọi `classRequests` cho từng lớp song song, gộp lại, mới nhất trước); bộ lọc `SegmentedButton`: "Chờ duyệt" (mặc định) / "Tất cả"; thẻ đơn: tên + MSSV, `môn · lớp`, ngày xin phép, lý do, chip trạng thái, ghi chú duyệt (nếu có); đơn `pending` có nút "Duyệt" và "Từ chối" → hộp thoại ghi chú tùy chọn → `review`; thành công → SnackBar ("Đã duyệt đơn"/"Đã từ chối đơn") và làm mới; lỗi `already_reviewed` hiện thông điệp và làm mới; nút khóa khi đang xử lý (không gọi hai lần). Rỗng: "Không có đơn nào chờ duyệt".

**Tests:** gộp nhiều lớp đúng thứ tự; bộ lọc; duyệt/từ chối gọi đúng `leaveId/decision/note (trim, null nếu rỗng)`; hủy hộp thoại không gọi API; bấm đúp chỉ gọi một lần; lỗi 409 làm mới; rỗng; lớp chưa có đơn nào; một lớp tải lỗi thì hiện lỗi + thử lại (không giấu).

### Task 6: Hoàn thiện

- [ ] `dart format`, `flutter analyze` sạch, `flutter test` xanh.
- [ ] README mobile cập nhật; `docs/STATUS.md` cập nhật.
- [ ] `flutter build apk --debug` thành công.
- [ ] Review toàn nhánh bằng reviewer độc lập; sửa lỗi Critical/Important theo TDD.
- [ ] Merge `--no-ff` vào `main` (chỉ trên máy).

---

## Self-Review

- **Phủ spec 7.3 giảng viên:** Lớp học + chi tiết (Sinh viên / Buổi học / Báo cáo + biểu đồ → *biểu đồ để sau, bảng + trung bình trước*), Buổi trực tiếp (mở chốt, kết thúc, override kèm lý do, Excel buổi), Xin phép (duyệt), Thông báo (đã có). Ghi chú: biểu đồ `fl_chart` (spec 7.1) chưa làm trong plan này, đưa vào giai đoạn hoàn thiện nếu còn thời gian.
- **Quét placeholder:** không có "TBD"; hành vi, thông điệp và danh sách test nêu cụ thể.
- **Nhất quán tên:** `SessionAttendance`, `AttendanceRecord`, `ClassReport`, `ExportFile`, `FileSharer`, các repository và provider dùng thống nhất.
