import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/driver_api.dart';
import '../services/public_api.dart';
import '../services/recovery_store.dart';

final dioProvider = Provider<Dio>((ref) => buildApiClient());

final driverApiProvider = Provider<DriverApi>((ref) => DriverApi(ref.watch(dioProvider)));

final publicApiProvider = Provider<PublicApi>((ref) => PublicApi(ref.watch(dioProvider)));

final recoveryStoreProvider = Provider<RecoveryStore>((ref) => RecoveryStore());
