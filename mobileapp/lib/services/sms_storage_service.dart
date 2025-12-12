import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sms_message.dart';

class SmsStorageService {
  static const String _storageKey = 'sms_messages';
  
  // Stream controller to notify when messages are updated
  static final StreamController<void> _messageUpdateController = 
      StreamController<void>.broadcast();
  
  // Stream to listen for message updates
  static Stream<void> get onMessageUpdate => _messageUpdateController.stream;

  // Save a message with API response
  static Future<bool> saveMessage(SmsMessage message) async {
    try {
      final messages = await getAllMessages();
      
      // Check if message already exists (update if exists)
      final existingIndex = messages.indexWhere((m) => m.id == message.id);
      if (existingIndex != -1) {
        messages[existingIndex] = message;
      } else {
        messages.add(message);
      }

      // Keep only last 1000 messages to avoid storage issues
      if (messages.length > 1000) {
        messages.sort((a, b) => b.date.compareTo(a.date));
        messages.removeRange(1000, messages.length);
      }

      final success = await _saveMessages(messages);
      
      // Notify listeners that messages were updated
      if (success && message.isRelevantBankMessage) {
        _messageUpdateController.add(null);
      }
      
      return success;
    } catch (e) {
      print('Error saving message: $e');
      return false;
    }
  }

  // Get all messages
  static Future<List<SmsMessage>> getAllMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => SmsMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading messages: $e');
      return [];
    }
  }

  // Get only relevant bank messages (isBankMessage: true)
  static Future<List<SmsMessage>> getRelevantBankMessages() async {
    try {
      final allMessages = await getAllMessages();
      // Filter to only show messages with isBankMessage: true
      // Sort by date (newest first)
      final relevant = allMessages
          .where((msg) => msg.isRelevantBankMessage)
          .toList();
      relevant.sort((a, b) => b.date.compareTo(a.date));
      return relevant;
    } catch (e) {
      print('Error loading relevant messages: $e');
      return [];
    }
  }

  // Delete a message
  static Future<bool> deleteMessage(String id) async {
    try {
      final messages = await getAllMessages();
      messages.removeWhere((m) => m.id == id);
      return await _saveMessages(messages);
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Clear all messages
  static Future<bool> clearAllMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_storageKey);
    } catch (e) {
      print('Error clearing messages: $e');
      return false;
    }
  }

  // Save messages to storage
  static Future<bool> _saveMessages(List<SmsMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = messages.map((m) => m.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      final success = await prefs.setString(_storageKey, jsonString);
      if (success) {
        await prefs.reload();
      }
      return success;
    } catch (e) {
      print('Error saving messages: $e');
      return false;
    }
  }
}

