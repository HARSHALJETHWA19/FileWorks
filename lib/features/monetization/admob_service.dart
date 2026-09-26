import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'ad_config.dart';
import 'ad_service.dart';

class AdmobService implements AdService {
  final SharedPreferences _prefs;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _operationCount = 0;
  bool _initialized = false;
  bool _isPro = false;
  DateTime? _lastInterstitialTime;

  AdmobService(this._prefs) {
    _operationCount = _prefs.getInt(AppConstants.keyOperationCount) ?? 0;
    _isPro = _prefs.getBool(AppConstants.keyIsProUser) ?? false;
  }

  @override
  int get operationCount => _operationCount;

  @override
  void updateProStatus(bool isPro) {
    _isPro = isPro;
    if (_isPro) {
      // Immediately stop and dispose cached interstitial
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialLoading = false;
    } else {
      if (_initialized && _interstitialAd == null && !_isInterstitialLoading) {
        _loadInterstitialAd();
      }
    }
  }

  @override
  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      if (!_isPro && AdConfig.interstitialEnabled) {
        _loadInterstitialAd();
      }
    } catch (e) {
      debugPrint('AdMob initialization skipped or failed: $e');
    }
  }

  void _loadInterstitialAd() {
    if (!_initialized || _isInterstitialLoading || _interstitialAd != null || _isPro) {
      return;
    }
    if (!AdConfig.interstitialEnabled) return;

    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_isPro) {
            ad.dispose();
            _isInterstitialLoading = false;
            _interstitialAd = null;
            return;
          }
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              if (!_isPro && AdConfig.interstitialEnabled) {
                _loadInterstitialAd(); // Preload next
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              if (!_isPro && AdConfig.interstitialEnabled) {
                _loadInterstitialAd();
              }
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
          _isInterstitialLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  @override
  Future<void> recordOperationCompleted() async {
    _operationCount++;
    await _prefs.setInt(AppConstants.keyOperationCount, _operationCount);
  }

  @override
  Future<void> showInterstitialIfReady({bool force = false}) async {
    if (!_initialized || _isPro || !AdConfig.interstitialEnabled) return;

    // Check cooldown
    if (!force && _lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!);
      if (elapsed < AdConfig.interstitialCooldown) {
        debugPrint('Interstitial skipped: Cooldown active (${elapsed.inSeconds}s < ${AdConfig.interstitialCooldown.inSeconds}s)');
        return;
      }
    }

    if (force || _operationCount >= AdConfig.interstitialOperationThreshold) {
      if (_interstitialAd != null) {
        await _interstitialAd!.show();
        _interstitialAd = null;
        _operationCount = 0;
        _lastInterstitialTime = DateTime.now();
        await _prefs.setInt(AppConstants.keyOperationCount, 0);
        if (!_isPro && AdConfig.interstitialEnabled) {
          _loadInterstitialAd();
        }
      } else {
        // Interstitial was not ready, trigger preload
        _loadInterstitialAd();
      }
    }
  }

  @override
  Widget buildBannerAd() {
    if (!_initialized || _isPro || !AdConfig.bannerEnabled) {
      return const SizedBox.shrink();
    }
    return _AdMobBannerWidget(adUnitId: AdConfig.bannerAdUnitId);
  }
}

class _AdMobBannerWidget extends StatefulWidget {
  final String adUnitId;

  const _AdMobBannerWidget({required this.adUnitId});

  @override
  State<_AdMobBannerWidget> createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<_AdMobBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}
