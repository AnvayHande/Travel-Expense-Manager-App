import 'package:flutter/material.dart';

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? height;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? 56,
      width: width ?? double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }

    return Text(label);
  }
}
