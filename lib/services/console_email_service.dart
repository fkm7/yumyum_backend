import 'dart:io';

import 'package:delmer_backend/services/email_service.dart';

/// Logs the reset link to stdout instead of sending a real email.
///
/// Selected when `SMTP_HOST` is not configured, so local development keeps
/// working without real mail infrastructure. This must never be used in
/// production — see the loud warning printed alongside this fallback being
/// chosen in `routes/_middleware.dart`.
class ConsoleEmailService implements EmailService {
  @override
  Future<void> sendPasswordResetEmail({
    required String toEmail,
    required String firstName,
    required String resetUrl,
  }) async {
    stdout.writeln(
      '[ConsoleEmailService] Password reset requested for $toEmail '
      '($firstName). Link (valid 30 minutes, single use): $resetUrl',
    );
  }
}
