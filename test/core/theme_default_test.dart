import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/app.dart';
import 'package:lamsa_app/core/theme/app_theme.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/theme_cubit.dart';

import '../auth/auth_fakes.dart';

void main() {
  late AppDependencies deps;
  setUp(() {
    final api = FakeAuthApi();
    deps = makeDeps(session: makeSession(api: api), api: api);
  });

  testWidgets('launches in light mode on a white background', (tester) async {
    // Even when the device itself is in dark mode.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx).brightness, Brightness.light);
    expect(Theme.of(ctx).scaffoldBackgroundColor, const Color(0xFFFFFFFF));
  });

  testWidgets('dark stays reachable and keeps its own colors', (tester) async {
    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();

    await deps.theme.setDark(true);
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(Theme.of(ctx).scaffoldBackgroundColor, LamsaColors.dark.bg);
  });

  test('no color token changed', () {
    expect(LamsaColors.light.bg, const Color(0xFFF7F0F2));
    expect(LamsaColors.light.surface, const Color(0xFFFFFFFF));
    expect(LamsaColors.dark.bg, const Color(0xFF161015));
    expect(LamsaColors.dark.surface, const Color(0xFF211820));
    expect(AppTheme.dark.scaffoldBackgroundColor, LamsaColors.dark.bg);
  });

  test('ThemeCubit starts light', () {
    expect(ThemeCubit().state, ThemeMode.light);
  });
}
