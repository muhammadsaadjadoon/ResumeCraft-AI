import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'resume.dart';

class AiFailure implements Exception {
  const AiFailure(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class AiService {
  AiService(this.cloudReady, {http.Client? client, String? baseUrl})
    : _client = client,
      _baseUrl = baseUrl ?? Config.api;
  final bool cloudReady;
  final http.Client? _client;
  final String _baseUrl;

  Future<Map<String, String>> _headers(bool refresh) async {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const AiFailure(
        'AI server is not configured. Set API_BASE_URL and restart the app.',
      );
    }
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cloudReady) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const AiFailure('Sign in from Account to use AI tools.');
      }
      try {
        final token = await user.getIdToken(refresh);
        if (token == null || token.isEmpty) {
          throw const AiFailure(
            'Could not refresh your session. Sign in again.',
          );
        }
        headers['Authorization'] = 'Bearer $token';
      } on FirebaseAuthException {
        throw const AiFailure(
          'Could not refresh your session. Check your connection or sign in again.',
        );
      }
    }
    return headers;
  }

  Uri _uri(String path) =>
      Uri.parse('${_baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Map<String, dynamic> _decode(http.Response response) {
    Object? body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw const AiFailure(
        'The server returned an unreadable response. Check the backend is running.',
      );
    }
    if (response.statusCode != 200) {
      final detail = body is Map ? body['detail'] : null;
      throw AiFailure(
        detail is String
            ? detail
            : 'The request was rejected (${response.statusCode}). Check your input and try again.',
        response.statusCode,
      );
    }
    if (body is! Map<String, dynamic> ||
        body['resume'] is! Map ||
        body['suggestions'] is! List) {
      throw const AiFailure(
        'AI returned an incomplete response. Your draft has not changed.',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> _send(
    String path,
    Map<String, dynamic>? payload, {
    Uint8List? pdf,
  }) async {
    final client = _client ?? http.Client();
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final headers = await _headers(attempt > 0);
        http.Response response;
        if (pdf != null) {
          headers.remove('Content-Type');
          final request = http.MultipartRequest('POST', _uri(path))
            ..headers.addAll(headers)
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                pdf,
                filename: 'profile.pdf',
              ),
            );
          response = await (() async {
            return http.Response.fromStream(await client.send(request));
          })().timeout(const Duration(seconds: 90));
        } else {
          response = await client
              .post(_uri(path), headers: headers, body: jsonEncode(payload))
              .timeout(const Duration(seconds: 90));
        }
        if (response.statusCode == 401 && cloudReady && attempt == 0) {
          continue;
        }
        return _decode(response);
      }
      throw const AiFailure('Could not verify your session. Sign in again.');
    } on TimeoutException {
      throw const AiFailure(
        'AI request timed out. Your draft is safe. Check the server and retry.',
      );
    } on http.ClientException {
      throw const AiFailure(
        'Cannot reach the AI server. Keep the backend running and check API_BASE_URL.',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<Map<String, dynamic>> generate(
    Resume resume,
    String job,
    String mode,
  ) => _send('/v1/assist', {'resume': resume.data, 'job': job, 'mode': mode});
  Future<Map<String, dynamic>> create(
    Resume details,
    String facts,
    String job,
  ) =>
      _send('/v1/create', {'resume': details.data, 'facts': facts, 'job': job});
  Future<Map<String, dynamic>> importProfile(String text) =>
      _send('/v1/import', {'text': text});
  Future<Map<String, dynamic>> importPdf(Uint8List bytes) =>
      _send('/v1/import-pdf', null, pdf: bytes);
}
