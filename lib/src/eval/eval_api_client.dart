// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The result of a single skill-trigger check via the Anthropic Messages API.
class TriggerCheckResult {
  /// Creates a trigger check result.
  const TriggerCheckResult({required this.triggered, this.error});

  /// Whether the skill was selected by the model for this query.
  final bool triggered;

  /// Non-null when the API call failed (network error, non-200 response).
  final String? error;

  /// True when [error] is non-null.
  bool get hasError => error != null;
}

/// Abstract API client so the runner can be tested with a mock.
abstract class EvalApiClient {
  /// Sends [query] to the model with [skillName]+[skillDescription] offered as
  /// a tool and returns whether the model chose to invoke that tool.
  ///
  /// [apiKey] is the Anthropic API key.
  /// [model] is the model identifier (e.g. "claude-haiku-4-5-20251001").
  Future<TriggerCheckResult> checkTrigger({
    required String apiKey,
    required String model,
    required String skillName,
    required String skillDescription,
    required String query,
  });
}

/// Live implementation that calls the Anthropic Messages API.
class AnthropicEvalClient implements EvalApiClient {
  /// Creates a const client instance.
  const AnthropicEvalClient();

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _anthropicVersion = '2023-06-01';

  @override
  Future<TriggerCheckResult> checkTrigger({
    required String apiKey,
    required String model,
    required String skillName,
    required String skillDescription,
    required String query,
  }) async {
    final payload = {
      'model': model,
      'max_tokens': 64,
      'tools': [
        {
          'name': _sanitiseName(skillName),
          'description': skillDescription,
          'input_schema': {'type': 'object', 'properties': {}},
        }
      ],
      'tool_choice': {'type': 'auto'},
      'messages': [
        {'role': 'user', 'content': query},
      ],
    };

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client
          .postUrl(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 60));
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set('x-api-key', apiKey)
        ..set('anthropic-version', _anthropicVersion);
      final body = utf8.encode(jsonEncode(payload));
      request.contentLength = body.length;
      request.add(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 429) {
        return const TriggerCheckResult(
            triggered: false, error: 'rate-limited (429)');
      }
      if (response.statusCode != 200) {
        String msg;
        try {
          final err = jsonDecode(responseBody) as Map<String, dynamic>;
          msg = (err['error'] as Map?)?['message'] as String? ??
              'HTTP ${response.statusCode}';
        } catch (_) {
          msg = 'HTTP ${response.statusCode}';
        }
        return TriggerCheckResult(triggered: false, error: msg);
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      return TriggerCheckResult(triggered: _didTrigger(data, skillName));
    } on SocketException catch (e) {
      return TriggerCheckResult(triggered: false, error: 'network error: $e');
    } on TimeoutException catch (_) {
      return TriggerCheckResult(triggered: false, error: 'request timed out');
    } on HttpException catch (e) {
      return TriggerCheckResult(triggered: false, error: 'HTTP error: $e');
    } finally {
      client.close();
    }
  }

  static bool _didTrigger(Map<String, dynamic> response, String skillName) {
    if (response['stop_reason'] == 'tool_use') return true;
    final content = response['content'];
    if (content is! List) return false;
    final sanitised = _sanitiseName(skillName);
    return content.any((block) =>
        block is Map &&
        block['type'] == 'tool_use' &&
        block['name'] == sanitised);
  }

  /// The Anthropic tool name must match `^[a-zA-Z0-9_-]{1,64}$`.
  static String _sanitiseName(String name) => name
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
      .substring(0, name.length.clamp(0, 64));
}
