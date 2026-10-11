/// The complete auth journey shares session, policy and native-link guards.
abstract final class AuthRoutes {
  static const entry = '/auth';
  static const email = '/auth/email';
  static const verify = '/auth/verify';

  static bool isAuthPath(String path) =>
      path == entry || path == email || path == verify;
}
