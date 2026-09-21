class Skill {
  final String id;
  final String name;

  Skill({required this.id, required this.name});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  /// Generate a unique ID based on timestamp
  factory Skill.create({required String name}) => Skill(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
      );
}
