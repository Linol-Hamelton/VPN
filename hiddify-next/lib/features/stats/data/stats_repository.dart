import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/utils/exception_handler.dart';
import 'package:hiddify/features/stats/model/stats_entity.dart';
import 'package:hiddify/features/stats/model/stats_failure.dart';
import 'package:hiddify/singbox/service/singbox_service.dart';
import 'package:hiddify/utils/custom_loggers.dart';

abstract interface class StatsRepository {
  Stream<Either<StatsFailure, StatsEntity>> watchStats();
}

class StatsRepositoryImpl
    with ExceptionHandler, InfraLogger
    implements StatsRepository {
  StatsRepositoryImpl({required this.singbox});

  final SingboxService singbox;

  @override
  Stream<Either<StatsFailure, StatsEntity>> watchStats() {
    return singbox
        .watchStats()
        .map(
          (event) => StatsEntity(
            uplink: event.uplink,
            downlink: event.downlink,
            uplinkTotal: event.uplinkTotal,
            downlinkTotal: event.downlinkTotal,
            ping: 0.0, // Default to 0, will be updated by performance monitor
            connections: 0, // Default to 0, will be updated by performance monitor
          ),
        )
        .handleExceptions(StatsUnexpectedFailure.new);
  }
}
