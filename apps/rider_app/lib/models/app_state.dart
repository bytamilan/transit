import 'package:transit_api_client/transit_api_client.dart';

/// Lightweight immutable state for the selected agency.
class AppState {
  final String? agencySlug;
  final Agency? agency;
  final AgencyConfig? config;
  final bool loading;
  final String? error;

  const AppState({
    this.agencySlug,
    this.agency,
    this.config,
    this.loading = false,
    this.error,
  });

  AppState copyWith({
    String? agencySlug,
    Agency? agency,
    AgencyConfig? config,
    bool? loading,
    String? error,
  }) {
    return AppState(
      agencySlug: agencySlug ?? this.agencySlug,
      agency: agency ?? this.agency,
      config: config ?? this.config,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}
