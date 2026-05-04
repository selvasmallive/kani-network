ALTER TABLE balances
  ADD CONSTRAINT balances_asset_code_format
  CHECK (asset ~ '^[A-Z0-9_]{3,32}$') NOT VALID;

ALTER TABLE transactions
  ADD CONSTRAINT transactions_asset_code_format
  CHECK (asset ~ '^[A-Z0-9_]{3,32}$') NOT VALID;

ALTER TABLE journal_entries
  ADD CONSTRAINT journal_entries_asset_code_format
  CHECK (asset ~ '^[A-Z0-9_]{3,32}$') NOT VALID;
