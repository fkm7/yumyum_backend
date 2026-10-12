import 'dart:developer' as developer;

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// A service for sending emails using SMTP.
class MailService {
  /// Creates a new instance of [MailService].
  MailService({
    required this.smtpServerHost,
    required this.smtpServerPort,
    required this.smtpUsername,
    required this.smtpPassword,
  });

  /// The SMTP server host.
  final String smtpServerHost;

  /// The SMTP server port.
  final int smtpServerPort;

  /// The SMTP username for authentication.
  final String smtpUsername;

  /// The SMTP password for authentication.
  final String smtpPassword;

  /// Sends an email with the given parameters.
  Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    final smtpServer = SmtpServer(
      smtpServerHost,
      port: smtpServerPort,
      username: smtpUsername,
      password: smtpPassword,
    );

    final message = Message()
      ..from = Address(smtpUsername)
      ..recipients.add(to)
      ..subject = subject
      ..text = body;

    try {
      final sendReport = await send(message, smtpServer);
      developer.log('Message sent: $sendReport');
    } on MailerException catch (e) {
      developer.log('Message not sent. \n$e');
    }
  }

  /// Sends a password reset email to the specified recipient with the provided token.
  Future<void>? sendResetEmail({
    required String to,
    required String token,
  }) async {}
}
