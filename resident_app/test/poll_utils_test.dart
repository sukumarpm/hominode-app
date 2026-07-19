// test/poll_utils_test.dart
// Unit tests for poll utility functions

import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/models/poll.dart';

void main() {
  group('Poll Utility Functions', () {
    test('calculatePercent returns correct percentage', () {
      expect(calculatePercent(46, 60), closeTo(76.67, 0.01));
      expect(calculatePercent(14, 60), closeTo(23.33, 0.01));
      expect(calculatePercent(0, 60), 0.0);
      expect(calculatePercent(60, 60), 100.0);
    });

    test('calculatePercent handles zero total votes', () {
      expect(calculatePercent(0, 0), 0.0);
      expect(calculatePercent(5, 0), 0.0);
    });

    test('formatPercent formats correctly', () {
      expect(formatPercent(76.67), '77%');
      expect(formatPercent(23.33), '23%');
      expect(formatPercent(0.0), '0%');
      expect(formatPercent(100.0), '100%');
    });

    test('Poll.isClosed returns true for closed status', () {
      final poll = Poll(
        id: 'test',
        question: 'Test?',
        options: [],
        totalVotes: 0,
        status: PollStatus.closed,
        createdAt: DateTime.now(),
      );
      expect(poll.isClosed, true);
    });

    test('Poll.isClosed returns true for expired poll', () {
      final poll = Poll(
        id: 'test',
        question: 'Test?',
        options: [],
        totalVotes: 0,
        status: PollStatus.open,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(poll.isClosed, true);
    });

    test('Poll.hasUserVoted returns true when user voted', () {
      final poll = Poll(
        id: 'test',
        question: 'Test?',
        options: [],
        totalVotes: 10,
        userVotedOptionId: 'opt_1',
        status: PollStatus.open,
        createdAt: DateTime.now(),
      );
      expect(poll.hasUserVoted, true);
    });

    test('Poll.hasUserVoted returns false when user has not voted', () {
      final poll = Poll(
        id: 'test',
        question: 'Test?',
        options: [],
        totalVotes: 10,
        userVotedOptionId: null,
        status: PollStatus.open,
        createdAt: DateTime.now(),
      );
      expect(poll.hasUserVoted, false);
    });
  });
}
