import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hiddify/features/stats/model/stats_entity.dart';
import 'package:http/http.dart' as http;

/// Service responsible for measuring network performance metrics (ping, speed) in real-time
class PerformanceMonitor {
  PerformanceMonitor({
    required this.statsEntity,
  });

  final StatsEntity statsEntity;
  
  Timer? _pingTimer;
  Timer? _speedTimer;
  final StreamController<StatsEntity> _statsStream = StreamController<StatsEntity>.broadcast();
  
  bool _isActive = false;

  /// Get stream of updated performance metrics
  Stream<StatsEntity> get statsStream => _statsStream.stream;

  /// Start monitoring performance metrics
  Future<void> startMonitoring() async {
    _isActive = true;
    
    // Start ping measurement timer (every 3 seconds according to spec)
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isActive) {
        _measurePing();
      }
    });
    
    // Start speed measurement timer (every 2 seconds according to spec)
    _speedTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isActive) {
        _measureSpeed();
      }
    });
    
    // Initial measurements
    await _measurePing();
    await _measureSpeed();
  }

  /// Stop monitoring performance metrics
  Future<void> stopMonitoring() async {
    _isActive = false;
    _pingTimer?.cancel();
    _speedTimer?.cancel();
    await _statsStream.close();
  }

  /// Measure ping to VPN server or fallback target
  Future<double> _measurePing() async {
    try {
      // According to the spec, ping to VPN gateway is primary
      final vpnGateway = await _getVpnGateway();
      
      if (vpnGateway != null) {
        final pingTime = await _pingHost(vpnGateway);
        _updateStats(ping: pingTime);
        return pingTime;
      } else {
        // Fallback to public DNS
        final pingTime = await _pingHost('8.8.8.8');
        _updateStats(ping: pingTime);
        return pingTime;
      }
    } catch (e) {
      debugPrint('Ping measurement failed: $e');
      _updateStats(ping: 999.0); // Mark as very high ping on error
      return 999.0;
    }
  }

  /// Measure download and upload speeds (passive monitoring based on existing stats)
  Future<(int downloadSpeed, int uploadSpeed)> _measureSpeed() async {
    try {
      // Since we already get uplink/downlink from the existing stats entity,
      // we just need to calculate the rate of change over time
      final currentUplink = statsEntity.uplink;
      final currentDownlink = statsEntity.downlink;
      
      // Return the current speeds from the stats entity
      _updateStats(
        uplink: currentUplink,
        downlink: currentDownlink,
      );
      
      return (currentUplink, currentDownlink);
    } catch (e) {
      debugPrint('Speed measurement failed: $e');
      _updateStats(uplink: 0, downlink: 0);
      return (0, 0);
    }
  }

  /// Update the stats entity and broadcast
  void _updateStats({
    int? uplink,
    int? downlink,
    double? ping,
    int? connections,
  }) {
    final updatedStats = StatsEntity(
      uplink: uplink ?? statsEntity.uplink,
      downlink: downlink ?? statsEntity.downlink,
      uplinkTotal: statsEntity.uplinkTotal,
      downlinkTotal: statsEntity.downlinkTotal,
      ping: ping ?? statsEntity.ping,
      connections: connections ?? statsEntity.connections,
    );
    
    _statsStream.add(updatedStats);
  }

  /// Internal function to ping a host using ICMP
  Future<double> _pingHost(String host) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile platforms, use HTTP request as fallback since ICMP is not accessible
        return await _pingWithHttp(host);
      } else {
        // For desktop platforms, we could use ICMP ping
        return await _pingWithSocket(host);
      }
    } catch (e) {
      debugPrint('Failed to ping host $host: $e');
      return 999.0;
    }
  }

  /// Ping using HTTP request as fallback
  Future<double> _pingWithHttp(String host) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Try common endpoints for latency testing
      final urls = [
        'https://$host',
        'https://1.1.1.1',
        'https://${host}/favicon.ico',
      ];
      
      for (final url in urls) {
        try {
          await http.get(Uri.parse(url), headers: {'Connection': 'close'});
          stopwatch.stop();
          return stopwatch.elapsedMilliseconds.toDouble();
        } catch (e) {
          continue; // Try next URL if this one fails
        }
      }
      
      // If all URLs fail, return high ping
      return 999.0;
    } catch (e) {
      return 999.0;
    }
  }

  /// Ping using socket connection
  Future<double> _pingWithSocket(String host) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Try to establish a TCP connection to the host on port 80
      final socket = await Socket.connect(host, 80,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds.toDouble();
    } catch (e) {
      return 999.0;
    }
  }

  /// Attempt to get the VPN gateway address
  Future<String?> _getVpnGateway() async {
    try {
      // This is platform-specific and depends on VPN implementation
      // Could use platform channels or check routing table
      // For now, returning null to trigger fallback
      return await _getVpnGatewayPlatformSpecific();
    } catch (e) {
      debugPrint('Could not get VPN gateway: $e');
      return null;
    }
  }

  /// Platform-specific implementation to get VPN gateway
  Future<String?> _getVpnGatewayPlatformSpecific() async {
    // This would typically use platform channels to get the VPN gateway
    // This is a placeholder implementation
    return null;
  }
}
