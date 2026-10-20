import { FileUp } from 'lucide-react'
import { useRef, useState } from 'react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

interface Props {
  accept: string
  disabled?: boolean
  onFile: (file: File) => void
}

/** Vùng chọn hoặc kéo thả một tệp. */
export default function FileDrop({ accept, disabled, onFile }: Props) {
  const input = useRef<HTMLInputElement>(null)
  const [over, setOver] = useState(false)

  function take(files: FileList | null) {
    const file = files?.[0]
    if (file && !disabled) onFile(file)
    if (input.current) input.current.value = '' // cho phép chọn lại cùng một tệp
  }

  return (
    <div
      onDragOver={(e) => {
        e.preventDefault()
        if (!disabled) setOver(true)
      }}
      onDragLeave={() => setOver(false)}
      onDrop={(e) => {
        e.preventDefault()
        setOver(false)
        take(e.dataTransfer.files)
      }}
      className={cn(
        'flex flex-col items-center gap-2 rounded-lg border-2 border-dashed p-6 text-center text-sm',
        over && 'border-primary bg-accent',
        disabled && 'opacity-50',
      )}
    >
      <FileUp className="size-6 text-muted-foreground" />
      <p className="text-muted-foreground">Kéo thả file vào đây hoặc</p>
      <input ref={input} type="file" accept={accept} hidden disabled={disabled} onChange={(e) => take(e.target.files)} />
      <Button type="button" variant="outline" disabled={disabled} onClick={() => input.current?.click()}>
        Chọn file
      </Button>
    </div>
  )
}
