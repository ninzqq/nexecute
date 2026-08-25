import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import test from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const thisDirectory = path.dirname(fileURLToPath(import.meta.url));
const rules = await readFile(
  path.join(thisDirectory, '..', 'firestore.rules'),
  'utf8',
);

const testEnvironment = await initializeTestEnvironment({
  projectId: 'nexecute-emulator-tests',
  firestore: {rules},
});

test.beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

test.after(async () => {
  await testEnvironment.cleanup();
});

test('an owner can read and write their user document and nested data', async () => {
  const owner = testEnvironment.authenticatedContext('owner').firestore();
  const user = doc(owner, 'users/owner');
  const note = doc(owner, 'users/owner/quicxecs/note-1');

  await assertSucceeds(setDoc(user, {tags: ['work']}));
  await assertSucceeds(setDoc(note, {title: 'Private note'}));
  await assertSucceeds(getDoc(user));
  await assertSucceeds(getDoc(note));
});

test('unauthenticated requests cannot access user data', async () => {
  const unauthenticated = testEnvironment.unauthenticatedContext().firestore();
  const user = doc(unauthenticated, 'users/owner');

  await assertFails(getDoc(user));
  await assertFails(setDoc(user, {tags: ['intrusion']}));
});

test('a different user cannot access another user or any nested document', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/owner'), {tags: ['private']});
    await setDoc(doc(context.firestore(), 'users/owner/todos/todo-1'), {
      title: 'Private task',
    });
  });

  const otherUser = testEnvironment.authenticatedContext('other').firestore();

  await assertFails(getDoc(doc(otherUser, 'users/owner')));
  await assertFails(getDoc(doc(otherUser, 'users/owner/todos/todo-1')));
  await assertFails(
    setDoc(doc(otherUser, 'users/owner/todos/todo-2'), {title: 'Intrusion'}),
  );
});
