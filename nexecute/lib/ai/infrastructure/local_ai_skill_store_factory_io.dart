import 'dart:io';

import 'package:nexecute/ai/infrastructure/file_system_ai_skill_store.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

AiSkillStore createLocalAiSkillStore() => FileSystemAiSkillStore(
  directoryProvider: () async {
    final applicationSupport = await getApplicationSupportDirectory();
    return Directory(path.join(applicationSupport.path, 'ai-skills'));
  },
);
