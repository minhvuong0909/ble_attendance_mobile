import { useState } from 'react'
import { ApiError } from '@/api/client'
import { useUpdateRssi, type ClassItem } from '@/api/classes'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const MIN = -100
const MAX = -30
const PRESETS = [
  { label: 'Phòng nhỏ', value: -70 },
  { label: 'Vừa', value: -75 },
  { label: 'Phòng lớn', value: -85 },
]

const parse = (text: string): number | null => {
  const t = text.trim()
  if (!/^-?\d+$/.test(t)) return null
  const n = Number(t)
  return n >= MIN && n <= MAX ? n : null
}

/** Giảng viên chỉnh ngưỡng RSSI của lớp theo kích thước phòng: càng âm càng chấp nhận sinh viên ngồi xa. */
export default function RssiSetting({ cls }: { cls: ClassItem }) {
  const update = useUpdateRssi(cls.id)
  const [value, setValue] = useState(String(cls.rssi_threshold))
  const [invalid, setInvalid] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)
  const changed = value.trim() !== String(cls.rssi_threshold)

  function edit(next: string) {
    setValue(next)
    setInvalid(false)
    setError(null)
    setSaved(false)
  }

  async function save() {
    if (update.isPending) return
    const parsed = parse(value)
    if (parsed === null) {
      setInvalid(true)
      return
    }
    try {
      await update.mutateAsync(parsed)
      setSaved(true)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    }
  }

  return (
    <div className="space-y-2 rounded-lg border p-4">
      <h2 className="font-semibold">Ngưỡng RSSI của lớp</h2>
      <p className="text-sm text-muted-foreground">
        Sinh viên được tính là ở trong lớp khi tín hiệu mạnh hơn ngưỡng này. Phòng nhỏ dùng −70, phòng lớn dùng −85 (càng âm càng chấp nhận ngồi xa). Áp dụng cho các buổi học bắt đầu sau khi lưu.
      </p>
      <div className="flex flex-wrap items-end gap-3">
        <div className="space-y-2">
          <Label htmlFor="rssi">Ngưỡng RSSI (dBm)</Label>
          <Input id="rssi" inputMode="numeric" className="w-32" value={value} onChange={(e) => edit(e.target.value)} />
        </div>
        {PRESETS.map((p) => (
          <Button key={p.value} type="button" variant="outline" size="sm" onClick={() => edit(String(p.value))}>
            {p.label} ({p.value})
          </Button>
        ))}
        <Button type="button" disabled={!changed || update.isPending} onClick={() => void save()}>
          Lưu ngưỡng
        </Button>
      </div>
      {invalid && <p className="text-sm text-destructive">Ngưỡng RSSI từ -100 đến -30</p>}
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
      {saved && (
        <p role="status" className="text-sm text-muted-foreground">
          Đã lưu ngưỡng RSSI
        </p>
      )}
    </div>
  )
}
