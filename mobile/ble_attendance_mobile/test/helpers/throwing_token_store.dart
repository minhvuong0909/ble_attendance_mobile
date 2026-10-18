import 'package:flutter/services.dart';

import 'memory_token_store.dart';

/// Kho token mô phỏng lỗi flutter_secure_storage (ví dụ sau khi khôi phục máy).
class ThrowingTokenStore extends MemoryTokenStore {
  @override
  Future<String?> readToken() async =>
      throw PlatformException(code: 'read_failed');
}
