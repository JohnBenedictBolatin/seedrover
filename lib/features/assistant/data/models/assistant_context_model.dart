class AssistantContextModel {
  const AssistantContextModel({
    required this.generatedAt,
    required this.crops,
    required this.stocks,
    required this.recentActivities,
    required this.rover,
    required this.farmAnalytics,
  });

  factory AssistantContextModel.empty() {
    return AssistantContextModel(
      generatedAt: DateTime.now(),
      crops: const [],
      stocks: const [],
      recentActivities: const [],
      rover: const {},
      farmAnalytics: const {},
    );
  }

  final DateTime generatedAt;
  final List<Map<String, dynamic>> crops;
  final List<Map<String, dynamic>> stocks;
  final List<Map<String, dynamic>> recentActivities;
  final Map<String, dynamic> rover;
  final Map<String, dynamic> farmAnalytics;

  Map<String, dynamic> toApiJson() {
    return {
      'source': 'current_app_state',
      'note':
          'Data comes from the current app state, which is backed by Supabase where integration is available.',
      'generatedAt': generatedAt.toIso8601String(),
      'rover': rover,
      'crops': crops,
      'stocks': stocks,
      'recentActivities': recentActivities,
      'farmAnalytics': farmAnalytics,
    };
  }
}
