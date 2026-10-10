class AuditSecurityModel {
  final String id;
  final String action;
  final String actor;
  final DateTime createdAt;

  const AuditSecurityModel({
    required this.id,
    required this.action,
    required this.actor,
    required this.createdAt,
  });
}
