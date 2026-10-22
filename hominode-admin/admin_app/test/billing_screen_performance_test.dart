import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile billing cards are built lazily without build-time logging', () {
    final source = File('lib/billing_screen.dart').readAsStringSync();
    final mobileBuildStart = source.indexOf('return CustomScrollView(');
    final mobileBuildEnd = source.indexOf(
      'Widget _buildDesktopBillTable(',
      mobileBuildStart,
    );
    final mobileBuild = source.substring(mobileBuildStart, mobileBuildEnd);
    final listStart = source.indexOf('Widget _buildBillListSliver(');
    final listEnd = source.indexOf('Widget _buildDueDate(', listStart);
    final billList = source.substring(listStart, listEnd);
    final actionStart = source.indexOf('Widget _buildActionButtons(');
    final actionEnd = source.indexOf(
      'Widget _buildPaymentHistory(',
      actionStart,
    );
    final actionBuilder = source.substring(actionStart, actionEnd);

    expect(mobileBuild, contains('_buildBillListSliver('));
    expect(billList, contains('SliverChildBuilderDelegate('));
    expect(billList, contains('childCount: bills.length'));
    expect(actionBuilder, isNot(contains('BUILD ACTIONS')));
  });
}
