String formatDate(DateTime dateTime) {
  return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
}

DateTime combineDateAndTime(DateTime date, DateTime time) {
  return date.isUtc
      ? DateTime.utc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
        time.second,
        time.millisecond,
        time.microsecond,
      )
      : DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
        time.second,
        time.millisecond,
        time.microsecond,
      );
}
