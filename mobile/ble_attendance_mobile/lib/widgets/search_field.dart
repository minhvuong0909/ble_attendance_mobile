import 'package:flutter/material.dart';

/// Ô tìm kiếm dùng chung cho các danh sách dài (lọc cục bộ, không gọi máy chủ).
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
        ),
      ),
    );
  }
}

/// So khớp không phân biệt hoa thường; chuỗi tìm rỗng khớp tất cả.
bool matchesQuery(String query, Iterable<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((f) => f != null && f.toLowerCase().contains(q));
}
