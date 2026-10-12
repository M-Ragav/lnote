enum MealType {
  morning,
  noon,
  evening,
  night;

  String get id => name;

  String get displayName {
    switch (this) {
      case MealType.morning:
        return 'Morning';
      case MealType.noon:
        return 'Noon';
      case MealType.evening:
        return 'Evening';
      case MealType.night:
        return 'Night';
    }
  }

  String get subtitle {
    switch (this) {
      case MealType.morning:
        return 'Breakfast & Start';
      case MealType.noon:
        return 'Lunch & Energy';
      case MealType.evening:
        return 'Snack & Tea';
      case MealType.night:
        return 'Dinner & Recovery';
    }
  }

  String get defaultTimeHint {
    switch (this) {
      case MealType.morning:
        return '06:00 AM - 11:00 AM';
      case MealType.noon:
        return '11:00 AM - 04:00 PM';
      case MealType.evening:
        return '04:00 PM - 07:30 PM';
      case MealType.night:
        return '07:30 PM - 11:00 PM';
    }
  }

  String get defaultDeadline {
    switch (this) {
      case MealType.morning:
        return '09:00 AM';
      case MealType.noon:
        return '01:30 PM';
      case MealType.evening:
        return '05:30 PM';
      case MealType.night:
        return '09:00 PM';
    }
  }

  static MealType fromString(String val) {
    return MealType.values.firstWhere(
      (m) => m.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MealType.morning,
    );
  }
}

class FoodItem {
  final String id;
  final String name;
  final String? count; // optional, e.g. "2 eggs", "1 bowl", "250 ml"
  final String? notes; // optional notes
  final List<int> daysOfWeek; // 1 = Mon, ..., 7 = Sun (compatible with DateTime.weekday)
  final String deadline; // e.g. "08:30 AM" or "08:30"
  final MealType mealType;
  final bool isEnabled;
  final DateTime createdAt;

  FoodItem({
    required this.id,
    required this.name,
    this.count,
    this.notes,
    required this.daysOfWeek,
    required this.deadline,
    required this.mealType,
    this.isEnabled = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool isActiveOnWeekday(int weekday) {
    if (!isEnabled) return false;
    return daysOfWeek.contains(weekday);
  }

  String get formattedDays {
    if (daysOfWeek.length == 7) return 'Every day';
    if (daysOfWeek.length == 5 &&
        !daysOfWeek.contains(6) &&
        !daysOfWeek.contains(7)) {
      return 'Weekdays';
    }
    if (daysOfWeek.length == 2 &&
        daysOfWeek.contains(6) &&
        daysOfWeek.contains(7)) {
      return 'Weekends';
    }
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = List<int>.from(daysOfWeek)..sort();
    return sorted.map((d) => dayNames[d - 1]).join(', ');
  }

  FoodItem copyWith({
    String? id,
    String? name,
    String? count,
    String? notes,
    List<int>? daysOfWeek,
    String? deadline,
    MealType? mealType,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
      notes: notes ?? this.notes,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      deadline: deadline ?? this.deadline,
      mealType: mealType ?? this.mealType,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'count': count,
        'notes': notes,
        'daysOfWeek': daysOfWeek,
        'deadline': deadline,
        'mealType': mealType.name,
        'isEnabled': isEnabled,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        name: json['name'] as String,
        count: json['count'] as String?,
        notes: json['notes'] as String?,
        daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [1, 2, 3, 4, 5, 6, 7],
        deadline: json['deadline'] as String? ?? '09:00 AM',
        mealType: MealType.fromString(json['mealType'] as String? ?? 'morning'),
        isEnabled: json['isEnabled'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  factory FoodItem.create({
    required String name,
    String? count,
    String? notes,
    required List<int> daysOfWeek,
    required String deadline,
    required MealType mealType,
  }) {
    return FoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      count: count?.trim().isEmpty == true ? null : count?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      daysOfWeek: daysOfWeek.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : daysOfWeek,
      deadline: deadline.trim(),
      mealType: mealType,
    );
  }
}
