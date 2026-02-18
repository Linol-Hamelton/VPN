import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/router.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/model/stats_entity.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class SimpleHomePage extends HookConsumerWidget {
  const SimpleHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with app title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(FluentIcons.shield_24_filled, size: 24),
                      const Gap(8),
                      Text(
                        t.general.appTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Settings button
                      IconButton(
                        onPressed: () => const SettingsRoute().push(context),
                        icon: const Icon(FluentIcons.settings_24_filled),
                        tooltip: t.settings.pageTitle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Main content area with status card, connection button and action buttons
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Connection Status Card with performance metrics
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Status icon and text
                              Icon(
                                FluentIcons.shield_24_filled,
                                size: 48,
                                color: _getStatusColor(ref),
                              ),
                              const Gap(8),
                              Consumer(
                                builder: (context, ref, child) {
                                  final connectionStatus = ref.watch(connectionNotifierProvider);

                                  return Text(
                                    switch (connectionStatus) {
                                      AsyncData(value: Connected()) => 'CONNECTED',
                                      AsyncData(value: Disconnected()) => 'DISCONNECTED',
                                      AsyncData(value: Connecting()) => 'CONNECTING...',
                                      AsyncError() => 'ERROR',
                                      _ => 'DISCONNECTED',
                                    },
                                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                                          color: _getStatusColor(ref),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  );
                                },
                              ),
                              const Gap(4),
                              Consumer(
                                builder: (context, ref, child) {
                                  final activeProxy = ref.watch(activeProxyNotifierProvider);
                                  final proxyName = activeProxy.valueOrNull?.name ?? 'No VPN Active';
                                  return Text(
                                    proxyName,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  );
                                },
                              ),
                              const Gap(16),
                              
                              // Performance metrics
                              _PerformanceMetricsCard(),
                              
                              // Split tunneling status indicator
                              _SplitTunnelingStatusIndicator(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const Gap(24),
                    
                    // Large Start VPN Button
                    SizedBox(
                      height: 64,
                      child: Consumer(
                        builder: (context, ref, child) {
                          return ElevatedButton.icon(
                            onPressed: () {
                              ref.read(connectionNotifierProvider.notifier).toggleConnection();
                            },
                            icon: Consumer(
                              builder: (context, ref, child) {
                                final connectionStatus = ref.watch(connectionNotifierProvider);
                                final icon = switch (connectionStatus) {
                                  AsyncData(value: Connected()) => FluentIcons.disconnect_24_filled,
                                  AsyncData(value: Disconnected()) || AsyncError() => FluentIcons.connect_24_filled,
                                  AsyncData(value: Connecting()) => FluentIcons.progress_24_filled,
                                  _ => FluentIcons.disconnect_24_filled,
                                };
                                return Icon(icon);
                              },
                            ),
                            label: Consumer(
                              builder: (context, ref, child) {
                                final connectionStatus = ref.watch(connectionNotifierProvider);
                                final label = switch (connectionStatus) {
                                  AsyncData(value: Connected()) => 'STOP VPN',
                                  AsyncData(value: Disconnected()) || AsyncError() => 'START VPN',
                                  AsyncData(value: Connecting()) => 'CONNECTING...',
                                  _ => 'START VPN',
                                };
                                return Text(
                                  label,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getActionButtonColor(ref),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              elevation: 4,
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const Gap(24),
                    
                    // Three main action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Add Profile Button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => const AddProfileRoute().push(context),
                            icon: const Icon(FluentIcons.add_circle_24_filled),
                            label: const Text('Add Profile'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        
                        const Gap(12),
                        
                        // Settings Button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => const SettingsRoute().push(context),
                            icon: const Icon(FluentIcons.settings_24_filled),
                            label: const Text('Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        
                        const Gap(12),
                        
                        // More Options Button
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Show more options menu
                              _showMoreOptions(context, ref);
                            },
                            icon: const Icon(FluentIcons.more_vertical_24_filled),
                            label: const Text(''),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Theme.of(context).colorScheme.outline),
                              padding: const EdgeInsets.all(14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider);
    return switch (connectionStatus) {
      AsyncData(value: Connected()) => Colors.green,
      AsyncData(value: Disconnected()) || AsyncError() => Colors.grey,
      AsyncData(value: Connecting()) => Colors.orange,
      _ => Colors.grey,
    };
  }

  Color _getActionButtonColor(WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider);
    return switch (connectionStatus) {
      AsyncData(value: Connected()) => Colors.red,
      AsyncData(value: Disconnected()) || AsyncError() => Colors.green,
      AsyncData(value: Connecting()) => Colors.orange,
      _ => Colors.grey,
    };
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        80,
        MediaQuery.of(context).size.width,
        150,
      ),
      items: [
        PopupMenuItem(
          value: 'profiles',
          child: Row(
            children: [
              const Icon(FluentIcons.people_24_filled),
              const Gap(8),
              Text('All Profiles'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logs',
          child: Row(
            children: [
              const Icon(FluentIcons.document_text_24_filled),
              const Gap(8),
              Text('Logs'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'stats',
          child: Row(
            children: [
              const Icon(FluentIcons.graph_24_filled),
              const Gap(8),
              Text('Statistics'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'per_app_proxy',
          child: Row(
            children: [
              const Icon(FluentIcons.apps_list_detail_24_filled),
              const Gap(8),
              Text('App Routing'),
            ],
          ),
        ),
      ],
      elevation: 8.0,
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'profiles':
            const ProfilesOverviewRoute().push(context);
            break;
          case 'logs':
            const LogsOverviewRoute().push(context);
            break;
          case 'stats':
            const ProxiesRoute().push(context);
            break;
          case 'per_app_proxy':
            const PerAppProxyRoute().push(context);
            break;
        }
      }
    });
  }
}

// A widget to display performance metrics like download/upload speed and ping
class _PerformanceMetricsCard extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsNotifierProvider);

    return Consumer(
      builder: (context, ref, child) {
        return switch (stats) {
          AsyncData(value: final data) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(FluentIcons.arrow_download_20_filled, size: 18),
                    const Gap(4),
                    Text(
                      _formatBytesPerSecond(data.downlink),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Gap(4),
                    _buildSpeedIndicator(data.downlink / 10000000.0), // Assuming max 10MB/s for scaling
                  ],
                ),
                Column(
                  children: [
                    const Icon(FluentIcons.arrow_upload_20_filled, size: 18),
                    const Gap(4),
                    Text(
                      _formatBytesPerSecond(data.uplink),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Gap(4),
                    _buildSpeedIndicator(data.uplink / 10000000.0), // Assuming max 10MB/s for scaling
                  ],
                ),
                Column(
                  children: [
                    const Icon(FluentIcons.gauge_20_filled, size: 18),
                    const Gap(4),
                    Text(
                      _formatPing(data.ping),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Gap(4),
                    _buildPingIndicator(data.ping / 200.0), // Assuming max 200ms for scaling
                  ],
                ),
              ],
            ),
          AsyncLoading() => const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(FluentIcons.arrow_download_20_filled, size: 18),
                    Gap(4),
                    Text('--', style: TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  children: [
                    Icon(FluentIcons.arrow_upload_20_filled, size: 18),
                    Gap(4),
                    Text('--', style: TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  children: [
                    Icon(FluentIcons.gauge_20_filled, size: 18),
                    Gap(4),
                    Text('--', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
          AsyncError() => const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(FluentIcons.arrow_download_20_filled, size: 18),
                    Gap(4),
                    Text('--', style: TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  children: [
                    Icon(FluentIcons.arrow_upload_20_filled, size: 18),
                    Gap(4),
                    Text('--', style: TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  children: [
                    Icon(FluentIcons.gauge_20_filled, size: 18),
                    Gap(4),
                    Text('--', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
          _ => const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(FluentIcons.arrow_download_20_filled, size: 18),
                    Gap(4),
                    Text('--', style: TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  children: [
                    Icon(FluentIcons.arrow_upload_20_filled, size: 18),
                    Gap(4),
                    Text('--', style: TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  children: [
                    Icon(FluentIcons.gauge_20_filled, size: 18),
                    Gap(4),
                    Text('--', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
        };
      },
    );
  }

  // Helper function to format bytes per second with automatic unit scaling
  String _formatBytesPerSecond(int bytesPerSec) {
    if (bytesPerSec < 1024) {
      return "${bytesPerSec} B/s";
    } else if (bytesPerSec < 1024 * 1024) {
      final kbPerSec = bytesPerSec / 1024;
      return "${kbPerSec < 10 ? kbPerSec.toStringAsFixed(1) : kbPerSec.round()} KB/s";
    } else if (bytesPerSec < 1024 * 1024 * 1024) {
      final mbPerSec = bytesPerSec / (1024 * 1024);
      return "${mbPerSec < 10 ? mbPerSec.toStringAsFixed(1) : mbPerSec.round()} MB/s";
    } else {
      final gbPerSec = bytesPerSec / (1024 * 1024 * 1024);
      return "${gbPerSec < 10 ? gbPerSec.toStringAsFixed(1) : gbPerSec.round()} GB/s";
    }
  }

  // Helper function to format ping with appropriate precision
  String _formatPing(double ping) {
    if (ping < 10) {
      return "${ping.toStringAsFixed(1)} ms";
    } else {
      return "${ping.round()} ms";
    }
  }

  Widget _buildSpeedIndicator(double normalizedValue) {
    int filledBars = (normalizedValue * 5).clamp(0, 5).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Container(
          width: 4,
          height: index < filledBars ? 12 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          color: _getSpeedBarColor(index, filledBars),
        ),
      ),
    );
  }

  Widget _buildPingIndicator(double normalizedValue) {
    int filledBars = (normalizedValue * 5).clamp(0, 5).round();
    // Invert for ping - lower is better
    int actualFilled = 5 - filledBars;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Container(
          width: 4,
          height: index < actualFilled ? 12 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          color: _getPingBarColor(index, actualFilled),
        ),
      ),
    );
  }

  // Color coding for speed bars based on performance thresholds
  Color _getSpeedBarColor(int index, int filledBars) {
    if (index >= filledBars) {
      return Colors.grey; // Unfilled bars are grey
    }
    
    // Determine the intensity based on how filled the bar is
    if (filledBars >= 4) {
      return Colors.green; // Excellent performance (>10 Mbps or >10 MB/s)
    } else if (filledBars >= 3) {
      return Colors.green[600] ?? Colors.green; // Good performance (5-10 Mbps or 1-10 MB/s)
    } else if (filledBars >= 2) {
      return Colors.orange; // Fair performance (1-5 Mbps or 0.1-1 MB/s)
    } else {
      return Colors.red; // Poor performance (<1 Mbps or <0.1 MB/s)
    }
  }

  // Color coding for ping bars based on performance thresholds
  Color _getPingBarColor(int index, int actualFilled) {
    if (index >= actualFilled) {
      return Colors.grey; // Unfilled bars are grey
    }
    
    // Determine the intensity based on ping quality
    if (actualFilled >= 4) {
      return Colors.green; // Excellent latency (< 50ms)
    } else if (actualFilled >= 3) {
      return Colors.green[600] ?? Colors.green; // Good latency (50-100ms)
    } else if (actualFilled >= 2) {
      return Colors.orange; // Fair latency (100-200ms)
    } else {
      return Colors.red; // Poor latency (> 200ms)
    }
  }
}

// Widget to display split tunneling status
class _SplitTunnelingStatusIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perAppProxyMode = ref.watch(Preferences.perAppProxyMode);
    final perAppEnabled = perAppProxyMode.enabled;

    if (!perAppEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.apps_list_detail_24_regular,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const Gap(8),
          Flexible(
            child: Text(
              perAppProxyMode == PerAppProxyMode.include
                  ? 'Include Mode: Split Tunneling Active'
                  : 'Exclude Mode: Split Tunneling Active',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
