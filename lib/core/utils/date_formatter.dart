import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _dateFormat = DateFormat('MMM dd, yyyy');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _dateTimeFormat = DateFormat('MMM dd, yyyy hh:mm a');
  static final _shortFormat = DateFormat('MM/dd/yy');
  static final _dayMonthFormat = DateFormat('MMM dd');

  static String formatDate(DateTime date) => _dateFormat.format(date);

  static String formatTime(DateTime date) => _timeFormat.format(date);

  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  static String formatShort(DateTime date) => _shortFormat.format(date);

  static String formatDayMonth(DateTime date) => _dayMonthFormat.format(date);

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return formatDate(date);
    }
  }
}
