import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/theme/app_theme.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/features/shell/main_shell.dart';

/// Publish dates (pub.dev API) of the versions this project pins. Add a row
/// whenever a pin changes; the test then enforces the 2-week rule.
final _published = <String, DateTime>{
  'connectivity_plus 7.3.1': DateTime.utc(2026, 7, 23),
};

void main() {
  test('pinned connectivity_plus is exact and at least 2 weeks old', () {
    final yaml = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'connectivity_plus:\s*(\S+)').firstMatch(yaml)!;
    final version = m.group(1)!;
    expect(version, isNot(startsWith('^')), reason: 'versions are pinned');
    final date = _published['connectivity_plus $version'];
    expect(date, isNotNull, reason: 'record the publish date of $version');
    expect(
      DateTime.now().toUtc().difference(date!).inDays,
      greaterThanOrEqualTo(14),
    );
  });

  group('bottom nav background', () {
    for (final (name, theme, colors) in [
      ('light', AppTheme.light, LamsaColors.light),
      ('dark', AppTheme.dark, LamsaColors.dark),
    ]) {
      test('$name: differs from the scaffold and uses an existing token', () {
        final bar = theme.navigationBarTheme.backgroundColor;
        expect(bar, isNotNull);
        expect(bar, isNot(theme.scaffoldBackgroundColor));
        expect(bar, colors.surface2);
      });

      test('$name: selected and unselected icons stay readable on the bar', () {
        final bar = theme.navigationBarTheme.backgroundColor!;
        double ratio(Color a, Color b) {
          final la = a.computeLuminance() + .05;
          final lb = b.computeLuminance() + .05;
          return la > lb ? la / lb : lb / la;
        }

        expect(ratio(colors.accent, bar), greaterThanOrEqualTo(3));
        expect(ratio(colors.muted, bar), greaterThanOrEqualTo(3));
      });
    }
  });

  group('NavBounce', () {
    Widget host({required bool selected, bool reduce = false}) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: NavBounce(
              selected: selected,
              child: const Icon(Icons.home, key: Key('icon')),
            ),
          ),
        );

    double scale(WidgetTester tester) => tester
        .widget<ScaleTransition>(find.descendant(
          of: find.byType(NavBounce),
          matching: find.byType(ScaleTransition),
        ))
        .scale
        .value;

    testWidgets('pops when it becomes selected, then settles at 1',
        (tester) async {
      await tester.pumpWidget(host(selected: false));
      expect(scale(tester), 1);

      await tester.pumpWidget(host(selected: true));
      await tester.pump(const Duration(milliseconds: 40));
      expect(scale(tester), lessThan(1));

      await tester.pump(NavBounce.duration);
      expect(scale(tester), 1);
      expect(NavBounce.duration.inMilliseconds, lessThan(300));
    });

    testWidgets('does not animate when reduced motion is on', (tester) async {
      await tester.pumpWidget(host(selected: false, reduce: true));
      await tester.pumpWidget(host(selected: true, reduce: true));
      await tester.pump(const Duration(milliseconds: 40));
      expect(scale(tester), 1);
    });
  });
}
