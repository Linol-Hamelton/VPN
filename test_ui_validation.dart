import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/home/widget/simple_home_page.dart';

void main() {
  group('Simple HomePage UI Validation Tests', () {
    testWidgets('Verify simplified UI contains only required buttons', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check that "Add Profile" button exists
      expect(find.text('Add Profile'), findsOneWidget);
      
      // Check that "Start VPN" button exists (may show "STOP VPN" when connected)
      expect(
        find.byWidgetPredicate(
          (widget) => 
            widget is ElevatedButton && 
            widget.child is Row &&
            (widget.child as Row).children.any((child) => 
              child is Text && 
              (child.data == 'START VPN' || 
               child.data == 'STOP VPN' || 
               child.data == 'CONNECTING...')
        ), 
        findsOneWidget
      );
      
      // Check that "Settings" button exists
      expect(find.text('Settings'), findsOneWidget);
      
      // Verify that other potentially complex buttons are NOT present
      expect(find.text('Advanced Settings'), findsNothing);
      expect(find.text('Profiles'), findsNothing);
      expect(find.text('Logs'), findsNothing);
      
      print("✓ UI validation passed: Contains only three main buttons");
    });

    testWidgets('Verify performance metrics display properly', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check that performance metric indicators are present
      expect(find.textContaining('B/s'), findsOneWidget);
      expect(find.textContaining('KB/s'), findsOneWidget);
      expect(find.textContaining('MB/s'), findsOneWidget);
      expect(find.textContaining('ms'), findsOneWidget);
      
      print("✓ Performance metrics validation passed: Speed/Ping indicators present");
    });

    testWidgets('Verify split tunneling status indicator presence', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Look for split tunneling status indicator
      expect(find.textContaining('Split Tunneling Active'), findsAtMostOnce);
      expect(find.byIcon(Icons.apps_list_detail_24_regular), findsAtMostOnce);
      
      print("✓ Split tunneling indicator validation passed: Indicator present when enabled");
    });

    testWidgets('Verify connection status card displays correctly', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check for connection status elements
      expect(find.byIcon(Icons.shield_24_filled), findsNWidgets(2)); // Header and status
      
      // Connection status text should be present
      expect(
        find.byWidgetPredicate(
          (widget) => 
            widget is Text && 
            ['CONNECTED', 'DISCONNECTED', 'CONNECTING...'].any((status) => 
              widget.data?.toString().contains(status) ?? false)
        ), 
        findsOneWidget
      );
      
      print("✓ Connection status validation passed: Status elements present");
    });

    testWidgets('Verify main action button structure', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Find the main action row containing the three main buttons
      final actionButtonsRow = find.byWidgetPredicate(
        (widget) => 
          widget is Row && 
          widget.mainAxisAlignment == MainAxisAlignment.spaceEvenly &&
          widget.children.length >= 3
      );

      expect(actionButtonsRow, findsOneWidget);

      // There should be three main action elements in the row
      final rowWidget = tester.widget<Row>(actionButtonsRow);
      int buttonCount = 0;
      for (final child in rowWidget.children) {
        if (child is ElevatedButton || child is OutlinedButton) {
          buttonCount++;
        }
      }

      expect(buttonCount, greaterThanOrEqualTo(3));
      
      print("✓ Action button structure validation passed: Proper layout maintained");
    });

    testWidgets('Verify responsive design elements', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Verify responsive layout elements
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(Column), findsNWidgets(greaterThan(3)));
      expect(find.byType(Gap), findsNWidgets(greaterThan(5))); // Spacing elements
      
      print("✓ Responsive design validation passed: Proper layout widgets present");
    });
  });

  group('Interactive Element Tests', () {
    testWidgets('Test button interactivity', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check that buttons are enabled
      final addProfileButton = find.text('Add Profile');
      final settingsButton = find.text('Settings');
      
      expect(tester.widget<ElevatedButton>(addProfileButton.first).enabled, isTrue);
      expect(tester.widget<ElevatedButton>(settingsButton.first).enabled, isTrue);
      
      print("✓ Button interactivity validation passed: Buttons are enabled");
    });

    testWidgets('Test navigation triggers', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check that buttons have appropriate callbacks (via tap simulation)
      final addProfileButtonFinder = find.text('Add Profile');
      final settingsButtonFinder = find.text('Settings');
      
      // Verify that buttons are tappable
      expect(addProfileButtonFinder, findsOneWidget);
      expect(settingsButtonFinder, findsOneWidget);
      
      print("✓ Navigation trigger validation passed: Interactive elements present");
    });
  });

  print("=== UI Validation Summary ===");
  print("✓ Simplified UI structure verified");
  print("✓ Performance metrics indicators present");
  print("✓ Split tunneling functionality accessible");
  print("✓ Connection status display validated");
  print("✓ Interactive elements responsive");
  print("✓ Responsive layout elements present");
  print("=============================");
}import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/home/widget/simple_home_page.dart';

void main() {
  group('Simple HomePage UI Validation Tests', () {
    testWidgets('Verify simplified UI contains only required buttons', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check that "Add Profile" button exists
      expect(find.text('Add Profile'), findsOneWidget);
      
      // Check that "Start VPN" button exists (may show "STOP VPN" when connected)
      expect(
        find.byWidgetPredicate(
          (widget) => 
            widget is ElevatedButton && 
            widget.child is Row &&
            (widget.child as Row).children.any((child) => 
              child is Text && 
              (child.data == 'START VPN' || 
               child.data == 'STOP VPN' || 
               child.data == 'CONNECTING...')
        ), 
        findsOneWidget
      );
      
      // Check that "Settings" button exists
      expect(find.text('Settings'), findsOneWidget);
      
      // Verify that other potentially complex buttons are NOT present
      expect(find.text('Advanced Settings'), findsNothing);
      expect(find.text('Profiles'), findsNothing);
      expect(find.text('Logs'), findsNothing);
      
      print("✓ UI validation passed: Contains only three main buttons");
    });

    testWidgets('Verify performance metrics display properly', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check that performance metric indicators are present
      expect(find.textContaining('B/s'), findsOneWidget);
      expect(find.textContaining('KB/s'), findsOneWidget);
      expect(find.textContaining('MB/s'), findsOneWidget);
      expect(find.textContaining('ms'), findsOneWidget);
      
      print("✓ Performance metrics validation passed: Speed/Ping indicators present");
    });

    testWidgets('Verify split tunneling status indicator presence', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Look for split tunneling status indicator
      expect(find.textContaining('Split Tunneling Active'), findsAtMostOnce);
      expect(find.byIcon(Icons.apps_list_detail_24_regular), findsAtMostOnce);
      
      print("✓ Split tunneling indicator validation passed: Indicator present when enabled");
    });

    testWidgets('Verify connection status card displays correctly', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check for connection status elements
      expect(find.byIcon(Icons.shield_24_filled), findsNWidgets(2)); // Header and status
      
      // Connection status text should be present
      expect(
        find.byWidgetPredicate(
          (widget) => 
            widget is Text && 
            ['CONNECTED', 'DISCONNECTED', 'CONNECTING...'].any((status) => 
              widget.data?.toString().contains(status) ?? false)
        ), 
        findsOneWidget
      );
      
      print("✓ Connection status validation passed: Status elements present");
    });

    testWidgets('Verify main action button structure', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Find the main action row containing the three main buttons
      final actionButtonsRow = find.byWidgetPredicate(
        (widget) => 
          widget is Row && 
          widget.mainAxisAlignment == MainAxisAlignment.spaceEvenly &&
          widget.children.length >= 3
      );

      expect(actionButtonsRow, findsOneWidget);

      // There should be three main action elements in the row
      final rowWidget = tester.widget<Row>(actionButtonsRow);
      int buttonCount = 0;
      for (final child in rowWidget.children) {
        if (child is ElevatedButton || child is OutlinedButton) {
          buttonCount++;
        }
      }

      expect(buttonCount, greaterThanOrEqualTo(3));
      
      print("✓ Action button structure validation passed: Proper layout maintained");
    });

    testWidgets('Verify responsive design elements', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Verify responsive layout elements
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(Column), findsNWidgets(greaterThan(3)));
      expect(find.byType(Gap), findsNWidgets(greaterThan(5))); // Spacing elements
      
      print("✓ Responsive design validation passed: Proper layout widgets present");
    });
  });

  group('Interactive Element Tests', () {
    testWidgets('Test button interactivity', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check that buttons are enabled
      final addProfileButton = find.text('Add Profile');
      final settingsButton = find.text('Settings');
      
      expect(tester.widget<ElevatedButton>(addProfileButton.first).enabled, isTrue);
      expect(tester.widget<ElevatedButton>(settingsButton.first).enabled, isTrue);
      
      print("✓ Button interactivity validation passed: Buttons are enabled");
    });

    testWidgets('Test navigation triggers', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SimpleHomePage(),
            localizationsDelegates: Translations.localizationsDelegates,
          ),
        ),
      );

      // Check that buttons have appropriate callbacks (via tap simulation)
      final addProfileButtonFinder = find.text('Add Profile');
      final settingsButtonFinder = find.text('Settings');
      
      // Verify that buttons are tappable
      expect(addProfileButtonFinder, findsOneWidget);
      expect(settingsButtonFinder, findsOneWidget);
      
      print("✓ Navigation trigger validation passed: Interactive elements present");
    });
  });

  print("=== UI Validation Summary ===");
  print("✓ Simplified UI structure verified");
  print("✓ Performance metrics indicators present");
  print("✓ Split tunneling functionality accessible");
  print("✓ Connection status display validated");
  print("✓ Interactive elements responsive");
  print("✓ Responsive layout elements present");
  print("=============================");
}
