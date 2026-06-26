import 'content_part.dart';
import 'reasoning_config.dart';

enum ThinkingMode { profileDefault, enabled, disabled }

enum EffectiveThinkingState { unsupported, enabled, disabled }

enum ThinkingControlMethod { none, systemMessagePrefix }

class ModelMatch {
  const ModelMatch.exact(this.pattern) : _kind = _ModelMatchKind.exact;

  const ModelMatch.prefix(this.pattern) : _kind = _ModelMatchKind.prefix;

  final String pattern;
  final _ModelMatchKind _kind;

  bool matches(String modelId) => switch (_kind) {
    _ModelMatchKind.exact => modelId == pattern,
    _ModelMatchKind.prefix => modelId.startsWith(pattern),
  };
}

enum _ModelMatchKind { exact, prefix }

class ModelProfileBinding {
  const ModelProfileBinding({required this.match, required this.profile});

  final ModelMatch match;
  final ModelProfile profile;
}

class ThinkingBehavior {
  const ThinkingBehavior({
    required this.supported,
    required this.defaultEnabled,
    required this.controlMethod,
    this.enabledSystemPromptPrefix,
    this.disabledSystemPromptPrefix,
  });

  const ThinkingBehavior.unsupported()
    : supported = false,
      defaultEnabled = false,
      controlMethod = ThinkingControlMethod.none,
      enabledSystemPromptPrefix = null,
      disabledSystemPromptPrefix = null;

  const ThinkingBehavior.systemMessagePrefix({
    required this.defaultEnabled,
    this.enabledSystemPromptPrefix,
    this.disabledSystemPromptPrefix,
  }) : supported = true,
       controlMethod = ThinkingControlMethod.systemMessagePrefix;

  final bool supported;
  final bool defaultEnabled;
  final ThinkingControlMethod controlMethod;
  final String? enabledSystemPromptPrefix;
  final String? disabledSystemPromptPrefix;

  bool get canToggle => canEnable && canDisable;

  bool get canEnable =>
      supported &&
      (defaultEnabled || _hasSystemPromptPrefix(enabledSystemPromptPrefix));

  bool get canDisable =>
      supported &&
      (!defaultEnabled || _hasSystemPromptPrefix(disabledSystemPromptPrefix));
}

class ContentPartOrdering {
  const ContentPartOrdering.preserve() : priority = const [];

  const ContentPartOrdering.priority(this.priority);

  final List<ContentPartKind> priority;

  bool get preservesInputOrder => priority.isEmpty;

  List<ContentPart> apply(List<ContentPart> parts) {
    if (priority.isEmpty || parts.length < 2) return parts;
    final priorityByKind = <ContentPartKind, int>{
      for (var i = 0; i < priority.length; i++) priority[i]: i,
    };
    final indexed =
        parts.indexed
            .map(
              (entry) => _IndexedContentPart(
                index: entry.$1,
                part: entry.$2,
                priority: priorityByKind[entry.$2.kind] ?? priority.length,
              ),
            )
            .toList()
          ..sort((a, b) {
            final priorityCompare = a.priority.compareTo(b.priority);
            if (priorityCompare != 0) return priorityCompare;
            return a.index.compareTo(b.index);
          });
    return [for (final entry in indexed) entry.part];
  }
}

class ModelProfile {
  const ModelProfile({
    required this.id,
    this.label,
    this.thinking = const ThinkingBehavior.unsupported(),
    this.reasoning,
    this.supportedModalities = const [ContentPartKind.text],
    this.contentPartOrdering = const ContentPartOrdering.preserve(),
  });

  final String id;
  final String? label;
  final ThinkingBehavior thinking;
  final ReasoningConfig? reasoning;
  final List<ContentPartKind> supportedModalities;
  final ContentPartOrdering contentPartOrdering;

  static const openAICompatible = ModelProfile(
    id: 'openai-compatible',
    label: 'OpenAI-compatible',
  );

  factory ModelProfile.gemma({
    String id = 'gemma-style',
    String? label,
    ThinkingBehavior thinking = const ThinkingBehavior.systemMessagePrefix(
      defaultEnabled: false,
      enabledSystemPromptPrefix: '<start_of_image_reasoning>\n',
      disabledSystemPromptPrefix: '<start_of_text_response>\n',
    ),
    ReasoningConfig? reasoning = ReasoningConfig.defaults,
  }) {
    return ModelProfile(
      id: id,
      label: label ?? 'Gemma-style',
      thinking: thinking,
      reasoning: reasoning,
      supportedModalities: const [
        ContentPartKind.image,
        ContentPartKind.text,
        ContentPartKind.audio,
      ],
      contentPartOrdering: const ContentPartOrdering.priority([
        ContentPartKind.image,
        ContentPartKind.text,
        ContentPartKind.audio,
      ]),
    );
  }
}

class ModelDescriptor {
  const ModelDescriptor({
    required this.modelId,
    required this.profile,
    required this.reasoning,
    this.matchedProfile,
  });

  final String modelId;
  final ModelProfile profile;
  final ModelProfile? matchedProfile;
  final ReasoningConfig reasoning;

  ThinkingBehavior get thinking => profile.thinking;

  List<ContentPartKind> get supportedModalities => profile.supportedModalities;

  ContentPartOrdering get contentPartOrdering => profile.contentPartOrdering;

  bool get reasoningExtractionEnabled => reasoning.emitEvents;
}

class RequestDescriptor {
  const RequestDescriptor({
    required this.modelId,
    required this.profile,
    required this.reasoning,
    required this.requestedThinking,
    required this.effectiveThinking,
    required this.requestModalities,
    required this.reordersContentParts,
    this.matchedProfile,
  });

  final String modelId;
  final ModelProfile profile;
  final ModelProfile? matchedProfile;
  final ReasoningConfig reasoning;
  final ThinkingMode requestedThinking;
  final EffectiveThinkingState effectiveThinking;
  final List<ContentPartKind> requestModalities;
  final bool reordersContentParts;

  ThinkingBehavior get thinking => profile.thinking;

  ContentPartOrdering get contentPartOrdering => profile.contentPartOrdering;

  bool get reasoningExtractionEnabled => reasoning.emitEvents;
}

class _IndexedContentPart {
  const _IndexedContentPart({
    required this.index,
    required this.part,
    required this.priority,
  });

  final int index;
  final ContentPart part;
  final int priority;
}

bool _hasSystemPromptPrefix(String? value) => value != null && value.isNotEmpty;
