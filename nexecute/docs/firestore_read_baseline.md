# Firestore read baseline

This procedure measures Nexecute's Firestore query lifecycle before query
scoping and pagination change. Run it again after each optimization phase and
compare the same scenarios and fixture sizes.

## What the app records

Debug builds emit structured JSON through the `nexecute.firestore.reads` log
channel. Release builds use a disabled observer and retain the normal Firestore
listener configuration.

The diagnostics include only:

- a fixed operation name;
- listener attach, snapshot, failure, and detach events;
- active listener counts;
- cache or server source metadata;
- result and document-change counts; and
- duration and error type for one-shot reads.

They never include user IDs, document IDs, query values, search text, dates,
document contents, credentials, or private URLs.

Firestore does not expose the exact billed-read count to the client. A
server-confirmed snapshot therefore must not be interpreted as an exact bill.
Use these logs to identify lifecycle, duplication, result size, and cache
behavior. Use Firebase usage or Google Cloud Monitoring as the authoritative
billed-read measurement.

## Operation names

| Operation | Source |
| --- | --- |
| `notes.all` | Complete Note listener |
| `notes.emptyTrash` | Archived Notes read before batch deletion |
| `todos.all` | Complete Task listener |
| `folders.all` | Note-folder listener |
| `folders.assignedNotes` | Notes read before deleting a folder |
| `tags.userDocument` | Tags stored on the user document |
| `events.overlap` | Calendar visible-range overlap listener |
| `events.recurring` | Recurring-series listener |
| `events.searchAll` | Complete Event read for local text matching |
| `ai.conversationSummaries` | Conversation-list listener |
| `ai.conversationMetadata` | Active-conversation document listener |
| `ai.messages` | Active-conversation message listener |
| `ai.getConversationSummaries` | One-shot conversation-summary read |
| `ai.getConversationMetadata` | One-shot conversation document read |
| `ai.getMessages` | One-shot conversation message read |
| `ai.deleteConversationMessages` | Message pages read during deletion |

## Controlled measurement rules

1. Use one dedicated test account and record its document counts before the
   run.
2. Change only one scenario variable at a time.
3. Start and end each run at a recorded wall-clock time and allow for reporting
   delay in the Firebase dashboard.
4. Do not browse Firestore collections in Firebase Console during the
   measurement window because console activity can contribute reads.
5. Keep background devices closed unless the scenario explicitly tests
   multi-device synchronization.
6. Record logical diagnostics and billed-read deltas separately.

## Baseline matrix

| Scenario | Procedure | Primary question |
| --- | --- | --- |
| Fresh installation | Clear only the test device's application data, launch into Notes, wait for server-confirmed snapshots, then close | Which queries and result sets are paid on a true cold start? |
| Warm relaunch | Relaunch the same device after approximately five minutes without changing data | Does persistent cache resume without broad synchronization? |
| Long-disconnect relaunch | Relaunch after the listener has been disconnected for more than 30 minutes | Which queries are treated like new queries? |
| Primary navigation | Visit Calendar, Tasks, and Notes once, then revisit each | Which listeners attach, remain active, or duplicate? |
| Assistant lifecycle | Open Assistant, allow the latest conversation to load, switch away, and wait | Do conversation and message listeners remain active while hidden? |
| Event search | Enter several distinct settled search terms in one search session | How many complete Event reads are started? |
| Remote mutation | With device A open, create or update one record on device B | Does device A receive only the expected changed document? |
| Three devices | Repeat a fixed cold or warm launch on three devices with no other activity | How does the per-device cache multiply reads? |

## Result template

Record one row per scenario and fixture size:

| Field | Value |
| --- | --- |
| Date, build, platform, and app version | |
| Notes / archived Notes | |
| Active / completed Tasks | |
| One-off / recurring Events | |
| Note folders | |
| AI conversations / messages in latest conversation | |
| Listener attachments by operation | |
| Peak `activeTotal` | |
| Cache snapshot sizes | |
| Server-confirmed snapshot sizes | |
| One-shot reads and result sizes | |
| Firebase or Cloud Monitoring read delta | |
| Unexpected duplicate or long-lived listeners | |
| Notes and anomalies | |

The initial acceptance rule is that rebuilding an unchanged screen does not
increase listener-attachment counts. Every listener observed during navigation
must also have a documented owner and cancellation point before Phase 2 changes
its lifetime.
