class SmsMessage {
  final String id;
  final String address;
  final String body;
  final int date;
  final ApiResponse? apiResponse;

  SmsMessage({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    this.apiResponse,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'body': body,
      'date': date,
      'apiResponse': apiResponse?.toJson(),
    };
  }

  // Create from JSON
  factory SmsMessage.fromJson(Map<String, dynamic> json) {
    return SmsMessage(
      id: json['id'] as String,
      address: json['address'] as String,
      body: json['body'] as String,
      date: json['date'] as int,
      apiResponse: json['apiResponse'] != null
          ? ApiResponse.fromJson(json['apiResponse'] as Map<String, dynamic>)
          : null,
    );
  }

  // Check if this is a relevant bank message
  bool get isRelevantBankMessage {
    return apiResponse?.isBankMessage == true;
  }

  // Check if API call was successful
  bool get isApiSuccess {
    return apiResponse?.isSuccess == true;
  }
}

class ApiResponse {
  final bool isSuccess;
  final String message;
  final bool? isBankMessage;
  final String? type; // DEBIT, CREDIT, etc.
  final String? amount;

  ApiResponse({
    required this.isSuccess,
    required this.message,
    this.isBankMessage,
    this.type,
    this.amount,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'message': message,
      'isBankMessage': isBankMessage,
      'type': type,
      'amount': amount,
    };
  }

  // Create from JSON
  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      isSuccess: json['isSuccess'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      isBankMessage: json['isBankMessage'] as bool?,
      type: json['type'] as String?,
      amount: json['amount'] as String?,
    );
  }

  // Parse from API response JSON
  factory ApiResponse.fromApiJson(Map<String, dynamic> json) {
    final message = json['message'] as String? ?? '';
    final isSuccess = message == 'Success';
    
    if (isSuccess && json.containsKey('data')) {
      final data = json['data'] as Map<String, dynamic>?;
      return ApiResponse(
        isSuccess: true,
        message: message,
        isBankMessage: data?['isBankMessage'] as bool? ?? false,
        type: data?['type'] as String?,
        amount: data?['amount'] as String?,
      );
    } else {
      // Error response like "Not a bank SMS, ignored."
      return ApiResponse(
        isSuccess: false,
        message: message,
        isBankMessage: false,
      );
    }
  }
}




