/// Sends transactional email on behalf of the app.
///
/// An interface rather than a single concrete sender so the actual delivery
/// mechanism (SMTP, SendGrid, SES, Postmark, ...) can be swapped without
/// touching anything that calls it — [PasswordResetService] only depends on
/// this.
abstract class EmailService {
  /// Sends a password-reset email to [toEmail].
  ///
  /// [resetUrl] already contains the raw, single-use token as a query
  /// parameter; this method does not construct it.
  Future<void> sendPasswordResetEmail({
    required String toEmail,
    required String firstName,
    required String resetUrl,
  });
}
