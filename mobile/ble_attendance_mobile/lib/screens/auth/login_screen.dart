import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/validators.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/success_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;
  bool _deviceMismatch = false;

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _deviceMismatch = false;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_idCtrl.text, _passwordCtrl.text);
      // Đăng nhập xong, router tự chuyển sang trang chủ theo vai trò.
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _deviceMismatch =
              error is ApiException && error.code == 'device_mismatch';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDeviceChange() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _DeviceChangeDialog(id: _idCtrl.text, password: _passwordCtrl.text),
    );
    if (sent == true && mounted) {
      setState(() {
        _error = null;
        _deviceMismatch = false;
        _notice =
            'Đã gửi đơn đổi thiết bị. Hãy chờ admin duyệt rồi đăng nhập lại trên máy này.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh BLE'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt máy chủ',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 84,
                      height: 84,
                      semanticLabel: 'Logo Điểm danh BLE',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đăng nhập để điểm danh',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('login-id'),
                    controller: _idCtrl,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _clearError(),
                    decoration: const InputDecoration(
                      labelText: 'Mã đăng nhập',
                      helperText: 'MSSV hoặc mã giảng viên, ví dụ 25CE099',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        Validators.requiredField(v, 'mã đăng nhập'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('login-password'),
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    onChanged: (_) => _clearError(),
                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        key: const Key('toggle-password'),
                        tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => Validators.requiredField(v, 'mật khẩu'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    ErrorBanner(_error!),
                  ],
                  if (_deviceMismatch) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _openDeviceChange,
                      icon: const Icon(Icons.phonelink_setup),
                      label: const Text('Gửi đơn đổi thiết bị'),
                    ),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 16),
                    SuccessBanner(_notice!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Đăng nhập'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => context.push('/register'),
                    child: const Text('Chưa có tài khoản? Đăng ký (sinh viên)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hộp thoại nhập lý do đổi thiết bị; dùng mã đăng nhập và mật khẩu đã gõ ở màn hình đăng nhập.
class _DeviceChangeDialog extends ConsumerStatefulWidget {
  const _DeviceChangeDialog({required this.id, required this.password});

  final String id;
  final String password;

  @override
  ConsumerState<_DeviceChangeDialog> createState() =>
      _DeviceChangeDialogState();
}

class _DeviceChangeDialogState extends ConsumerState<_DeviceChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestDeviceChange(
            id: widget.id,
            password: widget.password,
            reason: _reasonCtrl.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đơn đổi thiết bị'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tài khoản chỉ đăng nhập được trên một máy. Admin sẽ duyệt đơn để chuyển sang máy này.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('device-reason'),
              autofocus: true,
              controller: _reasonCtrl,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Lý do đổi máy'),
              validator: (v) => Validators.requiredField(v, 'lý do'),
            ),
            if (_error != null) ErrorBanner(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: const Text('Gửi đơn'),
        ),
      ],
    );
  }
}
