library;

/// FIREFA database schema foundation
/// Defines initial entities for backend planning.

class FirefaDatabaseEntity {
  final String name;
  final List<String> fields;

  const FirefaDatabaseEntity({
    required this.name,
    required this.fields,
  });
}

const firefaEntities = [
  FirefaDatabaseEntity(
    name: 'tenant',
    fields: ['id', 'name', 'status'],
  ),
  FirefaDatabaseEntity(
    name: 'outlet',
    fields: ['id', 'tenantId', 'name'],
  ),
  FirefaDatabaseEntity(
    name: 'user',
    fields: ['id', 'role', 'status'],
  ),
];
