import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/api/per_app_proxy_api.dart';
import 'package:hiddify/features/per_app_proxy/data/unified_per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Implementation of the unified API for managing app routing across all platforms
class PerAppProxyApiImpl extends PerAppProxyApi with InfraLogger {
  final UnifiedPerAppProxyRepository _unifiedRepository;

  PerAppProxyApiImpl(this._unifiedRepository);

  Future<PerAppProxyMode> _getMode(SharedPreferences prefs) async {
    final raw = prefs.getString("per_app_proxy_mode") ?? "off";
    return PerAppProxyMode.values.byName(raw);
  }

  @override
  Future<Either<String, List<InstalledPackageInfo>>> getInstalledApplications() async {
    return await _unifiedRepository.getAllInstalledApplications().run();
  }

  @override
  Future<Either<String, List<String>>> getRoutingRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = await _getMode(prefs);
      final appList = mode == PerAppProxyMode.off
          ? <String>[]
          : (mode == PerAppProxyMode.include
              ? (prefs.getStringList("per_app_proxy_include_list") ?? <String>[])
              : (prefs.getStringList("per_app_proxy_exclude_list") ?? <String>[]));
      return right(appList);
    } catch (e) {
      return left("Error getting routing rules: $e");
    }
  }

  @override
  Future<Either<String, Unit>> setRoutingRules(List<String> appIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = await _getMode(prefs);

      if (mode == PerAppProxyMode.off) {
        await prefs.setString("per_app_proxy_mode", PerAppProxyMode.include.name);
        await prefs.setStringList("per_app_proxy_include_list", appIds);
      } else if (mode == PerAppProxyMode.include) {
        await prefs.setStringList("per_app_proxy_include_list", appIds);
      } else {
        await prefs.setStringList("per_app_proxy_exclude_list", appIds);
      }

      final result = await _unifiedRepository
          .applyRoutingRules(appIds, mode == PerAppProxyMode.include)
          .run();
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

      return right(unit);
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

      final updatedRules =
          currentRules.getOrElse(() => <String>[]).where((id) => id != appId).toList();
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
        final prefs = await SharedPreferences.getInstance();
        final mode = await _getMode(prefs);

        for (final app in allApps.getOrElse(() => <InstalledPackageInfo>[])) {
          bool isRouted;
          if (mode == PerAppProxyMode.include) {
            isRouted = rules.contains(app.packageName);
          } else if (mode == PerAppProxyMode.exclude) {
            isRouted = !rules.contains(app.packageName);
          } else {
            isRouted = true;
          }
          if (isRouted) vpnRoutedApps.add(app);
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
        final prefs = await SharedPreferences.getInstance();
        final mode = await _getMode(prefs);

        for (final app in allApps.getOrElse(() => <InstalledPackageInfo>[])) {
          bool isDirect;
          if (mode == PerAppProxyMode.include) {
            isDirect = !rules.contains(app.packageName);
          } else if (mode == PerAppProxyMode.exclude) {
            isDirect = rules.contains(app.packageName);
          } else {
            isDirect = false;
          }
          if (isDirect) directRoutedApps.add(app);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("per_app_proxy_mode", defaultMode.name);
      return right(unit);
    } catch (e) {
      return left("Error setting default route: $e");
    }
  }

  @override
  Future<Either<String, PerAppProxyMode>> getDefaultRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return right(await _getMode(prefs));
    } catch (e) {
      return left("Error getting default route: $e");
    }
  }

  @override
  Future<Either<String, Unit>> applyRoutingConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = await _getMode(prefs);

      if (mode == PerAppProxyMode.off) {
        return await resetRoutingConfiguration();
      }

      final appIds = mode == PerAppProxyMode.include
          ? (prefs.getStringList("per_app_proxy_include_list") ?? <String>[])
          : (prefs.getStringList("per_app_proxy_exclude_list") ?? <String>[]);

      return await _unifiedRepository
          .applyRoutingRules(appIds, mode == PerAppProxyMode.include)
          .run();
    } catch (e) {
      return left("Error applying routing configuration: $e");
    }
  }

  @override
  Future<Either<String, Unit>> resetRoutingConfiguration() async {
    return await _unifiedRepository.resetRoutingRules().run();
  }
}
