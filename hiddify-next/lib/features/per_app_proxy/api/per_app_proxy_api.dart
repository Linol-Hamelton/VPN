import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';

/// Unified API interface for managing app routing across all platforms
/// This provides a consistent interface regardless of the underlying platform
abstract class PerAppProxyApi {
  /// Get list of installed applications
  Future<Either<String, List<InstalledPackageInfo>>> getInstalledApplications();

  /// Get current routing configuration
  Future<Either<String, List<String>>> getRoutingRules();

  /// Set routing rules for applications
  Future<Either<String, Unit>> setRoutingRules(List<String> appIds);

  /// Add a single routing rule
  Future<Either<String, Unit>> addRoutingRule(String appId);

  /// Remove a routing rule
  Future<Either<String, Unit>> removeRoutingRule(String appId);

  /// Get current routing status for an app
  Future<Either<String, bool>> getAppRoutingStatus(String appId);

  /// Get apps currently using VPN
  Future<Either<String, List<InstalledPackageInfo>>> getVPNRoutedApps();

  /// Get apps bypassing VPN
  Future<Either<String, List<InstalledPackageInfo>>> getDirectRoutedApps();

  /// Refresh application list
  Future<Either<String, List<InstalledPackageInfo>>> refreshApplications();

  /// Set default routing behavior
  Future<Either<String, Unit>> setDefaultRoute(PerAppProxyMode defaultMode);

  /// Get default routing behavior
  Future<Either<String, PerAppProxyMode>> getDefaultRoute();

  /// Apply the routing configuration to the OS
  Future<Either<String, Unit>> applyRoutingConfiguration();

  /// Reset routing configuration to default
  Future<Either<String, Unit>> resetRoutingConfiguration();
}import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';

/// Unified API interface for managing app routing across all platforms
/// This provides a consistent interface regardless of the underlying platform
abstract class PerAppProxyApi {
  /// Get list of installed applications
  Future<Either<String, List<InstalledPackageInfo>>> getInstalledApplications();

  /// Get current routing configuration
  Future<Either<String, List<String>>> getRoutingRules();

  /// Set routing rules for applications
  Future<Either<String, Unit>> setRoutingRules(List<String> appIds);

  /// Add a single routing rule
  Future<Either<String, Unit>> addRoutingRule(String appId);

  /// Remove a routing rule
  Future<Either<String, Unit>> removeRoutingRule(String appId);

  /// Get current routing status for an app
  Future<Either<String, bool>> getAppRoutingStatus(String appId);

  /// Get apps currently using VPN
  Future<Either<String, List<InstalledPackageInfo>>> getVPNRoutedApps();

  /// Get apps bypassing VPN
  Future<Either<String, List<InstalledPackageInfo>>> getDirectRoutedApps();

  /// Refresh application list
  Future<Either<String, List<InstalledPackageInfo>>> refreshApplications();

  /// Set default routing behavior
  Future<Either<String, Unit>> setDefaultRoute(PerAppProxyMode defaultMode);

  /// Get default routing behavior
  Future<Either<String, PerAppProxyMode>> getDefaultRoute();

  /// Apply the routing configuration to the OS
  Future<Either<String, Unit>> applyRoutingConfiguration();

  /// Reset routing configuration to default
  Future<Either<String, Unit>> resetRoutingConfiguration();
}
