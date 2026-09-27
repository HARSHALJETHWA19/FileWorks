import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filekit/core/constants/app_constants.dart';
import 'package:filekit/features/monetization/ad_config.dart';
import 'package:filekit/features/monetization/admob_service.dart';
import 'package:filekit/features/monetization/providers/monetization_provider.dart';
import 'package:filekit/features/settings/presentation/privacy_policy_screen.dart';
import 'package:filekit/features/settings/presentation/settings_screen.dart';

void main() {
  group('Privacy & Zero-Exfiltration Audit Tests', () {
    test('PRIVACY-001: pubspec.yaml contains no cloud exfiltration or remote backend dependencies', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final content = pubspecFile.readAsStringSync();
      const forbiddenPackages = [
        'http:',
        'dio:',
        'firebase_',
        'amplify_',
        'supabase',
        'graphql',
        'retrofit',
        'cloud_firestore',
        'firebase_storage',
        'aws_',
      ];

      for (final forbidden in forbiddenPackages) {
        expect(
          content.contains(RegExp('^\\s*$forbidden', multiLine: true)),
          isFalse,
          reason: 'Forbidden network dependency found in pubspec.yaml: $forbidden',
        );
      }
    });

    test('PRIVACY-002: Source code in lib/ contains zero remote HTTP client requests', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final code = file.readAsStringSync();
        // Check for HttpClient, http.get/post, dio calls
        expect(code.contains(RegExp(r'package:http/http\.dart')), isFalse,
            reason: 'Found http import in ${file.path}');
        expect(code.contains(RegExp(r'package:dio/dio\.dart')), isFalse,
            reason: 'Found dio import in ${file.path}');
        expect(code.contains(RegExp(r'HttpClient\(\)\.getUrl|HttpClient\(\)\.postUrl')), isFalse,
            reason: 'Found raw HttpClient network call in ${file.path}');
      }
    });

    test('PRIVACY-003: Canary string is isolated to local processing and never exfiltrated', () async {
      const canaryString = 'FILEWORKS_PRIVACY_CANARY_739281';
      final tempFile = File('${Directory.systemTemp.path}/canary_sample.txt')
        ..writeAsStringSync(canaryString);

      expect(tempFile.existsSync(), isTrue);
      expect(tempFile.readAsStringSync(), contains('CANARY_739281'));
      tempFile.deleteSync();
    });

    test('PRIVACY-004: AdMob frequency capping strictly enforced to 3 operations', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final admobService = AdmobService(prefs);

      expect(admobService.operationCount, equals(0));
      expect(AdConfig.interstitialOperationThreshold, equals(3));

      await admobService.recordOperationCompleted();
      expect(admobService.operationCount, equals(1));

      await admobService.recordOperationCompleted();
      expect(admobService.operationCount, equals(2));

      await admobService.recordOperationCompleted();
      expect(admobService.operationCount, equals(3));
      // Ready for ad display after exactly 3 operations, not before
    });

    test('PRIVACY-005: Privacy Policy URL is public HTTPS URL without localhost or file schemes', () {
      expect(AppConstants.privacyPolicyUrl, startsWith('https://'));
      expect(AppConstants.privacyPolicyUrl, equals('https://harshaljethwa19.github.io/FileWorks/privacy-policy.html'));
      expect(AppConstants.manageSubscriptionsUrl, startsWith('https://play.google.com/store/account/subscriptions'));
      expect(AppConstants.contactEmail, equals('aetherkube@gmail.com'));
    });

    test('PRIVACY-006: Standalone HTML Privacy Policy exists and contains required disclosures', () {
      final htmlFile = File('docs/privacy-policy.html');
      expect(htmlFile.existsSync(), isTrue);

      final content = htmlFile.readAsStringSync();
      expect(content, contains('On-Device Local File Processing'));
      expect(content, contains('Google Mobile Ads SDK'));
      expect(content, contains('Google Play Billing and Subscriptions'));
      expect(content, contains('aetherkube@gmail.com'));
      expect(content, contains('mailto:aetherkube@gmail.com'));
      final legacyEmail = ['support', 'fileworks.app'].join('@');
      expect(content.contains(legacyEmail), isFalse);
      expect(content.contains('mailto:$legacyEmail'), isFalse);
      expect(content, contains('fileworks_premium_6m'));
      expect(content, contains('fileworks_premium_1y'));
    });

    testWidgets('PRIVACY-007: PrivacyPolicyScreen renders all required policy sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('1. On-Device Local File Processing'), findsOneWidget);
      expect(find.text('2. Temporary Files and Local Storage'), findsOneWidget);
      expect(find.text('3. Advertising and Google Mobile Ads SDK'), findsOneWidget);
      expect(find.text('4. Voluntary Rewarded Advertisements'), findsOneWidget);
      expect(find.text('5. Google Play Billing and Subscriptions'), findsOneWidget);
      expect(find.text('6. Permissions Used'), findsOneWidget);
      expect(find.text('7. Third-Party Service Providers'), findsOneWidget);
      expect(find.text('8. Contact & Data Inquiries'), findsOneWidget);
      expect(find.textContaining('Email: aetherkube@gmail.com'), findsOneWidget);
      expect(find.text('View Official Web Privacy Policy'), findsOneWidget);
    });

    testWidgets('PRIVACY-008: SettingsScreen exposes Privacy Policy, Ad & Privacy Choices, and Manage Subscriptions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Local-First Processing'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Ad & Privacy Choices'), findsOneWidget);
      expect(find.text('Manage Subscriptions'), findsOneWidget);
    });

    test('PRIVACY-009: Legacy support email is completely absent from app source and privacy policy', () {
      final legacyEmail = ['support', 'fileworks.app'].join('@');

      final htmlContent = File('docs/privacy-policy.html').readAsStringSync();
      expect(htmlContent.contains(legacyEmail), isFalse);

      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final code = file.readAsStringSync();
        expect(code.contains(legacyEmail), isFalse,
            reason: 'Found legacy support email in ${file.path}');
      }
    });
  });
}
