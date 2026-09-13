CREATE TABLE launch_waitlist (
  email TEXT PRIMARY KEY COLLATE NOCASE,
  created_at TEXT NOT NULL,
  consented_at TEXT NOT NULL,
  consent_version TEXT NOT NULL
    CHECK (consent_version = 'launch_notification_v1'),
  notified_at TEXT,
  CHECK (length(email) BETWEEN 3 AND 254)
) WITHOUT ROWID;
