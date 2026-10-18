import 'package:intl/intl.dart';

final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final _date = DateFormat('dd/MM/yyyy');
final _apiDate = DateFormat('yyyy-MM-dd');

String formatDateTime(DateTime value) => _dateTime.format(value);
String formatDate(DateTime value) => _date.format(value);
String toApiDate(DateTime value) => _apiDate.format(value);

/// Server trả UTC có hậu tố Z; đổi sang giờ máy để hiển thị.
DateTime parseApiTime(String value) => DateTime.parse(value).toLocal();
