import { useParams, useSearchParams } from 'react-router-dom'
import { useClass } from '@/api/classes'
import QueryBoundary from '@/components/QueryBoundary'
import { cn } from '@/lib/utils'
import LeaveTab from './LeaveTab'
import RssiSetting from './RssiSetting'
import ReportTab from './ReportTab'
import SessionsTab from './SessionsTab'
import StudentsTab from './StudentsTab'

const TABS = [
  { id: 'students', label: 'Sinh viên' },
  { id: 'sessions', label: 'Buổi học' },
  { id: 'report', label: 'Báo cáo' },
  { id: 'leave', label: 'Xin phép' },
] as const

export default function TeacherClassDetailPage() {
  const { classId = '' } = useParams()
  const [params, setParams] = useSearchParams()
  const requested = params.get('tab')
  const tab = TABS.find((t) => t.id === requested)?.id ?? 'students'
  const query = useClass(classId)

  return (
    <QueryBoundary query={query}>
      {(cls) => (
        <div className="space-y-4">
          <div>
            <h1 className="text-2xl font-semibold">
              {cls.course_code} · {cls.class_code}
            </h1>
            <p className="text-sm text-muted-foreground">
              {cls.course_name} · {cls.semester} · {cls.student_count} sinh viên
            </p>
          </div>
          <RssiSetting cls={cls} />
          <div role="tablist" className="flex gap-1 border-b">
            {TABS.map((t) => (
              <button
                key={t.id}
                role="tab"
                aria-selected={t.id === tab}
                onClick={() => setParams({ tab: t.id }, { replace: true })}
                className={cn(
                  '-mb-px border-b-2 px-3 py-2 text-sm',
                  t.id === tab ? 'border-primary font-medium' : 'border-transparent text-muted-foreground hover:text-foreground',
                )}
              >
                {t.label}
              </button>
            ))}
          </div>
          <div role="tabpanel">
            {tab === 'students' && <StudentsTab classId={classId} />}
            {tab === 'sessions' && <SessionsTab classId={classId} />}
            {tab === 'report' && <ReportTab classId={classId} />}
            {tab === 'leave' && <LeaveTab classId={classId} />}
          </div>
        </div>
      )}
    </QueryBoundary>
  )
}
