import 'package:flutter_test/flutter_test.dart';
import 'package:resumecraft_ai/resume.dart';
import 'package:resumecraft_ai/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('backup round trip preserves user data and template', () {
    final original = Resume.empty()
      ..title = 'Flutter role'
      ..template = 'classic';
    original.data['name'] = 'Saadi';
    original.data['experience'] = 'Flutter intern\n- Built a REST API app.';
    final restored = Resume.fromJson(original.toJson());
    expect(restored.data, original.data);
    expect(restored.template, 'classic');
    expect(restored.id, original.id);
  });
  test('duplicates do not share mutable content', () {
    final original = Resume.empty();
    original.data['name'] = 'Original';
    final copy = original.duplicate();
    copy.data['name'] = 'Changed';
    expect(original.data['name'], 'Original');
    expect(copy.id, isNot(original.id));
  });
  test('completeness only counts non-empty essential sections', () {
    final r = Resume.empty();
    expect(r.completeness, 0);
    for (final k in [
      'name',
      'role',
      'email',
      'summary',
      'skills',
      'experience',
      'education',
    ]) {
      r.data[k] = 'Value';
    }
    expect(r.completeness, 100);
    expect(r.checks, isEmpty);
  });
  test('all templates create PDFs with bundled fonts', () async {
    final r = Resume.empty();
    r.data['name'] = 'Saadi';
    r.data['summary'] = 'Flutter developer';
    for (final template in ['modern', 'classic', 'minimal']) {
      r.template = template;
      final bytes = await ResumePdf.build(r);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    }
  });
  test(
    'long experience content paginates without an oversized text box',
    () async {
      final r = Resume.empty();
      r.data['name'] = 'Long resume';
      r.data['experience'] = List.filled(
        120,
        'Delivered a Flutter app with API integration and responsive layouts.',
      ).join('\n');
      final bytes = await ResumePdf.build(r);
      expect(bytes.length, greaterThan(1000));
    },
  );
}
