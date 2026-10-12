/// Predefined reason categories for conscious app usage.
enum ReasonCategory {
  work,
  study,
  communication,
  research,
  navigation,
  entertainment,
  social,
  emergency,
  other;

  String get displayName {
    switch (this) {
      case ReasonCategory.work:
        return 'Work';
      case ReasonCategory.study:
        return 'Study';
      case ReasonCategory.communication:
        return 'Communication';
      case ReasonCategory.research:
        return 'Research';
      case ReasonCategory.navigation:
        return 'Navigation';
      case ReasonCategory.entertainment:
        return 'Entertainment';
      case ReasonCategory.social:
        return 'Social';
      case ReasonCategory.emergency:
        return 'Emergency';
      case ReasonCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case ReasonCategory.work:
        return '💼';
      case ReasonCategory.study:
        return '📚';
      case ReasonCategory.communication:
        return '💬';
      case ReasonCategory.research:
        return '🔍';
      case ReasonCategory.navigation:
        return '🗺️';
      case ReasonCategory.entertainment:
        return '🎮';
      case ReasonCategory.social:
        return '👥';
      case ReasonCategory.emergency:
        return '🚨';
      case ReasonCategory.other:
        return '📝';
    }
  }
}

/// Records the conscious reason given for app access.
class UsageReason {
  final String id;
  final String sessionId;
  final String packageId;
  final String appName;
  final String mode; // "normal" or "strict"
  final String timestamp;
  final ReasonCategory category;
  final String? customReason;
  final int requestedMinutes;
  final int approvedMinutes;
  final bool wasAllowed;

  const UsageReason({
    required this.id,
    required this.sessionId,
    required this.packageId,
    required this.appName,
    required this.mode,
    required this.timestamp,
    required this.category,
    this.customReason,
    required this.requestedMinutes,
    required this.approvedMinutes,
    this.wasAllowed = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'packageId': packageId,
        'appName': appName,
        'mode': mode,
        'timestamp': timestamp,
        'category': category.name,
        'customReason': customReason,
        'requestedMinutes': requestedMinutes,
        'approvedMinutes': approvedMinutes,
        'wasAllowed': wasAllowed,
      };

  factory UsageReason.fromJson(Map<String, dynamic> json) {
    return UsageReason(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      packageId: json['packageId'] as String,
      appName: json['appName'] as String? ?? '',
      mode: json['mode'] as String? ?? 'normal',
      timestamp: json['timestamp'] as String,
      category: ReasonCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ReasonCategory.other,
      ),
      customReason: json['customReason'] as String?,
      requestedMinutes: json['requestedMinutes'] as int? ?? 0,
      approvedMinutes: json['approvedMinutes'] as int? ?? 0,
      wasAllowed: json['wasAllowed'] as bool? ?? true,
    );
  }
}
