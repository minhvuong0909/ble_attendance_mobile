# Frontend web React cho admin và giảng viên

## 1. Mục tiêu và phạm vi

Một ứng dụng web riêng (React) để **admin** và **giảng viên** quản lý trên laptop: quản trị môn/lớp/giảng viên, import và xuất file, theo dõi buổi học, báo cáo, duyệt xin phép, chỉnh tay điểm danh. Thay hẳn bản web build từ Flutter; backend phục vụ tại `/app/`. App Flutter giữ cho Android (sinh viên, và giảng viên di động); mã Flutter không đổi.

Ngoài phạm vi: trang cho sinh viên (sinh viên chỉ dùng app Android), phát/quét BLE, đa ngôn ngữ (chỉ tiếng Việt), đăng ký tài khoản (admin tạo tài khoản).

**Tiêu chí hoàn thành:** mọi chức năng admin/giảng viên đang có trong app Flutter dùng được trên web; import (CSV/XLSX có xem trước) và xuất Excel chạy thật trên trình duyệt; test tự động cho các luồng chính; `scripts/build_web.sh` build ra `backend/web_dist` và backend phục vụ; README/DEMO cập nhật.

## 2. Công nghệ

Vite + React 19 + TypeScript (strict) · Tailwind CSS + shadcn/ui (Radix) · React Router (BrowserRouter, `base=/app/`) · TanStack Query (dữ liệu, cache, làm mới) · react-hook-form + zod (form) · sonner (thông báo nhanh) · lucide-react (biểu tượng) · Vitest + Testing Library + MSW (test). Kiểu API sinh từ `openapi.json` của backend bằng `openapi-typescript` (`npm run gen:api`, file sinh ra được commit) để không lệch hợp đồng. Giao diện sáng/tối theo hệ thống.

## 3. Cấu trúc

```text
web/
├── src/
│   ├── api/          client.ts (fetch + token + lỗi {detail,code}), types.ts (sinh), hooks theo miền (courses, classes, ...)
│   ├── auth/         AuthProvider, RequireRole, trang đăng nhập và đổi mật khẩu bắt buộc
│   ├── components/   ui/ (shadcn), layout (Sidebar, Header, ProfileMenu), DataTable, ConfirmDialog, FileDrop, EmptyState
│   ├── pages/        admin/*, teacher/*, notifications, not-found
│   ├── lib/          format (ngày giờ UTC+7, phần trăm), download (Blob), utils
│   └── test/         MSW handlers, render helper
├── vite.config.ts    base /app/, proxy API sang :8000 khi dev
└── package.json
```

- **Backend:** `mount_web` thêm fallback `index.html` cho đường dẫn không phải tệp dưới `/app/` (để tải lại trang ở `/app/classes/3` không 404). API cùng origin nên không cần CORS. Khi dev (`npm run dev`) Vite proxy các đường dẫn API sang `localhost:8000`.
- **API client:** token JWT lưu `localStorage`; 401 (với token hiện tại) → đăng xuất về trang đăng nhập; lỗi `{detail, code}` thành `ApiError` hiển thị tiếng Việt từ `detail`. Tải file qua `fetch` kèm token rồi `Blob` + thẻ `<a download>`; tên file lấy từ `Content-Disposition`, bỏ mọi thành phần đường dẫn.
- **Phân quyền:** `RequireRole` điều hướng theo vai trò (`GET /auth/me`): admin vào `/admin/*`, giảng viên vào `/teacher/*`, sinh viên thấy trang hướng dẫn "dùng app Android". `must_change_password` buộc đổi mật khẩu trước.

## 4. Trang và chức năng

| Vai trò | Trang | Chức năng (API) |
|---|---|---|
| Chung | Đăng nhập, đổi mật khẩu, thông báo | `/auth/*`, `/notifications*`; chuông có số chưa đọc, làm mới định kỳ |
| Admin | Môn học | Bảng, thêm/sửa/xóa (`/admin/courses`) |
| Admin | Lớp học | Bảng + lọc theo môn; tạo lớp; chi tiết: sửa cấu hình (RSSI, % vắng tối đa, mã lớp/học kỳ), gán giảng viên, danh sách sinh viên, import sinh viên, xóa lớp (`/admin/classes*`, `/classes/{id}/students`) |
| Admin | Giảng viên | Bảng, tạo, đặt lại mật khẩu (`/admin/teachers`, `/admin/users/{id}/reset-password`); hiển thị mật khẩu tạm một lần |
| Admin | Import | Chọn loại (lớp/môn, giảng viên, sinh viên theo lớp), tải file mẫu, kéo thả CSV/XLSX, **xem trước** (dry-run) từng dòng, chặn xác nhận khi có lỗi, xác nhận nhập (`/admin/imports/*`) |
| Giảng viên | Lớp của tôi | Danh sách lớp được gán (`/classes/mine`) |
| Giảng viên | Chi tiết lớp | Tab Sinh viên · Buổi học (bắt đầu buổi, danh sách buổi, vào xem kết quả/xuất Excel) · Báo cáo (bảng sinh viên × buổi, cảnh báo vắng, xuất Excel) · Xin phép (duyệt/từ chối kèm lý do) |
| Giảng viên | Buổi trực tiếp | Buổi đang diễn ra: mở chốt, kết thúc (xác nhận), bảng điểm danh tự làm mới 5 giây, chỉnh tay có lý do (`/sessions/*`, `/attendance/*`) |

Tất cả danh sách có trạng thái tải, rỗng, lỗi kèm nút thử lại. Mọi thao tác ghi khóa nút khi đang gửi (không gửi trùng) và làm mới dữ liệu liên quan sau khi xong.

## 5. Xử lý lỗi và an toàn

- Lỗi API hiển thị `detail` của server; lỗi mạng hiển thị thông báo kết nối; không nuốt lỗi.
- Hành động phá hủy (xóa lớp/môn, kết thúc buổi, từ chối đơn) qua hộp thoại xác nhận.
- Không dùng `dangerouslySetInnerHTML`; dữ liệu từ file import chỉ hiển thị dạng văn bản. Token chỉ ở `localStorage` (giới hạn đã chấp nhận cho bản demo, ghi trong README).
- Giới hạn file import 2 MB và đuôi `.csv/.xlsx` kiểm tra ở client trước khi gửi (server vẫn kiểm tra).

## 6. Kiểm thử

- Vitest + Testing Library + MSW: client API (token, 401, lỗi), đăng nhập và điều hướng theo vai trò, từng trang chính (bảng, form, hộp thoại, trạng thái lỗi), luồng import (xem trước có lỗi bị chặn, xác nhận một lần), duyệt xin phép, chỉnh tay, tải file (tên an toàn).
- Chạy thật trên trình duyệt tích hợp với backend và dữ liệu demo: đăng nhập admin/giảng viên, import, xuất Excel (đưa file vào ô chọn file bằng JavaScript vì hộp thoại hệ điều hành không điều khiển được).
- `npm run build` + `tsc --noEmit` + lint phải sạch.

## 7. Kế hoạch (nhánh `feature/react-web`)

1. **Nền tảng:** scaffold Vite/Tailwind/shadcn, client API + kiểu sinh, AuthProvider, layout, đăng nhập, đổi mật khẩu, hướng dẫn cho sinh viên; backend fallback SPA.
2. **Admin:** môn học, giảng viên, lớp (+ chi tiết), import có xem trước.
3. **Giảng viên:** lớp của tôi, chi tiết lớp (4 tab), buổi trực tiếp, chỉnh tay, xuất Excel.
4. **Thông báo + hoàn thiện:** thông báo, giao diện tối, trạng thái rỗng/lỗi, `build_web.sh`, thay build Flutter web, README/DEMO/STATUS, chạy thật trên trình duyệt, review.

## 8. Rủi ro

- Khối lượng lớn (khoảng 15 trang): làm theo thứ tự trên, mỗi phần tự chạy được và có test.
- Kiểu sinh từ OpenAPI phụ thuộc backend đang chạy: file sinh ra được commit, chỉ chạy lại khi API đổi.
- Token trong `localStorage`: chấp nhận cho bản demo; triển khai thật cần HTTPS và cân nhắc cookie `HttpOnly`.
