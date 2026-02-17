import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/utils/utils.dart';

/// Interface for controlling routing across different desktop platforms
abstract interface class DesktopRoutingController {
  TaskEither<String, Unit> setupAppRouting(List<String> appIds, bool includeMode);
  TaskEither<String, Unit> resetRouting();
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId);
}

class DesktopRoutingControllerImpl
    with InfraLogger
    implements DesktopRoutingController {
  final _methodChannel = const MethodChannel("com.hiddify.app/desktop_routing");

  @override
  TaskEither<String, Unit> setupAppRouting(List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        loggy.debug("Setting up app routing for ${appIds.length} apps in ${includeMode ? 'include' : 'exclude'} mode");
        
        if (Platform.isWindows) {
          return _setupWindowsAppRouting(appIds, includeMode);
        } else if (Platform.isMacOS) {
          return _setupMacOSAppRouting(appIds, includeMode);
        } else if (Platform.isLinux) {
          return _setupLinuxAppRouting(appIds, includeMode);
        } else {
          return left("Unsupported platform for routing");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> resetRouting() {
    return TaskEither(
      () async {
        loggy.debug("Resetting routing configuration");
        
        if (Platform.isWindows) {
          return _resetWindowsRouting();
        } else if (Platform.isMacOS) {
          return _resetMacOSRouting();
        } else if (Platform.isLinux) {
          return _resetLinuxRouting();
        } else {
          return left("Unsupported platform for routing reset");
        }
      },
    );
  }

  @override
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Checking routing status for app: $appId");
        
        // This would typically involve checking the routing table or firewall rules
        // For now, we'll simulate the check
        return right(true);
      },
    );
  }

  /// Windows-specific routing implementation
  TaskEither<String, Unit> _setupWindowsAppRouting(
      List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        try {
          // Call the native layer to set up Windows-specific routing using Windows Filtering Platform (WFP)
          await _methodChannel.invokeMethod('setupWindowsAppRouting', {
            'appIds': appIds,
            'includeMode': includeMode,
          });
          return right(unit);
        } catch (e) {
          return left("Error setting up Windows routing: $e");
        }
      },
    );
  }

  TaskEither<String, Unit> _resetWindowsRouting() {
    return TaskEither(
      () async {
        try {
          await _methodChannel.invokeMethod('resetWindowsRouting');
          return right(unit);
        } catch (e) {
          return left("Error resetting Windows routing: $e");
        }
      },
    );
  }

  /// macOS-specific routing implementation
  TaskEither<String, Unit> _setupMacOSAppRouting(
      List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        try {
          // Call the native layer to set up macOS-specific routing using Network Extension Framework
          await _methodChannel.invokeMethod('setupMacOSAppRouting', {
            'appIds': appIds,
            'includeMode': includeMode,
          });
          return right(unit);
        } catch (e) {
          return left("Error setting up macOS routing: $e");
        }
      },
    );
  }

  TaskEither<String, Unit> _resetMacOSRouting() {
    return TaskEither(
      () async {
        try {
          await _methodChannel.invokeMethod('resetMacOSRouting');
          return right(unit);
        } catch (e) {
          return left("Error resetting macOS routing: $e");
        }
      },
    );
  }

  /// Linux-specific routing implementation
  TaskEither<String, Unit> _setupLinuxAppRouting(
      List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        try {
          // Call the native layer to set up Linux-specific routing using iptables
          await _methodChannel.invokeMethod('setupLinuxAppRouting', {
            'appIds': appIds,
            'includeMode': includeMode,
          });
          return right(unit);
        } catch (e) {
          return left("Error setting up Linux routing: $e");
        }
      },
    );
  }

  TaskEither<String, Unit> _resetLinuxRouting() {
    return TaskEither(
      () async {
        try {
          await _methodChannel.invokeMethod('resetLinuxRouting');
          return right(unit);
        } catch (e) {
          return left("Error resetting Linux routing: $e");
        }
      },
    );
  }
}import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/utils/utils.dart';

/// Interface for controlling routing across different desktop platforms
abstract interface class DesktopRoutingController {
  TaskEither<String, Unit> setupAppRouting(List<String> appIds, bool includeMode);
  TaskEither<String, Unit> resetRouting();
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId);
}

class DesktopRoutingControllerImpl
    with InfraLogger
    implements DesktopRoutingController {
  final _methodChannel = const MethodChannel("com.hiddify.app/desktop_routing");

  @override
  TaskEither<String, Unit> setupAppRouting(List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        loggy.debug("Setting up app routing for ${appIds.length} apps in ${includeMode ? 'include' : 'exclude'} mode");
        
        if (Platform.isWindows) {
          return _setupWindowsAppRouting(appIds, includeMode);
        } else if (Platform.isMacOS) {
          return _setupMacOSAppRouting(appIds, includeMode);
        } else if (Platform.isLinux) {
          return _setupLinuxAppRouting(appIds, includeMode);
        } else {
          return left("Unsupported platform for routing");
        }
      },
    );
  }

  @override
  TaskEither<String, Unit> resetRouting() {
    return TaskEither(
      () async {
        loggy.debug("Resetting routing configuration");
        
        if (Platform.isWindows) {
          return _resetWindowsRouting();
        } else if (Platform.isMacOS) {
          return _resetMacOSRouting();
        } else if (Platform.isLinux) {
          return _resetLinuxRouting();
        } else {
          return left("Unsupported platform for routing reset");
        }
      },
    );
  }

  @override
  TaskEither<String, bool> isAppRoutedThroughVPN(String appId) {
    return TaskEither(
      () async {
        loggy.debug("Checking routing status for app: $appId");
        
        // This would typically involve checking the routing table or firewall rules
        // For now, we'll simulate the check
        return right(true);
      },
    );
  }

  /// Windows-specific routing implementation
  TaskEither<String, Unit> _setupWindowsAppRouting(
      List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        try {
          // Call the native layer to set up Windows-specific routing using Windows Filtering Platform (WFP)
          await _methodChannel.invokeMethod('setupWindowsAppRouting', {
            'appIds': appIds,
            'includeMode': includeMode,
          });
          return right(unit);
        } catch (e) {
          return left("Error setting up Windows routing: $e");
        }
      },
    );
  }

  TaskEither<String, Unit> _resetWindowsRouting() {
    return TaskEither(
      () async {
        try {
          await _methodChannel.invokeMethod('resetWindowsRouting');
          return right(unit);
        } catch (e) {
          return left("Error resetting Windows routing: $e");
        }
      },
    );
  }

  /// macOS-specific routing implementation
  TaskEither<String, Unit> _setupMacOSAppRouting(
      List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        try {
          // Call the native layer to set up macOS-specific routing using Network Extension Framework
          await _methodChannel.invokeMethod('setupMacOSAppRouting', {
            'appIds': appIds,
            'includeMode': includeMode,
          });
          return right(unit);
        } catch (e) {
          return left("Error setting up macOS routing: $e");
        }
      },
    );
  }

  TaskEither<String, Unit> _resetMacOSRouting() {
    return TaskEither(
      () async {
        try {
          await _methodChannel.invokeMethod('resetMacOSRouting');
          return right(unit);
        } catch (e) {
          return left("Error resetting macOS routing: $e");
        }
      },
    );
  }

  /// Linux-specific routing implementation
  TaskEither<String, Unit> _setupLinuxAppRouting(
      List<String> appIds, bool includeMode) {
    return TaskEither(
      () async {
        try {
          // Call the native layer to set up Linux-specific routing using iptables
          await _methodChannel.invokeMethod('setupLinuxAppRouting', {
            'appIds': appIds,
            'includeMode': includeMode,
          });
          return right(unit);
        } catch (e) {
          return left("Error setting up Linux routing: $e");
        }
      },
    );
  }

  TaskEither<String, Unit> _resetLinuxRouting() {
    return TaskEither(
      () async {
        try {
          await _methodChannel.invokeMethod('resetLinuxRouting');
          return right(unit);
        } catch (e) {
          return left("Error resetting Linux routing: $e");
        }
      },
    );
  }
}
