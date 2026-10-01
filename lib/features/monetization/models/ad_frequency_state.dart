class AdFrequencyState {
  final DateTime? lastInterstitialAt;
  final DateTime? lastAppOpenAt;
  final int actionsSinceInterstitial;
  final bool isFullscreenAdShowing;
  final bool isProcessing;
  final bool isSaving;
  final bool isSharing;
  final String? currentRoute;
  final bool isPro;

  const AdFrequencyState({
    this.lastInterstitialAt,
    this.lastAppOpenAt,
    this.actionsSinceInterstitial = 0,
    this.isFullscreenAdShowing = false,
    this.isProcessing = false,
    this.isSaving = false,
    this.isSharing = false,
    this.currentRoute,
    this.isPro = false,
  });

  AdFrequencyState copyWith({
    DateTime? lastInterstitialAt,
    DateTime? lastAppOpenAt,
    int? actionsSinceInterstitial,
    bool? isFullscreenAdShowing,
    bool? isProcessing,
    bool? isSaving,
    bool? isSharing,
    String? currentRoute,
    bool? isPro,
  }) {
    return AdFrequencyState(
      lastInterstitialAt: lastInterstitialAt ?? this.lastInterstitialAt,
      lastAppOpenAt: lastAppOpenAt ?? this.lastAppOpenAt,
      actionsSinceInterstitial: actionsSinceInterstitial ?? this.actionsSinceInterstitial,
      isFullscreenAdShowing: isFullscreenAdShowing ?? this.isFullscreenAdShowing,
      isProcessing: isProcessing ?? this.isProcessing,
      isSaving: isSaving ?? this.isSaving,
      isSharing: isSharing ?? this.isSharing,
      currentRoute: currentRoute ?? this.currentRoute,
      isPro: isPro ?? this.isPro,
    );
  }
}
