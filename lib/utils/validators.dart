import 'constants.dart';

class Validators {
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
  );

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppConstants.emptyEmailMsg;
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return AppConstants.invalidEmailMsg;
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppConstants.emptyPasswordMsg;
    }
    if (value.length < 6) {
      return AppConstants.shortPasswordMsg;
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppConstants.emptyNameMsg;
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return AppConstants.passwordMismatchMsg;
    }
    return null;
  }

  /// Calculates password strength from 0.0 to 1.0 and returns label
  static PasswordStrength calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrength(score: 0.0, label: '', colorType: StrengthType.weak);
    }

    double score = 0.0;
    if (password.length >= 6) score += 0.3;
    if (password.length >= 8) score += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 0.15;

    if (score < 0.4) {
      return PasswordStrength(score: score, label: 'Weak', colorType: StrengthType.weak);
    } else if (score < 0.75) {
      return PasswordStrength(score: score, label: 'Medium', colorType: StrengthType.medium);
    } else {
      return PasswordStrength(score: score, label: 'Strong', colorType: StrengthType.strong);
    }
  }
}

enum StrengthType { weak, medium, strong }

class PasswordStrength {
  final double score;
  final String label;
  final StrengthType colorType;

  PasswordStrength({
    required this.score,
    required this.label,
    required this.colorType,
  });
}
