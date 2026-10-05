import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resumecraft_ai/ai_service.dart';
import 'package:resumecraft_ai/resume.dart';

void main() {
  test(
    'AI create sends facts and returns a draft without mutating input',
    () async {
      final resume = Resume.empty();
      resume.data['name'] = 'Original';
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/create');
        expect(jsonDecode(request.body)['facts'], 'Verified background');
        return http.Response(
          jsonEncode({
            'resume': {'name': 'Original', 'summary': 'Draft'},
            'suggestions': ['Review facts'],
          }),
          200,
        );
      });
      addTearDown(client.close);
      final service = AiService(
        false,
        client: client,
        baseUrl: 'http://localhost:8081',
      );
      final result = await service.create(
        resume,
        'Verified background',
        'Target role',
      );
      expect(result['resume']['summary'], 'Draft');
      expect(resume.data['summary'], '');
    },
  );
  test('server configuration error keeps its actionable message', () async {
    final client = MockClient(
      (_) async =>
          http.Response(jsonEncode({'detail': 'Set FIREBASE_PROJECT_ID'}), 503),
    );
    addTearDown(client.close);
    expect(
      AiService(
        false,
        client: client,
        baseUrl: 'http://localhost:8081',
      ).generate(Resume.empty(), '', 'rewrite'),
      throwsA(
        isA<AiFailure>().having(
          (e) => e.message,
          'message',
          'Set FIREBASE_PROJECT_ID',
        ),
      ),
    );
  });
  test('malformed successful output is rejected', () async {
    final client = MockClient((_) async => http.Response('{}', 200));
    addTearDown(client.close);
    expect(
      AiService(
        false,
        client: client,
        baseUrl: 'http://localhost:8081',
      ).generate(Resume.empty(), '', 'rewrite'),
      throwsA(isA<AiFailure>()),
    );
  });
}
