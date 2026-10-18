import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../providers/core_providers.dart';
import '../../widgets/error_banner.dart';

/// Cấu hình cho chức năng "đánh thức máy chủ" (máy chủ Render miễn phí ngủ khi không dùng).
class WakeConfig {
  const WakeConfig({required this.interval, required this.attempts});

  final Duration interval;
  final int attempts;
}

final wakeConfigProvider = Provider<WakeConfig>(
  (ref) => const WakeConfig(interval: Duration(seconds: 5), attempts: 12),
);

class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
  late final TextEditingController _urlCtrl;
  bool _busy = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ref.read(apiClientProvider).baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() => _run(() async {
    final api = ref.read(apiClientProvider);
    await api.setBaseUrl(_urlCtrl.text);
    await api.get('/health');
    if (mounted) setState(() => _status = 'Kết nối thành công');
  });

  Future<void> _save() => _run(() async {
    await ref.read(apiClientProvider).setBaseUrl(_urlCtrl.text);
    if (!mounted) return;
    _urlCtrl.text = ref.read(apiClientProvider).baseUrl;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu địa chỉ máy chủ')));
    if (context.canPop()) context.pop();
  });

  Future<void> _wake() => _run(() async {
    final api = ref.read(apiClientProvider);
    final config = ref.read(wakeConfigProvider);
    await api.setBaseUrl(_urlCtrl.text);
    for (var attempt = 1; attempt <= config.attempts; attempt++) {
      if (!mounted) return;
      setState(() => _status = 'Đang đánh thức máy chủ... ($attempt/${config.attempts})');
      try {
        await api.get('/health');
        if (mounted) setState(() => _status = 'Máy chủ đã sẵn sàng');
        return;
      } on ApiException {
        await Future<void>.delayed(config.interval);
      }
    }
    if (mounted) {
      setState(() => _status = 'Máy chủ chưa phản hồi, hãy thử lại sau ít phút.');
    }
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt máy chủ')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('server-url'),
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ máy chủ',
                    helperText: 'Trên điện thoại thật dùng http://<IP máy tính>:8000',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  ErrorBanner(_error!),
                ],
                if (_status != null) ...[
                  const SizedBox(height: 16),
                  Text(_status!, key: const Key('server-status')),
                ],
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _busy ? null : _check,
                  child: const Text('Kiểm tra kết nối'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _wake,
                  child: const Text('Đánh thức máy chủ (Render)'),
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: _busy ? null : _save, child: const Text('Lưu')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
