# TODO

- [ ] comment potential changes
- [ ] refactor code
- [ ] check all code tags
- [ ] set up vscode to read code tags

- [ ] remove import scripts (not used)
- [ ] remove maintenance script dir (empty)
- [ ] remove validation script dir (empty)
- [ ] check setup dir
- [ ] check migration dir
- [ ] create scripts for inspecting the database

- [ ] recreate Bob's macros
- [ ] add eventno to error log
- Bob will change PHOTOS=0 to PHOTOS=1
    - [ ] add macro to do this? or fix manually
- Day/Month/Time missing allowed for opportunistic sightings
    - [ ] change to warning
- [ ] lat out of range, add value
    - [ ] fix manually
- calf behaviour is warning
    - [ ] add warning override
- [ ] change strip > 16 to missing values
- ANHEAD = 19 is a valid error
    - [ ] change to missing, bob did
- [ ] change all ANHEAD > 22 to missing
- [ ] Add wind farm ships to SPECCODE
    - CV-C = Construction ship/barge – crane
    - CV-O = Construction ship/barge – other
    - CV-P = Construction ship/barge – pile-driver
    - CV-R = Construction ship/barge – rock dumper
- [ ] additional species code
    - ECOT dolphin watching (not whale watching)
- [ ] add BEHAV code
    - 73 = patrolling construction security zone (vessels)
    - 74 = pile-driving (construction ships or barges)
- "NUMBER" unusually large should depend on species or tax code
    - [ ] change to check tax code (make up some numbers)
    - [ ] add speccies code and tax code to warning output
- [ ] add to ANHEAD look up 20 = underway (vessels only, course unknown or unimportant)
- BLOCK = MB likely refers to Mass Bay but currently not in manual
    - [ ] add to look up table?
- c018101 possibly behav1 is placed in anhead?
- f011048 possibly behav1 is placed in anhead?
- f203360 possibly behav1 is placed in anhead?
- f607053 possibly behav1 is placed in anhead?
- f608034 possibly behav1 in placed in anhead?
- [ ] GLARE add 9 as missing value to look up table
    - or remove all 9 values?
- [ ] f403158 change GLARER=7 to 1
- [ ] add platforms
    - 573 "towboat or similar vessel" (not in manual yet)
    - 637 = APEM high-res photo survey aircraft (Partenavia)
    - 266 = Canadian Coast Guard
    - 193 = Mingan Island Cetacean Study
    - 280 = misc./unknown Canadian vessel
    - 325 = Fugro Explorer
    - 637 = APEM Partenavia
    - 329, 330, 332, 644, 70, ? MMO vessels around the windfarm
    - 194 = Helen H (used by several groups recently)
    - 268 = R/V Leeway Odyssey
- o105921 164 unknown
    - [ ] change to 900
- o112971 DDSOURCE unknown 
    - maybe copy IDSOURCE to DDSOURCE
- o113921 PLATFORM 266 = "Canadian Coast Guard"
- o117001 is special
    - lat outside of typical is valid
    - early year is valid
- [ ] check if year/month/day matches fileid (warning)
- o118921 lat/lon is valid
- o121911 CONFIDNC row 444 90 invalid
    - [ ] change to 0
- o123921
    - [ ] EVENT 159: TIME = 003716; DAY=11
    - [ ] EVENT 211: TIME = 001240; DAY=26
    - [ ] EVENT 212: TIME = 005201; DAY = 26
    - [ ] EVENT 283: LONG_DD = -71.93525 (they left of the negative sign)
- p3127214 row 540 lat/lon issue
    - Weird – fin whale sighting with both lat and long missing (0.0/0.0) in the original data, but the printout shows an interpolated location. EVENT 540: LAT_DD = 48.04200; LONG_DD = -63.71367
- p905169G large survey w/ lots of comments
    - suspect it may be corrupted


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