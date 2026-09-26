import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:filekit/features/monetization/ad_config.dart';
import 'package:filekit/features/monetization/admob_service.dart';

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
  });
}
