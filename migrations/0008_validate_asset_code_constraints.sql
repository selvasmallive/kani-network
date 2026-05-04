ALTER TABLE balances
  VALIDATE CONSTRAINT balances_asset_code_format;

ALTER TABLE transactions
  VALIDATE CONSTRAINT transactions_asset_code_format;

ALTER TABLE journal_entries
  VALIDATE CONSTRAINT journal_entries_asset_code_format;
