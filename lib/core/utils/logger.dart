import 'package:logger/logger.dart' as pkg_logger;

class AppLogger {
  AppLogger._();

  static final pkg_logger.Logger _logger = pkg_logger.Logger(
    printer: pkg_logger.PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: false,
      dateTimeFormat: pkg_logger.DateTimeFormat.onlyTime,
    ),
  );

  static void debug(String message) => _logger.d(message);

  static void info(String message) => _logger.i(message);

  static void warning(String message) => _logger.w(message);

  static void error(String message, [dynamic error, StackTrace? stack]) {
    _logger.e(message, error: error, stackTrace: stack);
  }

  static void fatal(String message, [dynamic error, StackTrace? stack]) {
    _logger.f(message, error: error, stackTrace: stack);
  }
}
