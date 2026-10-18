import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/validators.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/error_banner.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            fullName: _nameCtrl.text,
            identifier: _idCtrl.text,
            password: _passwordCtrl.text,
          );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký sinh viên')),
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
                  TextFormField(
                    key: const Key('register-name'),
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                    validator: (v) => Validators.requiredField(v, 'họ tên'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('register-id'),
                    controller: _idCtrl,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Mã sinh viên',
                      helperText: 'Ví dụ 25CE099 hoặc D26CE045',
                    ),
                    validator: (v) =>
                        Validators.requiredField(v, 'mã sinh viên'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('register-password'),
                    controller: _passwordCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('register-confirm'),
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu',
                    ),
                    validator: (v) => Validators.confirm(v, _passwordCtrl.text),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    ErrorBanner(_error!),
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
                        : const Text('Đăng ký'),
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
