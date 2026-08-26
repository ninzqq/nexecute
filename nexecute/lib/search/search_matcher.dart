import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/todo_item.dart';

String normalizeSearchQuery(String query) => query.trim().toLowerCase();

bool matchesSearchQuery(Iterable<String> fields, String query) {
  final normalizedQuery = normalizeSearchQuery(query);
  if (normalizedQuery.isEmpty) return false;

  final terms = normalizedQuery.split(RegExp(r'\s+'));
  final searchableText = fields.join(' ').toLowerCase();
  return terms.every(searchableText.contains);
}

bool eventMatchesSearch(Event event, String query) =>
    matchesSearchQuery([event.title, event.description, ...event.tags], query);

bool todoMatchesSearch(TodoItem todo, String query) =>
    matchesSearchQuery([todo.title], query);

bool noteMatchesSearch(Quicxec note, String query) =>
    matchesSearchQuery([note.title, note.searchableText, ...note.tags], query);

bool tagMatchesSearch(String tag, String query) =>
    matchesSearchQuery([tag], query);
