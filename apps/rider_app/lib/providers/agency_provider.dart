import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_state.dart';
import 'api_provider.dart';

final agencyProvider = StateNotifierProvider<AgencyNotifier, AppState>((ref) {
  return AgencyNotifier(ref.read(apiClientProvider));
});

class AgencyNotifier extends StateNotifier<AppState> {
  final _api;

  AgencyNotifier(this._api) : super(const AppState());

  Future<void> loadAgency(String slug) async {
    state = state.copyWith(agencySlug: slug, loading: true, error: null);
    try {
      final agency = await _api.getAgency(slug: slug);
      final config = await _api.getAgencyConfig(slug: slug);
      state = state.copyWith(
        agency: agency.data,
        config: config.data,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
