class ConflictRegressionScenario {
  List<String> get scenarios => [
    'offline transaction creates conflict',
    'owner reviews conflict detail',
    'owner resolves conflict',
    'audit record is stored'
  ];
}
