class UserProfile {
  final String name;
  final DateTime birthday;

  UserProfile({required this.name, required this.birthday});

  Map<String, dynamic> toJson() => {
        'name': name,
        'birthday': birthday.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String,
        birthday: DateTime.parse(json['birthday'] as String),
      );

  UserProfile copyWith({String? name, DateTime? birthday}) => UserProfile(
        name: name ?? this.name,
        birthday: birthday ?? this.birthday,
      );
}
