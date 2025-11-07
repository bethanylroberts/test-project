# NARWC Database Project

Northern Atlantic Right Whale Consortium aerial survey database management system.

**Status**: Phase 0 Complete - Project infrastructure and database connectivity established

## Quick Start

```matlab
% 1. Initialize project
startup

% 2. Configure database
copyfile('config/db_config_template.m', 'config/db_config.m')
edit config/db_config.m  % Add your credentials

% 3. Test connection
test_connection

% 4. Use database
conn = narwc.db.Connection.create();
data = conn.fetch('SELECT TOP 10 * FROM Master');
conn.close();
```

## Requirements

- MATLAB R2020b or later
- Database Toolbox
- SQL Server, MySQL, or PostgreSQL

## Project Structure

```
narwc-database/
├── src/+narwc/           # MATLAB packages
│   └── +db/              # Database operations
├── lib/+logging/         # Logging toolbox
├── scripts/              # Executable scripts
├── tests/                # Test suite
├── config/               # Configuration
└── docs/                 # Documentation
```

## Common Commands

```matlab
startup                              # Initialize project
test_connection                      # Test database
test_runner()                        # Run all tests

conn = narwc.db.Connection.create() # Connect to database
data = conn.fetch('SELECT ...')      # Query data
conn.close()                         # Close connection
```

## Development Status

- [x] Phase 0: Project infrastructure ✅
- [ ] Phase 1: Historical migration 🚧
- [ ] Phase 2: Validation framework
- [ ] Phase 3-7: Processing, I/O, reports, GUI

## Documentation

- Setup: Run `startup` and follow prompts
- Testing: `docs/testing_guide.md`
- Help: `help narwc`, `help narwc.db.Connection`

## Contact

For questions: russ.shomberg@marineacoustics.com

---
**Version**: 0.1.0 | **Last Updated**: 2025.11