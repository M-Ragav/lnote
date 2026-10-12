/// Status of a usage session.
enum SessionStatus {
  pending,
  active,
  completed,
  expired,
  blocked,
  cancelled;

  String get displayName {
    switch (this) {
      case SessionStatus.pending:
        return 'Pending';
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.expired:
        return 'Expired';
      case SessionStatus.blocked:
        return 'Blocked';
      case SessionStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Records a single usage session for a controlled application.
class UsageSession {
  final String id;
  final String packageId;
  final String appName;
  final String mode; // "normal" or "strict"
  final String startedAt;
  final String? expiresAt;
  final String? endedAt;
  final int requestedDurationMinutes;
  final int actualDurationMinutes;
  final String? reasonId;
  final SessionStatus status;

  const UsageSession({
    required this.id,
    required this.packageId,
    required this.appName,
    required this.mode,
    required this.startedAt,
    this.expiresAt,
    this.endedAt,
    required this.requestedDurationMinutes,
    this.actualDurationMinutes = 0,
    this.reasonId,
    this.status = SessionStatus.pending,
  });

  UsageSession copyWith({
    String? id,
    String? packageId,
    String? appName,
    String? mode,
    String? startedAt,
    String? expiresAt,
    String? endedAt,
    int? requestedDurationMinutes,
    int? actualDurationMinutes,
    String? reasonId,
    SessionStatus? status,
  }) {
    return UsageSession(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      appName: appName ?? this.appName,
      mode: mode ?? this.mode,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      endedAt: endedAt ?? this.endedAt,
      requestedDurationMinutes:
          requestedDurationMinutes ?? this.requestedDurationMinutes,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      reasonId: reasonId ?? this.reasonId,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'packageId': packageId,
        'appName': appName,
        'mode': mode,
        'startedAt': startedAt,
        'expiresAt': expiresAt,
        'endedAt': endedAt,
        'requestedDurationMinutes': requestedDurationMinutes,
        'actualDurationMinutes': actualDurationMinutes,
        'reasonId': reasonId,
        'status': status.name,
      };

  factory UsageSession.fromJson(Map<String, dynamic> json) {
    return UsageSession(
      id: json['id'] as String,
      packageId: json['packageId'] as String,
      appName: json['appName'] as String? ?? '',
      mode: json['mode'] as String? ?? 'normal',
      startedAt: json['startedAt'] as String,
      expiresAt: json['expiresAt'] as String?,
      endedAt: json['endedAt'] as String?,
      requestedDurationMinutes: json['requestedDurationMinutes'] as int? ?? 0,
      actualDurationMinutes: json['actualDurationMinutes'] as int? ?? 0,
      reasonId: json['reasonId'] as String?,
      status: SessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SessionStatus.pending,
      ),
    );
  }
}
