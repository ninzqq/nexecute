import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/domain/ai_skill.dart';
import 'package:nexecute/ai/infrastructure/ai_skill_markdown_codec.dart';

final class AiPickedSkillDocument {
  AiPickedSkillDocument({required this.fileName, required List<int> bytes})
    : bytes = Uint8List.fromList(bytes);

  final String fileName;
  final Uint8List bytes;
}

abstract interface class AiSkillFileGateway {
  Future<AiPickedSkillDocument?> pickSkillDocument();

  Future<bool> exportSkillDocument({
    required String fileName,
    required List<int> bytes,
  });
}

final class FilePickerAiSkillFileGateway implements AiSkillFileGateway {
  const FilePickerAiSkillFileGateway();

  @override
  Future<AiPickedSkillDocument?> pickSkillDocument() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import SKILL.md',
      type: FileType.custom,
      allowedExtensions: const ['md'],
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.size > aiMaxSkillDocumentBytes) {
      throw const FormatException('The skill document is too large.');
    }
    final bytes = await file.xFile.readAsBytes();
    return AiPickedSkillDocument(fileName: file.name, bytes: bytes);
  }

  @override
  Future<bool> exportSkillDocument({
    required String fileName,
    required List<int> bytes,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export ${AiSkillDocumentContract.fileName}',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['md'],
      bytes: Uint8List.fromList(bytes),
    );
    return kIsWeb || path != null;
  }
}
