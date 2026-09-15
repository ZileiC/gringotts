import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_settings.dart';

/// Error taxonomy for one OpenAI-compatible request (TICKETS_M2A T-15):
/// 未配置 / 401 / 超时 / 网络 / 429 / 空回复.
enum AiErrorKind {
  notConfigured,
  unauthorized,
  timeout,
  network,
  rateLimited,
  emptyReply,
}

/// Outcome of the one-shot probe.
class AiTestResult {
  const AiTestResult._(this.ok, this.latencyMs, this.error);

  const AiTestResult.ok(int latencyMs) : this._(true, latencyMs, null);

  const AiTestResult.failed(AiErrorKind error) : this._(false, null, error);

  final bool ok;
  final int? latencyMs;
  final AiErrorKind? error;
}

/// One raw HTTP answer (status + text body).
class AiHttpResponse {
  const AiHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

/// Transport seam: the real implementation talks to dart:io, tests inject a
/// fake. Failures are reported as [AiTransportFailure] so classification never
/// depends on an exception message (which could echo request material).
abstract interface class AiTransport {
  Future<AiHttpResponse> send({
    required Uri uri,
    required String apiKey,
    required String body,
    required Duration timeout,
  });
}

class AiTransportFailure implements Exception {
  const AiTransportFailure(this.kind);

  final AiErrorKind kind;
}

/// OpenAI-compatible `chat/completions` transport (dart:io).
class HttpAiTransport implements AiTransport {
  const HttpAiTransport();

  @override
  Future<AiHttpResponse> send({
    required Uri uri,
    required String apiKey,
    required String body,
    required Duration timeout,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      // The key only ever lives in the request header; it is never written to
      // a log, a file, an error message or a returned value.
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.write(body);
      final response = await request.close().timeout(timeout);
      final text = await response.transform(utf8.decoder).join().timeout(timeout);
      return AiHttpResponse(response.statusCode, text);
    } on TimeoutException {
      throw const AiTransportFailure(AiErrorKind.timeout);
    } on SocketException {
      throw const AiTransportFailure(AiErrorKind.network);
    } on HandshakeException {
      throw const AiTransportFailure(AiErrorKind.network);
    } on HttpException {
      throw const AiTransportFailure(AiErrorKind.network);
    } on FormatException {
      throw const AiTransportFailure(AiErrorKind.network);
    } finally {
      client.close(force: true);
    }
  }
}

/// One OpenAI-compatible client shared by the config page's probe and (later,
/// T-16) the analysis request.
class AiClient {
  AiClient({AiTransport transport = const HttpAiTransport()})
      : _transport = transport;

  /// Default one-request deadline (DESIGN_AI.md section 5 item 4).
  static const Duration defaultTimeout =
      Duration(seconds: aiDefaultTimeoutSeconds);

  final AiTransport _transport;

  /// `baseURL` + `/chat/completions`: the OpenAI-compatible endpoint, no
  /// vendor SDK (DESIGN_AI.md section 12).
  static Uri endpointFor(String baseUrl) {
    final trimmed = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$trimmed/chat/completions');
  }

  /// One minimal probe: a single `chat/completions` call with `max_tokens: 1`
  /// and a one-word prompt - never the analysis payload - so pressing
  /// 测试连接 cannot spend the user's analysis quota.
  Future<AiTestResult> testConnection({
    required AiSettings settings,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty || settings.baseUrl.trim().isEmpty) {
      return const AiTestResult.failed(AiErrorKind.notConfigured);
    }
    final Duration timeout = settings.timeoutSeconds <= 0
        ? defaultTimeout
        : Duration(seconds: settings.timeoutSeconds);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _transport.send(
        uri: endpointFor(settings.baseUrl),
        apiKey: apiKey,
        body: jsonEncode(<String, dynamic>{
          'model': settings.model,
          'messages': <Map<String, String>>[
            <String, String>{'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 1,
          'temperature': 0,
          'stream': false,
        }),
        timeout: timeout,
      );
      stopwatch.stop();
      final statusError = _errorForStatus(response.statusCode);
      if (statusError != null) return AiTestResult.failed(statusError);
      if (!_hasReplyContent(response.body)) {
        return const AiTestResult.failed(AiErrorKind.emptyReply);
      }
      return AiTestResult.ok(stopwatch.elapsedMilliseconds);
    } on AiTransportFailure catch (failure) {
      return AiTestResult.failed(failure.kind);
    } on FormatException {
      return const AiTestResult.failed(AiErrorKind.network);
    } catch (_) {
      // Never surface the raw error: a message could carry request material.
      // The key itself is only ever in the header, but the contract refuses to
      // leak anything.
      return const AiTestResult.failed(AiErrorKind.network);
    }
  }

  static AiErrorKind? _errorForStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return null;
    if (statusCode == 401 || statusCode == 403) return AiErrorKind.unauthorized;
    if (statusCode == 429) return AiErrorKind.rateLimited;
    return AiErrorKind.network;
  }

  /// A 2xx answer is only "usable" when it carries non-empty assistant text.
  static bool _hasReplyContent(String body) {
    if (body.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return false;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return false;
      final first = choices.first;
      if (first is! Map) return false;
      final message = first['message'];
      final content = message is Map ? message['content'] : null;
      return content is String && content.trim().isNotEmpty;
    } on FormatException {
      return false;
    }
  }
}
