// Dart Automated Verification Suite: Ad Networks Isolation & Compliance
import 'dart:io';

void main() {
  print('================================================================');
  print('FILEWORKS — AD NETWORKS SOURCE CODE AUDIT & ISOLATION SUITE');
  print('================================================================\n');

  int passed = 0;
  int failed = 0;

  void assertTest(String id, String description, bool condition) {
    if (condition) {
      passed++;
      print('[PASS] $id: $description');
    } else {
      failed++;
      print('[FAIL] $id: $description');
    }
  }

  final appJsFile = File('e:/FileKit/web_app/js/app.js');
  if (!appJsFile.existsSync()) {
    print('FATAL: web_app/js/app.js does not exist');
    exit(1);
  }
  final appJs = appJsFile.readAsStringSync();

  // 1. MODULE SEPARATION
  assertTest('AUDIT-001', 'FW.ads module exists independently in app.js',
    appJs.contains('ads: {') && appJs.contains('publisherId: \'ca-pub-7044469500687742\''));

  assertTest('AUDIT-002', 'FW.monetag module exists independently in app.js',
    appJs.contains('monetag: {') && appJs.contains('zone: \'303303\''));

  assertTest('AUDIT-003', 'Monetag module does not reference or modify AdSense objects',
    !appJs.substring(appJs.indexOf('monetag: {'), appJs.indexOf('analytics: {')).contains('adsbygoogle'));

  // 2. CAUTIOUS SUSPENSION & FORMAT VERIFICATION ENFORCEMENT
  assertTest('AUDIT-004', 'AdSense is flagged as suspended and disabled to protect account',
    appJs.contains('suspended: true') && appJs.contains('enabled: false'));

  assertTest('AUDIT-005', 'loadAds() checks suspension status before attempting any script injection',
    appJs.contains('if (this.suspended || !this.enabled)'));

  assertTest('AUDIT-006', 'Monetag tag is disabled pending dashboard format confirmation',
    appJs.contains("status: 'pending_dashboard_format_verification'") &&
    appJs.contains('if (!this.enabled)'));

  assertTest('AUDIT-007', 'Push Service Worker is disabled to prevent unprompted notifications',
    appJs.contains("status: 'disabled'") &&
    appJs.contains('sw:') &&
    appJs.contains('if (!this.enabled)'));

  final consentGrantedIdx = appJs.indexOf('onConsentGranted()');
  final afterConsentGranted = consentGrantedIdx != -1 ? appJs.substring(consentGrantedIdx) : '';
  assertTest('AUDIT-008', 'Registration call site is omitted from onConsentGranted()',
    !afterConsentGranted.contains('FW.sw.init()'));

  // 3. CONSENT HANDLING (Essential vs Advertising)
  assertTest('AUDIT-009', 'isAdConsentGranted() distinguishes explicit ad consent from essential cookies',
    appJs.contains('isAdConsentGranted()') && appJs.contains('localStorage.getItem(this.KEY) === \'accepted\''));

  assertTest('AUDIT-010', 'Navigation guard blocks unauthorized window.open popunders',
    appJs.contains('installNavigationGuard()') && appJs.contains('Blocked unprompted background window.open'));

  // 4. SERVICE WORKER FILES
  final swFile = File('e:/FileKit/web_app/sw.js');
  assertTest('AUDIT-011', 'Root web_app/sw.js exists with zone 12147235 and domain 3nbf4.com',
    swFile.existsSync() && swFile.readAsStringSync().contains('3nbf4.com') && swFile.readAsStringSync().contains('12147235'));

  final publicSwFile = File('e:/FileKit/web_app/public/sw.js');
  assertTest('AUDIT-012', 'Public directory public/sw.js exists with matching configuration',
    publicSwFile.existsSync() && publicSwFile.readAsStringSync().contains('3nbf4.com') && publicSwFile.readAsStringSync().contains('12147235'));

  print('\n================================================================');
  print('AUDIT SUMMARY: $passed PASSED, $failed FAILED out of ${passed + failed} TESTS');
  print('================================================================\n');

  if (failed > 0) exit(1);
}
