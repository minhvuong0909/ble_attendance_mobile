import { Link } from 'react-router-dom'

export default function NotFoundPage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-2">
      <h1 className="text-xl font-semibold">Không tìm thấy trang</h1>
      <Link className="text-primary underline" to="/">
        Về trang chủ
      </Link>
    </main>
  )
}
