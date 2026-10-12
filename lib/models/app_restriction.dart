/// Usage control mode for a controlled application.
enum UsageMode {
  normal,
  strict;

  String get displayName {
    switch (this) {
      case UsageMode.normal:
        return 'Normal';
      case UsageMode.strict:
        return 'Strict';
    }
  }

  String get description {
    switch (this) {
      case UsageMode.normal:
        return 'Monitor usage and restrict after daily limit';
      case UsageMode.strict:
        return 'Require a reason every time you open the app';
    }
  }
}

/// State of restriction for a controlled application.
enum RestrictionState {
  uncontrolled,
  allowed,
  restricted,
  needsReason,
  tempAccess;
}

/// Persistent configuration for a single controlled application.
class AppRestriction {
  final String packageId;
  final String appName;
  final bool enabled;
  final UsageMode mode;
  final int dailyLimitMinutes;
  final List<int> allowedPresets; // e.g. [5, 10, 15, 30]
  final String createdAt;
  final String updatedAt;

  const AppRestriction({
    required this.packageId,
    required this.appName,
    this.enabled = true,
    this.mode = UsageMode.normal,
    this.dailyLimitMinutes = 30,
    this.allowedPresets = const [2, 3, 5, 10, 15, 30],
    required this.createdAt,
    required this.updatedAt,
  });

  AppRestriction copyWith({
    String? packageId,
    String? appName,
    bool? enabled,
    UsageMode? mode,
    int? dailyLimitMinutes,
    List<int>? allowedPresets,
    String? createdAt,
    String? updatedAt,
  }) {
    return AppRestriction(
      packageId: packageId ?? this.packageId,
      appName: appName ?? this.appName,
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      allowedPresets: allowedPresets ?? this.allowedPresets,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'packageId': packageId,
        'appName': appName,
        'enabled': enabled,
        'mode': mode.name,
        'dailyLimitMinutes': dailyLimitMinutes,
        'allowedPresets': allowedPresets,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory AppRestriction.fromJson(Map<String, dynamic> json) {
    return AppRestriction(
      packageId: json['packageId'] as String,
      appName: json['appName'] as String,
      enabled: json['enabled'] as bool? ?? true,
      mode: UsageMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => UsageMode.normal,
      ),
      dailyLimitMinutes: json['dailyLimitMinutes'] as int? ?? 30,
      allowedPresets: (json['allowedPresets'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [5, 10, 15, 30],
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
