class Session {
  final DateTime inTime;
  final DateTime? outTime;
  final String? tag; // skill name or custom tag

  Session({required this.inTime, this.outTime, this.tag});

  bool get isActive => outTime == null;

  Duration get duration {
    if (outTime == null) return Duration.zero;
    return outTime!.difference(inTime);
  }

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Map<String, dynamic> toJson() => {
        'inTime': inTime.toIso8601String(),
        'outTime': outTime?.toIso8601String(),
        if (tag != null) 'tag': tag,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        inTime: DateTime.parse(json['inTime'] as String),
        outTime: json['outTime'] != null
            ? DateTime.parse(json['outTime'] as String)
            : null,
        tag: json['tag'] as String?,
      );

  Session copyWith({
    DateTime? inTime,
    DateTime? outTime,
    String? tag,
    bool clearOut = false,
    bool clearTag = false,
  }) =>
      Session(
        inTime: inTime ?? this.inTime,
        outTime: clearOut ? null : (outTime ?? this.outTime),
        tag: clearTag ? null : (tag ?? this.tag),
      );
}
