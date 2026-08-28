import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_core/transit_core.dart' as core;
import '../models/app_state.dart';
import 'api_provider.dart';

final agencyProvider = StateNotifierProvider<AgencyNotifier, AppState>((ref) {
  return AgencyNotifier(ref.read(apiClientProvider));
});

class AgencyNotifier extends StateNotifier<AppState> {
  final DefaultApi _api;

  AgencyNotifier(this._api) : super(const AppState());

  Future<void> loadAgency(String slug) async {
    state = state.copyWith(agencySlug: slug, loading: true, clearError: true);
    try {
      final agency = await _api.getAgency(slug: slug);
      final config = await _api.getAgencyConfig(slug: slug);
      state = state.copyWith(
        agency: agency.data!.toDomain(),
        config: config.data!.toDomain(),
        loading: false,
      );
    } catch (error) {
      final failure = error is core.TransitException
          ? error.failure
          : core.ValidationFailure(error.toString());
      state = state.copyWith(loading: false, error: failure);
    }
  }
}
