class Tool {
  const Tool.function({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

sealed class ToolChoice {
  const ToolChoice();

  static const auto = _SimpleToolChoice('auto');
  static const none = _SimpleToolChoice('none');
  static const required = _SimpleToolChoice('required');

  factory ToolChoice.function(String name) = _FunctionToolChoice;

  Object toJson();
}

class _SimpleToolChoice extends ToolChoice {
  const _SimpleToolChoice(this.value);

  final String value;

  @override
  Object toJson() => value;
}

class _FunctionToolChoice extends ToolChoice {
  const _FunctionToolChoice(this.name);

  final String name;

  @override
  Object toJson() => {
    'type': 'function',
    'function': {'name': name},
  };
}
