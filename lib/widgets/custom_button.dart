import 'package:flutter/material.dart';

enum ButtonType { primary, outlined, text }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonType type;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.type = ButtonType.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    if (type == ButtonType.outlined) {
      return OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        child: _buildContent(context, isPrimary: false),
      );
    } else if (type == ButtonType.text) {
      return TextButton(
        onPressed: isEnabled ? onPressed : null,
        child: Text(text),
      );
    }

    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      child: _buildContent(context, isPrimary: true),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isPrimary}) {
    if (isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            isPrimary ? Colors.white : Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }
}
