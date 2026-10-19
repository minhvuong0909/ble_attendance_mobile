import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'file_sharer.dart';

class SharePlusFileSharer implements FileSharer {
  @override
  Future<void> share(String filename, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], title: filename),
    );
  }
}

FileSharer createPlatformFileSharer() => SharePlusFileSharer();
