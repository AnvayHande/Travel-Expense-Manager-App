import 'package:flutter/material.dart';

class SnackbarHelper {
  SnackbarHelper._();

  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.green);
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.red);
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.blue);
  }

  static void showWarning(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.orange);
  }

  static void _showSnackBar(
    BuildContext context,
    String message,
    Color color,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIcon(color),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static IconData _getIcon(Color color) {
    if (color == Colors.green) return Icons.check_circle;
    if (color == Colors.red) return Icons.error;
    if (color == Colors.orange) return Icons.warning;
    return Icons.info;
  }
}
