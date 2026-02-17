import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/utils/utils.dart';

abstract interface class DesktopPerAppProxyRepository {
  TaskEither<String, List<InstalledPackageInfo>> getInstalledApplications();
  TaskEither<String, Uint8List> getApplicationIcon(String appId);
}

class DesktopPerAppProxyRepositoryImpl
    with InfraLogger
    implements DesktopPerAppProxyRepository {
  final _methodChannel = const MethodChannel("com.hiddify.app/desktop_platform");

  @override
  TaskEither<String, List<InstalledPackageInfo>> getInstalledApplications() {
    return TaskEither(
      () async {
        loggy.debug("getting installed applications info");
        
        if (Platform.isWindows) {
          return _getWindowsApplications();
        } else if (Platform.isMacOS) {
          return _getMacOSApplications();
        } else if (Platform.isLinux) {
          return _getLinuxApplications();
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  @override
  TaskEither<String, Uint8List> getApplicationIcon(String appId) {
    return TaskEither(
      () async {
        loggy.debug("getting application [$appId] icon");
        
        if (Platform.isWindows) {
          return _getWindowsApplicationIcon(appId);
        } else if (Platform.isMacOS) {
          return _getMacOSApplicationIcon(appId);
        } else if (Platform.isLinux) {
          return _getLinuxApplicationIcon(appId);
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  // Windows implementation
  TaskEither<String, List<InstalledPackageInfo>> _getWindowsApplications() {
    return TaskEither(
      () async {
        try {
          // On Windows, we look for installed programs in registry and Program Files
          const programFiles = r'C:\Program Files';
          const programFilesX86 = r'C:\Program Files (x86)';
          
          final apps = <InstalledPackageInfo>[];
          
          // Get apps from Program Files
          await _scanWindowsPrograms(programFiles, apps);
          await _scanWindowsPrograms(programFilesX86, apps);
          
          return right(apps);
        } catch (e) {
          return left("Error getting Windows applications: $e");
        }
      },
    );
  }

  Future<void> _scanWindowsPrograms(String directory, List<InstalledPackageInfo> apps) async {
    try {
      if (await Directory(directory).exists()) {
        final dir = Directory(directory);
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            final dirName = entity.path.split('\\').last;
            // Look for common executable files in common app directories
            final executables = await _findExecutables(entity.path);
            for (final exe in executables) {
              apps.add(InstalledPackageInfo(
                packageName: exe,
                name: dirName,
                isSystemApp: _isWindowsSystemApp(dirName),
              ));
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors scanning individual directories
    }
  }

  Future<List<String>> _findExecutables(String directory) async {
    final executables = <String>[];
    try {
      if (await Directory(directory).exists()) {
        await for (final entity in Directory(directory).list(recursive: true)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.exe')) {
            executables.add(entity.path);
            if (executables.length >= 5) break; // Limit to first few to improve performance
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return executables;
  }

  bool _isWindowsSystemApp(String appName) {
    const systemApps = {
      'Windows',
      'Microsoft',
      'Windows Defender',
      'Security Center'
    };
    return systemApps.any((sysApp) => appName.toLowerCase().contains(sysApp.toLowerCase()));
  }

  TaskEither<String, Uint8List> _getWindowsApplicationIcon(String appId) {
    return TaskEither(
      () async {
        try {
          // For Windows, we could extract icon from the executable
          // This is a simplified approach - in practice, more sophisticated icon extraction would be needed
          if (await File(appId).exists()) {
            // Would use a Windows-specific library to extract icons
            // For now, return a placeholder
            return left("Icon extraction not implemented for Windows");
          }
          return left("Application not found: $appId");
        } catch (e) {
          return left("Error getting Windows application icon: $e");
        }
      },
    );
  }

  // macOS implementation
  TaskEither<String, List<InstalledPackageInfo>> _getMacOSApplications() {
    return TaskEither(
      () async {
        try {
          const applicationsDir = '/Applications';
          const userApplicationsDir = '/Users/\$USER/Applications';
          
          final apps = <InstalledPackageInfo>[];
          
          // Scan Applications directory
          await _scanMacOSApplications(applicationsDir, apps);
          
          // Scan user Applications directory
          final userAppsDir = userApplicationsDir.replaceAll('\$USER', Platform.environment['USERNAME'] ?? '');
          await _scanMacOSApplications(userAppsDir, apps);
          
          return right(apps);
        } catch (e) {
          return left("Error getting macOS applications: $e");
        }
      },
    );
  }

  Future<void> _scanMacOSApplications(String directory, List<InstalledPackageInfo> apps) async {
    try {
      if (await Directory(directory).exists()) {
        await for (final entity in Directory(directory).list()) {
          if (entity is Directory && entity.path.endsWith('.app')) {
            final appName = entity.path.split('/').last.replaceAll('.app', '');
            final bundleId = await _getAppBundleId(entity.path);
            
            apps.add(InstalledPackageInfo(
              packageName: bundleId.isEmpty ? entity.path : bundleId,
              name: appName,
              isSystemApp: _isMacOSSystemApp(appName),
            ));
          }
        }
      }
    } catch (e) {
      // Ignore errors scanning individual directories
    }
  }

  Future<String> _getAppBundleId(String appPath) async {
    try {
      final infoPlistPath = '$appPath/Contents/Info.plist';
      if (await File(infoPlistPath).exists()) {
        // Parse the plist file to get bundle ID
        // This would require a plist parsing library
        // For now we return empty string to indicate we couldn't parse it
        return '';
      }
    } catch (e) {
      // Ignore errors
    }
    return '';
  }

  bool _isMacOSSystemApp(String appName) {
    const systemApps = {
      'Finder',
      'Terminal',
      'Safari',
      'System Preferences',
      'Activity Monitor',
      'Console',
      'Disk Utility'
    };
    return systemApps.any((sysApp) => sysApp.toLowerCase() == appName.toLowerCase());
  }

  TaskEither<String, Uint8List> _getMacOSApplicationIcon(String appId) {
    return TaskEither(
      () async {
        try {
          // Try to find the app in standard locations
          final possiblePaths = [
            '/Applications/$appId.app',
            '/Users/\$USER/Applications/$appId.app',
            '/System/Applications/$appId.app',
          ].map((path) => path.replaceAll('\$USER', Platform.environment['USERNAME'] ?? ''));
          
          for (final path in possiblePaths) {
            if (await Directory(path).exists()) {
              final iconPath = '$path/Contents/Resources/$appId.icns';
              if (await File(iconPath).exists()) {
                final bytes = await File(iconPath).readAsBytes();
                return right(bytes);
              }
              // Try alternative icon names
              final contentsDir = Directory('$path/Contents/Resources');
              if (await contentsDir.exists()) {
                await for (final entity in contentsDir.list()) {
                  if (entity.path.toLowerCase().endsWith('.icns')) {
                    final bytes = await File(entity.path).readAsBytes();
                    return right(bytes);
                  }
                }
              }
            }
          }
          return left("Icon not found for: $appId");
        } catch (e) {
          return left("Error getting macOS application icon: $e");
        }
      },
    );
  }

  // Linux implementation
  TaskEither<String, List<InstalledPackageInfo>> _getLinuxApplications() {
    return TaskEither(
      () async {
        try {
          final apps = <InstalledPackageInfo>[];
          
          // Scan common desktop file locations
          const desktopDirs = [
            '/usr/share/applications/',
            '/usr/local/share/applications/',
            '~/.local/share/applications/',
          ];
          
          for (final dirPath in desktopDirs) {
            final expandedPath = _expandHomePath(dirPath);
            if (expandedPath != null && await Directory(expandedPath).exists()) {
              await _scanLinuxDesktopFiles(expandedPath, apps);
            }
          }
          
          return right(apps);
        } catch (e) {
          return left("Error getting Linux applications: $e");
        }
      },
    );
  }

  String? _expandHomePath(String path) {
    if (path.startsWith('~')) {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        return path.replaceFirst('~', homeDir);
      }
      return null;
    }
    return path;
  }

  Future<void> _scanLinuxDesktopFiles(String directory, List<InstalledPackageInfo> apps) async {
    try {
      if (await Directory(directory).exists()) {
        await for (final entity in Directory(directory).list()) {
          if (entity is File && entity.path.endsWith('.desktop')) {
            await _parseDesktopFile(entity.path, apps);
          }
        }
      }
    } catch (e) {
      // Ignore errors scanning individual directories
    }
  }

  Future<void> _parseDesktopFile(String filePath, List<InstalledPackageInfo> apps) async {
    try {
      final lines = await File(filePath).readAsLines();
      String? execLine, nameLine, iconLine;
      
      for (final line in lines) {
        if (line.startsWith('Exec=')) {
          execLine = line.substring(5);
        } else if (line.startsWith('Name=')) {
          nameLine = line.substring(5);
        } else if (line.startsWith('Icon=')) {
          iconLine = line.substring(5);
        } else if (line.startsWith('[Desktop Entry]')) {
          execLine = nameLine = iconLine = null;
        }
      }
      
      if (nameLine != null && execLine != null) {
        final packageName = iconLine ?? execLine.split('/').last.split(' ').first;
        apps.add(InstalledPackageInfo(
          packageName: packageName,
          name: nameLine,
          isSystemApp: _isLinuxSystemApp(nameLine),
        ));
      }
    } catch (e) {
      // Ignore errors parsing individual files
    }
  }

  bool _isLinuxSystemApp(String appName) {
    const systemApps = {
      'gnome',
      'kde',
      'system',
      'settings',
      'terminal',
      'file manager',
      'calculator',
      'clock',
      'software'
    };
    final lowerAppName = appName.toLowerCase();
    return systemApps.any((sysApp) => lowerAppName.contains(sysApp));
  }

  TaskEither<String, Uint8List> _getLinuxApplicationIcon(String appId) {
    return TaskEither(
      () async {
        try {
          // Look for icon in standard icon theme locations
          const iconThemes = [
            '/usr/share/icons/hicolor/256x256/apps/',
            '/usr/share/icons/hicolor/128x128/apps/',
            '/usr/share/icons/hicolor/64x64/apps/',
            '/usr/local/share/icons/hicolor/256x256/apps/',
            '~/.local/share/icons/hicolor/256x256/apps/',
          ];
          
          for (final themePath in iconThemes) {
            final expandedPath = _expandHomePath(themePath);
            if (expandedPath != null && await Directory(expandedPath).exists()) {
              final possibleIcons = [
                '$expandedPath/$appId.png',
                '$expandedPath/${appId.replaceAll('.', '-')}.png',
                '$expandedPath/${appId.replaceAll(' ', '-')}.png',
                '$expandedPath/$appId.svg',
                '$expandedPath/${appId.replaceAll('.', '-')}.svg',
                '$expandedPath/${appId.replaceAll(' ', '-')}.svg',
              ];
              
              for (final iconPath in possibleIcons) {
                if (await File(iconPath).exists()) {
                  final bytes = await File(iconPath).readAsBytes();
                  return right(bytes);
                }
              }
            }
          }
          
          return left("Icon not found for: $appId");
        } catch (e) {
          return left("Error getting Linux application icon: $e");
        }
      },
    );
  }
}
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/utils/utils.dart';

abstract interface class DesktopPerAppProxyRepository {
  TaskEither<String, List<InstalledPackageInfo>> getInstalledApplications();
  TaskEither<String, Uint8List> getApplicationIcon(String appId);
}

class DesktopPerAppProxyRepositoryImpl
    with InfraLogger
    implements DesktopPerAppProxyRepository {
  final _methodChannel = const MethodChannel("com.hiddify.app/desktop_platform");

  @override
  TaskEither<String, List<InstalledPackageInfo>> getInstalledApplications() {
    return TaskEither(
      () async {
        loggy.debug("getting installed applications info");
        
        if (Platform.isWindows) {
          return _getWindowsApplications();
        } else if (Platform.isMacOS) {
          return _getMacOSApplications();
        } else if (Platform.isLinux) {
          return _getLinuxApplications();
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  @override
  TaskEither<String, Uint8List> getApplicationIcon(String appId) {
    return TaskEither(
      () async {
        loggy.debug("getting application [$appId] icon");
        
        if (Platform.isWindows) {
          return _getWindowsApplicationIcon(appId);
        } else if (Platform.isMacOS) {
          return _getMacOSApplicationIcon(appId);
        } else if (Platform.isLinux) {
          return _getLinuxApplicationIcon(appId);
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  // Windows implementation
  TaskEither<String, List<InstalledPackageInfo>> _getWindowsApplications() {
    return TaskEither(
      () async {
        try {
          // On Windows, we look for installed programs in registry and Program Files
          const programFiles = r'C:\Program Files';
          const programFilesX86 = r'C:\Program Files (x86)';
          
          final apps = <InstalledPackageInfo>[];
          
          // Get apps from Program Files
          await _scanWindowsPrograms(programFiles, apps);
          await _scanWindowsPrograms(programFilesX86, apps);
          
          return right(apps);
        } catch (e) {
          return left("Error getting Windows applications: $e");
        }
      },
    );
  }

  Future<void> _scanWindowsPrograms(String directory, List<InstalledPackageInfo> apps) async {
    try {
      if (await Directory(directory).exists()) {
        final dir = Directory(directory);
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            final dirName = entity.path.split('\\').last;
            // Look for common executable files in common app directories
            final executables = await _findExecutables(entity.path);
            for (final exe in executables) {
              apps.add(InstalledPackageInfo(
                packageName: exe,
                name: dirName,
                isSystemApp: _isWindowsSystemApp(dirName),
              ));
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors scanning individual directories
    }
  }

  Future<List<String>> _findExecutables(String directory) async {
    final executables = <String>[];
    try {
      if (await Directory(directory).exists()) {
        await for (final entity in Directory(directory).list(recursive: true)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.exe')) {
            executables.add(entity.path);
            if (executables.length >= 5) break; // Limit to first few to improve performance
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return executables;
  }

  bool _isWindowsSystemApp(String appName) {
    const systemApps = {
      'Windows',
      'Microsoft',
      'Windows Defender',
      'Security Center'
    };
    return systemApps.any((sysApp) => appName.toLowerCase().contains(sysApp.toLowerCase()));
  }

  TaskEither<String, Uint8List> _getWindowsApplicationIcon(String appId) {
    return TaskEither(
      () async {
        try {
          // For Windows, we could extract icon from the executable
          // This is a simplified approach - in practice, more sophisticated icon extraction would be needed
          if (await File(appId).exists()) {
            // Would use a Windows-specific library to extract icons
            // For now, return a placeholder
            return left("Icon extraction not implemented for Windows");
          }
          return left("Application not found: $appId");
        } catch (e) {
          return left("Error getting Windows application icon: $e");
        }
      },
    );
  }

  // macOS implementation
  TaskEither<String, List<InstalledPackageInfo>> _getMacOSApplications() {
    return TaskEither(
      () async {
        try {
          const applicationsDir = '/Applications';
          const userApplicationsDir = '/Users/\$USER/Applications';
          
          final apps = <InstalledPackageInfo>[];
          
          // Scan Applications directory
          await _scanMacOSApplications(applicationsDir, apps);
          
          // Scan user Applications directory
          final userAppsDir = userApplicationsDir.replaceAll('\$USER', Platform.environment['USERNAME'] ?? '');
          await _scanMacOSApplications(userAppsDir, apps);
          
          return right(apps);
        } catch (e) {
          return left("Error getting macOS applications: $e");
        }
      },
    );
  }

  Future<void> _scanMacOSApplications(String directory, List<InstalledPackageInfo> apps) async {
    try {
      if (await Directory(directory).exists()) {
        await for (final entity in Directory(directory).list()) {
          if (entity is Directory && entity.path.endsWith('.app')) {
            final appName = entity.path.split('/').last.replaceAll('.app', '');
            final bundleId = await _getAppBundleId(entity.path);
            
            apps.add(InstalledPackageInfo(
              packageName: bundleId.isEmpty ? entity.path : bundleId,
              name: appName,
              isSystemApp: _isMacOSSystemApp(appName),
            ));
          }
        }
      }
    } catch (e) {
      // Ignore errors scanning individual directories
    }
  }

  Future<String> _getAppBundleId(String appPath) async {
    try {
      final infoPlistPath = '$appPath/Contents/Info.plist';
      if (await File(infoPlistPath).exists()) {
        // Parse the plist file to get bundle ID
        // This would require a plist parsing library
        // For now we return empty string to indicate we couldn't parse it
        return '';
      }
    } catch (e) {
      // Ignore errors
    }
    return '';
  }

  bool _isMacOSSystemApp(String appName) {
    const systemApps = {
      'Finder',
      'Terminal',
      'Safari',
      'System Preferences',
      'Activity Monitor',
      'Console',
      'Disk Utility'
    };
    return systemApps.any((sysApp) => sysApp.toLowerCase() == appName.toLowerCase());
  }

  TaskEither<String, Uint8List> _getMacOSApplicationIcon(String appId) {
    return TaskEither(
      () async {
        try {
          // Try to find the app in standard locations
          final possiblePaths = [
            '/Applications/$appId.app',
            '/Users/\$USER/Applications/$appId.app',
            '/System/Applications/$appId.app',
          ].map((path) => path.replaceAll('\$USER', Platform.environment['USERNAME'] ?? ''));
          
          for (final path in possiblePaths) {
            if (await Directory(path).exists()) {
              final iconPath = '$path/Contents/Resources/$appId.icns';
              if (await File(iconPath).exists()) {
                final bytes = await File(iconPath).readAsBytes();
                return right(bytes);
              }
              // Try alternative icon names
              final contentsDir = Directory('$path/Contents/Resources');
              if (await contentsDir.exists()) {
                await for (final entity in contentsDir.list()) {
                  if (entity.path.toLowerCase().endsWith('.icns')) {
                    final bytes = await File(entity.path).readAsBytes();
                    return right(bytes);
                  }
                }
              }
            }
          }
          return left("Icon not found for: $appId");
        } catch (e) {
          return left("Error getting macOS application icon: $e");
        }
      },
    );
  }

  // Linux implementation
  TaskEither<String, List<InstalledPackageInfo>> _getLinuxApplications() {
    return TaskEither(
      () async {
        try {
          final apps = <InstalledPackageInfo>[];
          
          // Scan common desktop file locations
          const desktopDirs = [
            '/usr/share/applications/',
            '/usr/local/share/applications/',
            '~/.local/share/applications/',
          ];
          
          for (final dirPath in desktopDirs) {
            final expandedPath = _expandHomePath(dirPath);
            if (expandedPath != null && await Directory(expandedPath).exists()) {
              await _scanLinuxDesktopFiles(expandedPath, apps);
            }
          }
          
          return right(apps);
        } catch (e) {
          return left("Error getting Linux applications: $e");
        }
      },
    );
  }

  String? _expandHomePath(String path) {
    if (path.startsWith('~')) {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        return path.replaceFirst('~', homeDir);
      }
      return null;
    }
    return path;
  }

  Future<void> _scanLinuxDesktopFiles(String directory, List<InstalledPackageInfo> apps) async {
    try {
      if (await Directory(directory).exists()) {
        await for (final entity in Directory(directory).list()) {
          if (entity is File && entity.path.endsWith('.desktop')) {
            await _parseDesktopFile(entity.path, apps);
          }
        }
      }
    } catch (e) {
      // Ignore errors scanning individual directories
    }
  }

  Future<void> _parseDesktopFile(String filePath, List<InstalledPackageInfo> apps) async {
    try {
      final lines = await File(filePath).readAsLines();
      String? execLine, nameLine, iconLine;
      
      for (final line in lines) {
        if (line.startsWith('Exec=')) {
          execLine = line.substring(5);
        } else if (line.startsWith('Name=')) {
          nameLine = line.substring(5);
        } else if (line.startsWith('Icon=')) {
          iconLine = line.substring(5);
        } else if (line.startsWith('[Desktop Entry]')) {
          execLine = nameLine = iconLine = null;
        }
      }
      
      if (nameLine != null && execLine != null) {
        final packageName = iconLine ?? execLine.split('/').last.split(' ').first;
        apps.add(InstalledPackageInfo(
          packageName: packageName,
          name: nameLine,
          isSystemApp: _isLinuxSystemApp(nameLine),
        ));
      }
    } catch (e) {
      // Ignore errors parsing individual files
    }
  }

  bool _isLinuxSystemApp(String appName) {
    const systemApps = {
      'gnome',
      'kde',
      'system',
      'settings',
      'terminal',
      'file manager',
      'calculator',
      'clock',
      'software'
    };
    final lowerAppName = appName.toLowerCase();
    return systemApps.any((sysApp) => lowerAppName.contains(sysApp));
  }

  TaskEither<String, Uint8List> _getLinuxApplicationIcon(String appId) {
    return TaskEither(
      () async {
        try {
          // Look for icon in standard icon theme locations
          const iconThemes = [
            '/usr/share/icons/hicolor/256x256/apps/',
            '/usr/share/icons/hicolor/128x128/apps/',
            '/usr/share/icons/hicolor/64x64/apps/',
            '/usr/local/share/icons/hicolor/256x256/apps/',
            '~/.local/share/icons/hicolor/256x256/apps/',
          ];
          
          for (final themePath in iconThemes) {
            final expandedPath = _expandHomePath(themePath);
            if (expandedPath != null && await Directory(expandedPath).exists()) {
              final possibleIcons = [
                '$expandedPath/$appId.png',
                '$expandedPath/${appId.replaceAll('.', '-')}.png',
                '$expandedPath/${appId.replaceAll(' ', '-')}.png',
                '$expandedPath/$appId.svg',
                '$expandedPath/${appId.replaceAll('.', '-')}.svg',
                '$expandedPath/${appId.replaceAll(' ', '-')}.svg',
              ];
              
              for (final iconPath in possibleIcons) {
                if (await File(iconPath).exists()) {
                  final bytes = await File(iconPath).readAsBytes();
                  return right(bytes);
                }
              }
            }
          }
          
          return left("Icon not found for: $appId");
        } catch (e) {
          return left("Error getting Linux application icon: $e");
        }
      },
    );
  }
}

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/per_app_proxy/model/installed_package_info.dart';
import 'package:hiddify/utils/utils.dart';

abstract interface class DesktopPerAppProxyRepository {
  TaskEither<String, List<InstalledPackageInfo>> getInstalledApplications();
  TaskEither<String, Uint8List> getApplicationIcon(String appId);
}

class DesktopPerAppProxyRepositoryImpl
    with InfraLogger
    implements DesktopPerAppProxyRepository {
  final _methodChannel = const MethodChannel("com.hiddify.app/desktop_platform");

  @override
  TaskEither<String, List<InstalledPackageInfo>> getInstalledApplications() {
    return TaskEither(
      () async {
        loggy.debug("getting installed applications info");
        
        if (Platform.isWindows) {
          return _getWindowsApplications();
        } else if (Platform.isMacOS) {
          return _getMacOSApplications();
        } else if (Platform.isLinux) {
          return _getLinuxApplications();
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  @override
  TaskEither<String, Uint8List> getApplicationIcon(String appId) {
    return TaskEither(
      () async {
        loggy.debug("getting application [$appId] icon");
        
        if (Platform.isWindows) {
          return _getWindowsApplicationIcon(appId);
        } else if (Platform.isMacOS) {
          return _getMacOSApplicationIcon(appId);
        } else if (Platform.isLinux) {
          return _getLinuxApplicationIcon(appId);
        } else {
          return left("Unsupported platform");
        }
      },
    );
  }

  // Windows implementation
  TaskEither<String, List<InstalledPackageInfo>> _getWindowsApplications() {
    return TaskEither(
      () async {
        try {
          // On Windows, we look for installed programs in registry and Program Files
          const programFiles = r'C:\Program Files';
          const programFilesX86 = r'C:\Program Files (x86)';
          
          final apps = <InstalledPackageInfo>[];
          
          // Get apps from Program Files
          await _scanWindowsPrograms(programFiles, apps);
          await _scanWindowsPrograms(programFilesX86, apps);
          
          return right(apps);
        } catch (e) {
          return left("Error getting Windows applications: $e");
        }
      },
    );
  }

  Future<void> _scanWindowsPrograms(String directory, List<InstalledPackageInfo> apps) async {
    try {
      if (await Directory(directory).exists()) {
        final dir = Directory(directory);
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            final dirName = entity.path.split('\\').last;
            // Look for common executable files in common app directories
            final executables = await _findExecutables(entity.path);
            for (final exe in executables) {
              apps.add(InstalledPackageInfo(
                packageName: exe,
                name: dirName,
                isSystemApp: _isWindowsSystemApp(dirName),
              ));
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors scanning individual directories
    }
  }

  Future<List<String>> _findExecutables(String directory) async {
    final executables = <String>[];
    try {
      if (await Directory(directory).exists()) {
        await for (final entity in Directory(directory).list(recursive: true)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.exe')) {
            executables.add(entity.path);
            if (executables.length >= 5) break; // Limit to first few to improve performance
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return executables;
  }

  bool _isWindowsSystemApp(String appName) {
    const systemApps = {
      'Windows',
      'Microsoft',
      'Windows Defender',
      'Security Center'
    };
    return systemApps.any((sysApp) => appName.toLowerCase().contains(sysApp.toLowerCase()));
  }

  TaskEither<String, Uint8List> _getWindowsApplicationIcon(String appId) {
    return TaskEither(
      () async {
        try {
          // For Windows, we could extract icon from the executable
          // This is a simplified approach - in practice, more sophisticated icon extraction would be needed
          if (await File(appId).exists()) {
            // Would use a Windows-specific library to extract icons
            // For now, return a placeholder
            return left("Icon extraction not implemented for Windows");
          }
          return left("Application not found: $appId");
        } catch (e) {
          return left("Error getting Windows application icon: $e");
        }
      },
    );
  }

  // macOS implementation
  TaskEither<String, List<InstalledPackageInfo>> _getMacOSApplications() {
    return TaskEither(
      () async {
        try {
          const applicationsDir = '/Applications';
          const userApplicationsDir = '/Users/\$USER/Applications';
          
          final apps = <InstalledPackageInfo>[];
          
          // Scan Applications directory
          await _scanMacOSApplications(applicationsDir, apps);
          
          // Scan user Applications directory
          final userAppsDir = userApplicationsDir.replaceAll('\$USER', Platform.environment['USERNAME'] ?? '');
          await _scanMacOSApplications(userAppsDir, apps);
          
          return right(apps);
        } catch (e) {
          return left("Error getting macOS applications: $e");
        }
      },
    );
  }

  Future<void> _scanMacOSApplications(String directory, List<InstalledPackageInfo> apps) async {
    try {
      if (await Directory(directory).exists()) {
        await for (final entity in Directory(directory).list()) {
          if (entity is Directory && entity.path.endsWith('.app')) {
            final appName = entity.path.split('/').last.replaceAll('.app', '');
            final bundleId = await _getAppBundleId(entity.path);
            
            apps.add(InstalledPackageInfo(
              packageName: bundleId.isEmpty ? entity.path : bundleId,
              name: appName,
              isSystemApp: _isMacOSSystemApp(appName),
            ));
          }
        }
      }
    } catch (e) {
      // Ignore errors scanning individual directories
    }
  }

  Future<String> _getAppBundleId(String appPath) async {
    try {
      final infoPlistPath = '$appPath/Contents/Info.plist';
      if (await File(infoPlistPath).exists()) {
        // Parse the plist file to get bundle ID
        // This would require a plist parsing library
        // For now we return empty string to indicate we couldn't parse it
        return '';
      }
    } catch (e) {
      // Ignore errors
    }
    return '';
  }

  bool _isMacOSSystemApp(String appName) {
    const systemApps = {
      'Finder',
      'Terminal',
      'Safari',
      'System Preferences',
      'Activity Monitor',
      'Console',
      'Disk Utility'
    };
    return systemApps.any((sysApp) => sysApp.toLowerCase() == appName.toLowerCase());
  }

  TaskEither<String, Uint8List> _getMacOSApplicationIcon(String appId) {
    return TaskEither(
      () async {
        try {
          // Try to find the app in standard locations
          final possiblePaths = [
            '/Applications/$appId.app',
            '/Users/\$USER/Applications/$appId.app',
            '/System/Applications/$appId.app',
          ].map((path) => path.replaceAll('\$USER', Platform.environment['USERNAME'] ?? ''));
          
          for (final path in possiblePaths) {
            if (await Directory(path).exists()) {
              final iconPath = '$path/Contents/Resources/$appId.icns';
              if (await File(iconPath).exists()) {
                final bytes = await File(iconPath).readAsBytes();
                return right(bytes);
              }
              // Try alternative icon names
              final contentsDir = Directory('$path/Contents/Resources');
              if (await contentsDir.exists()) {
                await for (final entity in contentsDir.list()) {
                  if (entity.path.toLowerCase().endsWith('.icns')) {
                    final bytes = await File(entity.path).readAsBytes();
                    return right(bytes);
                  }
                }
              }
            }
          }
          return left("Icon not found for: $appId");
        } catch (e) {
          return left("Error getting macOS application icon: $e");
        }
      },
    );
  }

  // Linux implementation
  TaskEither<String, List<InstalledPackageInfo>> _getLinuxApplications() {
    return TaskEither(
      () async {
        try {
          final apps = <InstalledPackageInfo>[];
          
          // Scan common desktop file locations
          const desktopDirs = [
            '/usr/share/applications/',
            '/usr/local/share/applications/',
            '~/.local/share/applications/',
          ];
          
          for (final dirPath in desktopDirs) {
            final expandedPath = _expandHomePath(dirPath);
            if (expandedPath != null && await Directory(expandedPath).exists()) {
              await _scanLinuxDesktopFiles(expandedPath, apps);
            }
          }
          
          return right(apps);
        } catch (e) {
          return left("Error getting Linux applications: $e");
        }
      },
    );
  }

  String? _expandHomePath(String path) {
    if (path.startsWith('~')) {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        return path.replaceFirst('~', homeDir);
      }
      return null;
    }
    return path;
  }

  Future<void> _scanLinuxDesktopFiles(String directory, List<InstalledPackageInfo> apps) async {
    try {
      if (await Directory(directory).exists()) {
        await for (final entity in Directory(directory).list()) {
          if (entity is File && entity.path.endsWith('.desktop')) {
            await _parseDesktopFile(entity.path, apps);
          }
        }
      }
    } catch (e) {
      // Ignore errors scanning individual directories
    }
  }

  Future<void> _parseDesktopFile(String filePath, List<InstalledPackageInfo> apps) async {
    try {
      final lines = await File(filePath).readAsLines();
      String? execLine, nameLine, iconLine;
      
      for (final line in lines) {
        if (line.startsWith('Exec=')) {
          execLine = line.substring(5);
        } else if (line.startsWith('Name=')) {
          nameLine = line.substring(5);
        } else if (line.startsWith('Icon=')) {
          iconLine = line.substring(5);
        } else if (line.startsWith('[Desktop Entry]')) {
          execLine = nameLine = iconLine = null;
        }
      }
      
      if (nameLine != null && execLine != null) {
        final packageName = iconLine ?? execLine.split('/').last.split(' ').first;
        apps.add(InstalledPackageInfo(
          packageName: packageName,
          name: nameLine,
          isSystemApp: _isLinuxSystemApp(nameLine),
        ));
      }
    } catch (e) {
      // Ignore errors parsing individual files
    }
  }

  bool _isLinuxSystemApp(String appName) {
    const systemApps = {
      'gnome',
      'kde',
      'system',
      'settings',
      'terminal',
      'file manager',
      'calculator',
      'clock',
      'software'
    };
    final lowerAppName = appName.toLowerCase();
    return systemApps.any((sysApp) => lowerAppName.contains(sysApp));
  }

  TaskEither<String, Uint8List> _getLinuxApplicationIcon(String appId) {
    return TaskEither(
      () async {
        try {
          // Look for icon in standard icon theme locations
          const iconThemes = [
            '/usr/share/icons/hicolor/256x256/apps/',
            '/usr/share/icons/hicolor/128x128/apps/',
            '/usr/share/icons/hicolor/64x64/apps/',
            '/usr/local/share/icons/hicolor/256x256/apps/',
            '~/.local/share/icons/hicolor/256x256/apps/',
          ];
          
          for (final themePath in iconThemes) {
            final expandedPath = _expandHomePath(themePath);
            if (expandedPath != null && await Directory(expandedPath).exists()) {
              final possibleIcons = [
                '$expandedPath/$appId.png',
                '$expandedPath/${appId.replaceAll('.', '-')}.png',
                '$expandedPath/${appId.replaceAll(' ', '-')}.png',
                '$expandedPath/$appId.svg',
                '$expandedPath/${appId.replaceAll('.', '-')}.svg',
                '$expandedPath/${appId.replaceAll(' ', '-')}.svg',
              ];
              
              for (final iconPath in possibleIcons) {
                if (await File(iconPath).exists()) {
                  final bytes = await File(iconPath).readAsBytes();
                  return right(bytes);
                }
              }
            }
          }
          
          return left("Icon not found for: $appId");
        } catch (e) {
          return left("Error getting Linux application icon: $e");
        }
      },
    );
  }
}
