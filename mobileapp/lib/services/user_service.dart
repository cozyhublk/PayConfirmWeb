import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class UserService {
  static const String _userIdKey = 'user_id';
  static const String _apiUrl =
      'https://us-central1-payconfirmapp.cloudfunctions.net/swiftAlert';

  // Get stored user ID
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getString(_userIdKey);
    } catch (e) {
      print('Error getting user ID: $e');
      return null;
    }
  }

  // Save user ID
  static Future<bool> saveUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_userIdKey, userId);
      if (success) {
        await prefs.reload();
        print('Successfully saved user ID: $userId');
      }
      return success;
    } catch (e) {
      print('Error saving user ID: $e');
      return false;
    }
  }

  // Check if user ID exists
  static Future<bool> hasUserId() async {
    final userId = await getUserId();
    return userId != null && userId.isNotEmpty;
  }

  // Fetch user ID from customer (first time only)
  static Future<String?> fetchUserIdFromCustomer() async {
    try {
      final url = Uri.parse(_apiUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': 'shop_test',
          'smsText': 'Initial setup - requesting user ID',
        }),
      );

      print('User ID fetch response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        // Parse response to extract user_id
        // Adjust this based on your API response format
        try {
          final responseData = jsonDecode(response.body);
          
          // Try different possible response formats
          if (responseData is Map<String, dynamic>) {
            // Check for userId in response
            if (responseData.containsKey('userId')) {
              final userId = responseData['userId'];
              if (userId != null && userId.toString().isNotEmpty) {
                return userId.toString();
              }
            }
            // Check for user_id (with underscore)
            if (responseData.containsKey('user_id')) {
              final userId = responseData['user_id'];
              if (userId != null && userId.toString().isNotEmpty) {
                return userId.toString();
              }
            }
            // Check for data.userId
            if (responseData.containsKey('data') &&
                responseData['data'] is Map<String, dynamic>) {
              final data = responseData['data'] as Map<String, dynamic>;
              if (data.containsKey('userId')) {
                final userId = data['userId'];
                if (userId != null && userId.toString().isNotEmpty) {
                  return userId.toString();
                }
              }
            }
          }
          
          // If API doesn't return user_id in expected format,
          // user will need to set it manually in settings
          print('User ID not found in API response. User needs to set it manually.');
          return null;
        } catch (e) {
          print('Error parsing user ID from response: $e');
          return null;
        }
      } else {
        print('Failed to fetch user ID: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching user ID from customer: $e');
      return null;
    }
  }

  // Initialize user ID on first app load
  static Future<String?> initializeUserId() async {
    // Check if user ID already exists
    if (await hasUserId()) {
      return await getUserId();
    }

    // Try to fetch from customer
    final fetchedUserId = await fetchUserIdFromCustomer();
    if (fetchedUserId != null && fetchedUserId.isNotEmpty) {
      await saveUserId(fetchedUserId);
      return fetchedUserId;
    }

    // If fetch failed, return null (user will need to set it in settings)
    return null;
  }
}

