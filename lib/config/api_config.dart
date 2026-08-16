/// Backend base URL including global prefix, e.g. `http://localhost:3000/bds-api`
/// Override at build time: `--dart-define=BDS_API_BASE=http://localhost:3000/bds-api`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'BDS_API_BASE',
    defaultValue: 'https://apis.mybdis.com/bds-api',
  );
}
