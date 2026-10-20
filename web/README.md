# Web admin và giảng viên (React)

Vite + React + TypeScript + Tailwind + shadcn/ui (Base UI), TanStack Query, React Router, react-hook-form + zod. Giao diện tiếng Việt, dùng cho admin và giảng viên; sinh viên dùng app Android.

```bash
npm install
npm run dev          # http://localhost:5173/app/ ; proxy API sang http://localhost:8000
npm test             # Vitest + Testing Library + MSW
npx tsc -b --noEmit  # kiểm tra kiểu
npm run lint
npm run gen:api      # sinh src/api/types.ts từ openapi.json của backend (cần backend/.venv)
npm run build        # ra web/dist; backend/scripts/build_web.sh sao chép sang backend/web_dist
```

Cấu trúc: `src/api` (client + hook theo miền), `src/auth` (đăng nhập, phân quyền), `src/components` (layout, bảng, hộp thoại, file), `src/pages/admin` và `src/pages/teacher`, `src/test` (MSW, helper). Ghi chú kiểm thử: jsdom không gửi được `FormData` qua `fetch` của Node, nên test import mock hai hàm gửi file (`previewImport`, `commitImport`); phần multipart được kiểm tra bằng cách chạy thật trên trình duyệt.
