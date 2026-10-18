# Flutter Foundation Implementation Plan (Plan 3/5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (the human chose inline/native execution). Every task is TDD: write the listed tests, watch them fail, then implement.

**Goal:** Dựng lại nền tảng ứng dụng Flutter (Android): cấu trúc thư mục, Riverpod, go_router, lớp API mới khớp backend mới, đăng nhập/đăng ký/đổi mật khẩu bắt buộc/cài đặt máy chủ bằng tiếng Việt, và khung điều hướng cho 3 vai trò (admin, giảng viên, sinh viên) với các tab giữ chỗ.

**Architecture:** `data/` (ApiClient + repositories + TokenStore) → `providers/` (Riverpod Notifier) → `screens/` + `app/router.dart`. Logic quyết định điều hướng là hàm thuần để unit test. Mọi thao tác mạng đi qua `ApiClient` và ném `ApiException {code, message}` (tiếng Việt). Không phụ thuộc BLE trong plan này; mã quyền/foreground service cũ được chuyển nguyên vào `lib/ble/` để Plan 5 dùng lại.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `flutter_riverpod`, `go_router`, `intl`, `dio`, `flutter_secure_storage` (đã có).

**Spec:** `docs/superpowers/specs/2026-10-18-ble-attendance-expansion-design.md` (mục 7)

**Ghi chú định dạng (Ruling):** plan gọn như Plan 2 (hành vi + danh sách test, mã viết khi thực thi theo TDD), vì quy ước đã chốt và người dùng muốn làm tiếp ngay.

## Global Constraints

- Chỉ Android. Giao diện **tiếng Việt**, Material 3, màu chủ đạo `0xFF0B6E4F`, có dark mode (`ThemeMode.system`).
- Backend trả lỗi `{detail, code}`; mã lỗi mạng của app: `network`, `timeout`, `unknown`.
- Vai trò lấy từ `GET /auth/me`, **không** từ lựa chọn của người dùng. `must_change_password == true` thì mọi route (trừ `/settings`) chuyển về `/change-password`.
- 401 từ API (trừ `/auth/login`) → xóa token và về màn hình đăng nhập.
- Token và URL máy chủ lưu bằng `flutter_secure_storage` qua interface `TokenStore` (test dùng bản trong bộ nhớ).
- URL máy chủ mặc định lấy từ `--dart-define=API_BASE_URL`, mặc định `http://192.168.1.7:8000`; chuẩn hóa: thêm `http://` nếu thiếu, bỏ `/` cuối.
- Tab giữ chỗ: sinh viên 4 tab (Trang chủ, Lớp của tôi, Xin phép, Thông báo); giảng viên 4 tab (Lớp học, Buổi trực tiếp, Xin phép, Thông báo); admin 4 tab (Môn học, Lớp học, Giảng viên, Sinh viên).
- `flutter analyze` phải sạch; `flutter test` phải xanh sau mỗi task.
- Nhánh: `feature/flutter-foundation`.

## Review Focus

1. Mở app khi có token hết hạn: không kẹt ở splash, về màn hình đăng nhập (task 3).
2. Mất mạng lúc khởi động không xóa token và không làm app treo (task 3).
3. Mật khẩu nhập lệch xác nhận / ngắn hơn 6 ký tự bị chặn trước khi gọi API (task 5).
4. Người dùng buộc đổi mật khẩu không thoát được khỏi màn hình đó bằng nút Back hay URL khác (task 4).
5. Đăng nhập sai không để lại token cũ và không chuyển trang (task 3, 5).

## File Structure

```
lib/
├── main.dart                       ProviderScope + App
├── app/{app,router,theme}.dart
├── core/{app_constants,api_exception,validators}.dart
├── models/{app_role,auth_user}.dart
├── data/{token_store,api_client,auth_repository}.dart
├── providers/{core_providers,auth_controller}.dart
├── ble/{ble_permissions,foreground_service}.dart     (chuyển nguyên từ main.dart cũ)
├── screens/auth/{splash,login,register,change_password,server_settings}_screen.dart
├── screens/shell/{app_shell,placeholder_tab}.dart
└── widgets/{error_banner,labeled_field}.dart
test/ (unit + widget; helpers trong test/helpers/)
```
Xóa: `lib/models/student_tally.dart`, `lib/services/api_client.dart`, toàn bộ màn hình trong `main.dart` cũ.

---

### Task 1: Phụ thuộc, lõi lỗi, validator, mô hình

**Files:** modify `pubspec.yaml`; create `core/api_exception.dart`, `core/validators.dart`, `models/app_role.dart` (viết lại), `models/auth_user.dart`; tests `test/api_exception_test.dart`, `test/validators_test.dart`, `test/auth_user_test.dart`.

**Interfaces:**
- `ApiException(code, message, {statusCode})` implements `Exception`; `ApiException.fromDio(DioException)`; `String friendlyError(Object)`.
- `AppRole { admin, teacher, student }` với `AppRole.parse(String)` (lạ → ném `FormatException`) và `homePath` (`/admin`, `/teacher`, `/student`).
- `AuthUser { id, fullName, role, studentId, teacherId, mustChangePassword }`, `AuthUser.fromJson`, getter `loginId`.
- `Validators.requiredField(String? v, String label)`, `Validators.password(String? v)` (≥ 6), `Validators.confirm(String? v, String other)`, `normalizeId(String)` (trim + upper), `normalizeBaseUrl(String)` (ném `ApiException('invalid_url')` nếu rỗng/sai).
- Thêm gói: `flutter pub add flutter_riverpod go_router intl`.

**Tests:** `fromDio` map đúng `{detail, code}` → code/message/statusCode; 422 dạng danh sách mặc định của FastAPI → code `validation`; connectionError/timeout → `network`/`timeout` với thông báo tiếng Việt; lỗi lạ → `unknown`; `friendlyError` với `ApiException` và lỗi thường; `AppRole.parse` 3 giá trị + giá trị lạ; `AuthUser.fromJson` student/teacher/admin (`loginId` đúng); validators (rỗng, 5 vs 6 ký tự, khác xác nhận); `normalizeBaseUrl` (`192.168.1.7:8000/` → `http://192.168.1.7:8000`, giữ `https://`, rỗng → lỗi).

### Task 2: TokenStore và ApiClient

**Files:** create `data/token_store.dart`, `data/api_client.dart`; delete `services/api_client.dart`, `models/student_tally.dart`; tests `test/api_client_test.dart`, helper `test/helpers/memory_token_store.dart`, `test/helpers/fake_adapter.dart`.

**Interfaces:**
- `abstract class TokenStore { Future<String?> readToken(); Future<void> saveToken(String); Future<void> clearToken(); Future<String?> readBaseUrl(); Future<void> saveBaseUrl(String); }`; `SecureTokenStore` (flutter_secure_storage).
- `ApiClient({required TokenStore store, Dio? dio})`: `Future<void> init()` (đọc URL đã lưu), `String get baseUrl`, `Future<void> setBaseUrl(String)` (chuẩn hóa + lưu), `Dio get dio`, `void Function()? onUnauthorized`, `Future<T> request<T>(...)` hoặc các hàm `get/post` trả `dynamic` đã giải mã JSON và ném `ApiException`.
- Interceptor: gắn `Authorization: Bearer <token>` nếu có token; gặp 401 và đường dẫn khác `/auth/login` → `clearToken()` rồi gọi `onUnauthorized`.

**Tests:** gắn header Authorization khi có token, không gắn khi không có; 401 gọi `onUnauthorized` và xóa token; 401 của `/auth/login` thì không; lỗi `{detail, code}` thành `ApiException`; `setBaseUrl` chuẩn hóa, lưu và `init` đọc lại; mất kết nối → `ApiException('network')`.

### Task 3: AuthRepository và AuthController

**Files:** create `data/auth_repository.dart`, `providers/core_providers.dart`, `providers/auth_controller.dart`; tests `test/auth_controller_test.dart` (repository giả + MemoryTokenStore).

**Interfaces:**
- `abstract class AuthRepository { Future<LoginResult> login(String id, String password); Future<AuthUser> register({required String fullName, required String identifier, required String password}); Future<AuthUser> me(); Future<void> changePassword({required String oldPassword, required String newPassword}); }`, `LoginResult(accessToken, mustChangePassword)`; `ApiAuthRepository(ApiClient)` gọi `/auth/login`, `/auth/register`, `/auth/me`, `/auth/change-password`.
- `AuthStatus { unknown, unauthenticated, authenticated }`, `AuthState(status, user)`.
- `AuthController extends Notifier<AuthState>`: `bootstrap()`, `login(id, password)` (chuẩn hóa mã; lưu token; gọi `me()`; lỗi thì ném `ApiException` và giữ trạng thái cũ, không để token), `register(...)` (tạo rồi đăng nhập), `changePassword(old, new)` (xong gọi lại `me()` để cập nhật cờ), `logout()` (xóa token).
- Providers: `tokenStoreProvider`, `apiClientProvider`, `authRepositoryProvider` (ghi đè được trong test), `authControllerProvider`.
- `apiClient.onUnauthorized` được nối để `AuthController` chuyển sang `unauthenticated`.

**Tests:** bootstrap không token → unauthenticated; có token hợp lệ → authenticated với user; token hết hạn (repository ném 401) → unauthenticated và token bị xóa; mất mạng → unauthenticated nhưng **không xóa token**; login đúng → authenticated, token đã lưu, mã được chuẩn hóa; login sai → ném `ApiException`, trạng thái và token không đổi; register thành công tự đăng nhập; changePassword xóa cờ `mustChangePassword`; logout xóa token; `onUnauthorized` đưa về unauthenticated.

### Task 4: Router, theme, khung điều hướng 3 vai trò

**Files:** create `app/app.dart`, `app/router.dart`, `app/theme.dart`, `screens/shell/app_shell.dart`, `screens/shell/placeholder_tab.dart`, `screens/auth/splash_screen.dart`; rewrite `main.dart`; tests `test/router_redirect_test.dart`, `test/app_shell_test.dart`.

**Interfaces:**
- `String? authRedirect(AuthState auth, String location)` (thuần).
  - `unknown` → `/splash`; `unauthenticated` → cho phép `/login`, `/register`, `/settings`, còn lại → `/login`; `authenticated` + `mustChangePassword` → mọi route (trừ `/settings`) → `/change-password`; `authenticated` bình thường: `/login`, `/register`, `/splash`, `/change-password` → `role.homePath`; route không thuộc nhánh vai trò của mình (ví dụ GV vào `/admin/...`) → `role.homePath`; `/settings` luôn cho phép.
- `routerProvider` (GoRouter, `refreshListenable` theo `authControllerProvider`), `StatefulShellRoute.indexedStack` cho `/student`, `/teacher`, `/admin` (mỗi vai trò 4 nhánh theo Global Constraints).
- `AppShell`: `NavigationBar` + AppBar có menu hồ sơ (tên người dùng, "Đổi mật khẩu", "Cài đặt máy chủ", "Đăng xuất").
- `PlaceholderTab(title, icon)`.

**Tests:** bảng quyết định `authRedirect` đầy đủ (mọi trạng thái × vị trí quan trọng, gồm GV vào `/admin`, SV vào `/teacher/x`, `mustChangePassword`); khung vai trò hiển thị đúng 4 nhãn tab theo vai trò và chuyển tab được; menu hồ sơ có "Đăng xuất" và gọi logout; thanh điều hướng không xuất hiện ở màn hình đăng nhập.

### Task 5: Màn hình xác thực và cài đặt máy chủ

**Files:** create `screens/auth/{login,register,change_password,server_settings}_screen.dart`, `widgets/error_banner.dart`, `widgets/labeled_field.dart`; modify `router.dart` (nối route); tests `test/login_screen_test.dart`, `test/register_screen_test.dart`, `test/change_password_screen_test.dart`, `test/server_settings_screen_test.dart`.

**Behavior:**
- Đăng nhập: ô mã (tự viết hoa), ô mật khẩu (nút hiện/ẩn), nút "Đăng nhập" bị khóa khi đang gọi, lỗi hiện bằng `ErrorBanner`, biểu tượng bánh răng → `/settings`, liên kết "Chưa có tài khoản? Đăng ký (sinh viên)". Tiêu đề màn hình: **"Điểm danh BLE"**.
- Đăng ký (chỉ SV): họ tên, MSSV, mật khẩu, nhập lại mật khẩu; chặn ở client khi rỗng/ngắn/lệch xác nhận; lỗi server hiện bằng `ErrorBanner`.
- Đổi mật khẩu: mật khẩu hiện tại, mới, nhập lại; ở chế độ bắt buộc thì không có nút Back (`PopScope(canPop: false)`) và có nút "Đăng xuất"; thành công → trang chủ vai trò.
- Cài đặt máy chủ: ô URL, "Kiểm tra kết nối" (GET `/health`, hiện ✔/✘), "Lưu", "Đánh thức máy chủ" (thử `/health` mỗi 5 giây tối đa 12 lần, có đếm ngược; khoảng thời gian tiêm được để test nhanh).

**Tests:** đăng nhập: trường rỗng báo lỗi và không gọi controller; thành công điều hướng về trang chủ vai trò; sai mật khẩu hiện thông báo từ server và ở lại; nút bị khóa khi đang chờ; mã chữ thường được gửi đã chuẩn hóa. Đăng ký: mật khẩu ngắn, lệch xác nhận, đăng ký thành công. Đổi mật khẩu: bắt buộc thì không pop được và có "Đăng xuất"; sai mật khẩu cũ hiện lỗi; thành công về trang chủ. Cài đặt: URL sai định dạng báo lỗi; lưu chuẩn hóa URL; kiểm tra kết nối thành công/thất bại; đánh thức dừng ngay khi `/health` trả lời.

### Task 6: Dọn mã cũ, chuyển mã BLE dùng lại, tài liệu

**Files:** create `ble/ble_permissions.dart`, `ble/foreground_service.dart`; modify `README.md` (mobile); delete mã màn hình cũ còn sót; update `test/widget_test.dart`.

- Chuyển nguyên `_ensureBlePermissions`, `_ensureBleAdvertisePermissions`, `_ensureBleScanPermissions`, `_ensureBluetoothEnabled`, `_initForegroundTask`, `_startForegroundService` từ `main.dart` cũ thành hàm công khai trong `lib/ble/` (đổi tên bỏ dấu `_`), không đổi hành vi.
- `test/widget_test.dart` cập nhật: ứng dụng khởi động đến màn hình đăng nhập "Điểm danh BLE".
- [ ] `flutter analyze` sạch, `flutter test` xanh.
- [ ] README mobile: cấu trúc mới, lệnh chạy/kiểm thử, ghi chú Android-only.
- [ ] Nếu có Android SDK: `flutter build apk --debug` để xác nhận biên dịch (nếu không có SDK, ghi rõ chưa kiểm chứng).
- [ ] Commit.

---

## Self-Review

- **Phủ spec mục 7:** cấu trúc thư mục (7.2), Riverpod + go_router (7.1), auth + đổi mật khẩu bắt buộc + cài đặt máy chủ (7.3), `/auth/me` quyết định vai trò và 401 tự đăng xuất (7.4), khung 3 vai trò (7.3). Các màn hình nghiệp vụ, thống kê, thông báo, import, BLE mới thuộc Plan 4 và 5.
- **Quét placeholder:** không có "TBD"; hành vi, quy tắc điều hướng và danh sách test được nêu cụ thể.
- **Nhất quán tên:** `ApiException`, `AuthUser`, `AuthController`, `AuthState`, `TokenStore`, `authRedirect`, `AppRole.homePath` dùng thống nhất giữa các task.
