import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:filekit/core/utils/file_utils.dart';
import 'package:filekit/core/errors/exceptions.dart';

void main() {
  group('Adversarial Zip Slip & Path Traversal Security Tests', () {
    late Directory tempDir;
    late Directory targetDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('zip_slip_sec_');
      targetDir = Directory(p.join(tempDir.path, 'target'))..createSync();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('SEC-ZIP-001: Standard Unix path traversal is blocked', () {
      expect(
        () => FileUtils.validateZipPath('../outside.txt', targetDir),
        throwsA(isA<SecurityException>()),
      );
    });

    test('SEC-ZIP-002: Deep nested Unix traversal is blocked', () {
      expect(
        () => FileUtils.validateZipPath('sub/dir/../../../../etc/passwd', targetDir),
        throwsA(isA<SecurityException>()),
      );
    });

    test('SEC-ZIP-003: Windows backslash traversal is blocked', () {
      expect(
        () => FileUtils.validateZipPath(r'..\..\outside.txt', targetDir),
        throwsA(isA<SecurityException>()),
      );
    });

    test('SEC-ZIP-004: Windows mixed-slash traversal is blocked', () {
      expect(
        () => FileUtils.validateZipPath(r'sub\dir/../../../outside.txt', targetDir),
        throwsA(isA<SecurityException>()),
      );
    });

    test('SEC-ZIP-005: Partial path traversal sibling escape must be blocked', () {
      // e.g. target is /tmp/target and entry is ../target_fake/evil.txt
      // Both start with /tmp/target if string matching is done without separator!
      final evilSibling = '..${p.separator}${p.basename(targetDir.path)}_fake${p.separator}evil.txt';
      expect(
        () => FileUtils.validateZipPath(evilSibling, targetDir),
        throwsA(isA<SecurityException>()),
      );
    });

    test('SEC-ZIP-006: Valid inside sub-path is accepted', () {
      final valid = FileUtils.validateZipPath('documents/report.pdf', targetDir);
      expect(p.isWithin(targetDir.resolveSymbolicLinksSync(), valid.path), isTrue);
    });

    test('SEC-ZIP-007: Absolute Unix path is blocked from escaping targetDir', () {
      expect(
        () => FileUtils.validateZipPath('/etc/passwd', targetDir),
        // Since we strip leading slash, it becomes 'etc/passwd' inside targetDir, OR if it tries to escape, blocked
        returnsNormally,
      );
      final resolved = FileUtils.validateZipPath('/etc/passwd', targetDir);
      expect(p.isWithin(targetDir.resolveSymbolicLinksSync(), resolved.path), isTrue);
    });

    test('SEC-ZIP-008: Windows drive root is blocked', () {
      expect(
        () => FileUtils.validateZipPath(r'C:\Windows\System32\malicious.dll', targetDir),
        throwsA(isA<SecurityException>()),
      );
    });
  });
}
