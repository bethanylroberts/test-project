# Standard NARWC Survey Format

## Overview
Tab-delimited text file with 55 columns in standard order.

## File Format
- **Delimiter**: Tab (`\t`)
- **Header Row**: Yes (line 1)
- **Encoding**: UTF-8
- **Missing Values**: `NULL`, `.`, or empty

## Field Definitions

| Position | Field Name | Type | Description |
|----------|-----------|------|-------------|
| 1 | ALT | Numeric | Altitude in meters |
| 2 | ANGLEL | Numeric | Angle left of trackline |
| 3 | ANGLER | Numeric | Angle right of trackline |
| ... | ... | ... | ... |

## Example

```sql
ALT	ANGLEL	ANGLER	ANHEAD	BEAUFORT	...
244	NULL	NULL	NULL	4	...
244	NULL	NULL	NULL	4	...
```


## Validation Rules
- LAT_DD must be between 35 and 50
- LONG_DD must be between -75 and -60
- YEAR must be between 1970 and current year
- SPECCODE must match known species list