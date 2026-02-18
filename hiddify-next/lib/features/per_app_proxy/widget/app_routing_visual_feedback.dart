import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/per_app_proxy/api/per_app_proxy_api_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// Widget that displays visual feedback about app routing status
/// Shows which apps are currently going through VPN vs direct connection
class AppRoutingVisualFeedback extends ConsumerWidget {
  const AppRoutingVisualFeedback({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final api = ref.watch(perAppProxyApiProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getRoutingStatus(api),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(t);
        }
        
        if (snapshot.hasError) {
          return _buildErrorCard(t, snapshot.error.toString());
        }

        final data = snapshot.data ?? {};
        final enabled = data['enabled'] ?? false;
        final mode = data['mode'] as PerAppProxyMode?;
        final vpnRoutedCount = data['vpnRoutedCount'] ?? 0;
        final directRoutedCount = data['directRoutedCount'] ?? 0;
        final appCount = data['appCount'] ?? 0;

        if (!enabled) {
          return _buildDisabledCard(t);
        }

        return _buildStatusCard(
          t,
          mode!,
          vpnRoutedCount,
          directRoutedCount,
          appCount,
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getRoutingStatus(dynamic api) async {
    try {
      // Get current routing mode
      final currentMode = await api.getDefaultRoute();
      
      if (currentMode.isLeft()) {
        return {'enabled': false};
      }

      final mode = currentMode.getOrElse(() => PerAppProxyMode.off);
      final enabled = mode != PerAppProxyMode.off;

      if (!enabled) {
        return {'enabled': false};
      }

      // Get routed apps
      final vpnRoutedApps = await api.getVPNRoutedApps();
      final directRoutedApps = await api.getDirectRoutedApps();

      final vpnCount = vpnRoutedApps.isRight() 
          ? vpnRoutedApps.getOrElse(() => []).length 
          : 0;
      final directCount = directRoutedApps.isRight() 
          ? directRoutedApps.getOrElse(() => []).length 
          : 0;

      // Total apps
      final installedApps = await api.getInstalledApplications();
      final appCount = installedApps.isRight() 
          ? installedApps.getOrElse(() => []).length 
          : 0;

      return {
        'enabled': enabled,
        'mode': mode,
        'vpnRoutedCount': vpnCount,
        'directRoutedCount': directCount,
        'appCount': appCount,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Widget _buildLoadingCard(TranslationsEn t) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  FluentIcons.apps_list_detail_24_regular,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Text(
                  t.settings.network.routingStatusTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(t.settings.network.loadingStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(TranslationsEn t, String errorMessage) {
    return Card(
      color: Colors.red[50],
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  FluentIcons.warning_24_filled,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  t.settings.network.routingStatusTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              t.settings.network.statusError,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledCard(TranslationsEn t) {
    return Card(
      color: Colors.grey[100],
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  FluentIcons.shield_checkmark_24_regular,
                  color: Colors.grey[700],
                ),
                const SizedBox(width: 8),
                Text(
                  t.settings.network.routingStatusTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Icon(
              FluentIcons.shield_concept_24_regular,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              t.settings.network.routingDisabled,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    TranslationsEn t,
    PerAppProxyMode mode,
    int vpnRoutedCount,
    int directRoutedCount,
    int appCount,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      FluentIcons.apps_list_detail_24_regular,
                      color: mode == PerAppProxyMode.include 
                          ? Colors.green[700] 
                          : Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.settings.network.routingStatusTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: mode == PerAppProxyMode.include
                        ? Colors.green[100]
                        : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    mode == PerAppProxyMode.include
                        ? t.settings.network.includeMode
                        : t.settings.network.excludeMode,
                    style: TextStyle(
                      color: mode == PerAppProxyMode.include
                          ? Colors.green[800]
                          : Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    icon: FluentIcons.shield_24_filled,
                    label: t.settings.network.vpnRoutedApps,
                    value: vpnRoutedCount.toString(),
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    icon: FluentIcons.globe_location_24_regular,
                    label: t.settings.network.directRoutedApps,
                    value: directRoutedCount.toString(),
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProgressBar(vpnRoutedCount, directRoutedCount, appCount),
            const SizedBox(height: 8),
            Text(
              "${t.settings.network.totalApps}: $appCount",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int vpnRouted, int directRouted, int total) {
    if (total == 0) return const SizedBox.shrink();
    
    final vpnPercentage = (vpnRouted / total * 100).round();
    final directPercentage = (directRouted / total * 100).round();
    final othersPercentage = 100 - vpnPercentage - directPercentage;

    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          if (vpnPercentage > 0) ...[
            Expanded(
              flex: vpnPercentage,
              child: Container(
                color: Colors.green[400],
              ),
            ),
          ],
          if (directPercentage > 0) ...[
            Expanded(
              flex: directPercentage,
              child: Container(
                color: Colors.blue[400],
              ),
            ),
          ],
          if (othersPercentage > 0) ...[
            Expanded(
              flex: othersPercentage,
              child: Container(
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
