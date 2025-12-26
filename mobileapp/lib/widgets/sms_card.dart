import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sms_message.dart';
import '../services/allowed_numbers_service.dart';

class SmsCard extends StatelessWidget {
  final SmsMessage message;
  final VoidCallback? onTap;

  const SmsCard({
    super.key,
    required this.message,
    this.onTap,
  });

  String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Color _getAvatarColor(String? address) {
    if (address == null || address.isEmpty) {
      return Colors.grey;
    }
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    final index = address.hashCode % colors.length;
    return colors[index.abs()];
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) {
      return '?';
    }
    // Get first letter of name (or first letter of first word)
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      return trimmed.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  // Send SMS - opens SMS composer
  Future<void> _sendSMS(BuildContext context, String phoneNumber, String message) async {
    try {
      // Remove any non-digit characters except + for international numbers
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Create SMS URL
      final uri = Uri.parse('sms:$cleanNumber${message.isNotEmpty ? '?body=${Uri.encodeComponent(message)}' : ''}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open SMS composer'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening SMS: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Forward SMS - opens SMS composer with message body pre-filled
  Future<void> _forwardSMS(BuildContext context, String messageBody) async {
    try {
      // Create SMS URL with body but no recipient (user can choose)
      final uri = Uri.parse('sms:?body=${Uri.encodeComponent(messageBody)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open SMS composer'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error forwarding SMS: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _getAvatarColor(message.address);
    
    // Use FutureBuilder to get the name from allowed numbers
    return FutureBuilder<String>(
      future: AllowedNumbersService.getNameForNumber(message.address),
      builder: (context, snapshot) {
        final displayName = snapshot.data ?? message.address;
        final initials = _getInitials(displayName);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          avatarColor,
                          avatarColor.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // API Status Icon (Success or Fail)
                              if (message.apiResponse != null)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    message.isApiSuccess
                                        ? Icons.check_circle
                                        : Icons.error,
                                    size: 20,
                                    color: message.isApiSuccess
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          _formatDate(message.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Action buttons: Reply and Forward
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          // Reply button
                          TextButton.icon(
                            onPressed: () => _sendSMS(context, message.address, ''),
                            icon: const Icon(Icons.reply, size: 16),
                            label: const Text('Reply'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Forward button
                          TextButton.icon(
                            onPressed: () => _forwardSMS(context, message.body),
                            icon: const Icon(Icons.forward, size: 16),
                            label: const Text('Forward'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Show transaction details if available
                    if (message.apiResponse != null &&
                        message.apiResponse!.isBankMessage == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            if (message.apiResponse!.type != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: message.apiResponse!.type == 'DEBIT'
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  message.apiResponse!.type!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: message.apiResponse!.type == 'DEBIT'
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                            if (message.apiResponse!.amount != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                message.apiResponse!.amount!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }
}

