import 'package:flutter/material.dart';

/// Nhắc người quản trị rằng mật khẩu tạm của tài khoản chính là mã đăng nhập.
Future<void> showTempPasswordNotice(
  BuildContext context, {
  required String title,
  required String loginId,
  required String name,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        'Mật khẩu tạm của $name là chính mã đăng nhập ($loginId, viết hoa). '
        'Họ sẽ phải đổi mật khẩu khi đăng nhập lần đầu.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );
}
