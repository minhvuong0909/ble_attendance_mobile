import type { UseQueryResult } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'

interface Props<T> {
  query: UseQueryResult<T>
  isEmpty?: (data: T) => boolean
  emptyText?: string
  children: (data: T) => ReactNode
}

/** Hiển thị trạng thái tải / lỗi (có thử lại) / rỗng; dữ liệu cũ vẫn hiện khi làm mới thất bại. */
export default function QueryBoundary<T>({ query, isEmpty, emptyText = 'Chưa có dữ liệu', children }: Props<T>) {
  if (query.data === undefined) {
    if (query.isError) {
      return (
        <div role="alert" className="space-y-3 rounded-md border border-destructive/40 p-4">
          <p className="text-sm text-destructive">{query.error instanceof Error ? query.error.message : 'Đã xảy ra lỗi'}</p>
          <Button variant="outline" size="sm" onClick={() => void query.refetch()}>
            Thử lại
          </Button>
        </div>
      )
    }
    return (
      <div className="space-y-2" aria-busy="true">
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-10 w-full" />
      </div>
    )
  }
  return (
    <>
      {query.isError && (
        <p role="alert" className="mb-2 text-sm text-amber-600">
          Không cập nhật được, đang hiển thị dữ liệu gần nhất.
        </p>
      )}
      {isEmpty?.(query.data) ? (
        <p className="rounded-md border border-dashed p-8 text-center text-muted-foreground">{emptyText}</p>
      ) : (
        children(query.data)
      )}
    </>
  )
}
