---
name: ownfold-integration
description: Integrate, review, debug, or migrate Ownfold encrypted vaults in TypeScript applications. Use when working with Ownfold or any @ownfold/* package, choosing a backend or browser-E2EE architecture, wiring authentication/framework/database adapters, persisting encrypted records, handling Recovery Kits/devices/pairing/key rotation, diagnosing typed Ownfold errors, or testing an Ownfold security boundary.
---

# Ownfold Integration

Build Ownfold integrations from the current documentation and installed package exports. Preserve
the application's chosen trust boundary throughout implementation, review, and debugging.

## Start from authoritative sources

1. Read `https://ownfold.dipxsy.app/docs/get-started/installation.md` for current requirements, package
   tags, and supported adapters.
2. Select one architecture before choosing packages:
   - Backend coordination: the application chooses the client that owns encryption.
   - Trusted backend encryption: a service, worker, job, or CLI intentionally sees plaintext.
   - Browser E2EE: plaintext and record keys remain in the browser.
3. Read the matching quickstart:
   - Backend: `https://ownfold.dipxsy.app/docs/get-started/backend-quickstart.md`
   - Browser E2EE: `https://ownfold.dipxsy.app/docs/get-started/quickstart.md`
4. Inspect the host repository's framework, auth, database, runtime, package manager, and existing
   security controls before editing.
5. Verify every symbol against the installed package types or the relevant API reference. Do not
   invent an API from examples or memory.

Append `.md` to any Ownfold documentation route for agent-readable Markdown. Use
`https://ownfold.dipxsy.app/llms.txt` to discover pages and
`https://ownfold.dipxsy.app/llms-full.txt` only when broad, full-corpus context is necessary.

## Choose only the required layers

| Responsibility | Package or choice |
| --- | --- |
| Domain types, parsers, contracts, errors | `@ownfold/core` |
| Production cryptography | `@ownfold/crypto` |
| Vault coordination | `@ownfold/server` |
| Browser lifecycle and record encryption | `@ownfold/browser` |
| Optional headless React state/actions | `@ownfold/react` |
| Web-standard HTTP handler and browser transport | `@ownfold/fetch` |
| Framework bridge | One of `@ownfold/next`, `@ownfold/node`, `@ownfold/fastify`, `@ownfold/hono`, `@ownfold/elysia`, `@ownfold/tanstack-start`, or `@ownfold/trpc` |
| Authentication resolver | Host-owned resolver, `@ownfold/better-auth`, `@ownfold/auth-js`, or `@ownfold/workos/tanstack-start` |
| Vault storage | One of `@ownfold/postgres`, `@ownfold/drizzle`, `@ownfold/prisma`, or `@ownfold/sqlite` |
| Contract and adversarial test helpers | `@ownfold/testing` as a development dependency |
| Schema generation and migrations | `@ownfold/cli` as a development dependency |

Do not add browser or React packages to a backend-only service. Keep framework, authentication, and
database choices independent. Follow the host repository's existing dependency and module patterns.

## Configure environment variables

Applications set the variables documented for their selected Ownfold integrations. Ownfold owns
the T3 Env and validator schemas internally. Do not tell consumers to install, configure, or import
`@t3-oss/env-core` or Valibot for Ownfold.

Provider resolvers validate their provider boundary when constructed:

- Better Auth: `BETTER_AUTH_SECRET`, `BETTER_AUTH_URL`;
- Auth.js: `NEXTAUTH_SECRET`, `NEXTAUTH_URL`, and paired optional
  `GITHUB_ID`/`GITHUB_SECRET`;
- WorkOS AuthKit: required `WORKOS_CLIENT_ID`, `WORKOS_API_KEY`,
  `WORKOS_REDIRECT_URI`, `WORKOS_COOKIE_PASSWORD`, plus supported optional `WORKOS_API_*` and
  `WORKOS_COOKIE_*` overrides. Use `WORKOS_COOKIE_SAME_SITE`, not `WORKOS_COOKIE_SAMESITE`.

Use typed readers from `@ownfold/server` for PostgreSQL, SQLite, HTTP/listener settings, static
example identity, Node runtime, and passkey RP configuration. CLI-generated `env.server.ts` files
must call these readers and must not add T3 Env or Valibot to the consuming project. Read
`https://ownfold.dipxsy.app/docs/guides/environment-configuration.md` for the current inventory.

## Implement the server boundary

1. Create the selected storage adapter and run its documented schema/migration flow.
2. Resolve an immutable user ID from a verified server-side session.
3. Create one `VaultServer` with that adapter and resolver.
4. Mount one framework bridge at a host-owned route.
5. Preserve the framework's origin, CSRF, cookie, request-size, and cache controls.
6. Keep application records in application-owned routes and tables; Ownfold coordinates vault
   lifecycle state rather than becoming the application's content store.
7. Validate every encrypted application write with `validateEncryptedRecordWrite()` using the
   independently known authenticated owner, namespace, and record ID before persistence.

Never derive identity from a client-provided header, body, query parameter, envelope, or owner ID.
Use `singleUserResolver` only for an explicitly private single-user process, never a public or
multi-user service.

For WorkOS AuthKit in TanStack Start, use `workosAuthKitUserResolver()` only after AuthKit
middleware has established verified server context. Resolve only `user.id`; never derive identity
from email, organization membership, tokens, headers, query input, or request bodies.

## Implement passkey vault access

Keep authentication and encryption recovery separate. A Better Auth, Auth.js, or WorkOS passkey
login identifies the user but does not provide Ownfold's WebAuthn PRF result or vault key. Use a
dedicated Ownfold passkey credential for portable vault access.

1. Configure exact RP ID, RP name, and origin allowlist with the `OWNFOLD_WEBAUTHN_*` variables and
   construct coordination with `createPasskeyVaultServerFromEnvironment()`.
2. Mount `createPasskeyVaultFetchHandler()` on the server and use
   `createFetchPasskeyVaultTransport()` in the browser. Use the official framework helper where one
   exists, such as `createTanStackStartPasskeyVaultHandlers()` for TanStack Start.
3. Before enrolling a passkey from an unlocked device, call `beginDeviceApproval()`, create the
   device-bound proof with `VaultClient.createDeviceApprovalProof()`, and pass that proof to
   `beginPasskeyEnrollment({ authorizationProof })`.
4. Always require Ownfold's built-in device proof. It is bound to the owner, vault revision,
   authorizing device, enrollment challenge, and expiry, and the server consumes it atomically once.
   Session authentication, a device ID, or an optional host callback must never replace this proof.
5. Treat `verifyDeviceEnrollmentAuthorization`, when configured, as an additional authorization
   gate after the built-in proof succeeds, never as an alternative or bypass.
6. Configure `getPasskeyUserInfo` with a verified, recognizable account name and display name when
   the host can provide them. These labels are password-manager display metadata only; Ownfold
   continues to bind ownership to the immutable authenticated user ID and derives a stable opaque
   WebAuthn user handle from it.
7. Require user verification and runtime PRF support. Keep the Recovery Kit and trusted-device
   pairing as fail-closed fallbacks.
8. Pass server-returned registration and authentication options directly to the official browser
   helpers. They decode the base64url PRF input to the `ArrayBuffer` required by WebAuthn, reject a
   malformed input before the ceremony, and preserve wrapped cancellation/timeout errors.
9. Encrypt a portable X25519 private key locally from the PRF result; never send PRF output,
   private keys, root keys, Recovery Kit secrets, record keys, or plaintext to the server.
10. On a new browser, decrypt locally, open the root-key envelope, and enroll a normal local device.
11. Include every active passkey portable public key in atomic root-key rotation. Revocation blocks
   future passkey-assisted unlock without revoking normal devices already enrolled through it.
12. Do not exclude revoked passkey credential IDs from fresh enrollment. Revocation cannot delete
   credentials from a platform password manager; surface `PASSKEY_ALREADY_REGISTERED` with an
   instruction to remove the retained credential there or select another authenticator.
13. Prefer `getPasskeyCapabilityReport()` before enrollment and keep PRF capability `unknown` until
    a real ceremony proves it. Render its stable blocker codes and Recovery Kit/pairing fallbacks.
14. Prefer `createPasskeyFlowCoordinator()` or React's `usePasskeyFlow()` for complete enrollment
    and unlock flows. Subscribe to typed progress; do not reorder or duplicate low-level calls.
15. Use `betterAuthPasskeyUserInfo()`, `authJsPasskeyUserInfo()`, or
    `workosPasskeyUserInfo()` only with verified provider profiles. Treat
    `PASSKEY_USER_INFO_UNAVAILABLE` as fail-closed.

Use the official browser/server helpers and persistence contracts; do not hand-roll WebAuthn
verification. Read `https://ownfold.dipxsy.app/docs/guides/passkey-vault-access.md` before changing
this flow.

## Implement browser E2EE

1. Create one browser transport pointed at the host application's Ownfold route.
2. Create and initialize the browser client once. With React, let `VaultProvider` initialize it
   after hydration.
3. Render application-owned onboarding and settings UI from the discriminated vault state.
4. Require explicit vault creation. Create, download, and re-import-verify the Recovery Kit locally
   before treating onboarding as complete.
5. When the host needs application branding, create one configured file helper with
   `createRecoveryKitFile({ format, filename })`, pass it to `createVaultClient({ recoveryKit })`,
   and use the same helper for every initial, replacement, and rotation-kit download. Use a
   lowercase application identifier ending in `.recovery-kit`, such as `mori.recovery-kit`; the
   format is authenticated and existing `ownfold.recovery-kit` files remain readable.
6. Encrypt before application mutation. Persist the validated envelope plus only necessary routing
   metadata.
7. Decrypt only after retrieval, using namespace, record ID, and owner ID from an independent
   application source.
8. Lock on sign-out and account changes. Keep automatic and cross-tab locking enabled.
9. Prefer `createRecoveryKitFlowCoordinator()` or `useRecoveryKitFlow()` for branded download and
   re-import verification. Coordinator state and confirmation summaries must remain secret-free.
10. For device settings, prefer `getDeviceInventory()` over combining `listDevices()` with local
    state. Use `updateDeviceLabel(id, label, revision)` for display-only rename and
    `diagnoseLocalDevice()` for typed reconciliation guidance.

Device labels are normalized at the API boundary to 1–128 visible characters. Optional browser,
OS, and device-class metadata is untrusted presentation data only. Never authorize from labels or
environment metadata, and never expand the metadata into invasive fingerprinting. Apply device
environment migration `0007_ownfold_device_environment.sql` where relevant.

Keep Recovery Kit files, recovery passwords/codes, root keys, device private keys, record keys, and
plaintext out of transports, server actions, SSR props, logs, analytics, query-string state,
persisted client caches, and browser storage. Do not add plaintext search, previews, analytics
properties, or fallback fields to an E2EE record.

Treat XSS, malicious same-origin JavaScript, compromised dependencies, browser extensions, and a
compromised unlocked device as inside the browser trust boundary. Never claim Ownfold protects
against them. Read `https://ownfold.dipxsy.app/docs/security-guidance.md` and
`https://ownfold.dipxsy.app/docs/threat-model.md` before making a production-security claim.

## Preserve authenticated record context

Use stable, application-owned values for `namespace`, `recordId`, and optional `ownerId`. Supply the
same values during encryption, server validation, retrieval, and decryption. Never copy expected
context from the encrypted envelope itself. A mismatch is a security failure, not a signal to retry
with envelope-provided values.

Preserve unknown or unsupported ciphertext exactly. Do not relabel key versions, rewrite unknown
formats, weaken validation, or substitute plaintext/empty content to make decryption succeed.

## Handle failures explicitly

Ownfold returns typed `Result` values for expected failures. Branch on `status`, use stable `code` or
`_tag` values for application behavior, and show the safe message when appropriate. Do not swallow
errors or turn them into success-shaped fallbacks.

- Vault unavailable or locked: render create, unlock, restore, or pair actions from current state.
- Recovery authentication failure: remain locked and retry locally; upload nothing.
- Context mismatch, corruption, or authentication failure: return no partial plaintext and preserve
  the original ciphertext for investigation.
- Unsupported format: require a compatible reader or documented migration.
- Revision conflict: fetch authoritative state, reconcile, regenerate affected cryptographic
  artifacts, and retry with the new revision.
- Transport failure after a mutation: treat remote state as unknown and reload before retrying.
- Unexpected framework/runtime failure: return a generic safe response and keep scrubbed operational
  detail server-side.

Read `https://ownfold.dipxsy.app/docs/reference/errors.md` before adding recovery behavior. Never log
secrets, plaintext, raw request bodies, or database credentials.

Use `ErrorRecovery.describe(error)` for machine-readable recovery facts and
`CredentialLifecycle.describe(method)` for active/revoked passkey guidance. Keep final wording and
policy application-owned. Unknown facts must stay unknown.

## Review and debug systematically

For an existing integration:

1. Trace identity from the verified session through every adapter call.
2. Trace one record from plaintext to encryption, server validation, persistence, retrieval, and
   decryption.
3. Inspect network captures and server logs for plaintext, keys, and recovery material.
4. Confirm expected record context comes from the route/repository, not the envelope.
5. Check lifecycle handling for create, lock, unlock, restore, device enrollment/revocation,
   pairing expiry, and resumable rotation where used.
6. Compare findings with `https://ownfold.dipxsy.app/docs/unsafe-integrations.md`.
7. Run `ownfold doctor` after coordinated package or schema changes. It checks exact package versions,
   required environment names, generated assets, and standard wiring without reading secret
   values; its secure-context and custom-route warnings still require host verification.

For a failing integration, first identify the failing boundary: input parsing, vault state, crypto,
transport, authentication, storage, record context, device, pairing, or rotation. Preserve the typed
error and current state while narrowing the cause. Do not bypass the failing boundary to prove a
happy path.

## Verify the integration

Run the smallest relevant host checks, then cover these Ownfold-specific cases:

- authenticated, anonymous, expired, and malformed sessions;
- create, Recovery Kit verification, reload, lock, unlock, restore, and unavailable device;
- JSON or binary record round trip;
- wrong owner, namespace, and record ID;
- corrupted and unsupported envelopes;
- transport capture proving no plaintext, root keys, or recovery secrets crossed the boundary;
- stale revisions and interrupted/resumed lifecycle work used by the application;
- passkey PRF unavailable/cancelled paths, wrapped WebAuthn cancellation errors, malformed PRF,
  worker, and transport input, atomic concurrent challenge consumption, challenge replay/expiry,
  revocation, normal-device enrollment, reload, and active-recipient root rotation where passkeys
  are used;
- real database migration and adapter behavior.
- device rename normalization, stale revisions, current/other-device rename, exact adapter input
  projection, inventory consistency, and untrusted metadata behavior;
- `assertSecretSafeTransportCapture()` over host transport observations and deterministic passkey
  failures from `passkeyFailureScenario()` where appropriate.

Use `@ownfold/testing` compliance suites and in-memory helpers for tests, but do not ship them in
production or treat an in-memory pass as proof of real driver, transaction, migration, and
concurrency behavior. Read `https://ownfold.dipxsy.app/docs/reference/testing.md` for the current matrix.

Report the selected trust boundary, packages and adapters used, files changed, security invariants
preserved, checks run, and any unverified production controls. Clearly distinguish an SDK guarantee
from a responsibility retained by the host application.
