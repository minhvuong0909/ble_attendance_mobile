import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'

// Mặc định: không có thông báo chưa đọc (chuông trong layout luôn gọi API này).
export const server = setupServer(
  http.get(`${window.location.origin}/notifications/unread-count`, () => HttpResponse.json({ count: 0 })),
)
