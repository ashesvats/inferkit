import '../chat/tool.dart';

class AgentOptions {
  const AgentOptions({
    required this.model,
    this.temperature,
    this.maxIterations = 8,
    this.parallelTools = true,
    this.concurrencyLimit = 1,
    this.toolChoice = ToolChoice.auto,
  }) : assert(maxIterations > 0),
       assert(concurrencyLimit > 0);

  final String model;
  final double? temperature;
  final int maxIterations;
  final bool parallelTools;
  final int concurrencyLimit;
  final ToolChoice? toolChoice;
}
