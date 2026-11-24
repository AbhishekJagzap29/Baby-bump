import 'package:intl/intl.dart';

class DateTimeUtils {
  static String formatDisplayDate(DateTime dateTime) {
    return DateFormat('EEEE, MMM d, yyyy').format(dateTime);
  }

  static String formatIsoDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  static String format24HourTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  static bool isValid24HourTime(String time) {
    final regex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
    return regex.hasMatch(time.trim());
  }

  static String friendlyRelativeDate(String isoDate) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    if (isoDate == today) {
      return 'Today';
    } else if (isoDate == yesterday) {
      return 'Yesterday';
    } else {
      try {
        final parsed = DateTime.parse(isoDate);
        return DateFormat('EEE, d MMM yyyy').format(parsed);
      } catch (_) {
        return isoDate;
      }
    }
  }
}
