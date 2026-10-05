import 'package:uuid/uuid.dart';

const resumeFields = <String, String>{
  'name': 'Full name',
  'role': 'Target job title',
  'email': 'Email address',
  'phone': 'Phone number',
  'location': 'City, country',
  'linkedin': 'LinkedIn URL',
  'website': 'Portfolio / website',
  'summary': 'Professional summary',
  'skills': 'Skills (comma separated)',
  'experience': 'Experience',
  'education': 'Education',
  'projects': 'Projects',
  'certifications': 'Certifications',
  'languages': 'Languages',
};

class Resume {
  Resume({
    required this.id,
    required this.title,
    required this.data,
    this.template = 'modern',
    this.accent = 0xff245bdb,
    DateTime? updated,
  }) : updated = updated ?? DateTime.now();
  final String id;
  String title;
  Map<String, String> data;
  String template;
  int accent;
  DateTime updated;
  factory Resume.empty() => Resume(
    id: const Uuid().v4(),
    title: 'Untitled resume',
    data: {for (final k in resumeFields.keys) k: ''},
  );
  factory Resume.fromJson(Map<String, dynamic> json) => Resume(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'My resume',
    data: {
      for (final k in resumeFields.keys)
        k: '${(json['data'] as Map?)?[k] ?? ''}',
    },
    template: ['modern', 'classic', 'minimal'].contains(json['template'])
        ? json['template'] as String
        : 'modern',
    accent: json['accent'] as int? ?? 0xff245bdb,
    updated: DateTime.tryParse('${json['updated']}'),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'data': data,
    'template': template,
    'accent': accent,
    'updated': updated.toIso8601String(),
  };
  Resume duplicate() => Resume(
    id: const Uuid().v4(),
    title: '${title.length > 73 ? title.substring(0, 73) : title} (copy)',
    data: Map.of(data),
    template: template,
    accent: accent,
  );
  int get completeness {
    const keys = [
      'name',
      'role',
      'email',
      'summary',
      'skills',
      'experience',
      'education',
    ];
    return (keys.where((k) => data[k]!.trim().isNotEmpty).length /
            keys.length *
            100)
        .round();
  }

  List<String> get checks => [
    if (data['name']!.trim().isEmpty) 'Add your full name.',
    if (data['email']!.trim().isEmpty) 'Add a contact email.',
    if (data['summary']!.trim().isEmpty) 'Add a focused professional summary.',
    if (data['experience']!.trim().isEmpty)
      'Add experience, internships or volunteer work.',
    if (data['skills']!.trim().isEmpty)
      'Add skills relevant to your target role.',
    if (data['education']!.trim().isEmpty) 'Add your education.',
    if (data['summary']!.length > 900)
      'Shorten your summary for easier scanning.',
  ];
}
