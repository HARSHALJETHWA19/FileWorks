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
  /// Ensures ads never interrupt workflow and do not annoy users.
  static const int interstitialOperationThreshold = 3;

  /// Minimum cooldown interval between two interstitial ads.
  /// Prevents ad spamming on rapid successive operations.
  static const Duration interstitialCooldown = Duration(seconds: 45);

  /// Official Google Mobile Ads Sample Ad Unit IDs for Android:
  /// https://developers.google.com/admob/android/test-ads
  static const String _testBannerIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedIdAndroid = 'ca-app-pub-3940256099942544/5224354917';

  /// Official Google Mobile Ads Sample Ad Unit IDs for iOS:
  /// https://developers.google.com/admob/ios/test-ads
  static const String _testBannerIdIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialIdIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testRewardedIdIOS = 'ca-app-pub-3940256099942544/1712485313';

  /// Production Ad Unit IDs (To be populated from your AdMob Console before launch)
  static const String _prodBannerIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodInterstitialIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ';
  static const String _prodRewardedIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/WWWWWWWWWW';

  static const String _prodBannerIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodInterstitialIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ';
  static const String _prodRewardedIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/WWWWWWWWWW';

  static String get bannerAdUnitId {
    if (Platform.isIOS) {
      return isProduction ? _prodBannerIdIOS : _testBannerIdIOS;
    }
    return isProduction ? _prodBannerIdAndroid : _testBannerIdAndroid;
  }

  static String get interstitialAdUnitId {
    if (Platform.isIOS) {
      return isProduction ? _prodInterstitialIdIOS : _testInterstitialIdIOS;
    }
    return isProduction ? _prodInterstitialIdAndroid : _testInterstitialIdAndroid;
  }

  static String get rewardedAdUnitId {
    if (Platform.isIOS) {
      return isProduction ? _prodRewardedIdIOS : _testRewardedIdIOS;
    }
    return isProduction ? _prodRewardedIdAndroid : _testRewardedIdAndroid;
  }
}
