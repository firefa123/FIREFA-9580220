library;

/// FIREFA API contract foundation
/// Placeholder contracts for future backend integration.

class FirefaApiContract {
  final String endpoint;
  final String method;

  const FirefaApiContract({
    required this.endpoint,
    required this.method,
  });
}

const firefaApiContracts = [
  FirefaApiContract(endpoint: '/auth/login', method: 'POST'),
  FirefaApiContract(endpoint: '/orders', method: 'GET'),
  FirefaApiContract(endpoint: '/payments', method: 'POST'),
];
