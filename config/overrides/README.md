# Per-Batch Validation Overrides

Each batch (migration, future routine workflows, etc.) maintains its own
CSV of acknowledged warnings. The validator reads from the path set in the
active batch config (e.g., `config/batches/migration.m`).

## Schema

| Column             | Description                                                          |
|--------------------|----------------------------------------------------------------------|
| fileid             | Survey file ID                                                       |
| eventno            | Specific event number. Leave empty to acknowledge all events for the fileid/field/rule_id combination (per-survey override). |
| field              | Field name the warning is about                                      |
| rule_id            | The validation rule that fired                                       |
| acknowledged_by    | Who added this entry (initials or name)                              |
| acknowledged_date  | YYYY-MM-DD when added                                                |
| reason             | Free-text note explaining why this warning is acknowledged           |

## Per-batch separation

Each batch file is tracked in git and lives in this directory:

- `migration_overrides.csv` — legacy data migration
- `routine_overrides.csv` — curator routine workflow (create when needed)

Override entries are batch-specific. Migrating an entry between batches
is a deliberate decision.
