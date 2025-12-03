class AllowedNumber {
  final String id;
  final String phoneNumber;
  final String name;
  final DateTime createdAt;

  AllowedNumber({
    required this.id,
    required this.phoneNumber,
    required this.name,
    required this.createdAt,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory AllowedNumber.fromJson(Map<String, dynamic> json) {
    return AllowedNumber(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // Copy with method for updates
  AllowedNumber copyWith({
    String? id,
    String? phoneNumber,
    String? name,
    DateTime? createdAt,
  }) {
    return AllowedNumber(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Validation
  bool isValid() {
    return phoneNumber.trim().isNotEmpty && name.trim().isNotEmpty;
  }
}

