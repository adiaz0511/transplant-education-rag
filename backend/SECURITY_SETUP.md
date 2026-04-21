# Request Signing Integration Guide

This document explains how the iOS app authenticates requests to the backend using lightweight request signing.

The goal is practical protection for a short-lived TestFlight deployment:

- keep the Groq API key on the server only
- make direct unsigned requests fail
- let the iOS app prove it knows the shared app secret

This is intentionally a simple integration mechanism, not a high-assurance anti-reverse-engineering system.

## Protected Endpoints

The backend requires signed requests for:

- `POST /ask`
- `POST /lesson`
- `POST /quiz`

## Required Request Headers

Each protected request must include:

- `X-App-Id`
- `X-App-Version`
- `X-Timestamp`
- `X-Nonce`
- `X-Signature`

## Signing Algorithm

The backend verifies an `HMAC-SHA256` signature generated with the shared secret stored in `APP_SHARED_SECRET`.

The message format is:

```text
METHOD + "\n" + PATH + "\n" + TIMESTAMP + "\n" + NONCE + "\n" + RAW_BODY
```

Where:

1. `METHOD` is the uppercase HTTP method, for example `POST`
2. `PATH` is the request path only, for example `/ask`
3. `TIMESTAMP` is the Unix timestamp in seconds
4. `NONCE` is a cryptographically random per-request value
5. `RAW_BODY` is the exact request body byte sequence sent on the wire

The final signature is the lowercase hexadecimal digest of:

```text
HMAC_SHA256(APP_SHARED_SECRET, message)
```

## Pseudocode

```text
message = METHOD + "\n" + PATH + "\n" + TIMESTAMP + "\n" + NONCE + "\n" + RAW_BODY
signature = hex(HMAC_SHA256(APP_SHARED_SECRET, message))
```

## Implementation Requirements

The client must:

1. Serialize the JSON body exactly once
2. Use those exact bytes for both signing and transmission
3. Generate `X-Timestamp` as Unix time in seconds
4. Generate a fresh cryptographically random nonce for every request
5. Include all required headers on every protected endpoint call

Important:

- do not sign a body and then re-encode it differently
- do not sign the full URL; sign the path only
- do not reuse nonces

## Example

Request:

```http
POST /ask
```

Body:

```json
{"query":"What symptoms mean I should call the transplant team?"}
```

Example signing input:

```text
POST
/ask
1710000000
abc123noncevalue
{"query":"What symptoms mean I should call the transplant team?"}
```

The client computes the HMAC-SHA256 digest of that exact content using the shared secret, hex-encodes it, and sends it as `X-Signature`.

## Server Verification Behavior

The backend rejects the request when:

- a required header is missing
- `X-App-Id` does not match `APP_ID`
- the timestamp cannot be parsed
- the timestamp is outside the allowed window
- the nonce has already been used recently
- the signature does not match the expected value

## Configuration Contract

The backend and iOS app must agree on:

- `APP_ID`
- `APP_SHARED_SECRET`

Expected backend environment variables:

- `APP_ID`
- `APP_SHARED_SECRET`
- `SIGNATURE_MAX_AGE_SECONDS`
- `NONCE_TTL_SECONDS`

## Production Notes

- Never commit `APP_SHARED_SECRET` to git
- Inject the same secret into the deployed server and the app build process
- Set `APP_ENV=production` on the deployed server
- In production, the backend fails closed if `APP_SHARED_SECRET` or `APP_ID` is missing
- Keep `APP_DEBUG_LOGS=false` in production to avoid logging prompts, model output, or internal request details

## Local Development Notes

For local testing:

- the app and server must still use matching `APP_ID` and `APP_SHARED_SECRET`
- `ALLOWED_HOSTS` should include `localhost` and `127.0.0.1`
- if the signature is wrong, the backend returns `401`

## Common Failure Cases

### 401 Unauthorized

Usually caused by one of these:

- wrong `APP_ID`
- wrong shared secret
- body bytes changed after signing
- request path mismatch
- timestamp outside the allowed window
- nonce replay

### Signature mismatch even though headers are present

Check:

- whether the app is signing `/ask` instead of the full URL
- whether the app sends the exact same bytes it signed
- whether the timestamp string format matches exactly
- whether the shared secret on the app and server are identical
