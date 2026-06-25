import '../chat/reasoning_config.dart';
import 'http_transport.dart';

class ClientConfig {
  const ClientConfig({
    required this.baseUrl,
    this.apiKey = '',
    this.timeout = const Duration(minutes: 10),
    this.headers = const {},
    this.reasoning = ReasoningConfig.defaults,
    this.transport,
  });

  final String baseUrl;
  final String apiKey;
  final Duration timeout;
  final Map<String, String> headers;
  final ReasoningConfig reasoning;
  final HttpTransport? transport;
}
