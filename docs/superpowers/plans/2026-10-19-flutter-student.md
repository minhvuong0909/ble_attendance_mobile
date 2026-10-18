# Flutter Student & Shared Data Layer Implementation Plan (Plan 4A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline/native). Every task is TDD: write the listed tests, watch them fail, then implement.

**Goal:** Xây lớp dữ liệu dùng chung (models, repositories, providers, widget trạng thái tải/lỗi/rỗng) và hoàn thành các màn hình **sinh viên** + tab **thông báo** (kèm badge) theo spec mục 7.3.

**Architecture:** Mỗi miền có `abstract Repository` + `ApiXRepository` (dùng `ApiClient`), được cung cấp qua Riverpod provider để test thay bằng bản giả. Màn hình dùng `FutureProvider.autoDispose` + `AsyncValueView` (tải / lỗi có nút thử lại / rỗng). Xác thực sinh trắc đi qua interface `DeviceAuthenticator` để test không cần thiết bị.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, go_router 18, dio, local_auth, intl, flutter_localizations.

**Spec:** `docs/superpowers/specs/2026-10-18-ble-attendance-expansion-design.md` (mục 4.3, 4.4, 4.5, 6.2, 7.3). **Backend:** đã merge vào `main` (API ở `backend/README.md`).

**Ghi chú định dạng (Ruling):** plan gọn (hành vi + test), mã viết khi thực thi theo TDD, như Plan 2/3. **Phạm vi:** plan này *không* làm BLE (trạng thái gần/xa, phát/quét) — thuộc plan BLE sau. Màn hình chủ sinh viên vì vậy chưa có chỉ báo khoảng cách; chốt điểm danh vẫn gọi API và server tự kiểm tra `not_in_range`.

## Global Constraints

- Giao diện tiếng Việt, Material 3, mọi danh sách có đủ 3 trạng thái: đang tải, rỗng (có lời nhắn), lỗi (có nút "Thử lại").
- Thời gian từ server là UTC có hậu tố `Z`; hiển thị luôn đổi sang giờ máy (`toLocal()`), định dạng `dd/MM/yyyy HH:mm`.
- Mã lỗi/thông báo lỗi lấy từ `ApiException.message` (tiếng Việt từ server hoặc từ lớp lõi), không tự dịch lại.
- Trạng thái điểm danh hiển thị: `present` → "Có mặt" (xanh), `absent` → "Vắng" (đỏ), `excused` → "Có phép" (vàng/cam). Trạng thái đơn: `pending` "Chờ duyệt", `approved` "Đã duyệt", `rejected` "Bị từ chối".
- Cảnh báo vắng (`warning == true`) luôn hiện nổi bật (biểu tượng + chữ "Vượt mức vắng cho phép"), không chỉ dựa vào màu.
- Chốt điểm danh: bắt buộc qua `DeviceAuthenticator.authenticate` (vân tay/khóa màn hình, cho phép mã PIN) rồi mới gọi `POST /attendance/finalize`; người dùng hủy xác thực thì không gọi API.
- Thông báo: lấy số chưa đọc mỗi 30 giây khi app mở; badge hiện trên tab "Thông báo".
- `flutter analyze` sạch; `flutter test` xanh sau mỗi task.
- Nhánh: `feature/flutter-student`.

## Review Focus

1. Bấm "Xác nhận điểm danh" hai lần liên tiếp chỉ gọi API một lần (task 4).
2. Người dùng hủy xác thực sinh trắc: không có lỗi đỏ, không gọi API (task 4).
3. Đang tải danh sách thì kéo làm mới / chuyển tab không làm app crash do `setState` sau khi thoát màn hình (task 3–6).
4. Chọn ngày xin phép trong quá khứ xa / lớp chưa chọn bị chặn trước khi gọi API (task 6).
5. Thời gian hiển thị đúng múi giờ máy (giá trị UTC `Z` không bị hiểu thành giờ địa phương) (task 1).

## File Structure

```
lib/
├── core/formatters.dart
├── models/{attendance_status,class_info,session_info,attendance_history,class_stats,leave_request,app_notification}.dart
├── data/{class_repository,session_repository,stats_repository,leave_repository,notification_repository,device_authenticator}.dart
├── providers/{repositories,notifications_provider}.dart
├── widgets/{async_value_view,status_chip}.dart
├── screens/shell/tab_pages.dart                 (chọn trang cho từng tab theo vai trò)
├── screens/notifications/notifications_screen.dart
└── screens/student/{student_home,student_classes,class_detail,student_leave,leave_form}_screen.dart
```

---

### Task 1: Models, formatters, widget dùng chung

**Files:** create `core/formatters.dart`, `models/*.dart` (liệt kê ở trên), `widgets/async_value_view.dart`, `widgets/status_chip.dart`; modify `pubspec.yaml` (thêm `flutter_localizations`), `app/app.dart` (locale `vi`); tests `test/models_test.dart`, `test/formatters_test.dart`, `test/async_value_view_test.dart`, `test/status_chip_test.dart`.

**Interfaces:**
- `enum AttendanceStatus { present, absent, excused }` + `parse(String)`, `label` (tiếng Việt).
- `ClassInfo.fromJson` (khớp `ClassOut`: `id, course_id, course_code, course_name, class_code, semester, teacher_user_id, teacher_name, join_code, max_absence_percent, rssi_threshold, student_count`), getter `title` = `"$courseCode · $classCode"`.
- `SessionInfo.fromJson` (khớp `SessionOut` gồm `beacon_code`, `beacon_secret`), `startsAt/endsAt` là `DateTime` đã `toLocal()`.
- `AttendanceHistoryItem.fromJson` (`session_id, starts_at, ends_at, status, presence_ratio, first_seen_at, late_minutes`).
- `ClassStats.fromJson` (khớp `ClassStatsOut`).
- `LeaveStatus { pending, approved, rejected }` + `label`; `LeaveRequest.fromJson` (khớp `LeaveOut`, `date` là `DateTime` chỉ ngày).
- `AppNotification.fromJson` (`id, type, title, body, ref_id, is_read, created_at`) + `copyWith(isRead:)`.
- `formatDateTime(DateTime)` → `dd/MM/yyyy HH:mm`, `formatDate(DateTime)` → `dd/MM/yyyy`, `toApiDate(DateTime)` → `yyyy-MM-dd`.
- `AsyncValueView<T>({required AsyncValue<T> value, required Widget Function(T) data, required VoidCallback onRetry, bool Function(T)? isEmpty, String emptyMessage, IconData emptyIcon})`: loading → vòng quay; error → lời nhắn (`friendlyError`) + nút "Thử lại"; rỗng → icon + lời nhắn; ngược lại `data`.
- `StatusChip(label, color, {icon})`; helper `attendanceChip(AttendanceStatus)`, `leaveChip(LeaveStatus)`.

**Tests:** parse từng model với JSON mẫu giống backend (gồm giá trị null); thời gian UTC `…Z` thành đúng thời điểm (so với `DateTime.utc(...)`), đổi sang local giữ nguyên instant; enum lạ → `FormatException`; formatters; `AsyncValueView` đủ 4 trạng thái và nút "Thử lại" gọi callback; chip hiển thị nhãn tiếng Việt đúng.

### Task 2: Repositories và providers

**Files:** create `data/{class,session,stats,leave,notification}_repository.dart`, `data/device_authenticator.dart`, `providers/repositories.dart`; tests `test/repositories_test.dart` (ApiClient + `FakeAdapter`), helper `test/helpers/fakes.dart` (các repository giả).

**Interfaces (mỗi cái gồm `abstract` + `Api…`):**
- `ClassRepository`: `Future<List<ClassInfo>> myClasses()` (`GET /classes/mine`), `Future<ClassInfo> join(String joinCode)` (`POST /classes/join`).
- `SessionRepository`: `Future<SessionInfo?> activeSession()` (`GET /sessions/active`; mã lỗi `no_active_session` → `null`), `Future<void> finalize(String sessionId)` (`POST /attendance/finalize`).
- `StatsRepository`: `Future<List<ClassStats>> stats()` (`GET /me/attendance/stats`), `Future<List<AttendanceHistoryItem>> history(String classId)` (`GET /me/attendance?class_id=`).
- `LeaveRepository`: `Future<List<LeaveRequest>> mine()` (`GET /leave-requests/mine`), `Future<LeaveRequest> create({classId, date, reason})` (`POST /leave-requests`, `date` dạng `yyyy-MM-dd`).
- `NotificationRepository`: `list({bool unreadOnly})`, `unreadCount()`, `markRead(int id)`, `markAllRead()`.
- `abstract class DeviceAuthenticator { Future<bool> authenticate(String reason); }` + `LocalAuthAuthenticator` (`local_auth`, `biometricOnly: false`; thiết bị không hỗ trợ → ném `ApiException('device_auth_unavailable', …)`).
- Providers: `classRepositoryProvider`, `sessionRepositoryProvider`, `statsRepositoryProvider`, `leaveRepositoryProvider`, `notificationRepositoryProvider`, `deviceAuthenticatorProvider`.

**Tests:** mỗi repository gọi đúng method/đường dẫn/body/query và parse đúng; `activeSession` trả `null` khi 404 `no_active_session` nhưng vẫn ném với 404 khác; `create` gửi `date` đúng định dạng; lỗi server thành `ApiException`.

### Task 3: Thông báo (dùng chung) và badge

**Files:** create `providers/notifications_provider.dart`, `screens/notifications/notifications_screen.dart`, `screens/shell/tab_pages.dart`; modify `screens/shell/app_shell.dart`, `app/router.dart`; tests `test/notifications_screen_test.dart`.

**Behavior:** `unreadCountProvider` (poll 30 giây, `autoDispose`); màn hình liệt kê thông báo mới nhất trước, chưa đọc in đậm + chấm; chạm một thông báo → `markRead` và hiển thị đã đọc ngay (lạc quan, hoàn lại nếu lỗi); nút "Đọc tất cả" trên thanh công cụ; kéo để làm mới; trạng thái tải/rỗng ("Chưa có thông báo")/lỗi. `AppShell` hiển thị `Badge` số chưa đọc (ẩn khi 0, "99+" khi > 99) trên tab có path kết thúc `/notifications`. `tab_pages.dart`: `Widget pageFor(AppRole role, int index)`; tab thông báo của sinh viên/giảng viên dùng `NotificationsScreen`, các tab khác tạm giữ `PlaceholderTab` (sinh viên sẽ thay ở task 4–6).

**Tests:** danh sách đúng thứ tự và kiểu chữ chưa đọc; chạm → gọi `markRead` đúng id và mất dấu chưa đọc; `markRead` lỗi → hoàn lại và hiện thông báo lỗi; "Đọc tất cả" gọi repository và xóa dấu; trạng thái rỗng và lỗi + thử lại; badge hiện số đúng, ẩn khi 0, "99+" khi 150; admin không có tab thông báo.

### Task 4: Màn hình chủ sinh viên (buổi học đang diễn ra + chốt điểm danh)

**Files:** create `screens/student/student_home_screen.dart`; modify `tab_pages.dart`; tests `test/student_home_test.dart`.

**Behavior:** thẻ buổi học (môn, mã lớp, giờ bắt đầu, nhãn "Đang diễn ra"); trạng thái chốt: "Giảng viên chưa mở chốt" (nút khóa) hoặc "Đã mở chốt" (nút "Xác nhận điểm danh" bật); bấm nút → `deviceAuthenticator.authenticate('Xác nhận điểm danh')` → nếu `true` gọi `finalize`; thành công → thẻ xanh "Đã xác nhận điểm danh"; lỗi API → `ErrorBanner` với thông báo server (ví dụ chưa phát hiện trong lớp); hủy xác thực → không làm gì, không lỗi. Nút bị khóa trong lúc xử lý (chống bấm đúp). Không có buổi → lời nhắn "Hiện không có buổi học nào đang diễn ra". Tự làm mới mỗi 15 giây và khi kéo xuống; lỗi tải hiện + thử lại.

**Tests:** có/không có buổi; nút khóa khi chưa mở chốt, bật khi đã mở; thành công gọi `authenticate` rồi `finalize` đúng một lần và hiện thẻ xác nhận; bấm hai lần nhanh chỉ gọi `finalize` một lần; hủy xác thực → không gọi API và không có banner lỗi; xác thực ném lỗi → hiện thông báo; `finalize` lỗi `not_in_range` → banner hiện thông điệp server; tự làm mới sau 15 giây (dùng `tester.pump(Duration)`); lỗi tải + thử lại.

### Task 5: Lớp của tôi, thống kê, tham gia lớp, chi tiết lớp

**Files:** create `screens/student/student_classes_screen.dart`, `screens/student/class_detail_screen.dart`; modify `tab_pages.dart`, `app/router.dart` (route con `/student/classes/:id`); tests `test/student_classes_test.dart`, `test/class_detail_test.dart`.

**Behavior:** danh sách thẻ theo lớp: tên môn, `title`, học kỳ, vòng tròn % chuyên cần (`attendance_percent`), số buổi, chip cảnh báo "Vượt mức vắng cho phép" nếu `warning`; nút "Tham gia lớp" → hộp thoại nhập mã (tự viết hoa, không rỗng) → `join` → làm mới danh sách và hiện thông báo thành công; lỗi `invalid_join_code`/`already_enrolled` hiện trong hộp thoại và hộp thoại giữ mở. Chạm thẻ → chi tiết lớp: phần đầu tóm tắt (% chuyên cần, có mặt/vắng/có phép, cảnh báo nếu có) và danh sách lịch sử mới nhất trước: ngày giờ, chip trạng thái, "Trễ X phút" nếu có `late_minutes > 0`, % hiện diện; trạng thái rỗng "Chưa có buổi học nào kết thúc".

**Tests:** danh sách hiển thị đúng số liệu và cảnh báo; rỗng ("Bạn chưa tham gia lớp nào…") và lỗi + thử lại; tham gia lớp thành công làm mới, mã viết thường được gửi đã chuẩn hóa; lỗi mã sai giữ hộp thoại; không gọi API khi mã rỗng; chi tiết lớp hiển thị lịch sử đúng thứ tự, chip, "Trễ 3 phút" chỉ khi > 0; rỗng; điều hướng từ thẻ vào chi tiết và quay lại.

### Task 6: Xin phép vắng

**Files:** create `screens/student/student_leave_screen.dart`, `screens/student/leave_form_screen.dart`; modify `tab_pages.dart`, `app/router.dart` (route `/student/leave/new`); tests `test/student_leave_test.dart`.

**Behavior:** danh sách đơn (môn + mã lớp, ngày xin phép, lý do rút gọn, chip trạng thái, ghi chú duyệt nếu có), mới nhất trước; rỗng "Bạn chưa gửi đơn xin phép nào"; nút nổi "Xin phép". Form: chọn lớp (dropdown từ `myClasses`, bắt buộc; nếu chưa vào lớp nào thì báo "Hãy tham gia lớp trước"), chọn ngày (`showDatePicker`, từ hôm nay trừ 7 ngày đến hôm nay cộng 90 ngày, mặc định hôm nay), lý do (≥ 3 ký tự, ≤ 500); gửi → `create` → quay lại danh sách và làm mới, hiện "Đã gửi đơn xin phép"; lỗi (ví dụ `leave_exists`) hiện bằng `ErrorBanner` và giữ form; nút khóa khi đang gửi.

**Tests:** danh sách đúng nội dung/chip/ghi chú; rỗng; form chặn khi chưa chọn lớp / lý do ngắn; gửi thành công gọi `create` với `classId`, ngày dạng `yyyy-MM-dd` và lý do đã cắt khoảng trắng, quay lại và danh sách làm mới; lỗi 409 hiện thông điệp server; bấm gửi hai lần chỉ gọi một lần; date picker không cho ngày ngoài khoảng (kiểm tra `firstDate/lastDate` qua giá trị truyền vào hàm helper `leaveDateRange(DateTime today)`).

### Task 7: Hoàn thiện

- [ ] `dart format`, `flutter analyze` sạch, `flutter test` xanh.
- [ ] Cập nhật `README.md` (mobile): các màn hình sinh viên và thông báo đã có.
- [ ] `flutter build apk --debug` thành công (chạy nền, đợi bằng Monitor).
- [ ] Review toàn nhánh bằng reviewer độc lập, sửa lỗi Critical/Important theo TDD.
- [ ] Commit.

---

## Self-Review

- **Phủ spec:** 7.3 màn hình sinh viên — Trang chủ (task 4), Lớp của tôi + % chuyên cần + lịch sử + tham gia lớp (task 5), Xin phép (task 6), Thông báo + badge (task 3). Cảnh báo vắng (4.5) hiển thị ở task 5; "trễ X phút" (4.4) ở task 5; chốt cần xác thực (4.3) ở task 4. Chỉ báo gần/xa và BLE để plan BLE.
- **Quét placeholder:** không có "TBD"; hành vi, ngưỡng, thông điệp và danh sách test nêu cụ thể.
- **Nhất quán tên:** `AsyncValueView`, `StatusChip`, `DeviceAuthenticator`, các `*Repository`/`*RepositoryProvider`, `pageFor`, `leaveDateRange` dùng thống nhất.
