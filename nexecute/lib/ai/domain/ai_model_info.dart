import 'package:nexecute/ai/domain/ai_protocol.dart';

class AiModelInfo {
  AiModelInfo({
    required this.id,
    this.displayName,
    this.ownedBy,
    Set<AiCapability> capabilities = const {},
  }) : capabilities = Set.unmodifiable(capabilities);

  final String id;
  final String? displayName;
  final String? ownedBy;
  final Set<AiCapability> capabilities;
}
