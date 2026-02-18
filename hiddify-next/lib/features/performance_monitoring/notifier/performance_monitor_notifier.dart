import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../service/performance_monitor.dart';
import '../../stats/model/stats_entity.dart';
import '../../stats/notifier/stats_notifier.dart';

part 'performance_monitor_notifier.g.dart';

/// Notifier that manages the performance monitoring service lifecycle
@riverpod
class PerformanceMonitorNotifier extends _$PerformanceMonitorNotifier {
  PerformanceMonitor? _performanceMonitor;

  @override
  FutureOr<bool> build() {
    return false; // Initially not active
  }

  /// Start the performance monitoring service
  Future<void> startMonitoring({required StatsEntity initialStats}) async {
    ref.state = const AsyncValue.loading();
    
    try {
      _performanceMonitor = PerformanceMonitor(statsEntity: initialStats);
      await _performanceMonitor!.startMonitoring();
      
      // Listen to the performance stream and update stats
      _performanceMonitor!.statsStream.listen((updatedStats) {
        // We can send the updated stats somewhere, maybe update the main stats notifier
        // For now, just update our state
        ref.state = const AsyncValue.data(true);
      }).onError((error) {
        ref.state = AsyncValue.error(error, StackTrace.current);
      });
      
      ref.state = const AsyncValue.data(true);
    } catch (e, stack) {
      ref.state = AsyncValue.error(e, stack);
    }
  }

  /// Stop the performance monitoring service
  Future<void> stopMonitoring() async {
    ref.state = const AsyncValue.loading();
    
    try {
      await _performanceMonitor?.stopMonitoring();
      _performanceMonitor = null;
      ref.state = const AsyncValue.data(false);
    } catch (e, stack) {
      ref.state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider to watch performance monitoring status
@riverpod
bool isPerformanceMonitoringActive(Ref ref) {
  return ref.watch(performanceMonitorNotifierProvider).when(
        data: (active) => active,
        error: (error, stack) => false,
        loading: () => false,
      );
}
