abstract final class AppDataSchema {
  static const versionField = 'schemaVersion';
  static const currentVersion = 1;

  static Map<String, dynamic> stamp(Map<String, dynamic> document) => {
    ...document,
    versionField: currentVersion,
  };
}
