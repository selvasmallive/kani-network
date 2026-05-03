CREATE INDEX IF NOT EXISTS idx_audit_events_created_at_id
  ON audit_events(created_at, id);

CREATE INDEX IF NOT EXISTS idx_audit_events_lower_event_type_created_at_id
  ON audit_events(lower(event_type), created_at, id);

CREATE INDEX IF NOT EXISTS idx_audit_events_lower_decision_created_at_id
  ON audit_events(lower(metadata->>'decision'), created_at, id);

CREATE INDEX IF NOT EXISTS idx_audit_events_institution_created_at_id
  ON audit_events((metadata->>'institution_id'), created_at, id);
