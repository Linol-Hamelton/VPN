import 'package:hiddify/features/per_app_proxy/api/per_app_proxy_api_impl.dart';
import 'package:hiddify/features/per_app_proxy/data/unified_per_app_proxy_data_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'per_app_proxy_api_provider.g.dart';

@Riverpod(keepAlive: true)
PerAppProxyApiImpl perAppProxyApi(PerAppProxyApiRef ref) {
  final unifiedRepository = ref.watch(unifiedPerAppProxyRepositoryProvider);
  return PerAppProxyApiImpl(unifiedRepository);
}import 'package:hiddify/features/per_app_proxy/data/unified_per_app_proxy_data_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'per_app_proxy_api_provider.g.dart';

@Riverpod(keepAlive: true)
PerAppProxyApiImpl perAppProxyApi(PerAppProxyApiRef ref) {
  final unifiedRepository = ref.watch(unifiedPerAppProxyRepositoryProvider);
  return PerAppProxyApiImpl(unifiedRepository);
}
