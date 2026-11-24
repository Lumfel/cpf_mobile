# CPF System Phases & Scope Boundaries

## Phase 1 — Web Platform (ACTIVE / PILOT-READY)
- Stack: Laravel 13 + Vue 3.5 + Inertia.js v3 + Tailwind CSS v4 + Fortify (Passkeys/2FA) + MySQL (Laragon).
- Active Core: Public Landing & Data Privacy modal, First-Boot Adviser setup, Atomic Membership Application + Google Forms Webhook, 12-char Passkey Code login + Forced Password Change, QR-First Peer Dashboard, Single-Room Testing Room, Confidential Guidance Referrals (5-tier scale + safe peer status + counselor free-slot check), Parliamentary Elections (1-120+ seats, winner locks, tie-break), Campus Events + 2-Stage QR Attendance + Manual Fallback + Opt-in Reflections, 5-Theme Time Capsules, Peer Quotes, Officers/Counselors Private GCs + ZIP Archives, PIO/Secretary Templated Announcements, Treasurer Dues Validation, Policy & By-Laws, Same-Campus Profile Photos, and Guidance-Counselor-Only Adviser Handover + OTP Counselor Invites.
- Remaining Production Ops (not code bugs): Live Laravel Reverb (`BROADCAST_CONNECTION=reverb`), production SMTP, `SESSION_ENCRYPT=true`, and nightly `mysqldump` backups.

## Phase 2 — Flutter Android Mobile App (`cpf_mobile`, ACTIVE)
- Stack: Flutter + Dart + Dio + Laravel Sanctum (`/api/v1/*`) + `flutter_secure_storage` + `sqflite` + `qr_flutter` + `mobile_scanner`.
- Active Core: Synced 5 themes + official CPF logo, Auth (Email/Password + 12-char Passkey Code), Offline SQLite Peer QR Pass, Events + 2-Stage QR Scanner + Manual Checklist, Payments & Messenger GC A-Z Checklist, Among Us-style Elections + Ephemeral Session Chat, and direct APK QR installer (`GET /download/android`).

## Explicitly Deferred / Out of Scope (DO NOT FLAG AS MISSING)
- Awards, Digital Certificates, and Blockchain Credentials (deprioritized for now).
- Intercampus communication across campuses (deferred; Alijis is active pilot campus).
- iOS App Store / Google Play Store publishing (distributed via Android APK QR download for pilot).
- Neon Postgres, Supabase, and Argon2id migration (locked to MySQL + Laragon).
