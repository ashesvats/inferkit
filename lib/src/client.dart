import 'chat/chat_resource.dart';
import 'core/client_config.dart';
import 'core/http_transport.dart';
import 'models/models_resource.dart';

class InferKitClient {
  InferKitClient({required ClientConfig config})
    : config = config,
      _ownsTransport = config.transport == null,
      transport = config.transport ?? HttpTransport.client() {
    chat = ChatResource(this);
    models = ModelsResource(this);
  }

  final ClientConfig config;
  final HttpTransport transport;
  final bool _ownsTransport;

  late final ChatResource chat;
  late final ModelsResource models;

  Uri endpoint(String path) {
    final root = config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final versioned = root.endsWith('/v1') ? root : '$root/v1';
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$versioned$normalizedPath');
  }

  Map<String, String> headers() => {
    'Content-Type': 'application/json',
    ...config.headers,
    if (config.apiKey.trim().isNotEmpty)
      'Authorization': 'Bearer ${config.apiKey.trim()}',
  };

  void dispose() {
    if (_ownsTransport) transport.close();
  }
}
