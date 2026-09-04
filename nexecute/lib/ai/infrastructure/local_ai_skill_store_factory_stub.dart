import 'package:nexecute/ai/infrastructure/unavailable_ai_skill_store.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';

AiSkillStore createLocalAiSkillStore() => const UnavailableAiSkillStore();
