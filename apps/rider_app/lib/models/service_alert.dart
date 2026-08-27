class ServiceAlert {
  final String id;
  final String cause;
  final String effect;
  final String headerText;
  final String descriptionText;
  final String locale;
  final List<String> informedRoutes;
  final List<String> informedStops;

  ServiceAlert({
    required this.id,
    required this.cause,
    required this.effect,
    required this.headerText,
    required this.descriptionText,
    required this.locale,
    required this.informedRoutes,
    required this.informedStops,
  });

  factory ServiceAlert.fromJson(Map<String, dynamic> json) => ServiceAlert(
        id: json['id'] as String,
        cause: json['cause'] as String,
        effect: json['effect'] as String,
        headerText: json['header_text'] as String? ?? '',
        descriptionText: json['description_text'] as String? ?? '',
        locale: json['locale'] as String? ?? '',
        informedRoutes: (json['informed_routes'] as List<dynamic>? ?? []).cast<String>(),
        informedStops: (json['informed_stops'] as List<dynamic>? ?? []).cast<String>(),
      );
}
