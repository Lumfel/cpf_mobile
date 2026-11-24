# CPF Mobile (`cpf_mobile`) — REST API v1 & Release Contract

## Base URL & Required Headers

- **API Base URL:** `https://<host>/api/v1` (local Laragon example: `http://localhost/cpf/public/api/v1` or `http://127.0.0.1:8000/api/v1`)
- **Required Headers (all JSON endpoints):**
  ```http
  Accept: application/json
  Content-Type: application/json
  ```
- **Authenticated Endpoints Header:**
  ```http
  Authorization: Bearer <plainTextToken>
  ```
- **CORS (Flutter Web / Chrome & Mobile):** Configured in `config/cors.php` for `api/*` and `sanctum/csrf-cookie` with `allowed_origins: ['*']`, `allowed_methods: ['*']`, `allowed_headers: ['*']`, and `supports_credentials: false` (Bearer token auth only).

---

## Health Check Endpoint

### 0. API & Database Health Check

`GET /api/v1/health`  
**Auth:** Public

Verifies that the Laravel API and active database connection (`DB::connection()->getPdo()`) are reachable.

#### Response `200 OK`
```json
{
  "ok": true,
  "app": "CPF",
  "database": "connected"
}
```

#### Response `503 Service Unavailable` (Database Unreachable)
```json
{
  "ok": false,
  "app": "CPF",
  "database": "disconnected"
}
```

---

## Standard Error Responses

- **`401 Unauthorized`** (missing, invalid, or revoked Bearer token):
  ```json
  {
    "message": "Unauthenticated."
  }
  ```
- **`403 Forbidden`** (insufficient role or cross-campus restriction):
  ```json
  {
    "message": "Only verified campus officers and the Club Adviser can use the attendance QR scanner."
  }
  ```
- **`422 Unprocessable Content`** (validation failure or domain rule violation):
  ```json
  {
    "message": "The provided credentials are incorrect.",
    "errors": {
      "email": [
        "The provided credentials are incorrect."
      ]
    }
  }
  ```
- **`429 Too Many Requests`** (rate limit exceeded on throttled auth endpoints).

---

## Authentication & Profile Endpoints

### 1. Email + Password Sign-In

`POST /api/v1/auth/login`  
**Auth:** Public • **Rate Limit:** `10 requests / minute`

#### Request Body
```json
{
  "email": "sofia.mercado@chmsu.edu.ph",
  "password": "PersonalSecret2026!",
  "device_name": "Pixel 8 Pro (cpf_mobile)"
}
```

#### Response `200 OK`
```json
{
  "token_type": "Bearer",
  "token": "1|aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789",
  "user": {
    "id": 12,
    "name": "Mercado, Sofia R.",
    "email": "sofia.mercado@chmsu.edu.ph",
    "avatar_url": "/profile-photos/12?v=1795400000",
    "must_change_password": false,
    "email_verified_at": "2026-11-20T08:30:00+00:00"
  },
  "verified_role": "president",
  "verified_role_label": "President",
  "is_alumni": false,
  "former_role": null,
  "former_role_label": null,
  "permissions": {
    "is_officer_or_adviser": true,
    "is_club_adviser": false,
    "can_propose_events": true,
    "can_scan_attendance": true,
    "can_access_archive": true
  },
  "campus": {
    "id": 1,
    "code": "ALIJIS",
    "name": "CHMSU Alijis Campus",
    "slug": "alijis",
    "current_academic_year": "2026-2027",
    "gc_group_name": "CPF Alijis Official Peer GC"
  },
  "membership": {
    "id": 15,
    "status": "approved",
    "full_name_last_first_mi": "Mercado, Sofia R.",
    "course": "BSIT",
    "year_level": "4",
    "section": "A",
    "course_year_section": "BSIT 4A",
    "is_in_messenger_gc": true,
    "has_paid_dues": true
  },
  "qr_unlocked": true,
  "member_id_code": "CPF-ALIJIS-2026-0012",
  "qr_payload": "CPF|campus:ALIJIS|user:12|role:president|sig:a1b2c3d4e5f60718",
  "daily_quote": {
    "id": 1,
    "quote_text": "Take a breath. Your presence in this community matters more than perfection.",
    "author_name": "Circle of Peer Facilitators",
    "mood_tag": "Calm"
  }
}
```

> **Notes:**
> - When `must_change_password` is `true` or `verified_role` is `null` (pending, rejected, or Former/Alumni account), `qr_unlocked` is `false` and `member_id_code` / `qr_payload` are `null`.
> - For Former accounts (`is_alumni: true`), `verified_role` is `null`, `former_role` / `former_role_label` reflect the highest position held (e.g., `"Former Club Adviser"`, `"Former President"`, `"Former Member"`), and all active write permissions are `false`.

---

### 2. 12-Character Passkey Code Sign-In (Atomic One-Time Claim)

`POST /api/v1/auth/passkey-code`  
**Auth:** Public • **Rate Limit:** `5 requests / minute`

Accepts either dashed (`ABCD-EFGH-JKLM`) or raw (`ABCDEFGHJKLM`) 12-character passkeys. Uses `PasskeyCodeLoginController::claimPasskeyCode()` inside a `DB::transaction()` with `lockForUpdate()`, marking the passkey `claimed` atomically so concurrent or repeated submissions fail with `422`.

#### Request Body
```json
{
  "email": "katrina.reyes@chmsu.edu.ph",
  "passkey_code": "ABCD-EFGH-JKLM",
  "device_name": "Samsung A55 (cpf_mobile)"
}
```

#### Response `200 OK`
Returns the exact same payload structure as `POST /api/v1/auth/login` (`token_type`, `token`, `user`, `verified_role`, `verified_role_label`, `is_alumni`, `former_role`, `former_role_label`, `permissions`, `campus`, `membership`, `qr_unlocked`, `member_id_code`, `qr_payload`, `daily_quote`).

---

### 3. Current Authenticated User & Attendance QR Card

`GET /api/v1/auth/me`  
**Auth:** `Bearer <token>` (`auth:sanctum`)

#### Response `200 OK`
Returns the exact profile payload returned by `login` / `passkey-code` (without `token_type` or `token`).

---

### 4. Sign Out (Revoke Current Token)

`POST /api/v1/auth/logout`  
**Auth:** `Bearer <token>` (`auth:sanctum`)

#### Response `200 OK`
```json
{
  "status": "logged_out",
  "message": "Token revoked."
}
```

---

## Campus Events & Officer QR Attendance Endpoints

### 5. List Same-Campus Events & Personal Attendance Status

`GET /api/v1/events`  
**Auth:** `Bearer <token>` (`auth:sanctum`)

Regular verified members receive `approved` and `cancelled` events on their campus. Users with `can_propose_events` (Adviser, President, Vice President) also receive `pending_approval` events.

#### Response `200 OK`
```json
{
  "campus": {
    "id": 1,
    "code": "ALIJIS",
    "name": "CHMSU Alijis Campus"
  },
  "can_scan_events": true,
  "events": [
    {
      "id": 4,
      "title": "Peer Facilitators General Assembly",
      "description": "Orientation & attendance check-in.",
      "location": "CHMSU Guidance AVR",
      "event_date": "2026-11-24",
      "event_date_label": "Nov 24, 2026 (Tue)",
      "start_time": "09:00",
      "end_time": "11:00",
      "status": "approved",
      "effective_status": "active",
      "reflection_enabled": true,
      "cancellation_reason": null,
      "logged_in_count": 14,
      "logged_out_count": 0,
      "can_scan": true,
      "my_attendance": {
        "status": "logged_in",
        "logged_in_at": "2026-11-24T09:05:12+00:00",
        "logged_out_at": null
      }
    }
  ]
}
```

> `my_attendance.status` is one of `"not_checked_in"`, `"logged_in"`, or `"completed"`.

---

### 6. Officer / Adviser 2-Stage QR Attendance Scan

`POST /api/v1/events/{event}/scan`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Requires verified same-campus Officer or Club Adviser while `effective_status === "active"`**

Reuses `EventActivityController::scanQr()` validation, HMAC signature check, cross-campus isolation, and 2-stage Log-In / Log-Out rules.

#### Request Body
```json
{
  "qr_payload": "CPF|campus:ALIJIS|user:19|role:member|sig:0123456789abcdef",
  "scan_type": "login"
}
```
- `qr_payload` (`string`, required, max `255`): Accepts either the HMAC-signed QR payload (`CPF|campus:...|user:...|role:...|sig:...`) or Member ID code (`CPF-ALIJIS-2026-0019`).
- `scan_type` (`string`, required): `"login"` or `"logout"`.

#### Responses
- **First Log-In (`201 Created`):**
  ```json
  {
    "status": "logged_in",
    "member_name": "Reyes, Katrina M.",
    "course_year_section": "BSIT 4A",
    "attendance": {
      "id": 9,
      "campus_event_id": 4,
      "user_id": 19,
      "logged_in_at": "2026-11-24T09:05:12.000000Z",
      "logged_in_by_user_id": 12,
      "logged_out_at": null,
      "logged_out_by_user_id": null
    }
  }
  ```
- **Duplicate Log-In (`200 OK`):** `"status": "already_logged_in"`
- **First Log-Out (`200 OK`):** `"status": "logged_out"`
- **Duplicate Log-Out (`200 OK`):** `"status": "already_logged_out"`
- **Log-Out before Log-In / Event Inactive / Invalid Signature / Wrong Campus (`422 Unprocessable Content`)**
- **Regular Member / Alumni / Other Campus Officer (`403 Forbidden`)**

---

## Public Mobile Release Distribution

### 7. Android APK Download (for Landing / Dashboard Install QR Code)

`GET /download/android`  
**Auth:** Public (Web route, outside auth middleware)

- When `storage/app/releases/cpf-android-latest.apk` exists: streams the APK download (`cpf-android-latest.apk`) with `Content-Type: application/vnd.android.package-archive` (`200 OK`).
- When not yet uploaded: returns `404 Not Found` with a styled Coming Soon HTML page for browsers, or JSON when `Accept: application/json` is sent:
  ```json
  {
    "status": "coming_soon",
    "platform": "android",
    "message": "CPF Mobile Android APK is coming soon. Please check back once the release build is published."
  }
  ```
