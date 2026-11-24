# CPF Non-Negotiable System Rules
1. Zero Admin Role: Only native CpfRole values (adviser, president, vice_president, secretary, treasurer, auditor, business_manager, pio, sergeant_at_arms, member, guidance_counselor).
2. Guidance Counselor Boundary: Non-adviser `guidance_counselor` is strictly coordination-only (Counselors GC, Testing Room, Guidance Referrals) — NEVER member approvals, dues, Officers GC, elections/voting, or club events.
3. Strict Campus Isolation: Users in Campus A must NEVER view, mutate, vote, scan, or download files belonging to Campus B.
4. RA 10173 Privacy: Referring peers may ONLY see safe referral status (`pending`, `ongoing`, `completed`) + scheduled slot — NEVER clinical notes. Profile photos, receipts, and GC ZIP archives must never be publicly accessible.
5. Lockout & Auth Integrity: Sole Club Adviser cannot be demoted; students cannot be promoted directly to `adviser`; temp passwords cannot bypass `EnsureTemporaryPasswordChanged`; single-use passkey codes/OTPs/handovers must be atomic (`lockForUpdate`) and rate-limited.
6. Ephemeral Election Chat: Election live chat exists only while an election session is active and must NEVER be saved permanently to the database.
