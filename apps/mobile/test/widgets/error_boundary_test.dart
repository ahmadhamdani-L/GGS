import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/widgets/error_boundary.dart';

void main() {
  group('LoadingWidget', () {
    testWidgets('shows circular progress indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingWidget()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows message when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingWidget(message: 'Loading...')),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('fullScreen mode shows Scaffold', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoadingWidget(fullScreen: true),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('EmptyStateWidget', () {
    testWidgets('shows message and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(message: 'No items found'),
          ),
        ),
      );

      expect(find.text('No items found'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('shows action button when provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              message: 'No items',
              actionLabel: 'Refresh',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Refresh'), findsOneWidget);
      await tester.tap(find.text('Refresh'));
      expect(tapped, true);
    });

    testWidgets('custom icon is displayed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              message: 'No friends',
              icon: Icons.people_outline,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });
  });

  group('ShimmerPlaceholder', () {
    testWidgets('renders with specified dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerPlaceholder(width: 100, height: 50),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 100);
      expect(container.constraints?.maxHeight, 50);
    });

    testWidgets('animation runs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShimmerPlaceholder()),
        ),
      );

      // Animation should start
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShimmerPlaceholder), findsOneWidget);
    });
  });
}
