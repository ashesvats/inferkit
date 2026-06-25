class Usage {
  const Usage({this.promptTokens, this.completionTokens, this.totalTokens});

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  factory Usage.fromJson(Map<dynamic, dynamic> json) => Usage(
    promptTokens: _int(json['prompt_tokens']),
    completionTokens: _int(json['completion_tokens']),
    totalTokens: _int(json['total_tokens']),
  );

  Map<String, dynamic> toJson() => {
    if (promptTokens != null) 'prompt_tokens': promptTokens,
    if (completionTokens != null) 'completion_tokens': completionTokens,
    if (totalTokens != null) 'total_tokens': totalTokens,
  };
}

int? _int(Object? value) => value is num ? value.toInt() : null;
