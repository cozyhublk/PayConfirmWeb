class PhoneNumberUtils {
  // Normalize phone number - preserve leading +, remove spaces, dashes, parentheses
  static String normalizePhoneNumber(String phoneNumber) {
    // Trim and check if it starts with +
    final trimmed = phoneNumber.trim();
    final hasPlus = trimmed.startsWith('+');
    
    // Remove all spaces, dashes, parentheses, and plus signs
    String normalized = trimmed.replaceAll(RegExp(r'[\s\-+()]'), '');
    
    // Add back the + if it was present
    if (hasPlus && !normalized.startsWith('+')) {
      normalized = '+$normalized';
    }
    
    return normalized;
  }

  // Check if two phone numbers match (supports partial matching)
  static bool matchPhoneNumber(String number1, String number2) {
    final normalized1 = normalizePhoneNumber(number1);
    final normalized2 = normalizePhoneNumber(number2);

    // Exact match
    if (normalized1 == normalized2) {
      return true;
    }

    // Remove + for comparison of digits only
    final digits1 = normalized1.replaceAll('+', '');
    final digits2 = normalized2.replaceAll('+', '');

    // Exact digit match
    if (digits1 == digits2) {
      return true;
    }

    // If both are long enough, check last 10 digits (common for country codes)
    if (digits1.length >= 10 && digits2.length >= 10) {
      final last10_1 = digits1.substring(digits1.length - 10);
      final last10_2 = digits2.substring(digits2.length - 10);
      if (last10_1 == last10_2) {
        return true;
      }
    }

    // If one is shorter, check if it matches the end of the longer one
    if (digits1.length > digits2.length) {
      return digits1.endsWith(digits2);
    } else if (digits2.length > digits1.length) {
      return digits2.endsWith(digits1);
    }

    return false;
  }

  // Format phone number for display (add spaces for readability)
  static String formatPhoneNumber(String phoneNumber) {
    final normalized = normalizePhoneNumber(phoneNumber);
    
    // Check if it has a + prefix
    final hasPlus = normalized.startsWith('+');
    final digitsOnly = normalized.replaceAll('+', '');
    
    // Format based on length
    if (digitsOnly.length == 10) {
      // Format: XXX XXX XXXX or +XXX XXX XXXX
      final formatted = '${digitsOnly.substring(0, 3)} ${digitsOnly.substring(3, 6)} ${digitsOnly.substring(6)}';
      return hasPlus ? '+$formatted' : formatted;
    } else if (digitsOnly.length == 11) {
      // Format: X XXX XXX XXXX or +X XXX XXX XXXX
      final formatted = '${digitsOnly.substring(0, 1)} ${digitsOnly.substring(1, 4)} ${digitsOnly.substring(4, 7)} ${digitsOnly.substring(7)}';
      return hasPlus ? '+$formatted' : formatted;
    } else if (digitsOnly.length > 11) {
      // Format: +XX XXX XXX XXXX
      final countryCode = digitsOnly.substring(0, digitsOnly.length - 10);
      final rest = digitsOnly.substring(digitsOnly.length - 10);
      return '+$countryCode ${rest.substring(0, 3)} ${rest.substring(3, 6)} ${rest.substring(6)}';
    }
    
    return normalized;
  }

  // Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    final normalized = normalizePhoneNumber(phoneNumber);
    // Remove + for validation
    final digitsOnly = normalized.replaceAll('+', '');
    // At least 7 digits, max 15 digits (international standard)
    return RegExp(r'^\d{7,15}$').hasMatch(digitsOnly);
  }
}

