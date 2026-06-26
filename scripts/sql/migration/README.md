# Migration Scripts

SQL-side counterparts to the MATLAB migration tools in `src/+migration/`.

## Primary vs. SQL path

The MATLAB script `apply_known_fixes.m` (planned) is the **primary** correction path.
It applies known data-quality fixes to the CSV staging area before upload. The SQL
script `apply_known_fixes.sql` in this directory applies the same corrections
**post-upload**, for cases where data is already in the database and needs in-place
correction.

Keep both in sync. If a fix is added to `apply_known_fixes.m`, add the equivalent
UPDATE block to `apply_known_fixes.sql`, and vice versa. The header comment in each
block should reference the survey(s) affected so discrepancies can be spotted
during code review.

## Scripts

| File | Purpose |
|------|---------|
| `apply_known_fixes.sql` | Category C in-place corrections (post-upload) |
