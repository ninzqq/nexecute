import 'package:nexecute/repositories/google_calendar_local_store.dart';
import 'package:nexecute/repositories/google_calendar_local_store_factory_stub.dart'
    if (dart.library.io) 'google_calendar_local_store_factory_io.dart'
    as platform;

GoogleCalendarLocalStore createGoogleCalendarLocalStore() =>
    platform.createGoogleCalendarLocalStore();
