import 'dart:io';

class AdConfig {
  /// Toggle to switch between Google Test Ad IDs and real AdMob Production Ad IDs.
  /// Keep false during development, testing, and pre-launch QA.
  static const bool isProduction = false;

  /// Global master toggles for ad formats
  static const bool bannerEnabled = true;
  static const bool interstitialEnabled = true;
  static const bool rewardedEnabled = true;

  /// Number of completed operations before showing an interstitial ad.
  static const int interstitialOperationThreshold = 3;

  /// Centralized maximum transition actions between interstitials
  static const int maxActionsBetweenInterstitials = 2;

  /// Centralized cooldown interval between two interstitial ads.
  /// Prevents ad spamming on rapid successive operations.
  static const Duration interstitialCooldown = Duration(seconds: 60);

  /// Production AdMob Application ID for Android:
  static const String appIdAndroid = 'ca-app-pub-7044469500687742~3562545834';

  /// Production AdMob Ad Unit IDs for Android:
  static const String _bannerIdAndroid = 'ca-app-pub-7044469500687742/3758910393';
  static const String _interstitialIdAndroid = 'ca-app-pub-7044469500687742/4859229910';
  static const String _rewardedIdAndroid = 'ca-app-pub-7044469500687742/9709066069';

  /// Official Google Mobile Ads Sample Ad Unit IDs for iOS:
  /// https://developers.google.com/admob/ios/test-ads
  static const String _testBannerIdIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialIdIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testRewardedIdIOS = 'ca-app-pub-3940256099942544/1712485313';

  static const String _prodBannerIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodInterstitialIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ';
  static const String _prodRewardedIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/WWWWWWWWWW';

  static String get bannerAdUnitId {
    if (Platform.isIOS) {
      return isProduction ? _prodBannerIdIOS : _testBannerIdIOS;
    }
    return _bannerIdAndroid;
  }

  static String get interstitialAdUnitId {
    if (Platform.isIOS) {
      return isProduction ? _prodInterstitialIdIOS : _testInterstitialIdIOS;
    }
    return _interstitialIdAndroid;
  }

  static String get rewardedAdUnitId {
    if (Platform.isIOS) {
      return isProduction ? _prodRewardedIdIOS : _testRewardedIdIOS;
    }
    return _rewardedIdAndroid;
  }
}
