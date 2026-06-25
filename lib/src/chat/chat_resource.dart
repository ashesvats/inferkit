import '../client.dart';
import 'completions_resource.dart';

class ChatResource {
  ChatResource(InferKitClient client)
    : completions = ChatCompletionsResource(client);

  final ChatCompletionsResource completions;
}
