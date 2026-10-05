import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:resumecraft_ai/main.dart';
import 'package:resumecraft_ai/store.dart';

void main() {
  testWidgets('phone navigation creates a draft without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ResumeStore(preferences, false);
    // Fallback cleanup if setup fails; dispose is idempotent.
    addTearDown(store.dispose);

    try {
      await store.init();
      await tester.pumpWidget(ResumeCraft(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Your next chapter starts here.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);

      final createButton = find.widgetWithText(FilledButton, 'Create a resume');
      expect(createButton, findsOneWidget);
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(store.resumes, hasLength(1));
      expect(store.selected, isNotNull);
      expect(find.text('Resume editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      // Dispose before testWidgets verifies pending timers, not only
      // in addTearDown, which can run after invariant verification.
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await tester.pump();
    }
  });

  testWidgets('desktop has an extended navigation rail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ResumeStore(preferences, false);
    addTearDown(store.dispose);

    try {
      await store.init();
      await tester.pumpWidget(ResumeCraft(store: store));
      await tester.pumpAndSettle();

      final railFinder = find.byType(NavigationRail);
      expect(railFinder, findsOneWidget);
      expect(tester.widget<NavigationRail>(railFinder).extended, isTrue);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Your next chapter starts here.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await tester.pump();
    }
  });
  testWidgets('AI creation dialog survives keyboard and closing animation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = ResumeStore(await SharedPreferences.getInstance(), false);
    addTearDown(store.dispose);
    try {
      await store.init();
      await tester.pumpWidget(ResumeCraft(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create a resume with AI'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Build a resume with AI'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Test User');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(store.resumes, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await tester.pump();
    }
  });

  testWidgets('profile screen fits a phone without a signed-in account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = ResumeStore(await SharedPreferences.getInstance(), false);
    addTearDown(store.dispose);
    try {
      await store.init();
      await tester.pumpWidget(ResumeCraft(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(4));
      await tester.pumpAndSettle();
      expect(find.text('My account'), findsOneWidget);
      expect(find.text('Device workspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await tester.pump();
    }
  });
  testWidgets('template previews fit on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = ResumeStore(await SharedPreferences.getInstance(), false);
    addTearDown(store.dispose);
    try {
      await store.init();
      await tester.pumpWidget(ResumeCraft(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Modern'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('Minimal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await tester.pump();
    }
  });
}
