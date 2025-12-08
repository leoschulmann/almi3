/// Application configuration
class AppConfig {
  /// Backend API base URL
  static const String backendUrl = 'http://localhost:9999';

  /// API endpoints
  static const String rootsEndpoint = '/api/root';
  static const String binyanEndpoint = '/api/binyan';
  static const String prepEndpoint = '/api/preposition';
  static const String gizrahEndpoint = '/api/gizrah';

  /// Batch size for fetching and processing roots from backend
  /// API calls will use this size for pagination (page size per request)
  static const int batchSize = 500;
}
