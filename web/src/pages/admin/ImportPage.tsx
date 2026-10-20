import { useQueryClient } from '@tanstack/react-query'
import { Download } from 'lucide-react'
import { useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { toast } from 'sonner'
import { useAdminClasses } from '@/api/admin'
import { ApiError } from '@/api/client'
import {
  IMPORT_KINDS,
  commitImport,
  downloadTemplate,
  previewImport,
  validateImportFile,
  type ImportKind,
  type ImportReport,
} from '@/api/imports'
import FileDrop from '@/components/FileDrop'
import NativeSelect from '@/components/NativeSelect'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { saveBlob } from '@/lib/download'

const message = (e: unknown) => (e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
const STATUS_LABEL = { created: 'Sẽ tạo', skipped: 'Bỏ qua', error: 'Lỗi' } as const

export default function ImportPage() {
  const qc = useQueryClient()
  const [params, setParams] = useSearchParams()
  const kind = (params.get('kind') as ImportKind) in IMPORT_KINDS ? (params.get('kind') as ImportKind) : 'classes'
  const [classId, setClassId] = useState(params.get('classId') ?? '')
  const classes = useAdminClasses()

  const [file, setFile] = useState<File | null>(null)
  const [report, setReport] = useState<ImportReport | null>(null)
  const [imported, setImported] = useState<number | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const latest = useRef(0)
  const committing = useRef(false)

  function resetResult() {
    latest.current++
    setFile(null)
    setReport(null)
    setImported(null)
    setError(null)
    setBusy(false)
  }

  function chooseKind(next: ImportKind) {
    resetResult()
    setParams({ kind: next }, { replace: true })
  }

  async function onFile(chosen: File) {
    const ticket = ++latest.current
    setReport(null)
    setImported(null)
    setError(null)
    setFile(null)
    const invalid = validateImportFile(chosen)
    if (invalid) {
      setError(invalid)
      return
    }
    setFile(chosen)
    setBusy(true)
    try {
      const result = await previewImport(kind, chosen, classId)
      if (ticket === latest.current) setReport(result)
    } catch (e) {
      if (ticket === latest.current) setError(message(e))
    } finally {
      if (ticket === latest.current) setBusy(false)
    }
  }

  async function confirm() {
    if (!file || committing.current) return
    committing.current = true
    setBusy(true)
    setError(null)
    try {
      const result = await commitImport(kind, file, classId)
      if (!result.committed) {
        setReport(result)
        setError('Dữ liệu chưa được ghi, hãy kiểm tra lại file rồi thử lại.')
        return
      }
      setImported(result.created)
      setReport(null)
      setFile(null)
      for (const key of ['courses', 'admin-classes', 'teachers', 'class-students']) {
        void qc.invalidateQueries({ queryKey: [key] })
      }
    } catch (e) {
      setError(message(e))
    } finally {
      committing.current = false
      setBusy(false)
    }
  }

  async function template() {
    try {
      const { blob, filename } = await downloadTemplate(kind)
      saveBlob(blob, filename)
    } catch (e) {
      toast.error(message(e))
    }
  }

  const needsClass = kind === 'students' && !classId
  const canConfirm = !!report && report.errors === 0 && report.created > 0 && !busy

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Nhập danh sách</h1>
      <div className="flex flex-wrap gap-2">
        {(Object.keys(IMPORT_KINDS) as ImportKind[]).map((k) => (
          <Button key={k} variant={k === kind ? 'default' : 'outline'} aria-pressed={k === kind} onClick={() => chooseKind(k)}>
            {IMPORT_KINDS[k].label}
          </Button>
        ))}
      </div>

      <p className="text-sm text-muted-foreground">
        File CSV (UTF-8) hoặc Excel (.xlsx), tối đa 2 MB, dòng đầu là tiêu đề với các cột: {IMPORT_KINDS[kind].columns}
      </p>

      {kind === 'students' && (
        <div className="max-w-md space-y-2">
          <Label htmlFor="class">Lớp</Label>
          <NativeSelect
            id="class"
            value={classId}
            onChange={(e) => {
              resetResult()
              setClassId(e.target.value)
            }}
          >
            <option value="">— Chọn lớp —</option>
            {classes.data?.map((c) => (
              <option key={c.id} value={c.id}>
                {c.course_code} · {c.class_code} · {c.semester}
              </option>
            ))}
          </NativeSelect>
          {needsClass && <p className="text-sm text-muted-foreground">Hãy chọn lớp trước khi chọn file</p>}
        </div>
      )}

      <div className="flex flex-wrap items-start gap-3">
        <Button variant="outline" onClick={() => void template()}>
          <Download /> Tải file mẫu
        </Button>
      </div>
      <FileDrop accept=".csv,.xlsx" disabled={needsClass || busy} onFile={(f) => void onFile(f)} />

      {file && <p className="text-sm">{file.name}</p>}
      {error && (
        <p role="alert" className="rounded-md border border-destructive/40 p-3 text-sm text-destructive">
          {error}
        </p>
      )}
      {imported !== null && <p className="rounded-md border border-green-600/40 p-3 text-sm text-green-700 dark:text-green-400">Đã nhập {imported} dòng</p>}

      {report && (
        <div className="space-y-3">
          <div className="flex flex-wrap gap-4 text-sm font-medium">
            <span>Tổng: {report.total} dòng</span>
            <span>Sẽ tạo: {report.created}</span>
            <span>Bỏ qua: {report.skipped}</span>
            <span>Lỗi: {report.errors}</span>
          </div>
          <div className="overflow-x-auto rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Dòng</TableHead>
                  {IMPORT_KINDS[kind].preview.map(([, title]) => (
                    <TableHead key={title}>{title}</TableHead>
                  ))}
                  <TableHead>Kết quả</TableHead>
                  <TableHead className="text-right">Trạng thái</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {report.rows.map((r) => (
                  <TableRow key={r.row} className={r.status === 'error' ? 'bg-destructive/5' : undefined}>
                    <TableCell className="text-muted-foreground">Dòng {r.row}</TableCell>
                    {IMPORT_KINDS[kind].preview.map(([column, title]) => (
                      <TableCell key={title}>{r.data?.[column] ?? ''}</TableCell>
                    ))}
                    <TableCell>{r.message}</TableCell>
                    <TableCell className="text-right">
                      <Badge variant={r.status === 'error' ? 'destructive' : r.status === 'created' ? 'default' : 'secondary'}>{STATUS_LABEL[r.status]}</Badge>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
          {report.errors > 0 && <p className="text-sm text-muted-foreground">Sửa các dòng lỗi trong file rồi chọn lại file để tiếp tục.</p>}
          <Button className="w-full" disabled={!canConfirm} onClick={() => void confirm()}>
            Xác nhận nhập
          </Button>
        </div>
      )}
    </div>
  )
}
