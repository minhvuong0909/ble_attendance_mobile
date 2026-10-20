import type { components } from './types'
import { apiDownload, apiFetch } from './client'

export type ImportReport = components['schemas']['ImportReportOut']
export type ImportKind = 'classes' | 'teachers' | 'students'

export const MAX_IMPORT_BYTES = 2_000_000

export const IMPORT_KINDS: Record<ImportKind, { label: string; columns: string }> = {
  classes: { label: 'Môn và lớp', columns: 'course_code, course_name, class_code, semester, teacher_id' },
  teachers: { label: 'Giảng viên', columns: 'teacher_id, full_name' },
  students: { label: 'Sinh viên của một lớp', columns: 'student_id, full_name' },
}

export function validateImportFile(file: File): string | null {
  if (!/\.(csv|xlsx)$/i.test(file.name)) return 'Chỉ hỗ trợ file .csv hoặc .xlsx'
  if (file.size === 0) return 'File rỗng'
  if (file.size > MAX_IMPORT_BYTES) return 'File quá lớn (tối đa 2 MB)'
  return null
}

function endpoint(kind: ImportKind, classId?: string): string {
  if (kind === 'students') return `/admin/classes/${classId}/import-students`
  return `/admin/imports/${kind}`
}

function run(kind: ImportKind, file: File, classId: string | undefined, dryRun: boolean) {
  const form = new FormData()
  form.append('file', file)
  return apiFetch<ImportReport>(endpoint(kind, classId), { method: 'POST', body: form, query: { dry_run: dryRun } })
}

export const previewImport = (kind: ImportKind, file: File, classId?: string) => run(kind, file, classId, true)
export const commitImport = (kind: ImportKind, file: File, classId?: string) => run(kind, file, classId, false)
export const downloadTemplate = (kind: ImportKind) => apiDownload(`/admin/imports/templates/${kind}`, `${kind}_template.csv`)
