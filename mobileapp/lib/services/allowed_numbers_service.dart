import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/allowed_number.dart';
import 'phone_number_utils.dart';

class AllowedNumbersService {
  static const String _storageKey = 'allowed_numbers';

  // Get all allowed numbers
  static Future<List<AllowedNumber>> getAllAllowedNumbers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
      
      // Check for duplicates
      final isDuplicate = numbers.any((n) => 
        n.phoneNumber == number.phoneNumber
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

  // Check if a phone number is allowed
  static Future<bool> isNumberAllowed(String phoneNumber) async {
    try {
      final numbers = await getAllAllowedNumbers();
      return numbers.any((n) => 
        PhoneNumberUtils.matchPhoneNumber(n.phoneNumber, phoneNumber)
      );
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
      return await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error saving allowed numbers: $e');
      return false;
    }
  }
}

