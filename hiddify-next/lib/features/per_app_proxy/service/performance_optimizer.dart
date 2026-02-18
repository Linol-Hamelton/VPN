import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/features/per_app_proxy/data/per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_per_app_proxy_repository.dart';

/// Singleton service for optimizing performance of application detection and routing
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  // Cache for application lists with TTL
  Map<String, List<InstalledPackageInfo>> _cachedApps = {};
  Map<String, DateTime> _cacheTimestamp = {};
  Duration _cacheTtl = const Duration(minutes: 5);

  // Debounce timers for routing updates
  Timer? _debounceTimer;
  Duration _debounceDuration = const Duration(milliseconds: 300);

  // Resource monitoring
  int _lastMemoryUsage = 0;
  int _peakMemoryUsage = 0;

  /// Get cached applications if available and not expired, otherwise fetch from repository
  Future<List<InstalledPackageInfo>> getCachedApplications({
    required PerAppProxyRepository? androidRepo,
    required DesktopPerAppProxyRepository? desktopRepo,
  }) async {
    final platformKey = Platform.operatingSystem;
    
    // Check if we have a valid cache
    if (_cachedApps.containsKey(platformKey)) {
      final timestamp = _cacheTimestamp[platformKey]!;
      if (DateTime.now().difference(timestamp) < _cacheTtl) {
        return _cachedApps[platformKey]!;
      }
    }
    
    // Fetch fresh data
    List<InstalledPackageInfo> apps = [];
    if (Platform.isAndroid && androidRepo != null) {
      apps = await androidRepo.getInstalledPackages().getOrElse(() => []);
    } else if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) && desktopRepo != null) {
      apps = await desktopRepo.getInstalledApplications().getOrElse(() => []);
    }
    
    // Cache the results
    _cachedApps[platformKey] = apps;
    _cacheTimestamp[platformKey] = DateTime.now();
    
    return apps;
  }

  /// Invalidate the application cache
  void invalidateCache() {
    _cachedApps.clear();
    _cacheTimestamp.clear();
  }

  /// Debounce routing updates to prevent excessive system calls
  void debounceRoutingUpdate(VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, callback);
  }

  /// Check if the system has sufficient resources to perform routing operations
  bool hasSufficientResources() {
    // This is a simplified check - in a real implementation, we would check 
    // for actual system resource availability
    return true;  // Placeholder for actual resource check
  }

  /// Clear expired cache entries
  void clearExpiredCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _cacheTimestamp.entries) {
      if (now.difference(entry.value) >= _cacheTtl) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _cachedApps.remove(key);
      _cacheTimestamp.remove(key);
    }
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedPlatforms': _cachedApps.keys.toList(),
      'cacheSizes': {
        for (final entry in _cachedApps.entries)
          entry.key: entry.value.length
      },
      'lastUpdateTimes': {
        for (final entry in _cacheTimestamp.entries)
          entry.key: entry.value.toIso8601String()
      },
    };
  }

  /// Dispose of resources
  void dispose() {
    _debounceTimer?.cancel();
  }
}
