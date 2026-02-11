# Changelog

All notable changes to SwiftMockServer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-02-11

### Added

- **`RecordedRequest.response`** — each recorded request now includes the `MockHTTPResponse` that was returned, enabling full request/response inspection when debugging UI test failures.

### Changed

- Request recording in `MockServer` now happens **after** the response is resolved, so the response is available at recording time.

## [1.1.0] - 2026-02-10

### Added

- **XCFramework binary distribution** — pre-compiled binary for faster builds. Use the `SwiftMockServerBinary` product as an alternative to building from source. Both options share the same `import SwiftMockServer` API.
  - Archives 7 platform slices: iOS, iOS Simulator, macOS, tvOS, tvOS Simulator, watchOS, watchOS Simulator.
  - New `scripts/build-xcframework.sh` script to build, zip, and compute the checksum.
  - New `make xcframework` Makefile target.

### Fixed

- POST requests with JSON body (~1 KB+) no longer fail intermittently on slow CI runners (GitHub Actions `macos-15`). Two root causes were addressed:
  - **Server responded before receiving the full POST body.** `HTTPParser.parse()` succeeded as soon as headers arrived (`\r\n\r\n`), ignoring `Content-Length`. If the client sent headers and body in separate TCP segments, the server would respond and close the connection before the body was fully written — causing URLSession to receive a RST while still sending data. A new `HTTPParser.hasCompleteRequest(_:)` check now ensures the dispatcher waits for the complete body before invoking the handler.
  - **`SO_LINGER(0)` discarded buffered response data.** `closeConnection()` sent a TCP RST immediately, which could discard response bytes still in the kernel send buffer on CPU-constrained VMs. Replaced with `shutdown(SHUT_WR)` + drain + `close()`, which sends FIN only after all buffered data has been delivered.

## [1.0.0] - 2025-01-10

### Added

- **`MockServer`** — actor-based HTTP mock server with fully non-blocking, event-driven I/O (GCD + `DispatchSource`). No threads are ever blocked.
- **Route registration**
  - `stub(_:_:response:)` — static response for an exact method + path.
  - `register(_:_:handler:)` — dynamic async handler for exact path.
  - `registerParameterized(_:_:handler:)` — path templates with `:param` placeholders (e.g. `/users/:id`).
  - `registerPrefix(_:_:handler:)` — prefix matching (e.g. `/static/`).
  - `registerCatchAll(handler:)` — fallback for any unmatched request.
  - `registerAll(_:)` — batch-register from a `RouteStubCollection`.
  - LIFO priority: later routes override earlier ones for the same path.
- **Route management** — `removeRoute(id:)`, `removeAllRoutes()`, `setDefaultResponse(_:)`, `setResponseDelay(_:)`.
- **Response builders**
  - `.json(_:status:)` — from `Encodable`, raw `String`, or `Data`.
  - `.text(_:status:)`, `.html(_:status:)`, `.data(_:contentType:status:)`, `.status(_:)`.
  - `.imageFile(named:in:status:)` — load image from bundle with auto-inferred content type.
  - `.jsonFile(named:in:status:)` — load JSON from bundle resource.
  - `.image(_:contentType:status:)` — raw image data with magic-byte format auto-detection (PNG, JPEG, GIF, WebP, HEIC, TIFF, BMP, ICO, SVG).
- **Request recording & verification**
  - `requests` — all recorded requests in order.
  - `requests(method:path:)` — filter by method and/or path.
  - `didReceive(method:path:)` — boolean check.
  - `waitForRequest(method:path:timeout:)` — async polling with timeout.
  - `clearRecordedRequests()`.
- **`MockHTTPRequest`** — parsed request with `method`, `path`, `queryParameters`, `headers`, `body`, `bodyString`, and `jsonBody<T>()` decoder.
- **`HTTPParser`** — stateless HTTP/1.1 request parser and response serializer (public for advanced/isolated testing).
- **`HTTPStatus`** — value type with predefined constants for common status codes (200–504).
- **`HTTPMethod`** — enum covering all standard HTTP methods.
- **`MockServerError`** — typed errors for bind, listen, already-running, timeout, etc.
- **XCUITest integration**
  - `MockServerAppConfig` — generates `launchArguments` and `launchEnvironment` for `XCUIApplication`.
  - `MockServerDetector` — detect mock-server mode and read base URL/port from the environment inside the app under test.
- **`RouteStubCollection`** — declarative route list with `@resultBuilder` syntax, supporting conditionals and loops.
- **IPv6 loopback** — server binds to `[::1]` to avoid IPv4 ephemeral-port exhaustion and ambiguous `localhost` resolution.
- **Connection tracking** — `stop()` cancels all in-flight handler tasks and closes active connections immediately.
- **Comprehensive doc comments and README.**
