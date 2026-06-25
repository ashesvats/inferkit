class ReasoningConfig {
  const ReasoningConfig({
    required this.contentKeys,
    required this.summaryKeys,
    required this.inlineTags,
    required this.emitEvents,
  });

  final List<String> contentKeys;
  final List<String> summaryKeys;
  final ReasoningTagConfig? inlineTags;
  final bool emitEvents;

  static const defaults = ReasoningConfig(
    contentKeys: ['reasoning_content', 'reasoning', 'thinking'],
    summaryKeys: ['reasoning_summary'],
    inlineTags: ReasoningTagConfig.think,
    emitEvents: true,
  );

  static const none = ReasoningConfig(
    contentKeys: [],
    summaryKeys: [],
    inlineTags: null,
    emitEvents: false,
  );
}

class ReasoningTagConfig {
  const ReasoningTagConfig({required this.openTag, required this.closeTag});

  final String openTag;
  final String closeTag;

  static const think = ReasoningTagConfig(
    openTag: '<think>',
    closeTag: '</think>',
  );

  static const reasoning = ReasoningTagConfig(
    openTag: '<reasoning>',
    closeTag: '</reasoning>',
  );
}
