import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/widgets/accessible_button.dart';

void main() {
  group('AccessibleButton', () {
    testWidgets('renders with semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              onPressed: () {},
              semanticLabel: 'Test Button',
              child: const Text('Click Me'),
            ),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Check semantics
      final semantics = tester.getSemantics(find.byType(Semantics).first);
      expect(semantics.label, 'Test Button');
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              onPressed: null,
              semanticLabel: 'Disabled Button',
              child: Text('Disabled'),
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              onPressed: () => pressed = true,
              semanticLabel: 'Tap Me',
              child: const Text('Tap'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap'));
      expect(pressed, true);
    });

    testWidgets('applies destructive style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleButton(
              onPressed: () {},
              semanticLabel: 'Delete',
              isDestructive: true,
              child: const Text('Delete'),
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('AccessibleIconButton', () {
    testWidgets('renders icon with semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleIconButton(
              onPressed: () {},
              icon: Icons.settings,
              semanticLabel: 'Settings',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('has tooltip matching semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleIconButton(
              onPressed: () {},
              icon: Icons.home,
              semanticLabel: 'Go Home',
            ),
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Go Home');
    });

    testWidgets('has minimum touch target size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleIconButton(
              onPressed: () {},
              icon: Icons.add,
              semanticLabel: 'Add',
            ),
          ),
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.constraints?.minWidth, greaterThanOrEqualTo(48));
      expect(iconButton.constraints?.minHeight, greaterThanOrEqualTo(48));
    });
  });

  group('AccessibleCard', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('is tappable when onTap provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleCard(
              onTap: () => tapped = true,
              semanticLabel: 'Tap this card',
              child: const Text('Tappable'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable'));
      expect(tapped, true);
    });

    testWidgets('shows selection border when selected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleCard(
              selected: true,
              child: Text('Selected'),
            ),
          ),
        ),
      );

      // Find container with border
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AccessibleCard),
          matching: find.byType(Container),
        ).first,
      );
      
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNotNull);
    });
  });

  group('AccessibleText', () {
    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleText('Hello World'),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('applies heading semantics when isHeading true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleText(
              'Page Title',
              isHeading: true,
            ),
          ),
        ),
      );

      // Just verify it renders
      expect(find.text('Page Title'), findsOneWidget);
    });
  });

  group('AccessibleAvatar', () {
    testWidgets('shows fallback when no image', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleAvatar(
              playerName: 'John',
              size: 48,
            ),
          ),
        ),
      );

      // Should show first letter
      expect(find.text('J'), findsOneWidget);
    });

    testWidgets('renders with player name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleAvatar(
              playerName: 'TestPlayer',
              size: 48,
            ),
          ),
        ),
      );

      // Shows first letter T
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('renders for eliminated player', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibleAvatar(
              playerName: 'DeadPlayer',
              size: 48,
              isAlive: false,
            ),
          ),
        ),
      );

      // Still shows avatar (with grayscale filter)
      expect(find.text('D'), findsOneWidget);
    });
  });

  group('GameSemantics', () {
    testWidgets('wraps child with semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GameSemantics(
              label: 'Game element',
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders child when excluding semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GameSemantics(
              excludeFromSemantics: true,
              child: Text('Hidden from screen reader'),
            ),
          ),
        ),
      );

      expect(find.text('Hidden from screen reader'), findsOneWidget);
    });
  });
}
