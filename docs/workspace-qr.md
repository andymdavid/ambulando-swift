# Shared NStack workspace QR

Connect accepts copied `nstack:workspace:v3:…` text and QR images from the system
file picker. Apple's Vision scanner runs locally. Camera capture is not implemented.
Check service previews the signed name, exact UUID, service/authority keys and
endpoint. Choose an advertised transport explicitly before confirming.

The consumer rejects noncanonical base64url/JSON, duplicate/unknown fields, invalid
shape, oversized copy text (8192 bytes), invalid kind-30383 signatures and mismatched
service keys. A fresh random nonce goes to the exact workspace connection-proof
GET, authenticated by the existing unlocked identity. Kind-30384 signature, nonce,
exact URL, service, UUID, authority and 60-second expiry must match. Existing service
pins cannot be replaced by scanning. Denial and mismatch leave the connection
unselected; no workspace creation, app registration or membership grant occurs.

Authorized workspace/app listing and app-specific `/me` must agree with the QR.
Multiple namespaces require the existing namespace chooser rather than an implicit
choice. After proof and membership validation only the exact workspace is selected;
existing stored identities, namespaces, consent and other workspaces are preserved.
Legacy manual HTTPS connections continue unchanged.

HTTPS is supported. FIPS remains an explicit unsupported selection requiring the
existing native mesh transport capability; the consumer never retries HTTPS. No
second daemon, bridge or machine identity is introduced. A supported existing native
FIPS network/capability integration and peer-bound request/revocation contract are
needed for native FIPS acceptance. Browser FIPS is implemented separately in `sol`
using the existing universal scoped transport.

Swift core tests use the same signed fixture and signed rejection cases as Android,
including proof URL/nonce/authority/UUID/expiry mismatches. Denial tests inspect the
own-user NIP-98 GET and absence of mutation. App compilation and synthetic tests
are separate from installation and real-account acceptance. Source delivery is by
pushed GitHub main; it does not establish installation on another Mac or TestFlight
publication. This change advances Mac build 96 and iPhone/iPad build 100.
