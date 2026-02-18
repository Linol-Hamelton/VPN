import 'package:flutter/material.dart';
import 'package:hiddify/features/per_app_proxy/data/unified_per_app_proxy_data_providers.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_per_app_proxy_notifier.g.dart';

@riverpod
Future<List<InstalledPackageInfo>> installedApplications(
  InstalledApplicationsRef ref,
) async {
  return ref
      .watch(unifiedPerAppProxyRepositoryProvider)
      .getAllInstalledApplications()
      .getOrElse((err) {
        throw err;
      })
      .run();
}

@riverpod
Future<ImageProvider> applicationIcon(
  ApplicationIconRef ref,
  String appId,
) async {
  ref.disposeDelay(const Duration(seconds: 10));
  final bytes = await ref
      .watch(unifiedPerAppProxyRepositoryProvider)
      .getApplicationIcon(appId)
      .getOrElse((err) {
        throw err;
      })
      .run();
  return MemoryImage(bytes);
}

@riverpod
Future<bool> isAppRoutedThroughVPN(
  IsAppRoutedThroughVPNRef ref,
  String appId,
) async {
  return ref
      .watch(unifiedPerAppProxyRepositoryProvider)
      .isAppRoutedThroughVPN(appId)
      .getOrElse((err) {
        throw err;
      })
      .run();
}
