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

## Configuration

| Variable | Default | Notes |
| --- | --- | --- |
| `JWT_SECRET` | development fallback | Must be set in production; a warning is logged when it is not. |
| `DB_HOST` / `DB_PORT` | `localhost` / `5432` | |
| `DB_NAME` / `DB_USER` / `DB_PASS` | `yumyum` / `felix` / `1997` | |

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
