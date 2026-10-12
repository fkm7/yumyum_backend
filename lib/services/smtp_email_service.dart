import 'dart:io';

import 'package:yumyum_backend/services/email_service.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// [EmailService] backed by SMTP, via the `mailer` package.
///
/// Requires `mailer` to be added to `pubspec.yaml` — it is not a dependency
/// of the rest of this codebase yet.
class SmtpEmailService implements EmailService {
  /// Constructs an [SmtpEmailService] over the given [server].
  const SmtpEmailService({
    required this.server,
    required this.fromEmail,
    this.fromName = 'Delmer',
  });

  /// Configures an [SmtpEmailService] from `SMTP_*` environment variables.
  ///
  /// Only called once [SMTP_HOST] has already been confirmed set — see the
  /// fallback-to-console-logger decision in `routes/_middleware.dart`.
  factory SmtpEmailService.fromEnvironment() {
    final host = Platform.environment['SMTP_HOST']!;
    final port = int.tryParse(Platform.environment['SMTP_PORT'] ?? '') ?? 587;
    final username = Platform.environment['SMTP_USERNAME'];
    final password = Platform.environment['SMTP_PASSWORD'];
    final useSsl = Platform.environment['SMTP_USE_SSL'] == 'true';
    final fromEmail = Platform.environment['SMTP_FROM_EMAIL'] ??
        username ??
        'no-reply@delmer.app';
    final fromName = Platform.environment['SMTP_FROM_NAME'] ?? 'Delmer';

    return SmtpEmailService(
      server: SmtpServer(
        host,
        port: port,
        username: username,
        password: password,
        ssl: useSsl,
      ),
      fromEmail: fromEmail,
      fromName: fromName,
    );
  }

  /// The SMTP server connection details.
  final SmtpServer server;

  /// The address the email is sent from.
  final String fromEmail;

  /// The display name the email is sent from.
  final String fromName;

  @override
  Future<void> sendPasswordResetEmail({
    required String toEmail,
    required String firstName,
    required String resetUrl,
  }) async {
    final message = Message()
      ..from = Address(fromEmail, fromName)
      ..recipients.add(toEmail)
      ..subject = 'Reset your Delmer password'
      ..text = '''
Hi $firstName,

Use the link below to reset your password. This link expires in 30 minutes
and can only be used once.

$resetUrl

If you did not request this, you can safely ignore this email — your
password will not be changed.
''';

    // Left to propagate on failure: a real send failure is an
    // infrastructure fault, not a security-sensitive branch, so it should
    // surface as a 500 rather than being swallowed into the same generic
    // "if that email exists" response the route always gives.
    await send(message, server);
  }
}
