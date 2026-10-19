import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedFile {
  PickedFile({required this.name, required List<int> bytes})
    : bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  final String name;
  final Uint8List bytes;
}

/// Cho người dùng chọn một tệp CSV/Excel từ máy. Trả null nếu hủy.
abstract class FileChooser {
  Future<PickedFile?> pick();
}

class FilePickerChooser implements FileChooser {
  @override
  Future<PickedFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return PickedFile(name: file.name, bytes: bytes);
  }
}
