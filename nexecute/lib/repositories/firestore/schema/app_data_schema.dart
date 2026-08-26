abstract final class AppDataSchema {
  static const versionField = 'schemaVersion';
  static const currentVersion = 2;

  static Map<String, dynamic> stamp(Map<String, dynamic> document) => {
    ...document,
    versionField: currentVersion,
  };
}
