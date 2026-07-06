enum AssistantMessageRole {
  user,
  assistant;

  String get apiValue {
    return switch (this) {
      AssistantMessageRole.user => 'user',
      AssistantMessageRole.assistant => 'assistant',
    };
  }
}

class AssistantMessageModel {
  const AssistantMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final AssistantMessageRole role;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toApiJson() {
    return {
      'role': role.apiValue,
      'content': content,
    };
  }
}

