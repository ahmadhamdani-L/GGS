import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spin_models.dart';
import 'auth_provider.dart';

/// State for the Lucky Spin feature
class SpinState {
  final bool isLoading;
  final bool isSpinning;
  final List<SpinPrize> prizes;
  final int freeSpinsRemaining;
  final int totalSpins;
  final int luckyPoints;
  final int luckyPointsMax;
  final int spinCostDiamonds;
  final SpinResult? lastResult;
  final List<SpinHistoryEntry> history;
  final String? error;

  const SpinState({
    this.isLoading = true,
    this.isSpinning = false,
    this.prizes = const [],
    this.freeSpinsRemaining = 0,
    this.totalSpins = 0,
    this.luckyPoints = 0,
    this.luckyPointsMax = 100,
    this.spinCostDiamonds = 50,
    this.lastResult,
    this.history = const [],
    this.error,
  });

  SpinState copyWith({
    bool? isLoading,
    bool? isSpinning,
    List<SpinPrize>? prizes,
    int? freeSpinsRemaining,
    int? totalSpins,
    int? luckyPoints,
    int? luckyPointsMax,
    int? spinCostDiamonds,
    SpinResult? lastResult,
    List<SpinHistoryEntry>? history,
    String? error,
  }) {
    return SpinState(
      isLoading: isLoading ?? this.isLoading,
      isSpinning: isSpinning ?? this.isSpinning,
      prizes: prizes ?? this.prizes,
      freeSpinsRemaining: freeSpinsRemaining ?? this.freeSpinsRemaining,
      totalSpins: totalSpins ?? this.totalSpins,
      luckyPoints: luckyPoints ?? this.luckyPoints,
      luckyPointsMax: luckyPointsMax ?? this.luckyPointsMax,
      spinCostDiamonds: spinCostDiamonds ?? this.spinCostDiamonds,
      lastResult: lastResult ?? this.lastResult,
      history: history ?? this.history,
      error: error,
    );
  }

  /// Whether user can spin (has free spins or enough diamonds assumed)
  bool get hasFreeSpin => freeSpinsRemaining > 0;

  /// Lucky points progress as 0.0 - 1.0
  double get luckyPointsProgress =>
      luckyPointsMax > 0 ? (luckyPoints / luckyPointsMax).clamp(0.0, 1.0) : 0.0;
}

class SpinNotifier extends StateNotifier<SpinState> {
  SpinNotifier(this._ref) : super(const SpinState());
  final Ref _ref;

  /// Load spin status from backend
  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, error: null);

    final api = _ref.read(apiServiceProvider);
    final res = await api.getSpinStatus();

    if (res.isSuccess && res.data != null) {
      final status = SpinStatus.fromJson(res.data!);
      state = state.copyWith(
        isLoading: false,
        prizes: status.prizes,
        freeSpinsRemaining: status.freeSpinsRemaining,
        totalSpins: status.totalSpins,
        luckyPoints: status.luckyPoints,
        luckyPointsMax: status.luckyPointsMax,
        spinCostDiamonds: status.spinCostDiamonds,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: res.error ?? 'Gagal memuat data spin',
      );
    }
  }

  /// Perform a spin — returns the prize index for wheel animation
  Future<int?> doSpin() async {
    if (state.isSpinning) return null;
    state = state.copyWith(isSpinning: true, error: null);

    final api = _ref.read(apiServiceProvider);
    final res = await api.doSpin();

    if (res.isSuccess && res.data != null) {
      final result = SpinResult.fromJson(res.data!);

      // Find the prize index in our list for wheel targeting
      final prizeIndex = state.prizes.indexWhere((p) => p.id == result.prize.id);

      state = state.copyWith(
        isSpinning: false,
        lastResult: result,
        freeSpinsRemaining: result.freeSpinsRemaining,
        luckyPoints: result.luckyPoints,
      );

      return prizeIndex >= 0 ? prizeIndex : 0;
    } else {
      state = state.copyWith(
        isSpinning: false,
        error: res.error ?? 'Gagal melakukan spin',
      );
      return null;
    }
  }

  /// Mark spinning complete (called after animation finishes)
  void clearSpinning() {
    state = state.copyWith(isSpinning: false);
  }

  /// Load spin history
  Future<void> loadHistory() async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.getSpinHistory();

    if (res.isSuccess && res.data != null) {
      final entries = (res.data!['history'] as List<dynamic>? ?? [])
          .map((e) => SpinHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(history: entries);
    }
  }

  /// Clear last result (dismiss dialog)
  void clearLastResult() {
    state = SpinState(
      isLoading: state.isLoading,
      isSpinning: state.isSpinning,
      prizes: state.prizes,
      freeSpinsRemaining: state.freeSpinsRemaining,
      totalSpins: state.totalSpins,
      luckyPoints: state.luckyPoints,
      luckyPointsMax: state.luckyPointsMax,
      spinCostDiamonds: state.spinCostDiamonds,
      history: state.history,
    );
  }
}

final spinProvider = StateNotifierProvider<SpinNotifier, SpinState>((ref) {
  return SpinNotifier(ref);
});
