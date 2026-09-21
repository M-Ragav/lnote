import 'session.dart';

class AttendanceDay {
  final String date; // "2026-09-21"
  final List<Session> sessions;

  AttendanceDay({required this.date, List<Session>? sessions})
      : sessions = sessions ?? [];

  /// Whether there's an active (un-ended) session
  bool get hasActiveSession =>
      sessions.isNotEmpty && sessions.last.isActive;

  /// Last IN time across all sessions
  DateTime? get lastInTime =>
      sessions.isNotEmpty ? sessions.last.inTime : null;

  /// Last OUT time across all sessions
  DateTime? get lastOutTime {
    for (int i = sessions.length - 1; i >= 0; i--) {
      if (sessions[i].outTime != null) return sessions[i].outTime;
    }
    return null;
  }

  /// Total work duration for completed sessions
  Duration get totalDuration {
    return sessions.fold(
      Duration.zero,
      (total, session) => total + session.duration,
    );
  }

  String get formattedTotalDuration {
    final d = totalDuration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  int get totalInCount => sessions.length;

  int get totalOutCount =>
      sessions.where((s) => s.outTime != null).length;

  Map<String, dynamic> toJson() => {
        'date': date,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory AttendanceDay.fromJson(Map<String, dynamic> json) =>
      AttendanceDay(
        date: json['date'] as String,
        sessions: (json['sessions'] as List<dynamic>)
            .map((s) => Session.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
