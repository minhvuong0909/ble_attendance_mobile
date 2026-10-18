import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/validators.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/error_banner.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(bool forced) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = ref.read(authControllerProvider.notifier);
    final home = ref.read(authControllerProvider).user!.role.homePath;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await controller.changePassword(
        oldPassword: _oldCtrl.text,
        newPassword: _newCtrl.text,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu')));
      if (forced) {
        router.go(home);
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go(home);
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forced =
        ref.watch(authControllerProvider).user?.mustChangePassword ?? false;
    return PopScope(
      canPop: !forced,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đổi mật khẩu'),
          automaticallyImplyLeading: !forced,
          actions: [
            if (forced)
              TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Đăng xuất'),
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
                    if (forced) ...[
                      const Text(
                        'Bạn đang dùng mật khẩu tạm. Hãy đặt mật khẩu mới để tiếp tục.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      key: const Key('old-password'),
                      controller: _oldCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu hiện tại',
                      ),
                      validator: (v) =>
                          Validators.requiredField(v, 'mật khẩu hiện tại'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('new-password'),
                      controller: _newCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu mới',
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('confirm-password'),
                      controller: _confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nhập lại mật khẩu mới',
                      ),
                      validator: (v) => Validators.confirm(v, _newCtrl.text),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ErrorBanner(_error!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : () => _submit(forced),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Đổi mật khẩu'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
