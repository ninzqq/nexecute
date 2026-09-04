import 'package:nexecute/ai/infrastructure/local_ai_skill_store_factory_stub.dart'
    if (dart.library.io) 'local_ai_skill_store_factory_io.dart'
    as platform;
import 'package:nexecute/ai/repositories/ai_skill_store.dart';

AiSkillStore createLocalAiSkillStore() => platform.createLocalAiSkillStore();
