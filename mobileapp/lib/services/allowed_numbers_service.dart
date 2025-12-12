import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/allowed_number.dart';

class AllowedNumbersService {
  static const String _storageKey = 'allowed_numbers';

  // Get all allowed numbers
  static Future<List<AllowedNumber>> getAllAllowedNumbers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Reload to ensure we have the latest data
      await prefs.reload();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => AllowedNumber.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading allowed numbers: $e');
      return [];
    }
  }

  // Add a new allowed number
  static Future<bool> addAllowedNumber(AllowedNumber number) async {
    try {
      final numbers = await getAllAllowedNumbers();

      // Check for duplicates using simple equality (case-insensitive)
      final isDuplicate = numbers.any(
        (n) => n.phoneNumber.trim().toLowerCase() == 
               number.phoneNumber.trim().toLowerCase(),
      );

      if (isDuplicate) {
        return false;
      }

      numbers.add(number);
      return await _saveNumbers(numbers);
    } catch (e) {
      print('Error adding allowed number: $e');
      return false;
    }
  }

  // Update an existing allowed number
  static Future<bool> updateAllowedNumber(AllowedNumber number) async {
    try {
      final numbers = await getAllAllowedNumbers();
      final index = numbers.indexWhere((n) => n.id == number.id);

      if (index == -1) {
        return false;
      }

      numbers[index] = number;
      return await _saveNumbers(numbers);
    } catch (e) {
      print('Error updating allowed number: $e');
      return false;
    }
  }

  // Delete an allowed number
  static Future<bool> deleteAllowedNumber(String id) async {
    try {
      final numbers = await getAllAllowedNumbers();
      numbers.removeWhere((n) => n.id == id);
      return await _saveNumbers(numbers);
    } catch (e) {
      print('Error deleting allowed number: $e');
      return false;
    }
  }

  // Check if a phone number or text is allowed (simple equality check)
  static Future<bool> isNumberAllowed(String phoneNumberOrText) async {
    try {
      final numbers = await getAllAllowedNumbers();
      print(
        'Checking if "$phoneNumberOrText" is allowed. Total allowed entries: ${numbers.length}',
      );

      // Simple equality check (case-insensitive for text)
      final result = numbers.any(
        (n) => n.phoneNumber.trim().toLowerCase() == 
               phoneNumberOrText.trim().toLowerCase(),
      );

      print(
        'Final result: "$phoneNumberOrText" is ${result ? "ALLOWED" : "NOT ALLOWED"}',
      );
      return result;
    } catch (e) {
      print('Error checking allowed number: $e');
      return false;
    }
  }

  // Save numbers to storage
  static Future<bool> _saveNumbers(List<AllowedNumber> numbers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = numbers.map((n) => n.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      // Save the data
      final success = await prefs.setString(_storageKey, jsonString);

      if (success) {
        // Reload to ensure the data is persisted and cached correctly
        await prefs.reload();
        print('Successfully saved ${numbers.length} allowed number(s)');
      } else {
        print('Failed to save allowed numbers - setString returned false');
      }

      return success;
    } catch (e) {
      print('Error saving allowed numbers: $e');
      return false;
    }
  }
}
