# backend

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]
[![Powered by Dart Frog](https://img.shields.io/endpoint?url=https://tinyurl.com/dartfrog-badge)](https://dartfrog.vgv.dev)

An example application built with dart_frog

## Architecture

Routes are thin: they parse the request, call a repository or service, and map
the result onto a status code. Data access lives behind the interfaces in
`lib/repositories/`, with PostgreSQL implementations in
`lib/repositories/postgres/`. Business logic that does not need a database —
order pricing and validation — lives in `lib/services/` as pure functions.

That layering is what makes the routes testable: `package:postgres` types never
reach a route, so tests mock a repository interface instead of faking a
`Connection`, `Result`, and `ResultRow`.

## Testing

```sh
dart test                  # unit + route tests, no database needed
dart test --coverage=coverage
```

Integration tests exercise the real SQL and the driver's type mapping, so they
need a live database:

```sh
docker compose up -d
dart test --tags integration --run-skipped
```

`--run-skipped` is required: the `integration` tag is marked skipped in
`dart_test.yaml` so it stays out of the default run.

Where the mock boundary goes:

| Layer | How it is tested |
| --- | --- |
| Routes, middleware, services | Mocked repository interfaces |
| Repository implementations | Integration tests against real PostgreSQL |
| Models, pure logic | Plain unit tests, no mocks |

## Passwords

Passwords are stored as salted bcrypt digests. Credentials created under the
previous scheme (unsalted SHA-256) cannot be converted without the plaintext,
so they are still accepted at login and rewritten as bcrypt at that moment —
the one point where the plaintext is available. The same path upgrades a
bcrypt digest whose cost is below the current `BCRYPT_ROUNDS`.

Two details worth knowing before changing this code:

- bcrypt rejects inputs over 72 bytes. Passwords are reduced to a base64
  SHA-256 token first, which keeps their full entropy and avoids both the
  length limit and bcrypt's truncation at the first NUL byte.
- `/auth/login` hashes even when no user matched. bcrypt is deliberately slow,
  so returning early for an unknown address would make it measurably faster to
  reject than a registered one, turning the generic error message into a user
  enumeration oracle.

## Sessions

Access tokens are stateless and short-lived. Refresh tokens are not: each one
has a row in `refresh_tokens`, carries that row's id as its `jti`, and is only
accepted while the row exists unrevoked. Verifying the signature is not enough,
which is what makes revocation possible at all.

Exchanging a refresh token rotates it — the presented token is revoked and a
successor is issued in the same *family*. Presenting an already-rotated token
therefore means a copy is in circulation, so the whole family is revoked and
every device on that chain has to log in again. `POST /auth/logout` revokes a
family outright; other sessions for the same user are unaffected.

Two operational notes:

- Refresh tokens issued before this existed have no `jti` and are refused, so
  deploying this signs existing sessions out. Grandfathering them would have
  meant leaving unrevocable tokens live for their full lifetime.
- Rows are not deleted when they expire. `RefreshTokenRepository.deleteExpired`
  prunes them and needs to be run periodically, or the table grows without
  bound.

## Configuration

| Variable | Default | Notes |
| --- | --- | --- |
| `JWT_SECRET` | development fallback | Must be set in production; a warning is logged when it is not. |
| `BCRYPT_ROUNDS` | `12` | bcrypt cost factor. Logarithmic — each increment doubles the work. Raising it migrates existing credentials on their next login. |
| `DB_HOST` / `DB_PORT` | `localhost` / `5432` | |
| `DB_NAME` / `DB_USER` / `DB_PASS` | `yumyum` / `felix` / `1997` | |

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
