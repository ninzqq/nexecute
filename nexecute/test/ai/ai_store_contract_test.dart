import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  group('in-memory stores', () {
    _profileStoreContract(() => InMemoryAiConnectionProfileStore());
    _conversationStoreContract(() => InMemoryAiConversationStore());
  });

  group('fake stores', () {
    _profileStoreContract(() => FakeAiConnectionProfileStore());
    _conversationStoreContract(() => FakeAiConversationStore());
  });
}

void _profileStoreContract(AiConnectionProfileStore Function() createStore) {
  test('saves, activates, updates, and deletes profiles', () async {
    final store = createStore();
    addTearDown(store.dispose);
    final profile = AiConnectionProfile(
      id: 'home',
      name: 'Home model',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'local-model',
    );
    final profiles = <List<AiConnectionProfile>>[];
    final activeProfiles = <AiConnectionProfile?>[];
    final profilesSubscription = store.watchProfiles().listen(profiles.add);
    final activeSubscription = store.watchActiveProfile().listen(
      activeProfiles.add,
    );
    addTearDown(profilesSubscription.cancel);
    addTearDown(activeSubscription.cancel);
    await Future<void>.delayed(Duration.zero);

    await store.saveProfile(profile);
    await store.setActiveProfileId(profile.id);
    final renamed = profile.copyWith(name: 'Renamed model');
    await store.saveProfile(renamed);
    await store.deleteProfile(profile.id);
    await Future<void>.delayed(Duration.zero);

    expect(profiles.first, isEmpty);
    expect(profiles[1].single.name, 'Home model');
    expect(profiles[2].single.name, 'Renamed model');
    expect(profiles.last, isEmpty);
    expect(activeProfiles.first, isNull);
    expect(activeProfiles[1], same(profile));
    expect(activeProfiles[2], same(renamed));
    expect(activeProfiles.last, isNull);
    expect(await store.getActiveProfile(), isNull);
  });

  test('rejects an unknown active profile', () async {
    final store = createStore();
    addTearDown(store.dispose);

    expect(
      () => store.setActiveProfileId('missing'),
      throwsA(isA<StateError>()),
    );
  });
}

void _conversationStoreContract(AiConversationStore Function() createStore) {
  test('saves, sorts, updates, and deletes conversations', () async {
    final store = createStore();
    addTearDown(store.dispose);
    final older = _conversation(id: 'older', updatedAt: DateTime(2026, 8, 28));
    final newer = _conversation(id: 'newer', updatedAt: DateTime(2026, 8, 29));
    final emissions = <List<AiConversation>>[];
    final subscription = store.watchConversations().listen(emissions.add);
    addTearDown(subscription.cancel);

    await store.saveConversation(older);
    await store.saveConversation(newer);
    final updatedOlder = older.copyWith(updatedAt: DateTime(2026, 8, 30));
    await store.saveConversation(updatedOlder);
    await Future<void>.delayed(Duration.zero);

    expect((await store.getConversations()).first.id, older.id);
    expect(await store.getConversation(older.id), same(updatedOlder));
    expect(emissions.last.first, same(updatedOlder));

    await store.deleteConversation(older.id);
    expect(await store.getConversation(older.id), isNull);
    expect((await store.getConversations()).single.id, newer.id);
  });
}

AiConversation _conversation({
  required String id,
  required DateTime updatedAt,
}) {
  return AiConversation(
    id: id,
    title: id,
    connectionProfileId: 'home',
    modelId: 'local-model',
    createdAt: DateTime(2026, 8, 27),
    updatedAt: updatedAt,
  );
}
