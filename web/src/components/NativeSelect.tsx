import type { ComponentProps } from 'react'
import { cn } from '@/lib/utils'

/** Ô chọn dùng thẻ <select> của trình duyệt: gọn, truy cập được bằng bàn phím và dễ kiểm thử. */
export default function NativeSelect({ className, ...props }: ComponentProps<'select'>) {
  return (
    <select
      className={cn(
        'h-8 w-full min-w-0 rounded-lg border border-input bg-transparent px-2.5 text-sm outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 disabled:opacity-50 dark:bg-input/30',
        className,
      )}
      {...props}
    />
  )
}
