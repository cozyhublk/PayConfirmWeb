class PhoneNumberUtils {
  // Normalize phone number - remove spaces, dashes, plus signs, parentheses
  static String normalizePhoneNumber(String phoneNumber) {
    return phoneNumber
        .replaceAll(RegExp(r'[\s\-+()]'), '')
        .trim();
  }

  // Check if two phone numbers match (supports partial matching)
  static bool matchPhoneNumber(String number1, String number2) {
    final normalized1 = normalizePhoneNumber(number1);
    final normalized2 = normalizePhoneNumber(number2);

    // Exact match
    if (normalized1 == normalized2) {
      return true;
    }

    // If both are long enough, check last 10 digits (common for country codes)
    if (normalized1.length >= 10 && normalized2.length >= 10) {
      final last10_1 = normalized1.substring(normalized1.length - 10);
      final last10_2 = normalized2.substring(normalized2.length - 10);
      if (last10_1 == last10_2) {
        return true;
      }
    }

    // If one is shorter, check if it matches the end of the longer one
    if (normalized1.length > normalized2.length) {
      return normalized1.endsWith(normalized2);
    } else if (normalized2.length > normalized1.length) {
      return normalized2.endsWith(normalized1);
    }

    return false;
  }

  // Format phone number for display (add spaces for readability)
  static String formatPhoneNumber(String phoneNumber) {
    final normalized = normalizePhoneNumber(phoneNumber);
    
    // Format based on length
    if (normalized.length == 10) {
      // Format: XXX XXX XXXX
      return '${normalized.substring(0, 3)} ${normalized.substring(3, 6)} ${normalized.substring(6)}';
    } else if (normalized.length == 11) {
      // Format: X XXX XXX XXXX
      return '${normalized.substring(0, 1)} ${normalized.substring(1, 4)} ${normalized.substring(4, 7)} ${normalized.substring(7)}';
    } else if (normalized.length > 11) {
      // Format: +XX XXX XXX XXXX
      final countryCode = normalized.substring(0, normalized.length - 10);
      final rest = normalized.substring(normalized.length - 10);
      return '+$countryCode ${rest.substring(0, 3)} ${rest.substring(3, 6)} ${rest.substring(6)}';
    }
    
    return normalized;
  }

  // Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    final normalized = normalizePhoneNumber(phoneNumber);
    // At least 7 digits, max 15 digits (international standard)
    return RegExp(r'^\d{7,15}$').hasMatch(normalized);
  }
}

