class AppDateUtils {
  static String formatDateTime(String? dateTimeStr, {String format = '{y}-{m}-{d} {h}:{i}:{s}'}) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '';

    try {
      final date = DateTime.parse(dateTimeStr);
      final formatObj = {
        'y': date.year,
        'm': date.month,
        'd': date.day,
        'h': date.hour,
        'i': date.minute,
        's': date.second,
        'a': date.weekday,
      };

      final weekDays = ['一', '二', '三', '四', '五', '六', '日'];

      return format.replaceAllMapped(
        RegExp(r'\{([ymdhisa])\}'),
        (match) {
          final key = match.group(1)!;
          final value = formatObj[key]!;
          if (key == 'a') {
            return weekDays[value - 1];
          }
          return value.toString().padLeft(2, '0');
        },
      );
    } catch (e) {
      return dateTimeStr;
    }
  }
}
