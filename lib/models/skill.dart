class Skill {
  String id;
  String name;
  int experienceYears;
  String level; // 'débutant', 'intermédiaire', 'avancé', 'expert'

  Skill({
    required this.name,
    required this.experienceYears,
    required this.level,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'],
      name: json['name'],
      experienceYears: json['experience_years'],
      level: json['level'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'experience_years': experienceYears,
      'level': level,
    };
  }
}
