import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/api/per_app_proxy_api.dart';
import 'package:hiddify/features/per_app_proxy/data/unified_per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:hiddify/utils/utils.dart';

/// Implementation of the unified API for managing app routing across all platforms
class PerAppProxyApiImpl extends PerAppProxyApi with InfraLogger {
  final UnifiedPerAppProxyRepository _unifiedRepository;

  PerAppProxyApiImpl(this._unifiedRepository);

  @override
  Future<Either<String, List<InstalledPackageInfo>>> getInstalledApplications() async {
    return await _unifiedRepository.getAllInstalledApplications().run();
  }

  @override
  Future<Either<String, List<String>>> getRoutingRules() async {
    // Get the current routing rules from preferences
    try {
      final prefs = await SharedPrefs.instance;
      final currentMode = prefs.perAppProxyMode;
      final appList = currentMode == PerAppProxyMode.off 
          ? <String>[] 
          : (currentMode == PerAppProxyMode.include 
              ? prefs.perAppProxyIncludeList 
              : prefs.perAppProxyExcludeList);
      return right(appList);
    } catch (e) {
      return left("Error getting routing rules: $e");
    }
  }

  @override
  Future<Either<String, Unit>> setRoutingRules(List<String> appIds) async {
    try {
      final prefs = await SharedPrefs.instance;
      final currentMode = prefs.perAppProxyMode;
      
      if (currentMode == PerAppProxyMode.off) {
        // If currently off, default to include mode
        await prefs.setPerAppProxyMode(PerAppProxyMode.include);
        await prefs.setPerAppProxyIncludeList(appIds);
      } else if (currentMode == PerAppProxyMode.include) {
        await prefs.setPerAppProxyIncludeList(appIds);
      } else {  // exclude mode
        await prefs.setPerAppProxyExcludeList(appIds);
      }
      
      // Apply the routing configuration to the system
      final result = await _unifiedRepository.applyRoutingRules(appIds, currentMode == PerAppProxyMode.include).run();
      if (result.isLeft()) {
        return left(result.getLeft().getOrElse(() => "Unknown error"));
      }
      
      return right(unit);
    } catch (e) {
      return left("Error setting routing rules: $e");
    }
  }

  @override
  Future<Either<String, Unit>> addRoutingRule(String appId) async {
    try {
      final currentRules = await getRoutingRules();
      if (currentRules.isLeft()) {
        return left(currentRules.getLeft().getOrElse(() => "Failed to get current rules"));
      }
      
      final updatedRules = [...currentRules.getOrElse(() => <String>[])];
      if (!updatedRules.contains(appId)) {
        updatedRules.add(appId);
        return await setRoutingRules(updatedRules);
      }
      
      return right(unit); // Already added
    } catch (e) {
      return left("Error adding routing rule: $e");
    }
  }

  @override
  Future<Either<String, Unit>> removeRoutingRule(String appId) async {
    try {
      final currentRules = await getRoutingRules();
      if (currentRules.isLeft()) {
        return left(currentRules.getLeft().getOrElse(() => "Failed to get current rules"));
      }
      
      final updatedRules = currentRules.getOrElse(() => <String>[]).where((id) => id != appId).toList();
      return await setRoutingRules(updatedRules);
    } catch (e) {
      return left("Error removing routing rule: $e");
    }
  }

  @override
  Future<Either<String, bool>> getAppRoutingStatus(String appId) async {
    return await _unifiedRepository.isAppRoutedThroughVPN(appId).run();
  }

  @override
  Future<Either<String, List<InstalledPackageInfo>>> getVPNRoutedApps() async {
    try {
      final allApps = await getInstalledApplications();
      if (allApps.isLeft()) {
        return left(allApps.getLeft().getOrElse(() => "Failed to get installed apps"));
      }
      
      final vpnRoutedApps = <InstalledPackageInfo>[];
      final appList = await getRoutingRules();
      
      if (appList.isRight()) {
        final rules = appList.getOrElse(() => <String>[]);
        final prefs = await SharedPrefs.instance;
        final mode = prefs.perAppProxyMode;
        
        for (final app in allApps.getOrElse(() => <InstalledPackageInfo>[])) {
          bool isRouted = false;
          
          if (mode == PerAppProxyMode.include) {
            // In include mode, only apps in the list are routed through VPN
            isRouted = rules.contains(app.packageName);
          } else if (mode == PerAppProxyMode.exclude) {
            // In exclude mode, apps NOT in the list are routed through VPN
            isRouted = !rules.contains(app.packageName);
          } else {
            // Off mode - all apps go through VPN
            isRouted = true;
          }
          
          if (isRouted) {
            vpnRoutedApps.add(app);
          }
        }
      }
      
      return right(vpnRoutedApps);
    } catch (e) {
      return left("Error getting VPN routed apps: $e");
    }
  }

  @override
  Future<Either<String, List<InstalledPackageInfo>>> getDirectRoutedApps() async {
    try {
      final allApps = await getInstalledApplications();
      if (allApps.isLeft()) {
        return left(allApps.getLeft().getOrElse(() => "Failed to get installed apps"));
      }
      
      final directRoutedApps = <InstalledPackageInfo>[];
      final appList = await getRoutingRules();
      
      if (appList.isRight()) {
        final rules = appList.getOrElse(() => <String>[]);
        final prefs = await SharedPrefs.instance;
        final mode = prefs.perAppProxyMode;
        
        for (final app in allApps.getOrElse(() => <InstalledPackageInfo>[])) {
          bool isRouted = false;
          
          if (mode == PerAppProxyMode.include) {
            // In include mode, apps NOT in the list go directly
            isRouted = !rules.contains(app.packageName);
          } else if (mode == PerAppProxyMode.exclude) {
            // In exclude mode, only apps in the list go directly
            isRouted = rules.contains(app.packageName);
          } else {
            // Off mode - no apps go directly
            isRouted = false;
          }
          
          if (isRouted) {
            directRoutedApps.add(app);
          }
        }
      }
      
      return right(directRoutedApps);
    } catch (e) {
      return left("Error getting direct routed apps: $e");
    }
  }

  @override
  Future<Either<String, List<InstalledPackageInfo>>> refreshApplications() async {
    return await _unifiedRepository.getAllInstalledApplications().run();
  }

  @override
  Future<Either<String, Unit>> setDefaultRoute(PerAppProxyMode defaultMode) async {
    try {
      final prefs = await SharedPrefs.instance;
      await prefs.setPerAppProxyMode(defaultMode);
      return right(unit);
    } catch (e) {
      return left("Error setting default route: $e");
    }
  }

  @override
  Future<Either<String, PerAppProxyMode>> getDefaultRoute() async {
    try {
      final prefs = await SharedPrefs.instance;
      return right(prefs.perAppProxyMode);
    } catch (e) {
      return left("Error getting default route: $e");
    }
  }

  @override
  Future<Either<String, Unit>> applyRoutingConfiguration() async {
    try {
      final prefs = await SharedPrefs.instance;
      final mode = prefs.perAppProxyMode;
      
      if (mode == PerAppProxyMode.off) {
        // If off, reset all routing
        return await resetRoutingConfiguration();
      }
      
      final appIds = mode == PerAppProxyMode.include 
          ? prefs.perAppProxyIncludeList 
          : prefs.perAppProxyExcludeList;
      
      final result = await _unifiedRepository.applyRoutingRules(appIds, mode == PerAppProxyMode.include).run();
      return result;
    } catch (e) {
      return left("Error applying routing configuration: $e");
    }
  }

  @override
  Future<Either<String, Unit>> resetRoutingConfiguration() async {
    return await _unifiedRepository.resetRoutingRules().run();
  }
}
