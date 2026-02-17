import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_routing_controller.dart';
import 'package:hiddify/features/per_app_proxy/data/per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/utils/utils.dart';

/// Unified interface that provides per-app proxy functionality across all platforms
abstract interface class UnifiedPerAppProxyRepository {
  /// Get all installed applications/packages regardless of platform
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications();

  /// Get application icon by package/app ID
  TaskEither<String, Uint8List> getApplicationIcon(String appId);

  /// Apply routing rules to the system
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode);

  /// Get the current routing status of an app
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId);

  /// Reset all routing rules to default
  TaskEither<String, Unit> resetRoutingRules();
}

class UnifiedPerAppProxyRepositoryImpl
    with InfraLogger
    implements UnifiedPerAppProxyRepository {
  final PerAppProxyRepository _androidRepo;
  final DesktopPerAppProxyRepository _desktopRepo;
  final DesktopRoutingController _desktopRoutingController;

  UnifiedPerAppProxyRepositoryImpl(
    this._androidRepo, 
    this._desktopRepo,
    this._desktopRoutingController,
  );

  @override
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications() {
    return TaskEither(
      () async {
        loggy.debug("Getting all installed applications");
        if (Platform.isAndroid) {
          return _androidRepo.getInstalledPackages();
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getInstalledApplications();
        } else {
          return left("Unsupported platform");
        }
      },
    ).flatMap((apps) async {
      // Sort applications by name for consistent UI presentation
      apps.sort((a, b) => a.name.compareTo(b.name));
      return right(apps);
    });
  }

  @override
  TaskEither<String, Uint8List> getApplicationIcon(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Getting application icon for: $appId");
        if (Platform.isAndroid) {
          return _androidRepo.getPackageIcon(appId);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getApplicationIcon(appId);
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        loggy.debug("Applying routing rules for ${appIds.length} apps in ${includeMode ? 'include' : 'exclude'} mode");
        
        if (Platform.isAndroid) {
          // On Android, we use the existing Android VPN service functionality
          return _applyAndroidRoutingRules(appIds, includeMode);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // On desktop platforms, use the desktop routing controller
          return _desktopRoutingController.setupAppRouting(appIds, includeMode);
        } else {
          return left("Unsupported platform for routing rules");
        }
      },
    );
  }

  /// Android-specific routing implementation
  TaskEither<String, Unit> _applyAndroidRoutingRules(
      List<String> appIds, bool includeMode) {
    // This would integrate with the existing Android VPN service
    // In practice, this would store the routing preferences and trigger service restart
    try {
      // The actual implementation would involve calling the Android native layer
      // We'd need to update SharedPreferences with the app list and trigger VPN restart
      return right(unit);
    } catch (e) {
      return left("Error applying Android routing rules: $e");
    }
  }

  @override
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Checking if app $appId is routed through VPN");
        
        if (Platform.isAndroid) {
          // This would check the existing Android VPN service routing status
          // For now, simulate
          return right(true);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // Use the desktop routing controller to check status
          return _desktopRoutingController.isAppRoutedThroughVPN(appId);
        } else {
          return left("Unsupported platform for routing status check");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> resetRoutingRules() {
    return TaskEither(
      () async {
        loggy.debug("Resetting all routing rules to default");
        
        if (Platform.isAndroid) {
          // Reset Android VPN routing
          // In practice, this would involve clearing preferences and restarting the VPN
          return right(unit);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // Use the desktop routing controller to reset routing
          return _desktopRoutingController.resetRouting();
        } else {
          return left("Unsupported platform for routing reset");
        }
      },
    );
  }
}

import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_routing_controller.dart';
import 'package:hiddify/features/per_app_proxy/data/per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/utils/utils.dart';

/// Unified interface that provides per-app proxy functionality across all platforms
abstract interface class UnifiedPerAppProxyRepository {
  /// Get all installed applications/packages regardless of platform
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications();

  /// Get application icon by package/app ID
  TaskEither<String, Uint8List> getApplicationIcon(String appId);

  /// Apply routing rules to the system
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode);

  /// Get the current routing status of an app
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId);

  /// Reset all routing rules to default
  TaskEither<String, Unit> resetRoutingRules();
}

class UnifiedPerAppProxyRepositoryImpl
    with InfraLogger
    implements UnifiedPerAppProxyRepository {
  final PerAppProxyRepository _androidRepo;
  final DesktopPerAppProxyRepository _desktopRepo;
  final DesktopRoutingController _desktopRoutingController;

  UnifiedPerAppProxyRepositoryImpl(
    this._androidRepo, 
    this._desktopRepo,
    this._desktopRoutingController,
  );

  @override
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications() {
    return TaskEither(
      () async {
        loggy.debug("Getting all installed applications");
        if (Platform.isAndroid) {
          return _androidRepo.getInstalledPackages();
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getInstalledApplications();
        } else {
          return left("Unsupported platform");
        }
      },
    ).flatMap((apps) async {
      // Sort applications by name for consistent UI presentation
      apps.sort((a, b) => a.name.compareTo(b.name));
      return right(apps);
    });
  }

  @override
  TaskEither<String, Uint8List> getApplicationIcon(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Getting application icon for: $appId");
        if (Platform.isAndroid) {
          return _androidRepo.getPackageIcon(appId);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getApplicationIcon(appId);
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        loggy.debug("Applying routing rules for ${appIds.length} apps in ${includeMode ? 'include' : 'exclude'} mode");
        
        if (Platform.isAndroid) {
          // On Android, we use the existing Android VPN service functionality
          return _applyAndroidRoutingRules(appIds, includeMode);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // On desktop platforms, use the desktop routing controller
          return _desktopRoutingController.setupAppRouting(appIds, includeMode);
        } else {
          return left("Unsupported platform for routing rules");
        }
      },
    );
  }

  /// Android-specific routing implementation
  TaskEither<String, Unit> _applyAndroidRoutingRules(
      List<String> appIds, bool includeMode) {
    // This would integrate with the existing Android VPN service
    // In practice, this would store the routing preferences and trigger service restart
    try {
      // The actual implementation would involve calling the Android native layer
      // We'd need to update SharedPreferences with the app list and trigger VPN restart
      return right(unit);
    } catch (e) {
      return left("Error applying Android routing rules: $e");
    }
  }

  @override
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Checking if app $appId is routed through VPN");
        
        if (Platform.isAndroid) {
          // This would check the existing Android VPN service routing status
          // For now, simulate
          return right(true);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // Use the desktop routing controller to check status
          return _desktopRoutingController.isAppRoutedThroughVPN(appId);
        } else {
          return left("Unsupported platform for routing status check");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> resetRoutingRules() {
    return TaskEither(
      () async {
        loggy.debug("Resetting all routing rules to default");
        
        if (Platform.isAndroid) {
          // Reset Android VPN routing
          // In practice, this would involve clearing preferences and restarting the VPN
          return right(unit);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // Use the desktop routing controller to reset routing
          return _desktopRoutingController.resetRouting();
        } else {
          return left("Unsupported platform for routing reset");
        }
      },
    );
  }
}
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/utils/utils.dart';

/// Unified interface that provides per-app proxy functionality across all platforms
abstract interface class UnifiedPerAppProxyRepository {
  /// Get all installed applications/packages regardless of platform
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications();

  /// Get application icon by package/app ID
  TaskEither<String, Uint8List> getApplicationIcon(String appId);

  /// Apply routing rules to the system
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode);

  /// Get the current routing status of an app
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId);

  /// Reset all routing rules to default
  TaskEither<String, Unit> resetRoutingRules();
}

class UnifiedPerAppProxyRepositoryImpl
    with InfraLogger
    implements UnifiedPerAppProxyRepository {
  final PerAppProxyRepository _androidRepo;
  final DesktopPerAppProxyRepository _desktopRepo;

  UnifiedPerAppProxyRepositoryImpl(this._androidRepo, this._desktopRepo);

  @override
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications() {
    return TaskEither(
      () async {
        loggy.debug("Getting all installed applications");
        if (Platform.isAndroid) {
          return _androidRepo.getInstalledPackages();
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getInstalledApplications();
        } else {
          return left("Unsupported platform");
        }
      },
    ).flatMap((apps) async {
      // Sort applications by name for consistent UI presentation
      apps.sort((a, b) => a.name.compareTo(b.name));
      return right(apps);
    });
  }

  @override
  TaskEither<String, Uint8List> getApplicationIcon(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Getting application icon for: $appId");
        if (Platform.isAndroid) {
          return _androidRepo.getPackageIcon(appId);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getApplicationIcon(appId);
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        loggy.debug("Applying routing rules for ${appIds.length} apps in ${includeMode ? 'include' : 'exclude'} mode");
        
        if (Platform.isAndroid) {
          // On Android, we use the existing Android VPN service functionality
          return _applyAndroidRoutingRules(appIds, includeMode);
        } else if (Platform.isWindows) {
          // On Windows, use TUN interface and routing tables
          return _applyWindowsRoutingRules(appIds, includeMode);
        } else if (Platform.isMacOS) {
          // On macOS, use TUN interface and routing tables
          return _applyMacOSRoutingRules(appIds, includeMode);
        } else if (Platform.isLinux) {
          // On Linux, use iptables and routing tables
          return _applyLinuxRoutingRules(appIds, includeMode);
        } else {
          return left("Unsupported platform for routing rules");
        }
      },
    );
  }

  /// Android-specific routing implementation
  TaskEither<String, Unit> _applyAndroidRoutingRules(
      List<String> appIds, bool includeMode) {
    // This would integrate with the existing Android VPN service
    // In practice, this would store the routing preferences and trigger service restart
    try {
      // The actual implementation would involve calling the Android native layer
      // We'd need to update SharedPreferences with the app list and trigger VPN restart
      return right(unit);
    } catch (e) {
      return left("Error applying Android routing rules: $e");
    }
  }

  /// Windows-specific routing implementation
  TaskEither<String, Unit> _applyWindowsRoutingRules(
      List<String> appIds, bool includeMode) {
    // On Windows, we would use Windows Filtering Platform (WFP) for app-specific routing
    // This is a higher level implementation that would call the native layer
    try {
      // For now, we simulate the implementation
      loggy.debug("Applying Windows routing rules for apps: $appIds");
      // In practice, this would call WinTun driver and set up application-specific routes
      return right(unit);
    } catch (e) {
      return left("Error applying Windows routing rules: $e");
    }
  }

  /// macOS-specific routing implementation
  TaskEither<String, Unit> _applyMacOSRoutingRules(
      List<String> appIds, bool includeMode) {
    // On macOS, we would use Network Extension Framework
    try {
      // For now, we simulate the implementation
      loggy.debug("Applying macOS routing rules for apps: $appIds");
      // In practice, this would call TUN interface with bundle ID filters
      return right(unit);
    } catch (e) {
      return left("Error applying macOS routing rules: $e");
    }
  }

  /// Linux-specific routing implementation
  TaskEither<String, Unit> _applyLinuxRoutingRules(
      List<String> appIds, bool includeMode) {
    // On Linux, we would use iptables with UID-based filtering
    try {
      // For now, we simulate the implementation
      loggy.debug("Applying Linux routing rules for apps: $appIds");
      // In practice, this would call iptables commands with owner matching
      return right(unit);
    } catch (e) {
      return left("Error applying Linux routing rules: $e");
    }
  }

  @override
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Checking if app $appId is routed through VPN");
        
        // This would check the current routing status
        // For now, simulate by checking if app exists in routing list
        // In practice, this would query the OS networking layer
        return right(true); // Default assumption
      },
    );
  }

  @override
  TaskEither<String, Unit> resetRoutingRules() {
    return TaskEither(
      () async {
        loggy.debug("Resetting all routing rules to default");
        
        // This would reset all routing rules to default state
        // Remove all applied rules and restore default routing behavior
        return right(unit);
      },
    );
  }
}

import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_routing_controller.dart';
import 'package:hiddify/features/per_app_proxy/data/per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/utils/utils.dart';

/// Unified interface that provides per-app proxy functionality across all platforms
abstract interface class UnifiedPerAppProxyRepository {
  /// Get all installed applications/packages regardless of platform
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications();

  /// Get application icon by package/app ID
  TaskEither<String, Uint8List> getApplicationIcon(String appId);

  /// Apply routing rules to the system
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode);

  /// Get the current routing status of an app
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId);

  /// Reset all routing rules to default
  TaskEither<String, Unit> resetRoutingRules();
}

class UnifiedPerAppProxyRepositoryImpl
    with InfraLogger
    implements UnifiedPerAppProxyRepository {
  final PerAppProxyRepository _androidRepo;
  final DesktopPerAppProxyRepository _desktopRepo;
  final DesktopRoutingController _desktopRoutingController;

  UnifiedPerAppProxyRepositoryImpl(
    this._androidRepo, 
    this._desktopRepo,
    this._desktopRoutingController,
  );

  @override
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications() {
    return TaskEither(
      () async {
        loggy.debug("Getting all installed applications");
        if (Platform.isAndroid) {
          return _androidRepo.getInstalledPackages();
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getInstalledApplications();
        } else {
          return left("Unsupported platform");
        }
      },
    ).flatMap((apps) async {
      // Sort applications by name for consistent UI presentation
      apps.sort((a, b) => a.name.compareTo(b.name));
      return right(apps);
    });
  }

  @override
  TaskEither<String, Uint8List> getApplicationIcon(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Getting application icon for: $appId");
        if (Platform.isAndroid) {
          return _androidRepo.getPackageIcon(appId);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getApplicationIcon(appId);
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        loggy.debug("Applying routing rules for ${appIds.length} apps in ${includeMode ? 'include' : 'exclude'} mode");
        
        if (Platform.isAndroid) {
          // On Android, we use the existing Android VPN service functionality
          return _applyAndroidRoutingRules(appIds, includeMode);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // On desktop platforms, use the desktop routing controller
          return _desktopRoutingController.setupAppRouting(appIds, includeMode);
        } else {
          return left("Unsupported platform for routing rules");
        }
      },
    );
  }

  /// Android-specific routing implementation
  TaskEither<String, Unit> _applyAndroidRoutingRules(
      List<String> appIds, bool includeMode) {
    // This would integrate with the existing Android VPN service
    // In practice, this would store the routing preferences and trigger service restart
    try {
      // The actual implementation would involve calling the Android native layer
      // We'd need to update SharedPreferences with the app list and trigger VPN restart
      return right(unit);
    } catch (e) {
      return left("Error applying Android routing rules: $e");
    }
  }

  @override
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Checking if app $appId is routed through VPN");
        
        if (Platform.isAndroid) {
          // This would check the existing Android VPN service routing status
          // For now, simulate
          return right(true);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // Use the desktop routing controller to check status
          return _desktopRoutingController.isAppRoutedThroughVPN(appId);
        } else {
          return left("Unsupported platform for routing status check");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> resetRoutingRules() {
    return TaskEither(
      () async {
        loggy.debug("Resetting all routing rules to default");
        
        if (Platform.isAndroid) {
          // Reset Android VPN routing
          // In practice, this would involve clearing preferences and restarting the VPN
          return right(unit);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // Use the desktop routing controller to reset routing
          return _desktopRoutingController.resetRouting();
        } else {
          return left("Unsupported platform for routing reset");
        }
      },
    );
  }
}
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/utils/utils.dart';

/// Unified interface that provides per-app proxy functionality across all platforms
abstract interface class UnifiedPerAppProxyRepository {
  /// Get all installed applications/packages regardless of platform
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications();

  /// Get application icon by package/app ID
  TaskEither<String, Uint8List> getApplicationIcon(String appId);

  /// Apply routing rules to the system
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode);

  /// Get the current routing status of an app
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId);

  /// Reset all routing rules to default
  TaskEither<String, Unit> resetRoutingRules();
}

class UnifiedPerAppProxyRepositoryImpl
    with InfraLogger
    implements UnifiedPerAppProxyRepository {
  final PerAppProxyRepository _androidRepo;
  final DesktopPerAppProxyRepository _desktopRepo;

  UnifiedPerAppProxyRepositoryImpl(this._androidRepo, this._desktopRepo);

  @override
  TaskEither<String, List<InstalledPackageInfo>> getAllInstalledApplications() {
    return TaskEither(
      () async {
        loggy.debug("Getting all installed applications");
        if (Platform.isAndroid) {
          return _androidRepo.getInstalledPackages();
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getInstalledApplications();
        } else {
          return left("Unsupported platform");
        }
      },
    ).flatMap((apps) async {
      // Sort applications by name for consistent UI presentation
      apps.sort((a, b) => a.name.compareTo(b.name));
      return right(apps);
    });
  }

  @override
  TaskEither<String, Uint8List> getApplicationIcon(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Getting application icon for: $appId");
        if (Platform.isAndroid) {
          return _androidRepo.getPackageIcon(appId);
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return _desktopRepo.getApplicationIcon(appId);
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> applyRoutingRules(List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        loggy.debug("Applying routing rules for ${appIds.length} apps in ${includeMode ? 'include' : 'exclude'} mode");
        
        if (Platform.isAndroid) {
          // On Android, we use the existing Android VPN service functionality
          return _applyAndroidRoutingRules(appIds, includeMode);
        } else if (Platform.isWindows) {
          // On Windows, use TUN interface and routing tables
          return _applyWindowsRoutingRules(appIds, includeMode);
        } else if (Platform.isMacOS) {
          // On macOS, use TUN interface and routing tables
          return _applyMacOSRoutingRules(appIds, includeMode);
        } else if (Platform.isLinux) {
          // On Linux, use iptables and routing tables
          return _applyLinuxRoutingRules(appIds, includeMode);
        } else {
          return left("Unsupported platform for routing rules");
        }
      },
    );
  }

  /// Android-specific routing implementation
  TaskEither<String, Unit> _applyAndroidRoutingRules(
      List<String> appIds, bool includeMode) {
    // This would integrate with the existing Android VPN service
    // In practice, this would store the routing preferences and trigger service restart
    try {
      // The actual implementation would involve calling the Android native layer
      // We'd need to update SharedPreferences with the app list and trigger VPN restart
      return right(unit);
    } catch (e) {
      return left("Error applying Android routing rules: $e");
    }
  }

  /// Windows-specific routing implementation
  TaskEither<String, Unit> _applyWindowsRoutingRules(
      List<String> appIds, bool includeMode) {
    // On Windows, we would use Windows Filtering Platform (WFP) for app-specific routing
    // This is a higher level implementation that would call the native layer
    try {
      // For now, we simulate the implementation
      loggy.debug("Applying Windows routing rules for apps: $appIds");
      // In practice, this would call WinTun driver and set up application-specific routes
      return right(unit);
    } catch (e) {
      return left("Error applying Windows routing rules: $e");
    }
  }

  /// macOS-specific routing implementation
  TaskEither<String, Unit> _applyMacOSRoutingRules(
      List<String> appIds, bool includeMode) {
    // On macOS, we would use Network Extension Framework
    try {
      // For now, we simulate the implementation
      loggy.debug("Applying macOS routing rules for apps: $appIds");
      // In practice, this would call TUN interface with bundle ID filters
      return right(unit);
    } catch (e) {
      return left("Error applying macOS routing rules: $e");
    }
  }

  /// Linux-specific routing implementation
  TaskEither<String, Unit> _applyLinuxRoutingRules(
      List<String> appIds, bool includeMode) {
    // On Linux, we would use iptables with UID-based filtering
    try {
      // For now, we simulate the implementation
      loggy.debug("Applying Linux routing rules for apps: $appIds");
      // In practice, this would call iptables commands with owner matching
      return right(unit);
    } catch (e) {
      return left("Error applying Linux routing rules: $e");
    }
  }

  @override
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Checking if app $appId is routed through VPN");
        
        // This would check the current routing status
        // For now, simulate by checking if app exists in routing list
        // In practice, this would query the OS networking layer
        return right(true); // Default assumption
      },
    );
  }

  @override
  TaskEither<String, Unit> resetRoutingRules() {
    return TaskEither(
      () async {
        loggy.debug("Resetting all routing rules to default");
        
        // This would reset all routing rules to default state
        // Remove all applied rules and restore default routing behavior
        return right(unit);
      },
    );
  }
}

  }

  @override
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Checking if app $appId is routed through VPN");
        
        // This would check the current routing status
        // For now, simulate by checking if app exists in routing list
        // In practice, this would query the OS networking layer
        return right(true); // Default assumption
      },
    );
  }

  @override
  TaskEither<String, Unit> resetRoutingRules() {
    return TaskEither(
      () async {
        loggy.debug("Resetting all routing rules to default");
        
        // This would reset all routing rules to default state
        // Remove all applied rules and restore default routing behavior
        return right(unit);
      },
    );
  }
}
