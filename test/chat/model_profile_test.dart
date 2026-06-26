import 'dart:convert';

import 'package:inferkit/inferkit.dart';
import 'package:test/test.dart';

import '../support/fake_transport.dart';

void main() {
  test('matches exact and prefix model profile bindings', () {
    const exactProfile = ModelProfile(id: 'exact-profile');
    final gemmaProfile = ModelProfile.gemma(id: 'gemma-profile');
    final client = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        modelProfiles: [
          const ModelProfileBinding(
            match: ModelMatch.exact('gemma-3n-e4b-it'),
            profile: exactProfile,
          ),
          ModelProfileBinding(
            match: const ModelMatch.prefix('gemma'),
            profile: gemmaProfile,
          ),
        ],
      ),
    );

    final exactDescriptor = client.describeModel('gemma-3n-e4b-it');
    final prefixDescriptor = client.describeModel('gemma-3n-e2b-it');

    expect(exactDescriptor.matchedProfile?.id, 'exact-profile');
    expect(prefixDescriptor.matchedProfile?.id, 'gemma-profile');
  });

  test('uses the openai-compatible fallback for unmatched models', () async {
    final transport = FakeTransport((request) {
      final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
      expect(body, {
        'model': 'llama',
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
        'stream': false,
      });
      return jsonResponse({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'hi'},
          },
        ],
      });
    });
    final client = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        modelProfiles: const [
          ModelProfileBinding(
            match: ModelMatch.prefix('gemma'),
            profile: ModelProfile(id: 'never-used'),
          ),
        ],
        transport: transport,
      ),
    );

    final descriptor = client.describeModel('llama');
    final requestDescriptor = client.describeRequest(
      ChatCompletionRequest(
        model: 'llama',
        messages: [ChatMessage.user('hello')],
        thinking: ThinkingMode.enabled,
      ),
    );
    final response = await client.chat.completions.create(
      ChatCompletionRequest(
        model: 'llama',
        messages: [ChatMessage.user('hello')],
      ),
    );

    expect(descriptor.matchedProfile, isNull);
    expect(descriptor.profile.id, 'openai-compatible');
    expect(descriptor.thinking.supported, isFalse);
    expect(
      requestDescriptor.effectiveThinking,
      EffectiveThinkingState.unsupported,
    );
    expect(response.text, 'hi');
  });

  test('injects an enabled thinking prefix when the profile opts in', () async {
    final transport = FakeTransport((request) {
      final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
      expect(body['messages'], [
        {'role': 'system', 'content': 'ENABLE_THINKING\n'},
        {'role': 'user', 'content': 'hello'},
      ]);
      return jsonResponse({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'hi'},
          },
        ],
      });
    });
    final client = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        transport: transport,
        modelProfiles: const [
          ModelProfileBinding(
            match: ModelMatch.exact('gemma-local'),
            profile: ModelProfile(
              id: 'thinker',
              thinking: ThinkingBehavior.systemMessagePrefix(
                defaultEnabled: false,
                enabledSystemPromptPrefix: 'ENABLE_THINKING\n',
                disabledSystemPromptPrefix: 'DISABLE_THINKING\n',
              ),
            ),
          ),
        ],
      ),
    );

    await client.chat.completions.create(
      ChatCompletionRequest(
        model: 'gemma-local',
        thinking: ThinkingMode.enabled,
        messages: [ChatMessage.user('hello')],
      ),
    );
  });

  test(
    'injects a disabled thinking prefix into the first system message',
    () async {
      final transport = FakeTransport((request) {
        final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
        expect(body['messages'], [
          {'role': 'system', 'content': 'NO_THINK\nBe terse.'},
          {'role': 'user', 'content': 'hello'},
        ]);
        return jsonResponse({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': 'ok'},
            },
          ],
        });
      });
      final client = InferKitClient(
        config: ClientConfig(
          baseUrl: 'http://localhost:8080',
          transport: transport,
          modelProfiles: const [
            ModelProfileBinding(
              match: ModelMatch.exact('gemma-local'),
              profile: ModelProfile(
                id: 'thinker',
                thinking: ThinkingBehavior.systemMessagePrefix(
                  defaultEnabled: true,
                  enabledSystemPromptPrefix: 'YES_THINK\n',
                  disabledSystemPromptPrefix: 'NO_THINK\n',
                ),
              ),
            ),
          ],
        ),
      );

      await client.chat.completions.create(
        ChatCompletionRequest(
          model: 'gemma-local',
          thinking: ThinkingMode.disabled,
          messages: [
            ChatMessage.system('Be terse.'),
            ChatMessage.user('hello'),
          ],
        ),
      );
    },
  );

  test('reorders multimodal content parts for gemma-style profiles', () async {
    final transport = FakeTransport((request) {
      final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
      final content =
          ((body['messages'] as List).single as Map<String, dynamic>)['content']
              as List;
      expect(
        content.map((part) => (part as Map<String, dynamic>)['type']).toList(),
        ['image_url', 'text', 'input_audio'],
      );
      return jsonResponse({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'done'},
          },
        ],
      });
    });
    final client = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        transport: transport,
        modelProfiles: [
          ModelProfileBinding(
            match: const ModelMatch.prefix('gemma'),
            profile: ModelProfile.gemma(),
          ),
        ],
      ),
    );

    await client.chat.completions.create(
      ChatCompletionRequest(
        model: 'gemma-3n',
        messages: [
          ChatMessage.user([
            const TextPart('describe the scene'),
            const AudioPart.base64(data: 'YWJj', format: 'wav'),
            const ImagePart.dataUrl('data:image/png;base64,abc'),
          ]),
        ],
      ),
    );
  });

  test('describeModel reports thinking, reasoning, and modalities', () {
    final client = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        modelProfiles: [
          ModelProfileBinding(
            match: const ModelMatch.prefix('gemma'),
            profile: ModelProfile.gemma(id: 'gemma-ui'),
          ),
        ],
      ),
    );

    final descriptor = client.describeModel('gemma-3n-e2b-it');

    expect(descriptor.matchedProfile?.id, 'gemma-ui');
    expect(descriptor.thinking.supported, isTrue);
    expect(descriptor.thinking.canToggle, isTrue);
    expect(
      descriptor.thinking.controlMethod,
      ThinkingControlMethod.systemMessagePrefix,
    );
    expect(descriptor.reasoningExtractionEnabled, isTrue);
    expect(descriptor.supportedModalities, [
      ContentPartKind.image,
      ContentPartKind.text,
      ContentPartKind.audio,
    ]);
    expect(descriptor.contentPartOrdering.priority, [
      ContentPartKind.image,
      ContentPartKind.text,
      ContentPartKind.audio,
    ]);
  });

  test('describeRequest reports effective thinking and ordering behavior', () {
    final client = InferKitClient(
      config: ClientConfig(
        baseUrl: 'http://localhost:8080',
        modelProfiles: const [
          ModelProfileBinding(
            match: ModelMatch.exact('gemma-local'),
            profile: ModelProfile(
              id: 'request-profile',
              thinking: ThinkingBehavior.systemMessagePrefix(
                defaultEnabled: true,
                disabledSystemPromptPrefix: 'NO_THINK\n',
              ),
              reasoning: ReasoningConfig.none,
              supportedModalities: [
                ContentPartKind.image,
                ContentPartKind.text,
                ContentPartKind.audio,
              ],
              contentPartOrdering: ContentPartOrdering.priority([
                ContentPartKind.image,
                ContentPartKind.text,
                ContentPartKind.audio,
              ]),
            ),
          ),
        ],
      ),
    );

    final descriptor = client.describeRequest(
      ChatCompletionRequest(
        model: 'gemma-local',
        thinking: ThinkingMode.disabled,
        messages: [
          ChatMessage.user([
            const TextPart('hello'),
            const AudioPart.base64(data: 'YWJj', format: 'wav'),
            const ImagePart.dataUrl('data:image/png;base64,abc'),
          ]),
        ],
      ),
    );

    expect(descriptor.matchedProfile?.id, 'request-profile');
    expect(descriptor.effectiveThinking, EffectiveThinkingState.disabled);
    expect(descriptor.reasoningExtractionEnabled, isFalse);
    expect(descriptor.requestModalities, [
      ContentPartKind.image,
      ContentPartKind.text,
      ContentPartKind.audio,
    ]);
    expect(descriptor.reordersContentParts, isTrue);
    expect(descriptor.contentPartOrdering.priority, [
      ContentPartKind.image,
      ContentPartKind.text,
      ContentPartKind.audio,
    ]);
  });

  test('request serialization stays compatible without profile behavior', () {
    final request = ChatCompletionRequest(
      model: 'llama',
      messages: [ChatMessage.user('hello')],
    );

    expect(request.toJson(stream: false), {
      'model': 'llama',
      'messages': [
        {'role': 'user', 'content': 'hello'},
      ],
      'stream': false,
    });
  });
}
