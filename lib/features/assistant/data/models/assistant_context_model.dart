class AssistantContextModel {
  const AssistantContextModel({
    required this.generatedAt,
    required this.crops,
    required this.stocks,
    required this.recentActivities,
    required this.rover,
  });

  factory AssistantContextModel.empty() {
    return AssistantContextModel(
      generatedAt: DateTime.now(),
      crops: const [],
      stocks: const [],
      recentActivities: const [],
      rover: const {},
    );
  }

  final DateTime generatedAt;
  final List<Map<String, dynamic>> crops;
  final List<Map<String, dynamic>> stocks;
  final List<Map<String, dynamic>> recentActivities;
  final Map<String, dynamic> rover;

  Map<String, dynamic> toApiJson() {
    return {
      'source': 'current_app_mock_data',
      'note':
          'Data comes from the current app state/mock repositories, not live Supabase crop or stock tables yet.',
      'generatedAt': generatedAt.toIso8601String(),
      'rover': rover,
      'crops': crops,
      'stocks': stocks,
      'recentActivities': recentActivities,
    };
  }
}
