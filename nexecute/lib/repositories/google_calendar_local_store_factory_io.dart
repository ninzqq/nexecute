import 'dart:io';

import 'package:nexecute/repositories/file_system_google_calendar_local_store.dart';
import 'package:nexecute/repositories/google_calendar_local_store.dart';
import 'package:nexecute/repositories/google_calendar_local_store_factory_stub.dart'
    as stub;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

GoogleCalendarLocalStore createGoogleCalendarLocalStore() {
  if (!Platform.isAndroid && !Platform.isMacOS) {
    return stub.createGoogleCalendarLocalStore();
  }
  return FileSystemGoogleCalendarLocalStore(
    directoryProvider: () async {
      final applicationSupport = await getApplicationSupportDirectory();
      return Directory(path.join(applicationSupport.path, 'google-calendar'));
    },
  );
}
