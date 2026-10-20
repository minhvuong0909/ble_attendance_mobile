import { Download } from 'lucide-react'
import { useRef, useState } from 'react'
import { toast } from 'sonner'
import { ApiError } from '@/api/client'
import { Button } from '@/components/ui/button'
import { saveBlob } from '@/lib/download'

interface Props {
  label: string
  onExport: () => Promise<{ blob: Blob; filename: string }>
}

/** Nút tải file: khóa khi đang tải, lỗi hiện thành thông báo, bấm lại được. */
export default function ExportButton({ label, onExport }: Props) {
  const [busy, setBusy] = useState(false)
  const running = useRef(false)

  async function click() {
    if (running.current) return
    running.current = true
    setBusy(true)
    try {
      const { blob, filename } = await onExport()
      saveBlob(blob, filename)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'Không tải được file')
    } finally {
      running.current = false
      setBusy(false)
    }
  }

  return (
    <Button variant="outline" disabled={busy} onClick={() => void click()}>
      <Download /> {label}
    </Button>
  )
}
