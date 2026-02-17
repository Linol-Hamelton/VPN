import 'package:dartx/dartx.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/widget/adaptive_icon.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/per_app_proxy/overview/per_app_proxy_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

class PerAppProxyPage extends HookConsumerWidget with PresLogger {
  const PerAppProxyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final localizations = MaterialLocalizations.of(context);

    final asyncPackages = ref.watch(installedPackagesInfoProvider);
    final perAppProxyMode = ref.watch(Preferences.perAppProxyMode);
    final perAppProxyList = ref.watch(perAppProxyListProvider);

    final showSystemApps = useState(true);
    final isSearching = useState(false);
    final searchQuery = useState("");
    final selectedCategory = useState<String?>('all');
    final selectAllMode = useState(false);

    // Categories for app grouping
    final categories = {
      'all': t.settings.network.allApps,
      'browsers': t.settings.network.browsers,
      'social': t.settings.network.social,
      'media': t.settings.network.media,
      'productivity': t.settings.network.productivity,
      'games': t.settings.network.games,
    };

    // Categorize apps (basic categorization based on name)
    final categorizedPackages = useMemoized(() {
      if (!asyncPackages.hasValue) return const AsyncData([]);
      
      final packages = asyncPackages.requireValue;
      Map<String, List<InstalledPackageInfo>> result = {
        'browsers': [],
        'social': [],
        'media': [],
        'productivity': [],
        'games': [],
        'other': [],
      };

      for (var pkg in packages) {
        if (pkg.name.toLowerCase().contains('browser') ||
            pkg.name.toLowerCase().contains('chrome') ||
            pkg.name.toLowerCase().contains('firefox') ||
            pkg.name.toLowerCase().contains('edge') ||
            pkg.name.toLowerCase().contains('opera')) {
          result['browsers']!.add(pkg);
        } else if (pkg.name.toLowerCase().contains('facebook') ||
            pkg.name.toLowerCase().contains('instagram') ||
            pkg.name.toLowerCase().contains('twitter') ||
            pkg.name.toLowerCase().contains('whatsapp') ||
            pkg.name.toLowerCase().contains('telegram') ||
            pkg.name.toLowerCase().contains('messenger')) {
          result['social']!.add(pkg);
        } else if (pkg.name.toLowerCase().contains('youtube') ||
            pkg.name.toLowerCase().contains('spotify') ||
            pkg.name.toLowerCase().contains('netflix') ||
            pkg.name.toLowerCase().contains('music') ||
            pkg.name.toLowerCase().contains('video')) {
          result['media']!.add(pkg);
        } else if (pkg.name.toLowerCase().contains('office') ||
            pkg.name.toLowerCase().contains('word') ||
            pkg.name.toLowerCase().contains('excel') ||
            pkg.name.toLowerCase().contains('slack') ||
            pkg.name.toLowerCase().contains('teams') ||
            pkg.name.toLowerCase().contains('mail')) {
          result['productivity']!.add(pkg);
        } else if (pkg.name.toLowerCase().contains('game') ||
            pkg.name.toLowerCase().contains('play') ||
            pkg.name.toLowerCase().contains('steam')) {
          result['games']!.add(pkg);
        } else {
          result['other']!.add(pkg);
        }
      }

      // Combine filtered results based on selection
      if (selectedCategory.value == null || selectedCategory.value == 'all') {
        return AsyncData(packages.where((pkg) {
          if (!showSystemApps.value && pkg.isSystemApp) return false;
          if (!searchQuery.value.isBlank) {
            return pkg.name.toLowerCase().contains(searchQuery.value.toLowerCase());
          }
          return true;
        }).toList());
      } else {
        final filtered = result[selectedCategory.value]?.where((pkg) {
          if (!showSystemApps.value && pkg.isSystemApp) return false;
          if (!searchQuery.value.isBlank) {
            return pkg.name.toLowerCase().contains(searchQuery.value.toLowerCase());
          }
          return true;
        }).toList() ?? [];
        
        return AsyncData(filtered);
      }
    }, [asyncPackages, showSystemApps.value, searchQuery.value, selectedCategory.value]);

    return Scaffold(
      appBar: isSearching.value
          ? AppBar(
              title: TextFormField(
                onChanged: (value) => searchQuery.value = value,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "${localizations.searchFieldLabel}...",
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
              leading: IconButton(
                onPressed: () {
                  searchQuery.value = "";
                  isSearching.value = false;
                },
                icon: const Icon(Icons.close),
                tooltip: localizations.cancelButtonLabel,
              ),
            )
          : AppBar(
              title: Text(t.settings.network.perAppProxyPageTitle),
              actions: [
                IconButton(
                  icon: const Icon(FluentIcons.search_24_regular),
                  onPressed: () => isSearching.value = true,
                  tooltip: localizations.searchFieldLabel,
                ),
                PopupMenuButton(
                  icon: Icon(AdaptiveIcon(context).more),
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        child: Text(
                          showSystemApps.value
                              ? t.settings.network.hideSystemApps
                              : t.settings.network.showSystemApps,
                        ),
                        onTap: () =>
                            showSystemApps.value = !showSystemApps.value,
                      ),
                      PopupMenuItem(
                        child: Text(t.settings.network.selectAll),
                        onTap: () {
                          if (categorizedPackages.hasValue) {
                            final allPackageNames = categorizedPackages.requireValue.map((pkg) => pkg.packageName).toList();
                            ref.read(perAppProxyListProvider.notifier).update(allPackageNames);
                          }
                        },
                      ),
                      PopupMenuItem(
                        child: Text(t.settings.network.clearSelection),
                        onTap: () => ref
                            .read(perAppProxyListProvider.notifier)
                            .update([]),
                      ),
                      PopupMenuItem(
                        child: Text(t.settings.network.invertSelection),
                        onTap: () async {
                          if (categorizedPackages.hasValue) {
                            final currentSelection = ref.read(perAppProxyListProvider);
                            final allPackageNames = categorizedPackages.requireValue.map((pkg) => pkg.packageName).toList();
                            
                            final invertedSelection = allPackageNames.where((pkg) => !currentSelection.contains(pkg)).toList();
                            await ref.read(perAppProxyListProvider.notifier).update(invertedSelection);
                          }
                        },
                      ),
                    ];
                  },
                ),
              ],
            ),
      body: CustomScrollView(
        slivers: [
          // Mode selection header
          SliverPinnedHeader(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Column(
                children: [
                  // Include/Exclude mode toggle
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).cardColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ToggleButtons(
                              direction: Axis.horizontal,
                              constraints: const BoxConstraints.expand(),
                              isSelected: [
                                perAppProxyMode == PerAppProxyMode.include,
                                perAppProxyMode == PerAppProxyMode.exclude,
                              ],
                              onPressed: (index) {
                                final newMode = index == 0 ? PerAppProxyMode.include : PerAppProxyMode.exclude;
                                ref.read(Preferences.perAppProxyMode.notifier).update(newMode);
                              },
                              borderRadius: BorderRadius.circular(12),
                              fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              selectedBorderColor: Theme.of(context).colorScheme.primary,
                              selectedColor: Theme.of(context).colorScheme.onPrimary,
                              color: Theme.of(context).colorScheme.primary,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text(
                                    t.settings.network.includeMode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text(
                                    t.settings.network.excludeMode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Current routing status summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              perAppProxyMode == PerAppProxyMode.include 
                                ? FluentIcons.app_recent_24_regular 
                                : FluentIcons.globe_location_24_regular,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                  children: [
                                    TextSpan(
                                      text: perAppProxyMode == PerAppProxyMode.include
                                          ? '${t.settings.network.selectedApps}: '
                                          : '${t.settings.network.excludedApps}: ',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: '${perAppProxyList.length}'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const Divider(height: 1),
                ],
              ),
            ),
          ),
          
          // Category filter section
          SliverToBoxAdapter(
            child: Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: categories.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: selectedCategory.value == entry.key,
                      onSelected: (selected) {
                        if (selected) {
                          selectedCategory.value = entry.key;
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Main app list
          switch (categorizedPackages) {
            AsyncData(value: final packages) => SliverList.builder(
                itemBuilder: (context, index) {
                  final package = packages[index];
                  final selected =
                      perAppProxyList.contains(package.packageName);
                  return CheckboxListTile(
                    title: Text(
                      package.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          package.packageName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: package.isSystemApp 
                                ? Theme.of(context).colorScheme.surface 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: package.isSystemApp 
                                  ? Theme.of(context).dividerColor 
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            package.isSystemApp 
                                ? t.settings.network.systemAppAbbr 
                                : t.settings.network.userAppAbbr,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: package.isSystemApp 
                                      ? Theme.of(context).colorScheme.primary 
                                      : null,
                                ),
                          ),
                        ),
                      ],
                    ),
                    value: selected,
                    onChanged: (value) async {
                      final List<String> newSelection;
                      if (selected) {
                        newSelection = perAppProxyList
                            .exceptElement(package.packageName)
                            .toList();
                      } else {
                        newSelection = [
                          ...perAppProxyList,
                          package.packageName,
                        ];
                      }
                      await ref
                          .read(perAppProxyListProvider.notifier)
                          .update(newSelection);
                    },
                    secondary: SizedBox(
                      width: 48,
                      height: 48,
                      child: ref
                          .watch(packageIconProvider(package.packageName))
                          .when(
                            data: (data) => Image(image: data),
                            error: (error, _) =>
                                const Icon(FluentIcons.error_circle_24_regular),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                    ),
                  );
                },
                itemCount: packages.length,
              ),
            AsyncLoading() => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
            AsyncError(:final error) =>
              SliverToBoxAdapter(
                child: Center(child: Text('Error: $error')),
              ),
            _ => const SliverToBoxAdapter(
                child: Center(child: Text('No packages found')),
              ),
          },
          
          // Footer buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.settings.network.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Save settings and return
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: Text(t.settings.network.save),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).cardColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ToggleButtons(
                              direction: Axis.horizontal,
                              constraints: const BoxConstraints.expand(),
                              isSelected: [
                                perAppProxyMode == PerAppProxyMode.include,
                                perAppProxyMode == PerAppProxyMode.exclude,
                              ],
                              onPressed: (index) {
                                final newMode = index == 0 ? PerAppProxyMode.include : PerAppProxyMode.exclude;
                                ref.read(Preferences.perAppProxyMode.notifier).update(newMode);
                              },
                              borderRadius: BorderRadius.circular(12),
                              fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              selectedBorderColor: Theme.of(context).colorScheme.primary,
                              selectedColor: Theme.of(context).colorScheme.onPrimary,
                              color: Theme.of(context).colorScheme.primary,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text(
                                    t.settings.network.includeMode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text(
                                    t.settings.network.excludeMode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Current routing status summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              perAppProxyMode == PerAppProxyMode.include 
                                ? FluentIcons.app_recent_24_regular 
                                : FluentIcons.globe_location_24_regular,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                  children: [
                                    TextSpan(
                                      text: perAppProxyMode == PerAppProxyMode.include
                                          ? '${t.settings.network.selectedApps}: '
                                          : '${t.settings.network.excludedApps}: ',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: '${perAppProxyList.length}'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const Divider(height: 1),
                ],
              ),
            ),
          ),
          
          // Category filter section
          SliverToBoxAdapter(
            child: Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: categories.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: selectedCategory.value == entry.key,
                      onSelected: (selected) {
                        if (selected) {
                          selectedCategory.value = entry.key;
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Main app list
          switch (categorizedPackages) {
            AsyncData(value: final packages) => SliverList.builder(
                itemBuilder: (context, index) {
                  final package = packages[index];
                  final selected =
                      perAppProxyList.contains(package.packageName);
                  return CheckboxListTile(
                    title: Text(
                      package.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          package.packageName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: package.isSystemApp 
                                ? Theme.of(context).colorScheme.surface 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: package.isSystemApp 
                                  ? Theme.of(context).dividerColor 
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            package.isSystemApp 
                                ? t.settings.network.systemAppAbbr 
                                : t.settings.network.userAppAbbr,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: package.isSystemApp 
                                      ? Theme.of(context).colorScheme.primary 
                                      : null,
                                ),
                          ),
                        ),
                      ],
                    ),
                    value: selected,
                    onChanged: (value) async {
                      final List<String> newSelection;
                      if (selected) {
                        newSelection = perAppProxyList
                            .exceptElement(package.packageName)
                            .toList();
                      } else {
                        newSelection = [
                          ...perAppProxyList,
                          package.packageName,
                        ];
                      }
                      await ref
                          .read(perAppProxyListProvider.notifier)
                          .update(newSelection);
                    },
                    secondary: SizedBox(
                      width: 48,
                      height: 48,
                      child: ref
                          .watch(packageIconProvider(package.packageName))
                          .when(
                            data: (data) => Image(image: data),
                            error: (error, _) =>
                                const Icon(FluentIcons.error_circle_24_regular),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                    ),
                  );
                },
                itemCount: packages.length,
              ),
            AsyncLoading() => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
            AsyncError(:final error) =>
              SliverToBoxAdapter(
                child: Center(child: Text('Error: $error')),
              ),
            _ => const SliverToBoxAdapter(
                child: Center(child: Text('No packages found')),
              ),
          },
          
          // Footer buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.settings.network.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Save settings and return
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: Text(t.settings.network.save),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

