# Thiết kế mở rộng: Hệ thống quản lý lớp học và điểm danh BLE

Ngày: 2026-10-18 · Trạng thái: chờ duyệt · Thời hạn: 3 tuần · Nền tảng: chỉ Android (APK)

## 1. Mục tiêu và phạm vi

### 1.1 Bối cảnh
Repo hiện chỉ có một chức năng: điểm danh bằng BLE (xem `ARCHITECTURE.md`, `TAI_LIEU_DU_AN_BLE_ATTENDANCE.docx`). Đề tài môn học PRM cần phạm vi rộng hơn và code chắc hơn. Giữ lõi BLE đã có, sửa các lỗi logic, rồi mở rộng thành **hệ thống quản lý lớp học và điểm danh**.

### 1.2 Trong phạm vi
1. **Sửa lõi điểm danh:** công thức presence, lỗi override bị ghi đè, báo cáo thiếu SV vắng, chống giả mạo BLE ở mức vừa phải.
2. **Quản lý học vụ (Admin):** môn học, lớp, tài khoản giảng viên, gán GV vào lớp, import danh sách (môn/lớp, GV, SV vào lớp).
3. **Dashboard và thống kê cho SV:** lịch sử điểm danh, % chuyên cần theo lớp, cảnh báo vắng.
4. **Báo cáo và quản lý cho GV:** xem lại buổi cũ, UI chỉnh tay có lý do, báo cáo cả kỳ, Excel nhiều buổi, biểu đồ.
5. **Xin phép vắng và thông báo trong app.**
6. Tái cấu trúc backend (Alembic, routers, services) và Flutter (tách màn hình, Riverpod, go_router), giao diện tiếng Việt, có test.

### 1.3 Ngoài phạm vi
iOS; push notification (FCM); điểm danh nhanh ngẫu nhiên nhiều lần trong buổi; trạng thái `late` riêng; khôi phục mật khẩu qua email; đăng nhập nhiều thiết bị; tích hợp hệ thống đào tạo; chống gian lận khi GV dùng client giả mạo.

### 1.4 Tiêu chí thành công
- Admin tạo môn/lớp, import GV và SV, gán GV; GV mở buổi và điểm danh trên máy thật; SV chốt; báo cáo cả kỳ đúng, gồm cả SV vắng.
- Các kịch bản gian lận cơ bản (phát lại mã SV, SV ngoài lớp, SV rời đi sau khi chốt) bị xử lý đúng quy tắc ở mục 4.
- Pytest và Flutter test chạy xanh; build được release APK; có tài liệu và kịch bản demo.

## 2. Vai trò

| Việc | Admin | Giảng viên | Sinh viên |
|---|---|---|---|
| Tạo môn, lớp; tạo/import tài khoản GV; gán GV vào lớp | ✅ | ❌ | ❌ |
| Import danh sách SV vào lớp | ✅ | ❌ | ❌ |
| Mở buổi, điểm danh, mở chốt, override | ❌ | ✅ (lớp được gán) | ❌ |
| Xem báo cáo lớp | ✅ tất cả | ✅ lớp mình | ❌ |
| Điểm danh, chốt, xem chuyên cần của mình | ❌ | ❌ | ✅ |
| Gửi đơn xin phép | ❌ | ❌ | ✅ |
| Duyệt đơn xin phép | ❌ | ✅ (lớp mình) | ❌ |

- Tài khoản admin đầu tiên do `seed_demo.py` tạo. Tài khoản GV chỉ do admin tạo hoặc import (**bỏ** tự đăng ký GV).
- SV có thể tự đăng ký và vào lớp bằng `join_code`, hoặc được tạo sẵn qua import.
- Tài khoản tạo bằng import có mật khẩu tạm bằng mã định danh và `must_change_password = true`. Admin có thể reset mật khẩu.
- Role do server trả về qua `GET /auth/me`; app không còn cho người dùng chọn role khi đăng nhập.

## 3. Mô hình dữ liệu

Quản lý schema bằng **Alembic**, bỏ `ALTER TABLE` thủ công khi khởi động.

| Bảng | Trường chính |
|---|---|
| `users` | `id`, `student_id`, `teacher_id` (dùng chung cho mã GV và mã admin), `full_name`, `role` (admin/teacher/student), `password_hash`, `must_change_password`, `created_at` |
| `courses` | `id`, `code` (unique), `name`, `credits` |
| `classes` | `id`, `course_id`, `class_code`, `semester`, `teacher_user_id` (**nullable** đến khi được gán), `join_code` (unique), `max_absence_percent` (mặc định 20), `rssi_threshold` (mặc định -75), unique `(course_id, class_code, semester)` |
| `enrollments` | `class_id`, `student_user_id`, `joined_at`, `source` (import/join_code), unique theo cặp |
| `sessions` | `id`, `class_id`, `teacher_user_id`, `token`, `starts_at`, `ends_at`, `is_active`, `finalization_open` |
| `detections` | `id`, `session_id`, `student_user_id`, `rssi`, `detected_at` (giờ quan sát), index `(session_id, student_user_id, detected_at)` |
| `attendance` | `session_id`, `student_user_id`, `presence_ratio`, `status` (present/absent/excused), `finalized` (SV đã chốt), `finalized_at`, `first_seen_at`, `overridden_by`, `overridden_at`, `override_reason`, unique `(session_id, student_user_id)` |
| `leave_requests` | `id`, `student_user_id`, `class_id`, `date`, `reason`, `status` (pending/approved/rejected), `reviewed_by`, `reviewed_at`, `review_note` |
| `notifications` | `id`, `user_id`, `type`, `title`, `body`, `ref_id`, `is_read`, `created_at` |

`detections.proximity_ok` bị **bỏ**: server tự quyết định theo `classes.rssi_threshold`, không tin cờ do client gửi.

## 4. Quy tắc điểm danh

### 4.1 Cửa sổ và ratio
- Mỗi buổi chia thành các cửa sổ 30 giây, tính từ `starts_at`.
- `total_windows = max(1, ceil((ends_at − starts_at) / 30s))`. Buổi chưa kết thúc thì dùng thời điểm hiện tại, chỉ để hiển thị tạm.
- Một cửa sổ **hợp lệ** khi có detection đã xác minh trong cửa sổ và **trung vị RSSI** của các detection đó lớn hơn `rssi_threshold` của lớp.
- `presence_ratio = số cửa sổ hợp lệ / total_windows` (tối đa 1.0).
- Bucket được tính bằng Python để chạy giống nhau trên PostgreSQL và SQLite (test).

### 4.2 Trạng thái
Ratio được tính **một lần khi GV kết thúc buổi** (không phải lúc SV bấm chốt). Khi kết thúc buổi, server tạo/cập nhật `attendance` cho **toàn bộ SV của lớp** trong một transaction:

1. Có override của GV → giữ nguyên giá trị override (override luôn thắng).
2. `ratio ≥ 0.6` **và** `finalized = true` → `present`.
3. Không đạt mục 2 nhưng có đơn xin phép `approved` cho đúng ngày buổi học → `excused`.
4. Còn lại → `absent`.

SV chưa từng được phát hiện có ratio 0 và `absent`. Lệnh kết thúc buổi idempotent.

### 4.3 Chốt điểm danh
- Điều kiện: SV thuộc lớp; buổi còn active; GV đã mở chốt; **SV có detection hợp lệ (RSSI > `rssi_threshold`) trong 90 giây gần nhất** (chặn SV đã rời đi hoặc ngồi ngoài tầm). Dùng 90 giây thay vì 60 vì máy GV gửi lô mỗi 30 giây nên dữ liệu về server có độ trễ.
- App gọi `local_auth` (vân tay hoặc PIN máy); thành công mới gọi API. Server chỉ ghi `finalized = true`, không tính ratio ở bước này, không đụng vào override.
- Biometric vẫn là xác nhận phía client; giới hạn này được ghi vào tài liệu.

### 4.4 Đi trễ
SV đến trễ vẫn được điểm danh miễn ratio cuối buổi đạt 0.6 (ví dụ buổi 90 phút cho phép trễ tối đa khoảng 36 phút) và chốt khi chốt đang mở. Hệ thống ghi `first_seen_at`; báo cáo hiển thị "trễ X phút" so với `starts_at`. Không có trạng thái `late`.

### 4.5 Chuyên cần
`chuyên cần = số buổi present hoặc excused / tổng số buổi đã kết thúc của lớp`. Số buổi vắng (absent) vượt `max_absence_percent` thì cảnh báo SV (UI và thông báo).

## 5. BLE và chống giả mạo (Android)

### 5.1 Payload
- **GV phát:** mã buổi học ngắn (8 ký tự đầu của `token`). Không phát tên môn; SV lấy tên môn từ server.
- **SV phát:** `student_id` + `tag` (8 ký tự hex).
- Cả hai dùng manufacturer data như hiện tại; payload ≤ 20 byte để nằm trong giới hạn quảng cáo BLE legacy. Phải kiểm tra trên máy thật ngay tuần 1.

### 5.2 Xác minh
1. Khi SV lấy buổi đang diễn ra (`GET /sessions/active`), server trả `beacon_secret = HMAC(server_key, session_id ‖ student_id)`. Khóa chỉ đi qua HTTPS/JWT, không phát qua BLE.
2. `tag = hex(HMAC(beacon_secret, bucket))[:8]`, với `bucket = floor(epoch_seconds / 30)`.
3. Máy GV gửi `{student_id, bucket, tag, rssi, observed_at}`. Server tính lại tag, chấp nhận bucket lệch ±1 so với `observed_at` (sai lệch đồng hồ), và chỉ nhận `observed_at` trong buổi học và lệch không quá 10 phút so với giờ server. Detection sai tag, SV ngoài lớp, hoặc buổi không active đều bị bỏ.
4. Giới hạn đã chấp nhận: bắt gói rồi phát lại chỉ dùng được trong cửa sổ 30 đến 60 giây; GV dùng client giả mạo vẫn gửi được detection bậy (GV là bên tin cậy, có audit override).

### 5.3 Sức chịu đựng
- Foreground service và nút hướng dẫn tắt tối ưu pin (Xiaomi/Samsung) giữ lại.
- Hàng đợi detection của GV gửi lại khi lỗi mạng, có giới hạn kích thước. Mở lại app giữa buổi thì GV khôi phục luôn việc phát và quét (sửa lỗi hiện tại).

## 6. Backend

### 6.1 Cấu trúc
```
backend/
├── alembic/
├── app/
│   ├── main.py            tạo app, include router
│   ├── core/              config, database, security (JWT, require_role)
│   ├── models/            users, academic, sessions, attendance, leave, notification
│   ├── schemas/
│   ├── routers/           auth, admin, classes, sessions, detections, attendance, leave, notifications, reports
│   └── services/          presence, attendance, beacon, importer, report_builder, notifier
└── tests/
```
Router chỉ nhận request và gọi service. Lỗi trả định dạng `{detail, code}`.

### 6.2 API
| Module | Endpoint |
|---|---|
| Auth | `POST /auth/register` (chỉ SV), `POST /auth/login`, `GET /auth/me`, `POST /auth/change-password` |
| Admin | CRUD `/admin/courses`, `/admin/classes`, `/admin/teachers`; `POST /admin/classes/{id}/assign-teacher`; `POST /admin/users/{id}/reset-password` |
| Import (admin) | `POST /admin/imports/classes`, `/admin/imports/teachers`, `/admin/classes/{id}/import-students`; `dry_run=true` trả bản xem trước kèm lỗi từng dòng; `GET /admin/imports/templates/{type}` |
| Lớp | `GET /classes/mine` (GV: lớp được gán; SV: lớp đã vào), `POST /classes/join`, `GET /classes/{id}` |
| Buổi học | `POST /classes/{id}/sessions`, `POST /sessions/{id}/end`, `POST /sessions/{id}/open-finalization`, `GET /sessions/active`, `GET /classes/{id}/sessions` |
| Detection | `POST /detections/batch` (GV) |
| Điểm danh | `POST /attendance/finalize` (SV), `GET /sessions/{id}/attendance`, `POST /sessions/{id}/attendance/override` |
| Thống kê SV | `GET /me/attendance?class_id=`, `GET /me/attendance/stats` |
| Báo cáo | `GET /classes/{id}/report`, `GET /classes/{id}/report/export`, `GET /sessions/{id}/export` |
| Xin phép | `POST /leave-requests`, `GET /leave-requests/mine`, `GET /classes/{id}/leave-requests`, `POST /leave-requests/{id}/review` |
| Thông báo | `GET /notifications`, `GET /notifications/unread-count`, `POST /notifications/{id}/read`, `POST /notifications/read-all` |

### 6.3 Import
- Định dạng CSV hoặc XLSX. SV: `student_id`, `full_name`. GV: `teacher_id`, `full_name`. Lớp: `course_code`, `course_name`, `class_code`, `semester`, `teacher_id` (tùy chọn).
- Xác thực từng dòng (regex mã SV, trùng, thiếu trường, lớp/môn không tồn tại); không dừng ở lỗi đầu tiên.
- Ghi thật trong một transaction; tài khoản mới có mật khẩu tạm và `must_change_password`.

### 6.4 Thông báo tự động (in-app, polling)
- GV mở chốt → SV trong lớp.
- SV gửi đơn → GV của lớp.
- GV duyệt hoặc từ chối → SV.
- Kết thúc buổi, SV vượt ngưỡng vắng → cảnh báo SV.

## 7. Ứng dụng Flutter (Android)

### 7.1 Công nghệ
`flutter_riverpod`, `go_router`, `file_picker`, `share_plus` + `path_provider` (lưu và chia sẻ Excel, tương thích Android 10+), `fl_chart`, `intl`; giữ các gói BLE, `local_auth`, `flutter_foreground_task`, `dio`, `flutter_secure_storage`. Bỏ cấu hình iOS khỏi phạm vi.

### 7.2 Cấu trúc
```
lib/
├── app/        app, router, theme
├── core/       constants, formatters, map lỗi API sang tiếng Việt
├── models/
├── data/       repositories theo domain
├── ble/        teacher_ble_service, student_ble_service, ble_payload (thuần), ble_permissions, foreground_service
├── providers/
├── screens/    auth/ student/ teacher/ admin/ shared/
└── widgets/
```

### 7.3 Màn hình
- **Auth:** đăng nhập; đăng ký SV; bắt buộc đổi mật khẩu lần đầu; cài đặt URL server (và nút "Wake Server").
- **Sinh viên (4 tab):** Trang chủ (buổi đang diễn ra, gần/xa, chốt, cảnh báo); Lớp của tôi (tham gia lớp, % chuyên cần, lịch sử từng buổi); Xin phép; Thông báo (badge chưa đọc).
- **Giảng viên (4 tab):** Lớp học (chi tiết lớp: Sinh viên / Buổi học / Báo cáo + biểu đồ + Excel); Buổi trực tiếp (BLE, danh sách SV, mở chốt, kết thúc, override kèm lý do); Xin phép (duyệt); Thông báo.
- **Admin:** Môn học; Lớp học (tạo, gán GV, import SV); Giảng viên (tạo, import, reset mật khẩu); Import có xem trước dòng hợp lệ/lỗi.
- Tiếng Việt, Material 3, màu chủ đạo `#0B6E4F`, dark mode, mọi danh sách có đủ trạng thái tải, rỗng, lỗi có nút thử lại.

### 7.4 Điều hướng và phiên
`GET /auth/me` khi khởi động; 401 tự đăng xuất; `must_change_password` chuyển thẳng sang đổi mật khẩu; go_router chặn route theo role.

### 7.5 Build
Release APK có ký (keystore), dùng `scripts/package_release_apks.sh`; lưu Excel qua MediaStore hoặc share sheet.

## 8. Xử lý lỗi
- Backend: phân quyền tập trung, lỗi định dạng thống nhất, kết thúc buổi idempotent, import báo từng dòng.
- Flutter: một hàm chung map lỗi sang tiếng Việt; hàng đợi detection gửi lại; mất mạng khi chốt không làm mất trạng thái; SV offline vẫn thấy tín hiệu GV nhưng được báo cần mạng để chốt.

## 9. Kiểm thử
| Lớp | Nội dung |
|---|---|
| Backend pytest (SQLite) | Presence (bucket, trung vị RSSI, `ends_at`, chạm trần), tạo attendance cả lớp, override không bị ghi đè, `excused`, xác minh HMAC tag và `observed_at`, chốt cần detection gần đây, import, ma trận quyền 3 role cho từng endpoint |
| Flutter | Mã hóa/giải mã payload, parse model, mapper lỗi, widget test đăng nhập và đổi mật khẩu, màn xem trước import (repository giả) |
| Thủ công trên máy thật | TC-01…TC-14 của tài liệu, thêm: tag giả bị bỏ, SV ngoài lớp không ghi nhận, đến trễ, rời đi sau khi chốt, đứng ngoài hành lang, khóa màn hình 10 phút, ít nhất 2 hãng Android |

## 10. Kế hoạch 3 tuần
| Tuần | Backend | Flutter |
|---|---|---|
| 1 | Alembic, tách routers/services, role admin, bảng mới, `/auth/me`, đổi mật khẩu, presence mới, tạo attendance cả lớp, sửa override, test; thử payload BLE trên máy thật | Cấu trúc thư mục, Riverpod, go_router, theme tiếng Việt, đăng nhập mới, khung điều hướng 3 role |
| 2 | CRUD môn/lớp/GV, gán GV, import, chuyên cần, báo cáo và Excel cả kỳ, HMAC tag | Màn Admin, danh sách và chi tiết lớp, lịch sử và % chuyên cần, UI override, buổi trực tiếp mới, BLE có tag |
| 3 | Xin phép (gồm `excused`), thông báo và sự kiện tự động, rà soát bảo mật | Màn xin phép, thông báo kèm badge, biểu đồ, làm đẹp UI, release APK, test thiết bị, tài liệu, kịch bản demo |

Nếu trễ, cắt theo thứ tự: biểu đồ → thông báo → xin phép. Lõi, học vụ (Admin), báo cáo giữ nguyên.

## 11. Rủi ro
- BLE trên máy thật và nhiều hãng Android khác nhau: test sớm từ tuần 1, cần ít nhất 2 điện thoại.
- Khối lượng lớn so với 3 tuần: có thứ tự cắt giảm ở mục 10.
- Giới hạn bảo mật còn lại: người đứng ngoài lớp nhưng trong tầm BLE vẫn có thể bị tính hiện diện (giảm thiểu bằng ngưỡng RSSI theo lớp, trung vị theo cửa sổ, chốt cần detection gần đây, GV override); biometric chỉ xác nhận phía client; GV dùng client giả mạo gửi được detection bậy.
