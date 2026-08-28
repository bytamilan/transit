import 'package:transit_core/transit_core.dart' as core;

/// Lightweight immutable state for the selected agency.
class AppState {
  final String? agencySlug;
  final core.Agency? agency;
  final core.AgencyConfig? config;
  final bool loading;
  final core.Failure? error;

  const AppState({
    this.agencySlug,
    this.agency,
    this.config,
    this.loading = false,
    this.error,
  });

  AppState copyWith({
    String? agencySlug,
    core.Agency? agency,
    core.AgencyConfig? config,
    bool? loading,
    core.Failure? error,
    bool clearError = false,
  }) {
    return AppState(
      agencySlug: agencySlug ?? this.agencySlug,
      agency: agency ?? this.agency,
      config: config ?? this.config,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
    );
  }
}
