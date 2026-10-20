import { Button } from '@/components/ui/button'
import {
  AlertDialog,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'

interface Props {
  open: boolean
  loginId: string
  name: string
  onClose: () => void
}

/** Mật khẩu tạm của tài khoản do admin tạo là chính mã đăng nhập; chỉ hiển thị một lần ở đây. */
export default function TempPasswordDialog({ open, loginId, name, onClose }: Props) {
  return (
    <AlertDialog open={open}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Tài khoản đã sẵn sàng</AlertDialogTitle>
          <AlertDialogDescription>
            Mật khẩu tạm của {name} trùng với mã đăng nhập: <strong className="text-foreground">{loginId}</strong>. Hãy báo cho họ; họ bắt buộc đổi mật khẩu ở lần đăng nhập đầu.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <Button onClick={onClose}>Đã ghi nhận</Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
