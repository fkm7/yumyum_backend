import 'dart:async';

import 'package:dart_frog/dart_frog.dart';

import 'package:yumyum_backend/services/account_deletion_service.dart';

/// A public account-deletion page, reachable without the YumYum app
/// installed.
///
/// This satisfies Google Play's requirement that account/data deletion be
/// available via a web resource independent of the app — this route sits
/// outside `routes/api/v1/user/`, so it is not behind that tree's
/// `authMiddleware`. It is a plain HTML form rather than a JSON API so it
/// works when opened directly in a browser (including by a Play reviewer),
/// with no JavaScript required.
///
/// Register this page's full URL as the "account deletion" link in Play
/// Console's Data Safety section.
FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => _page(),
    HttpMethod.post => await _submit(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _submit(RequestContext context) async {
  final Map<String, String> form;
  try {
    // A plain HTML <form method="post"> submits
    // application/x-www-form-urlencoded, which uses the same escaping rules
    // as a URL query string, so Uri.splitQueryString decodes it correctly
    // without depending on a form-parsing helper that may differ across
    // dart_frog versions.
    form = Uri.splitQueryString(await context.request.body());
  } catch (_) {
    return _page(error: 'Something went wrong reading the form. Try again.');
  }

  final email = form['email']?.trim() ?? '';
  final password = form['password'] ?? '';
  final confirmed = form['confirm'] == 'on';

  if (email.isEmpty || password.isEmpty) {
    return _page(error: 'Email and password are required.', email: email);
  }
  if (!confirmed) {
    return _page(
      error: 'Please check the box confirming you understand this is '
          'permanent.',
      email: email,
    );
  }

  final result = await context
      .read<AccountDeletionService>()
      .deleteByEmail(email: email, password: password);

  return switch (result) {
    AccountDeleted() => _confirmation(),
    AccountCredentialsRejected() =>
      _page(error: 'Invalid email or password.', email: email),
  };
}

Response _page({String? error, String? email}) {
  final errorHtml =
      error == null ? '' : '<p class="error">${_escape(error)}</p>';
  return _html('''
<h1>Delete your YumYum account</h1>
<p>This permanently deletes your account, saved addresses, saved payment
methods, and favorites.</p>
<p>Past orders are kept as anonymized business/accounting records — the
delivery address and payment details on them are removed too, but the order
itself (items, cost, date, restaurant) is retained.</p>
$errorHtml
<form method="post">
  <label for="email">Email</label>
  <input type="email" id="email" name="email" value="${_escape(email ?? '')}"
    required autocomplete="email">

  <label for="password">Password</label>
  <input type="password" id="password" name="password" required
    autocomplete="current-password">

  <label class="checkbox">
    <input type="checkbox" name="confirm">
    I understand this is permanent and cannot be undone.
  </label>

  <button type="submit">Delete my account and data</button>
</form>
<p class="note">Prefer to do this from the app? Open YumYum and go to
Account &rarr; Delete account.</p>
''');
}

Response _confirmation() {
  return _html('''
<h1>Your account has been deleted</h1>
<p>Your account, saved addresses, saved payment methods and favorites have
been permanently removed. Past orders are retained as anonymized business
records, with the personal delivery/payment details removed from them.</p>
''');
}

Response _html(String bodyContent) => Response(
      headers: const {'content-type': 'text/html; charset=utf-8'},
      body: '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Delete your YumYum account</title>
<style>
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    max-width: 480px; margin: 40px auto; padding: 0 16px; color: #1a1a1a;
    line-height: 1.5;
  }
  h1 { font-size: 1.4rem; }
  label { display: block; margin-top: 16px; font-weight: 600; }
  input[type=email], input[type=password] {
    width: 100%; padding: 8px; margin-top: 4px; box-sizing: border-box;
    font-size: 1rem;
  }
  .checkbox {
    display: flex; align-items: flex-start; gap: 8px; margin-top: 20px;
    font-weight: normal;
  }
  .checkbox input { margin-top: 5px; }
  button {
    margin-top: 24px; padding: 10px 20px; background: #c0392b; color: white;
    border: none; border-radius: 4px; font-size: 1rem; cursor: pointer;
  }
  .error { color: #c0392b; font-weight: 600; }
  .note { color: #555; font-size: 0.9rem; margin-top: 24px; }
</style>
</head>
<body>
$bodyContent
</body>
</html>
''',
    );

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
