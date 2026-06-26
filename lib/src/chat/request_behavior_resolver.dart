import '../core/client_config.dart';
import 'completion_request.dart';
import 'content_part.dart';
import 'model_profile.dart';
import 'reasoning_config.dart';

ModelDescriptor describeModelBehavior(ClientConfig config, String modelId) {
  final matchedProfile = _matchProfile(config.modelProfiles, modelId);
  final profile = matchedProfile ?? ModelProfile.openAICompatible;
  return ModelDescriptor(
    modelId: modelId,
    profile: profile,
    matchedProfile: matchedProfile,
    reasoning: matchedProfile?.reasoning ?? config.reasoning,
  );
}

ResolvedRequestBehavior describeRequestBehavior(
  ClientConfig config,
  ChatCompletionRequest request,
) {
  final model = describeModelBehavior(config, request.model);
  final effectiveThinking = _resolveEffectiveThinking(
    model.profile.thinking,
    request.thinking,
  );
  final thinkingPrefix = _thinkingPrefix(
    model.profile.thinking,
    request.thinking,
    effectiveThinking,
  );

  final messageJson = <Map<String, dynamic>>[];
  final requestModalities = <ContentPartKind>[];
  var reordersContentParts = false;
  var prefixedSystemMessage = false;

  for (final message in request.messages) {
    final orderedParts = _orderedParts(
      message.contentParts,
      model.profile.contentPartOrdering,
    );
    if (!reordersContentParts &&
        message.contentParts != null &&
        !_sameParts(message.contentParts!, orderedParts)) {
      reordersContentParts = true;
    }
    if (message.content is String) {
      if (!requestModalities.contains(ContentPartKind.text)) {
        requestModalities.add(ContentPartKind.text);
      }
    } else {
      for (final part in orderedParts) {
        if (!requestModalities.contains(part.kind)) {
          requestModalities.add(part.kind);
        }
      }
    }
    final json = message.toJson(
      contentPartsOverride:
          message.contentParts != null &&
                  !_sameParts(message.contentParts!, orderedParts)
              ? orderedParts
              : null,
    );
    if (!prefixedSystemMessage &&
        thinkingPrefix != null &&
        message.role == 'system' &&
        message.content is String) {
      json['content'] = '$thinkingPrefix${message.content as String}';
      prefixedSystemMessage = true;
    }
    messageJson.add(json);
  }

  if (!prefixedSystemMessage && thinkingPrefix != null) {
    messageJson.insert(0, {'role': 'system', 'content': thinkingPrefix});
  }

  return ResolvedRequestBehavior(
    descriptor: RequestDescriptor(
      modelId: request.model,
      profile: model.profile,
      matchedProfile: model.matchedProfile,
      reasoning: model.reasoning,
      requestedThinking: request.thinking,
      effectiveThinking: effectiveThinking,
      requestModalities: List<ContentPartKind>.unmodifiable(requestModalities),
      reordersContentParts: reordersContentParts,
    ),
    messageJson: List<Map<String, dynamic>>.unmodifiable(messageJson),
  );
}

class ResolvedRequestBehavior {
  const ResolvedRequestBehavior({
    required this.descriptor,
    required this.messageJson,
  });

  final RequestDescriptor descriptor;
  final List<Map<String, dynamic>> messageJson;

  ReasoningConfig get reasoning => descriptor.reasoning;

  Map<String, dynamic> toJson(
    ChatCompletionRequest request, {
    required bool stream,
  }) => {
    'model': request.model,
    'messages': messageJson,
    'stream': stream,
    if (request.temperature != null) 'temperature': request.temperature,
    if (stream && request.includeUsage)
      'stream_options': {'include_usage': true},
    if (request.tools.isNotEmpty)
      'tools': [for (final tool in request.tools) tool.toJson()],
    if (request.toolChoice != null) 'tool_choice': request.toolChoice!.toJson(),
  };
}

ModelProfile? _matchProfile(
  List<ModelProfileBinding> bindings,
  String modelId,
) {
  for (final binding in bindings) {
    if (binding.match.matches(modelId)) return binding.profile;
  }
  return null;
}

EffectiveThinkingState _resolveEffectiveThinking(
  ThinkingBehavior behavior,
  ThinkingMode mode,
) {
  if (!behavior.supported) return EffectiveThinkingState.unsupported;
  switch (mode) {
    case ThinkingMode.profileDefault:
      return behavior.defaultEnabled
          ? EffectiveThinkingState.enabled
          : EffectiveThinkingState.disabled;
    case ThinkingMode.enabled:
      if (behavior.defaultEnabled || behavior.canEnable) {
        return EffectiveThinkingState.enabled;
      }
      return EffectiveThinkingState.disabled;
    case ThinkingMode.disabled:
      if (!behavior.defaultEnabled || behavior.canDisable) {
        return EffectiveThinkingState.disabled;
      }
      return EffectiveThinkingState.enabled;
  }
}

String? _thinkingPrefix(
  ThinkingBehavior behavior,
  ThinkingMode requested,
  EffectiveThinkingState effective,
) {
  if (behavior.controlMethod != ThinkingControlMethod.systemMessagePrefix) {
    return null;
  }
  return switch (requested) {
    ThinkingMode.profileDefault => null,
    ThinkingMode.enabled
        when effective == EffectiveThinkingState.enabled &&
            !behavior.defaultEnabled =>
      behavior.enabledSystemPromptPrefix,
    ThinkingMode.disabled
        when effective == EffectiveThinkingState.disabled &&
            behavior.defaultEnabled =>
      behavior.disabledSystemPromptPrefix,
    _ => null,
  };
}

List<ContentPart> _orderedParts(
  List<ContentPart>? parts,
  ContentPartOrdering ordering,
) {
  if (parts == null) return const [];
  return ordering.apply(parts);
}

bool _sameParts(List<ContentPart> left, List<ContentPart> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (!identical(left[i], right[i])) return false;
  }
  return true;
}
