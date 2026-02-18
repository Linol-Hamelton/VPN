import 'package:hiddify/features/per_app_proxy/data/desktop_per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/desktop_routing_controller.dart';
import 'package:hiddify/features/per_app_proxy/data/per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/unified_per_app_proxy_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_per_app_proxy_data_providers.g.dart';

@Riverpod(keepAlive: true)
UnifiedPerAppProxyRepository unifiedPerAppProxyRepository(UnifiedPerAppProxyRepositoryRef ref) {
  final androidRepo = ref.watch(perAppProxyRepositoryProvider);
  final desktopRepo = ref.watch(desktopPerAppProxyRepositoryProvider);
  final routingController = ref.watch(desktopRoutingControllerProvider);
  return UnifiedPerAppProxyRepositoryImpl(androidRepo, desktopRepo, routingController);
}

@Riverpod(keepAlive: true)
DesktopPerAppProxyRepository desktopPerAppProxyRepository(DesktopPerAppProxyRepositoryRef ref) {
  return DesktopPerAppProxyRepositoryImpl();
}

@Riverpod(keepAlive: true)
DesktopRoutingController desktopRoutingController(DesktopRoutingControllerRef ref) {
  return DesktopRoutingControllerImpl();
}
import 'package:hiddify/features/per_app_proxy/data/desktop_routing_controller.dart';
import 'package:hiddify/features/per_app_proxy/data/per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/unified_per_app_proxy_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_per_app_proxy_data_providers.g.dart';

@Riverpod(keepAlive: true)
UnifiedPerAppProxyRepository unifiedPerAppProxyRepository(UnifiedPerAppProxyRepositoryRef ref) {
  final androidRepo = ref.watch(perAppProxyRepositoryProvider);
  final desktopRepo = ref.watch(desktopPerAppProxyRepositoryProvider);
  final routingController = ref.watch(desktopRoutingControllerProvider);
  return UnifiedPerAppProxyRepositoryImpl(androidRepo, desktopRepo, routingController);
}

@Riverpod(keepAlive: true)
DesktopPerAppProxyRepository desktopPerAppProxyRepository(DesktopPerAppProxyRepositoryRef ref) {
  return DesktopPerAppProxyRepositoryImpl();
}

@Riverpod(keepAlive: true)
DesktopRoutingController desktopRoutingController(DesktopRoutingControllerRef ref) {
  return DesktopRoutingControllerImpl();
}
import 'package:hiddify/features/per_app_proxy/data/unified_per_app_proxy_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_per_app_proxy_data_providers.g.dart';

@Riverpod(keepAlive: true)
UnifiedPerAppProxyRepository unifiedPerAppProxyRepository(UnifiedPerAppProxyRepositoryRef ref) {
  final androidRepo = ref.watch(perAppProxyRepositoryProvider);
  final desktopRepo = ref.watch(desktopPerAppProxyRepositoryProvider);
  return UnifiedPerAppProxyRepositoryImpl(androidRepo, desktopRepo);
}

@Riverpod(keepAlive: true)
DesktopPerAppProxyRepository desktopPerAppProxyRepository(DesktopPerAppProxyRepositoryRef ref) {
  return DesktopPerAppProxyRepositoryImpl();
}
import 'package:hiddify/features/per_app_proxy/data/desktop_routing_controller.dart';
import 'package:hiddify/features/per_app_proxy/data/per_app_proxy_repository.dart';
import 'package:hiddify/features/per_app_proxy/data/unified_per_app_proxy_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_per_app_proxy_data_providers.g.dart';

@Riverpod(keepAlive: true)
UnifiedPerAppProxyRepository unifiedPerAppProxyRepository(UnifiedPerAppProxyRepositoryRef ref) {
  final androidRepo = ref.watch(perAppProxyRepositoryProvider);
  final desktopRepo = ref.watch(desktopPerAppProxyRepositoryProvider);
  final routingController = ref.watch(desktopRoutingControllerProvider);
  return UnifiedPerAppProxyRepositoryImpl(androidRepo, desktopRepo, routingController);
}

@Riverpod(keepAlive: true)
DesktopPerAppProxyRepository desktopPerAppProxyRepository(DesktopPerAppProxyRepositoryRef ref) {
  return DesktopPerAppProxyRepositoryImpl();
}

@Riverpod(keepAlive: true)
DesktopRoutingController desktopRoutingController(DesktopRoutingControllerRef ref) {
  return DesktopRoutingControllerImpl();
}
