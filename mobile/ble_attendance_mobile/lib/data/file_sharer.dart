import 'file_sharer_io.dart'
    if (dart.library.js_interop) 'file_sharer_web.dart';

/// Chia sẻ một tệp ra ngoài app (share sheet trên Android, tải xuống trên web).
abstract class FileSharer {
  Future<void> share(String filename, List<int> bytes);
}

FileSharer createFileSharer() => createPlatformFileSharer();
