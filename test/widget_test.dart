import 'dart:io';
import 'package:filekit/core/errors/exceptions.dart';
import 'package:filekit/core/utils/file_utils.dart';
import 'package:filekit/features/file_tools/services/rename_service.dart';
import 'package:filekit/features/history/models/history_item.dart';
import 'package:filekit/features/monetization/ad_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileUtils Unit Tests', () {
    test('formatBytes formats properly across units', () {
      expect(FileUtils.formatBytes(0), '0 B');
      expect(FileUtils.formatBytes(500), '500.0 B');
      expect(FileUtils.formatBytes(1024), '1.0 KB');
      expect(FileUtils.formatBytes(1024 * 1024), '1.0 MB');
      expect(FileUtils.formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(FileUtils.formatBytes(2 * 1024 * 1024 * 1024), '2.0 GB');
    });

    test('calculateSavings calculates percentage saved correctly', () {
      expect(FileUtils.calculateSavings(100, 50), 50.0);
      expect(FileUtils.calculateSavings(1000, 250), 75.0);
      expect(FileUtils.calculateSavings(100, 100), 0.0);
      expect(FileUtils.calculateSavings(100, 120), -20.0);
      expect(FileUtils.calculateSavings(0, 50), 0.0);
    });

    test('sanitizeFilename removes illegal characters', () {
      expect(FileUtils.sanitizeFilename('report:final?.pdf'), 'report_final_.pdf');
      expect(FileUtils.sanitizeFilename('my<awesome>file|name*.png'), 'my_awesome_file_name_.png');
      expect(FileUtils.sanitizeFilename('clean_name.jpg'), 'clean_name.jpg');
      expect(FileUtils.sanitizeFilename(''), startsWith('file_'));
    });

    test('parsePageRange parses ranges and singles correctly', () {
      final pages = FileUtils.parsePageRange('1-3, 5, 8-10', 10);
      expect(pages, [1, 2, 3, 5, 8, 9, 10]);

      final clamped = FileUtils.parsePageRange('8-15', 10);
      expect(clamped, [8, 9, 10]);

      final empty = FileUtils.parsePageRange('', 10);
      expect(empty, isEmpty);
    });

    test('validateZipPath prevents path traversal (Zip Slip vulnerability)', () {
      final tempDir = Directory.systemTemp.createTempSync('zip_test_');

      try {
        // Valid relative file path inside tempDir
        final validFile = FileUtils.validateZipPath('folder/document.txt', tempDir);
        expect(validFile.path.startsWith(tempDir.resolveSymbolicLinksSync()), isTrue);

        // Malicious entry attempting to write outside target destination
        expect(
          () => FileUtils.validateZipPath('../../etc/passwd', tempDir),
          throwsA(isA<SecurityException>()),
        );

        expect(
          () => FileUtils.validateZipPath('../outside.exe', tempDir),
          throwsA(isA<SecurityException>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('RenameService Unit Tests', () {
    test('generatePreview replaces {number} with proper padding', () {
      final renameService = RenameService();
      final dummyFiles = [
        File('/storage/img_old1.jpg'),
        File('/storage/img_old2.jpg'),
        File('/storage/img_old3.jpg'),
      ];

      final preview = renameService.generatePreview(
        files: dummyFiles,
        pattern: 'Vacation_{number}',
        startNumber: 1,
        zeroPadding: 3,
      );

      expect(preview.length, 3);
      expect(preview[0].newName, 'Vacation_001.jpg');
      expect(preview[1].newName, 'Vacation_002.jpg');
      expect(preview[2].newName, 'Vacation_003.jpg');
    });

    test('generatePreview replaces {name} with original basename', () {
      final renameService = RenameService();
      final dummyFiles = [
        File('/storage/invoice_march.pdf'),
      ];

      final preview = renameService.generatePreview(
        files: dummyFiles,
        pattern: 'PREFIX_{name}',
      );

      expect(preview.length, 1);
      expect(preview[0].newName, 'PREFIX_invoice_march.pdf');
    });
  });

  group('HistoryItem Model Tests', () {
    test('toJson and fromJson preserve all data', () {
      final item = HistoryItem(
        id: '12345',
        toolName: 'PDF Merge',
        title: 'merged_final.pdf',
        subtitle: '3 PDFs merged',
        filePaths: ['/data/merged_final.pdf'],
        originalBytes: 2048,
        outputBytes: 1024,
        timestamp: DateTime(2026, 9, 23, 10, 30),
      );

      final json = item.toJson();
      final restored = HistoryItem.fromJson(json);

      expect(restored.id, '12345');
      expect(restored.toolName, 'PDF Merge');
      expect(restored.title, 'merged_final.pdf');
      expect(restored.subtitle, '3 PDFs merged');
      expect(restored.filePaths, ['/data/merged_final.pdf']);
      expect(restored.originalBytes, 2048);
      expect(restored.outputBytes, 1024);
      expect(restored.timestamp, DateTime(2026, 9, 23, 10, 30));
    });
  });

  group('AdConfig Tests', () {
    test('Uses configured production AdMob IDs', () {
      expect(AdConfig.appIdAndroid, 'ca-app-pub-7044469500687742~3562545834');
      expect(AdConfig.bannerAdUnitId, 'ca-app-pub-7044469500687742/3758910393');
      expect(AdConfig.interstitialAdUnitId, 'ca-app-pub-7044469500687742/4859229910');
      expect(AdConfig.rewardedAdUnitId, 'ca-app-pub-7044469500687742/9709066069');
      expect(AdConfig.interstitialOperationThreshold, 3);
    });
  });
}
