/// Hardcoded backend configuration.
///
/// Organizers never see or type a server address — the app ships
/// pre-configured. Access is instead gated by a real per-admin account
/// (username/password, see [LoginScreen]), not a hardcoded key or shared
/// passcode — NEW_PROJECT_PLAN.md replaced both of those with appointed-only
/// admin accounts and server-side session tokens.
abstract final class AppConfig {
  static const String serverUrl = 'https://ysf-basketball-app.onrender.com/api/v1';

  // For local backend testing: temporarily swap the line above for
  // 'http://127.0.0.1:8000/api/v1' — always switch it back before
  // committing, since this app has no runtime way to change it (see the
  // gotcha about Dart `const` + hot reload in PROJECT_CONTEXT.md).
}
