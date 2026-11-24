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
- **`429 Too Many Requests`** (rate limit exceeded on throttled endpoints).

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
Returns the exact same payload structure as `POST /api/v1/auth/login`.

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
- **First Log-In (`201 Created`):** `"status": "logged_in"`
- **Duplicate Log-In (`200 OK`):** `"status": "already_logged_in"`
- **First Log-Out (`200 OK`):** `"status": "logged_out"`
- **Duplicate Log-Out (`200 OK`):** `"status": "already_logged_out"`
- **Log-Out before Log-In / Event Inactive / Invalid Signature / Wrong Campus (`422 Unprocessable Content`)**
- **Regular Member / Alumni / Other Campus Officer (`403 Forbidden`)**

---

## Membership Roster, Messenger GC Checklist & Payments Endpoints

### 7. Same-Campus Approved Roster (A–Z)

`GET /api/v1/membership/roster`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Requires verified same-campus Officer or Club Adviser (`isOfficerOrAdviser()`)**

Returns the alphabetical (`last_name`, `first_name`) approved chapter roster with `is_in_messenger_gc` and `has_paid_dues` flags.

#### Response `200 OK`
```json
{
  "campus": {
    "id": 1,
    "code": "ALIJIS",
    "name": "CHMSU Alijis Campus",
    "gc_group_name": "CPF Alijis Official Peer GC"
  },
  "permissions": {
    "can_confirm_messenger_gc": true,
    "can_validate_payments": true
  },
  "roster": [
    {
      "id": 15,
      "user_id": 12,
      "full_name_last_first_mi": "Mercado, Sofia R.",
      "course": "BSIT",
      "year_level": "4",
      "section": "A",
      "course_year_section": "BSIT 4A",
      "role": "president",
      "role_label": "President",
      "is_in_messenger_gc": true,
      "gc_confirmed_at": "2026-11-24T09:00:00+00:00",
      "gc_confirmed_by_name": "Montemayor, Elena V.",
      "has_paid_dues": true,
      "dues_confirmed_at": "2026-11-24T09:05:00+00:00",
      "dues_confirmed_by_name": "Alvarez, Hannah G."
    }
  ]
}
```

---

### 8. Toggle Messenger GC Checklist

`PATCH /api/v1/membership/{membership}/toggle-gc`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Requires same-campus role with `canConfirmMessengerGc()` (Adviser, President, Vice President, Secretary, PIO)**

#### Response `200 OK`
```json
{
  "status": "updated",
  "membership_id": 15,
  "is_in_messenger_gc": true,
  "gc_confirmed_by": 12,
  "gc_confirmed_at": "2026-11-24T09:00:00+00:00"
}
```

---

### 9. Toggle Membership Dues Checklist

`PATCH /api/v1/membership/{membership}/toggle-dues`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Requires same-campus role with `canValidatePayments()` (Treasurer, Adviser, President, Vice President)**

#### Response `200 OK`
```json
{
  "status": "updated",
  "membership_id": 15,
  "has_paid_dues": true,
  "dues_confirmed_by": 14,
  "dues_confirmed_at": "2026-11-24T09:05:00+00:00"
}
```

---

### 10. List Approved Payment Channels, Personal Receipts & Treasurer Validation Queue

`GET /api/v1/payments`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Blocked for Guidance Counselors (`403`)**

- Every campus member receives `destinations` (Adviser-approved GCash/Maya/Cash/Bank channels) and `my_submissions`.
- Roles with `canValidatePayments()` or `canAuditFinances()` also receive `validation_queue` containing same-campus payment submissions; regular members receive `"validation_queue": []`.

#### Response `200 OK`
```json
{
  "campus": {
    "id": 1,
    "code": "ALIJIS",
    "name": "CHMSU Alijis Campus"
  },
  "my_dues_status": {
    "has_paid_dues": false,
    "dues_confirmed_at": null
  },
  "permissions": {
    "can_validate_payments": true,
    "can_audit_finances": true
  },
  "destinations": [
    {
      "id": 1,
      "channel": "GCash",
      "account_name": "CPF Alijis Chapter",
      "account_number": "0917-000-1111"
    }
  ],
  "my_submissions": [],
  "validation_queue": [
    {
      "id": 3,
      "user_id": 19,
      "member_name": "Reyes, Katrina M.",
      "course_year_section": "BSIT 4A",
      "destination_id": 1,
      "channel": "GCash",
      "account_name": "CPF Alijis Chapter",
      "purpose": "AY 2026-2027 Membership Dues",
      "amount": 100,
      "reference_number": "GCASH-998877",
      "has_receipt": true,
      "status": "pending",
      "treasurer_notes": null,
      "validated_by_treasurer_id": null,
      "validated_at": null,
      "created_at": "2026-11-24T10:15:00+00:00"
    }
  ]
}
```

---

### 11. Submit Payment & Optional Receipt Upload

`POST /api/v1/payments/submit`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Accepts JSON or `multipart/form-data`**

#### Request Fields
- `destination_id` (`integer`, required): Must belong to the member's campus, be active, and approved by the Club Adviser.
- `purpose` (`string`, required, max `140`)
- `amount` (`numeric`, required, `1`–`50000`)
- `reference_number` (`string`, required, max `100`)
- `receipt` (`file`, optional, `jpg|jpeg|png|pdf`, max `5120` KB)

#### Response `201 Created`
```json
{
  "status": "submitted",
  "payment": {
    "id": 3,
    "campus_id": 1,
    "user_id": 19,
    "destination_id": 1,
    "purpose": "AY 2026-2027 Membership Dues",
    "amount": 100,
    "reference_number": "GCASH-998877",
    "status": "pending"
  }
}
```

---

### 12. Validate or Reject Submitted Payment

`PATCH /api/v1/payments/{payment}/validate`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Requires same-campus role with `canValidatePayments()`**

#### Request Body
```json
{
  "status": "validated",
  "treasurer_notes": "Verified against GCash statement."
}
```

---

## Referrals & Counselor Coordination Endpoints

### 13. View Own Submitted Referrals (Privacy-Safe Status & Slot View)

`GET /api/v1/referrals/mine`  
**Auth:** `Bearer <token>` (`auth:sanctum`)

Strictly enforces clinical confidentiality: the referring peer sees **only** the safe `status` / `feedback_status` (`"pending"`, `"ongoing"`, or `"completed"`), non-clinical `safe_scheduling_note`, `suggested_slot`, and `confirmed_slot`. `concern_summary` and `confidential_clinical_notes` are **never** returned. Also returns active campus `counselors` (with `weekly_vacant_slots`) and `booked_slots` (anonymized timeslots) to assist free-slot selection.

#### Response `200 OK`
```json
{
  "campus": {
    "id": 1,
    "code": "ALIJIS",
    "name": "CHMSU Alijis Campus"
  },
  "counselors": [
    {
      "id": 1,
      "name": "Dr. Elena V. Montemayor, RGC",
      "title": "Lead Guidance Counselor & CPF Adviser",
      "specialty": "Crisis Triage & Personal Wellness",
      "weekly_vacant_slots": [
        {
          "start": "08:30",
          "end": "10:00",
          "label": "8:30 AM – 10:00 AM",
          "days": [1, 2, 3, 4, 5]
        }
      ]
    }
  ],
  "booked_slots": [],
  "referrals": [
    {
      "id": 7,
      "referral_type": "peer_referral",
      "student_identifier": "Mendoza, Carlo T.",
      "student_course_section": "BSED 2B",
      "status": "ongoing",
      "feedback_status": "ongoing",
      "safe_scheduling_note": "Scheduled at Guidance Testing Room.",
      "counselor": {
        "id": 1,
        "name": "Dr. Elena V. Montemayor, RGC",
        "title": "Lead Guidance Counselor & CPF Adviser",
        "specialty": "Crisis Triage & Personal Wellness"
      },
      "suggested_slot": {
        "date": "2026-11-27",
        "start_time": "08:30",
        "end_time": "09:30"
      },
      "confirmed_slot": {
        "date": "2026-11-27",
        "start_time": "08:30",
        "end_time": "09:30",
        "room_status": "approved"
      },
      "preferred_date": "2026-11-27",
      "preferred_start_time": "08:30",
      "preferred_end_time": "09:30",
      "created_at": "2026-11-24T10:30:00+00:00"
    }
  ]
}
```

---

### 14. Submit Guidance Referral with Optional Free-Slot Suggestion

`POST /api/v1/referrals`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Read-only Alumni blocked (`403`)**

Validates optional slot suggestions (`preferred_date`, `preferred_start_time`, `preferred_end_time`) against:
1. Selected counselor's `weekly_vacant_slots` schedule (day-of-week + consultation window), and
2. Atomic `lockForUpdate()` overlap checks against existing `RoomRequest` and active `GuidanceReferral` bookings (`422` if unavailable).

#### Request Body
```json
{
  "referral_type": "peer_referral",
  "student_identifier": "Mendoza, Carlo T.",
  "student_course_section": "BSED 2B",
  "suggested_priority": "semi_urgent",
  "concern_summary": "Requested a calm check-in regarding academic workload.",
  "counselor_id": 1,
  "preferred_date": "2026-11-27",
  "preferred_start_time": "08:30",
  "preferred_end_time": "09:30"
}
```
- `campus_id` (`integer`, optional): Defaults to the authenticated user's `primaryMembership.campus_id`; cross-campus IDs fail with `403`.
- `referral_type`: `"self_counseling"` or `"peer_referral"`.
- `suggested_priority` (`string`, optional, defaults to `"routine"`): `"emergency"`, `"very_urgent"`, `"urgent"`, `"semi_urgent"`, or `"routine"`.

#### Response `201 Created`
```json
{
  "status": "submitted",
  "referral_id": 7,
  "feedback_status": "pending",
  "suggested_slot": {
    "date": "2026-11-27",
    "start_time": "08:30",
    "end_time": "09:30"
  }
}
```

---

## Mobile Elections & Ephemeral Session Chat Endpoints

### 15. Get Active Campus Election, Seats, Nominees & Voting Status

`GET /api/v1/elections/active`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Requires verified campus member or Club Adviser; Guidance Counselors blocked (`403`)**

Returns `"active_election": null` when no open election session is currently running on the user's campus.

#### Response `200 OK`
```json
{
  "campus": {
    "id": 1,
    "code": "ALIJIS",
    "name": "CHMSU Alijis Campus"
  },
  "seats": [
    {
      "key": "president",
      "label": "President",
      "optional": false,
      "required_year": null,
      "seat_order": 1,
      "is_current": true,
      "result": null
    }
  ],
  "active_election": {
    "id": 5,
    "title": "AY 2026-2027 CPF General Election",
    "academic_year": "2026-2027",
    "status": "open",
    "current_position": "president",
    "current_position_label": "President",
    "current_phase": "voting",
    "round_number": 1,
    "opens_at": null,
    "closes_at": null,
    "position_results": {},
    "nominees": [
      {
        "id": 11,
        "user_id": 19,
        "name": "Reyes, Katrina M.",
        "course_year_section": "BSIT 4A",
        "year_level": "4",
        "avatar_url": null,
        "position": "president",
        "platform": "Accessible peer listening circles.",
        "nominated_by_user_id": 12,
        "nomination_status": "accepted",
        "is_tie_contender": false,
        "votes": 8
      }
    ],
    "current_position_nominees": [],
    "voting_status": {
      "can_nominate": false,
      "can_vote": true,
      "has_voted_current_round": false,
      "my_current_vote_candidate_id": null,
      "my_votes": {},
      "has_opted_out": false
    },
    "live_chat": {
      "enabled": true,
      "ephemeral": true,
      "max_messages": 100,
      "ttl_seconds": 7200
    }
  }
}
```

---

### 16. Nominate Candidate for Current Seat

`POST /api/v1/elections/{election}/nominate`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Requires verified same-campus member while `status === "open"` and `current_phase === "nomination"`**

#### Request Body
```json
{
  "nominee_user_id": 19,
  "platform": "Accessible peer listening circles."
}
```

#### Response `201 Created`
```json
{
  "status": "nominated",
  "candidate": {
    "id": 11,
    "election_id": 5,
    "user_id": 19,
    "position": "president",
    "nomination_status": "pending"
  }
}
```

---

### 17. Cast Floor Vote

`POST /api/v1/elections/{election}/vote`  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Requires verified student member/officer (Adviser & Guidance Counselors blocked with `403`) while `current_phase` is `"voting"` or `"tie_breaker"`**

#### Request Body
```json
{
  "candidate_id": 11,
  "position": "president"
}
```
> `position` is optional on mobile and defaults to the election's active `current_position` if omitted.

#### Response `200 OK`
```json
{
  "status": "voted"
}
```
(Subsequent submissions in the same round return `"status": "already_voted"`.)

---

### 18. Ephemeral Election Session Live Chat (Cache-Only)

`GET /api/v1/elections/{election}/live-chat`  
`POST /api/v1/elections/{election}/live-chat` (**Rate Limit:** `30 requests / minute`)  
**Auth:** `Bearer <token>` (`auth:sanctum`) — **Verified same-campus members & Club Adviser only**

- **Zero Permanent Storage:** Messages are stored **exclusively** in Laravel `Cache` under key `election:{id}:live_chat` (capped at the latest `100` messages with a `2-hour` TTL). No database table is ever written.
- **Active Session Guard:** If the election is `draft`, `closed`, `completed`, or outside its `opens_at`/`closes_at` window, both `GET` and `POST` return `422 Unprocessable Content` (`403 Forbidden` for unauthorized/cross-campus users).
- **Automatic Flush on Close:** Closing or completing an election (`Election` model lifecycle hook) immediately flushes `Cache::forget("election:{id}:live_chat")` so session chat is permanently wiped.

#### `POST` Request Body
```json
{
  "message_body": "Seconding Katrina's nomination for President!"
}
```

#### `POST` Response `201 Created`
```json
{
  "status": "sent",
  "ephemeral": true,
  "ttl_seconds": 7200,
  "message": {
    "id": "b1d2e3f4-5678-490a-bcde-0123456789ab",
    "election_id": 5,
    "sender_user_id": 12,
    "sender_name": "Mercado, Sofia R.",
    "sender_role": "president",
    "sender_role_label": "President",
    "message_body": "Seconding Katrina's nomination for President!",
    "sent_at": "2026-11-24T11:00:00+00:00"
  },
  "messages_count": 1
}
```

#### `GET` Response `200 OK`
```json
{
  "election_id": 5,
  "ephemeral": true,
  "max_messages": 100,
  "ttl_seconds": 7200,
  "messages": []
}
```

---

## Public Mobile Release Distribution

### 19. Android APK Download (for Landing / Dashboard Install QR Code)

`GET /download/android`  
**Auth:** Public (Web route, outside auth middleware)

- When `storage/app/releases/cpf-android-latest.apk` exists: streams the APK download (`cpf-android-latest.apk`) with `Content-Type: application/vnd.android.package-archive` (`200 OK`).
- When not yet uploaded: returns `404 Not Found` with a styled Coming Soon HTML page for browsers, or JSON when `Accept: application/json` is sent.
