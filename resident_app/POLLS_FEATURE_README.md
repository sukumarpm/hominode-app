# Polls Feature

## Overview
Complete polling functionality integrated into the Events & Announcements screen with pixel-perfect UI matching the design.

## Features Implemented

### UI Components
- ✅ Poll cards with question and options
- ✅ Radio button selection for voting
- ✅ Progress bars showing vote percentages
- ✅ "Vote Now" button (blue) and "Voted" badge (green)
- ✅ Total votes counter
- ✅ Responsive design matching screenshot exactly

### Functionality
- ✅ Vote submission with optimistic UI updates
- ✅ Results view after voting
- ✅ Disabled voting for already-voted polls
- ✅ Loading state during vote submission
- ✅ Success feedback via SnackBar

## Data Models

### Poll Model
```dart
class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final PollStatus status; // open or closed
  final DateTime createdAt;
  final DateTime? expiresAt;
  String? userVotedOptionId;
  
  int get totalVotes;
  bool get hasVoted;
  bool get isExpired;
  bool get canVote;
}
```

### PollOption Model
```dart
class PollOption {
  final String id;
  final String label;
  int votes;
}
```

## Components

### PollCard Widget
Main poll card component that handles:
- Displaying question
- Showing voting options (radio buttons)
- Showing results (progress bars)
- Vote submission
- State management

### PollProgressBar Widget
Reusable horizontal progress bar for showing vote percentages:
- Height: 8px
- Fill color: Black (#000000)
- Track color: Light gray (#E6E6E6)
- Rounded corners

## Usage

### Displaying Polls
Polls are automatically shown when the "Polls" tab is selected in the Events & Announcements screen.

### Sample Data
Two sample polls are provided:
1. **Poll 1** - Open poll ready for voting
2. **Poll 2** - Already voted poll showing results

### Voting Flow
1. User selects an option (radio button)
2. User clicks "Vote Now" button
3. Button shows loading spinner
4. Optimistic update increments vote count
5. Card switches to results view
6. Success message shown via SnackBar

## API Integration (Ready for Implementation)

### Endpoints
```
GET /polls?tab=active&page=1
Response: List<Poll>

GET /polls/{id}
Response: Poll

POST /polls/{id}/vote
Body: { "optionId": "opt_123" }
Response: Poll (updated)
```

### Vote Submission Function
```dart
Future<void> submitVote(String pollId, String optionId) async {
  // TODO: Implement API call
  // final response = await http.post(
  //   Uri.parse('$baseUrl/polls/$pollId/vote'),
  //   body: json.encode({'optionId': optionId}),
  // );
}
```

## Design Specifications

### Colors
- Primary Blue: `#2563EB` (Vote button)
- Voted Green: `#00A84F` (Voted badge)
- Progress Fill: `#000000` (Black)
- Progress Track: `#E6E6E6` (Light gray)
- Text Muted: `#9B9B9B`

### Typography
- Question: 17pt Semibold
- Option Label: 15pt Regular/Semibold (when selected)
- Vote Count: 14pt Regular
- Total Votes: 14pt Regular

### Spacing
- Card padding: 16px
- Option spacing: 8-12px vertical
- Progress bar height: 8px
- Button padding: 24px horizontal, 12px vertical

## State Management

### Poll States
1. **Can Vote** - Shows radio buttons and "Vote Now" button
2. **Has Voted** - Shows results with progress bars and "Voted" badge
3. **Closed** - Shows results (voting disabled)
4. **Expired** - Shows results (voting disabled)

### Optimistic Updates
When a user votes:
1. Immediately update local state
2. Increment vote count
3. Set `userVotedOptionId`
4. Switch to results view
5. Show success message

## Future Enhancements

### Realtime Updates
```dart
Stream<PollEvent> pollUpdates({String? pollId}) {
  // TODO: Implement WebSocket connection
  // return webSocketChannel.stream.map((event) => PollEvent.fromJson(event));
}
```

### Offline Support
```dart
Future<void> queueVoteWhenOffline(String pollId, String optionId) async {
  // TODO: Store in local database (Hive/SQLite)
  // await pollQueue.add(PollVote(pollId, optionId));
}

Future<void> syncQueuedVotes() async {
  // TODO: Sync queued votes when online
  // final queued = await pollQueue.getAll();
  // for (var vote in queued) {
  //   await submitVote(vote.pollId, vote.optionId);
  // }
}
```

### Caching
```dart
Future<void> cachePolls(List<Poll> polls) async {
  // TODO: Cache polls locally
  // await cache.set('polls', polls.map((p) => p.toJson()).toList());
}

Future<List<Poll>> getCachedPolls() async {
  // TODO: Retrieve cached polls
  // final cached = await cache.get('polls');
  // return cached.map((p) => Poll.fromJson(p)).toList();
}
```

## Testing

### Unit Tests (Suggested)
```dart
// test/poll_utils_test.dart
test('calculatePercent returns correct percentage', () {
  expect(calculatePercent(45, 60), 75);
  expect(calculatePercent(0, 60), 0);
  expect(calculatePercent(60, 60), 100);
});

test('Poll.canVote returns false when already voted', () {
  final poll = Poll(
    id: '1',
    question: 'Test?',
    options: [],
    status: PollStatus.open,
    createdAt: DateTime.now(),
    userVotedOptionId: 'opt_1',
  );
  expect(poll.canVote, false);
});
```

### Widget Tests
```dart
testWidgets('PollCard shows radio buttons when can vote', (tester) async {
  final poll = Poll.samplePolls()[0];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PollCard(poll: poll, onVote: (_, __) {}),
    ),
  ));
  expect(find.text('Vote Now'), findsOneWidget);
});
```

## Accessibility

- ✅ Radio buttons have 44x44px tappable area
- ✅ Buttons have sufficient contrast
- ✅ Text is readable with proper font sizes
- ✅ Loading states are indicated
- ✅ Success/error feedback provided

## Performance Considerations

- Optimistic updates for instant feedback
- Minimal rebuilds using StatefulWidget
- Efficient progress bar rendering
- Lazy loading for large poll lists (future)

## Error Handling

Current implementation shows success messages. For production:
- Add error handling for API failures
- Rollback optimistic updates on error
- Show error SnackBar with retry option
- Handle network timeouts
- Validate poll status before voting
