# NARWC Database Project Structure

```
narwc-database/
├── README.md
├── CHANGELOG.md
├── startup.m                      # Auto-setup paths when opening project
│
├── src/                           # Source code toolboxes
│   └── +narwc/
│       ├── Contents.m
│       │
│       ├── +db/                   # Database Management
│       │   ├── Contents.m
│       │   ├── Connection.m       # Database connection handler
│       │   ├── Schema.m           # Schema management & validation
│       │   ├── Transaction.m      # Transaction wrapper
│       │   ├── QueryBuilder.m     # SQL query builder
│       │   └── Migrator.m         # Database migration tools
│       │
│       ├── +io/                   # Input/Output Operations
│       │   ├── Contents.m
│       │   ├── SurveyReader.m     # Universal survey file reader
│       │   ├── SurveyWriter.m     # Export surveys to files
│       │   ├── SurveyUploader.m   # Upload surveys to database
│       │   ├── SurveyExporter.m   # Export from database to files
│       │   ├── ReportGenerator.m  # Generate processing reports
│       │   └── +parsers/          # Format-specific parsers
│       │       ├── Contents.m
│       │       ├── BaseParser.m           # Abstract base class
│       │       ├── StandardFormat.m       # Standard NARWC format
│       │       ├── LegacyFormat.m         # Old database format
│       │       ├── NEAQFormat.m           # New England Aquarium
│       │       ├── CCSFormat.m            # Center for Coastal Studies
│       │       ├── NOAAFormat.m           # NOAA format
│       │       └── ParserFactory.m        # Auto-detect format
│       │
│       ├── +validation/           # Data Validation & Error Checking
│       │   ├── Contents.m
│       │   ├── SurveyValidator.m  # Main validation orchestrator
│       │   ├── FieldValidator.m   # Individual field validation
│       │   ├── RuleEngine.m       # Validation rule engine
│       │   ├── ErrorCollector.m   # Collect and categorize errors
│       │   └── +rules/            # Validation rules
│       │       ├── Contents.m
│       │       ├── coordinate_rules.m
│       │       ├── species_rules.m
│       │       ├── temporal_rules.m
│       │       ├── behavioral_rules.m
│       │       └── platform_rules.m
│       │
│       ├── +processing/           # Data Processing & Transformation
│       │   ├── Contents.m
│       │   ├── SurveyProcessor.m  # Main processing pipeline
│       │   ├── DataCleaner.m      # Clean and standardize data
│       │   ├── DataTransformer.m  # Transform between formats
│       │   ├── QualityControl.m   # QC checks and flags
│       │   └── +steps/            # Processing steps
│       │       ├── Contents.m
│       │       ├── remove_duplicates.m
│       │       ├── standardize_coordinates.m
│       │       ├── standardize_species_codes.m
│       │       ├── calculate_derived_fields.m
│       │       ├── flag_outliers.m
│       │       └── fill_missing_values.m
│       │
│       ├── +reports/              # Report Generation
│       │   ├── Contents.m
│       │   ├── ProcessingReport.m     # Processing steps report
│       │   ├── ValidationReport.m     # Validation errors report
│       │   ├── ChangeLog.m            # Log of changes made
│       │   ├── SummaryStatistics.m    # Survey statistics
│       │   └── +templates/            # Report templates
│       │       ├── processing_template.html
│       │       ├── validation_template.html
│       │       └── summary_template.html
│       │
│       ├── +migration/            # Historical Database Migration
│       │   ├── Contents.m
│       │   ├── LegacyConverter.m      # Convert old CSV to SQL
│       │   ├── SurveyExtractor.m      # Extract individual surveys
│       │   ├── MetadataExtractor.m    # Extract survey metadata
│       │   ├── BatchConverter.m       # Batch conversion tool
│       │   └── ConversionValidator.m  # Validate conversion
│       │
│       └── +utils/                # Utility Functions
│           ├── Contents.m
│           ├── coordinate_utils.m
│           ├── date_utils.m
│           ├── species_utils.m
│           ├── string_utils.m
│           └── table_utils.m
│
├── apps/                          # MATLAB App Designer Applications
│   ├── NARWCDatabaseApp.mlapp     # Main application
│   ├── SurveyBrowser.mlapp        # Browse and search surveys
│   ├── SurveyImporter.mlapp       # Import new survey wizard
│   ├── ValidationViewer.mlapp     # View validation results
│   ├── ReportViewer.mlapp         # View generated reports
│   └── DataEntryForm.mlapp        # Manual data entry/editing
│
├── scripts/                       # Executable Scripts
│   │
│   ├── migration/                 # Historical migration scripts
│   │   ├── migrate_all_surveys.m
│   │   ├── extract_surveys_from_csv.m
│   │   ├── validate_migration.m
│   │   └── generate_migration_report.m
│   │
│   ├── import/                    # Import new surveys
│   │   ├── import_single_survey.m
│   │   ├── batch_import_surveys.m
│   │   ├── validate_survey_folder.m
│   │   └── process_and_import.m
│   │
│   ├── validation/                # Validation scripts
│   │   ├── validate_database.m
│   │   ├── check_survey_quality.m
│   │   └── generate_validation_reports.m
│   │
│   ├── maintenance/               # Database maintenance
│   │   ├── backup_database.m
│   │   ├── optimize_database.m
│   │   └── clean_orphaned_records.m
│   │
│   └── setup/                     # Setup scripts
│       ├── setup_project.m
│       ├── setup_database.m
│       ├── create_tables.m
│       └── load_lookup_tables.m
│
├── tests/                         # Unit & Integration Tests
│   ├── unit/
│   │   ├── test_parsers.m
│   │   ├── test_validators.m
│   │   ├── test_processors.m
│   │   ├── test_db_operations.m
│   │   └── test_report_generation.m
│   │
│   ├── integration/
│   │   ├── test_import_pipeline.m
│   │   ├── test_migration_pipeline.m
│   │   └── test_end_to_end.m
│   │
│   └── fixtures/                  # Test data
│       ├── sample_surveys/
│       ├── expected_outputs/
│       └── validation_cases/
│
├── config/                        # Configuration Files
│   ├── db_config.m                # Database credentials
│   ├── logging_config.m           # Logging configuration
│   ├── validation_config.m        # Validation rules config
│   ├── format_definitions.json    # Survey format definitions
│   └── species_lookup.csv         # Species code lookup table
│
├── data/                          # Data Files (NOT in version control)
│   ├── raw/                       # Raw incoming surveys
│   │   ├── pending/               # Awaiting processing
│   │   ├── processed/             # Successfully processed
│   │   └── rejected/              # Failed validation
│   │
│   ├── legacy/                    # Historical database files
│   │   ├── original_csv/
│   │   ├── extracted_surveys/
│   │   └── migration_status.csv
│   │
│   ├── exports/                   # Exported data
│   │   ├── surveys/
│   │   └── reports/
│   │
│   └── archives/                  # Archived surveys
│       └── [YEAR]/
│           └── [SURVEY_ID]/
│
├── reports/                       # Generated Reports (NOT in version control)
│   ├── processing/                # Processing reports
│   │   └── [SURVEY_ID]_processing_[DATE].html
│   │
│   ├── validation/                # Validation reports
│   │   └── [SURVEY_ID]_validation_[DATE].html
│   │
│   ├── migration/                 # Migration reports
│   │   └── migration_summary_[DATE].html
│   │
│   └── quality/                   # Quality control reports
│       └── database_quality_[DATE].html
│
├── logs/                          # Log Files (NOT in version control)
│   ├── application.log
│   ├── database.log
│   ├── validation.log
│   ├── migration.log
│   └── errors.log
│
├── docs/                          # Documentation
│   ├── user_guide.md              # End user guide
│   ├── developer_guide.md         # Developer documentation
│   ├── database_schema.md         # Database schema docs
│   ├── validation_rules.md        # Validation rules reference
│   ├── format_specifications/     # Format specs for each source
│   │   ├── standard_format.md
│   │   ├── neaq_format.md
│   │   ├── ccs_format.md
│   │   └── noaa_format.md
│   │
│   └── api/                       # Auto-generated API docs
│       └── [generated by help2html or similar]
│
├── lib/                           # External Dependencies
│   ├── +logging/                   # Logging toolbox
│   └── [other external toolboxes]
│
└── resources/                     # Project Resources
    ├── icons/                     # App icons
    ├── templates/                 # Document templates
    └── examples/                  # Example files
        ├── sample_import.m
        └── sample_validation.m
```

## Key Workflows

### 1. Historical Migration Workflow
```matlab
% Step 1: Extract individual surveys from legacy CSV
scripts/migration/extract_surveys_from_csv

% Step 2: Validate extraction
scripts/migration/validate_migration

% Step 3: Migrate to database
scripts/migration/migrate_all_surveys

% Step 4: Generate report
scripts/migration/generate_migration_report
```

### 2. New Survey Import Workflow
```matlab
% Option A: Single survey with GUI
SurveyImporter  % Launch app

% Option B: Single survey via script
scripts/import/process_and_import('data/raw/pending/survey_2025.csv')

% Option C: Batch import
scripts/import/batch_import_surveys('data/raw/pending')
```

### 3. Typical Processing Pipeline
```matlab
import narwc.io.*
import narwc.processing.*
import narwc.validation.*
import narwc.reports.*

% 1. Read survey (auto-detect format)
reader = SurveyReader('data/raw/pending/survey_2025.csv');
raw_data = reader.read();

% 2. Process data
processor = SurveyProcessor();
processed_data = processor.process(raw_data);

% 3. Validate
validator = SurveyValidator();
[is_valid, errors, warnings] = validator.validate(processed_data);

% 4. Generate reports
proc_report = ProcessingReport(processor.getLog());
proc_report.generate('reports/processing/survey_2025_processing.html');

val_report = ValidationReport(errors, warnings);
val_report.generate('reports/validation/survey_2025_validation.html');

% 5. Upload if valid
if is_valid
    conn = narwc.db.Connection.create();
    uploader = SurveyUploader(conn);
    uploader.upload(processed_data);
    conn.close();
end
```

## File Organization Conventions

### Naming Conventions
- **Classes**: PascalCase (`SurveyValidator.m`)
- **Functions**: snake_case (`calculate_distance.m`)
- **Packages**: lowercase (`+validation`, `+processing`)
- **Scripts**: snake_case (`import_survey.m`)
- **Apps**: PascalCase (`SurveyImporter.mlapp`)

### Data File Naming
```
[SOURCE]_[PLATFORM]_[YEAR][MONTH][DAY]_[VERSION].csv

Examples:
CCS_PLANE_20250115_v1.csv
NEAQ_VESSEL_20250120_v2.csv
NOAA_AERIAL_20250201_final.csv
```

### Report File Naming
```
[SURVEY_ID]_[REPORT_TYPE]_[TIMESTAMP].html

Examples:
F098027_processing_20250115_143022.html
F098027_validation_20250115_143025.html
```

## Configuration Files

### format_definitions.json example
```json
{
  "formats": {
    "standard": {
      "delimiter": "\t",
      "header_row": 1,
      "required_columns": ["ALT", "LAT_DD", "LONG_DD", "YEAR"],
      "parser": "narwc.io.parsers.StandardFormat"
    },
    "neaq": {
      "delimiter": ",",
      "header_row": 2,
      "required_columns": ["Latitude", "Longitude", "Date"],
      "parser": "narwc.io.parsers.NEAQFormat"
    },
    "ccs": {
      "delimiter": "\t",
      "header_row": 1,
      "required_columns": ["LAT", "LON", "SPECIES"],
      "parser": "narwc.io.parsers.CCSFormat"
    }
  }
}
```


# NARWC Database Project - Development TODO List

## Phase 0: Project Setup & Foundation
**Goal**: Get the basic project structure and infrastructure in place

### Tasks
- [X] Create directory structure as specified
- [X] Set up Git repository and `.gitignore`
- [X] Create `startup.m` for automatic path setup
- [ ] Set up logging infrastructure
  - [X] Install/integrate logging toolbox in `lib/`
  - [ ] Create `config/logging_config.m`
  - [X] Test basic logging functionality
- [ ] Create database connection framework
  - [X] `src/+narwc/+db/Connection.m`
  - [X] `config/db_config.m` (template)
  - [X] Test database connection
- [ ] Create basic utility functions
  - [ ] `src/+narwc/+utils/coordinate_utils.m`
  - [ ] `src/+narwc/+utils/date_utils.m`
  - [ ] `src/+narwc/+utils/table_utils.m`
- [ ] Set up testing framework
  - [X] Create test runner script
  - [X] Set up test fixtures directory
- [X] Write initial README.md with setup instructions

**Deliverable**: Working project skeleton with database connectivity

---

## Phase 1: Historical Database Migration
**Goal**: Convert existing legacy CSV database to SQL

### 1.1 Legacy Data Analysis
- [ ] Document legacy CSV structure and quirks
- [X] Identify all unique FILEID values (surveys)
- [ ] Create data quality assessment
- [ ] Document special cases and edge cases

### 1.2 Database Schema
- [ ] Design SQL schema for Master table
- [ ] Create `src/+narwc/+db/Schema.m`
- [ ] Write `scripts/setup/create_tables.m`
- [ ] Create lookup tables (species codes, platforms, etc.)
- [ ] Test schema creation

### 1.3 Survey Extraction
- [ ] Create `src/+narwc/+migration/SurveyExtractor.m`
  - [ ] Extract surveys by FILEID
  - [ ] Handle NULL values properly
  - [ ] Preserve data types
- [ ] Create `src/+narwc/+migration/MetadataExtractor.m`
  - [ ] Extract survey metadata
  - [ ] Count records per survey
  - [ ] Identify date ranges
- [ ] Write `scripts/migration/extract_surveys_from_csv.m`
- [ ] Test extraction on sample surveys

### 1.4 Legacy Converter
- [ ] Create `src/+narwc/+migration/LegacyConverter.m`
  - [ ] Column mapping from old to new schema
  - [ ] Data type conversions
  - [ ] Handle special cases
- [ ] Create `src/+narwc/+migration/ConversionValidator.m`
  - [ ] Verify row counts match
  - [ ] Verify data integrity
  - [ ] Check for data loss
- [ ] Test converter on multiple surveys

### 1.5 Batch Migration
- [ ] Create `src/+narwc/+migration/BatchConverter.m`
  - [ ] Process all surveys
  - [ ] Track progress
  - [ ] Handle errors gracefully
  - [ ] Generate summary statistics
- [ ] Write `scripts/migration/migrate_all_surveys.m`
- [ ] Write `scripts/migration/validate_migration.m`
- [ ] Write `scripts/migration/generate_migration_report.m`

### 1.6 Migration Testing & Execution
- [ ] Test migration on subset of surveys
- [ ] Review migration reports
- [ ] Fix any data issues discovered
- [ ] **Execute full migration**
- [ ] Validate entire database
- [ ] Archive legacy CSV files

**Deliverable**: Complete historical database in SQL with validation reports

---

## Phase 2: Core Validation Framework
**Goal**: Build robust validation system for survey data

### 2.1 Validation Rules
- [ ] Document all validation rules in `docs/validation_rules.md`
- [ ] Create `config/validation_config.m`
- [ ] Implement validation rules:
  - [ ] `src/+narwc/+validation/+rules/coordinate_rules.m`
    - Geographic bounds
    - Coordinate format validation
    - Land/sea validation
  - [ ] `src/+narwc/+validation/+rules/temporal_rules.m`
    - Date range validation
    - Time format validation
    - Temporal sequence checks
  - [ ] `src/+narwc/+validation/+rules/species_rules.m`
    - Species code validation
    - Behavioral code validation
    - Group composition rules
  - [ ] `src/+narwc/+validation/+rules/platform_rules.m`
    - Platform-specific rules
    - Altitude validation
    - Visibility checks
  - [ ] `src/+narwc/+validation/+rules/behavioral_rules.m`
    - Behavior code combinations
    - Context-dependent validation

### 2.2 Validation Engine
- [ ] Create `src/+narwc/+validation/RuleEngine.m`
  - [ ] Rule registration system
  - [ ] Rule execution with priorities
  - [ ] Skip/ignore capability
- [ ] Create `src/+narwc/+validation/ErrorCollector.m`
  - [ ] Collect errors, warnings, info
  - [ ] Categorize by severity
  - [ ] Track error locations
- [ ] Create `src/+narwc/+validation/FieldValidator.m`
  - [ ] Field-level validation
  - [ ] Type checking
  - [ ] Range checking
  - [ ] Pattern matching

### 2.3 Survey Validator
- [ ] Create `src/+narwc/+validation/SurveyValidator.m`
  - [ ] Orchestrate all validation rules
  - [ ] Generate validation report data
  - [ ] Return structured results
- [ ] Write `scripts/validation/check_survey_quality.m`
- [ ] Write `scripts/validation/validate_database.m`

### 2.4 Testing
- [ ] Create test fixtures with known errors
- [ ] Write `tests/unit/test_validators.m`
  - [ ] Test each rule individually
  - [ ] Test error collection
  - [ ] Test edge cases
- [ ] Test on real survey data
- [ ] Document validation examples

**Deliverable**: Complete validation framework with comprehensive rules

---

## Phase 3: Data Processing Pipeline
**Goal**: Build data cleaning and transformation system

### 3.1 Processing Steps
- [ ] Create individual processing steps:
  - [ ] `src/+narwc/+processing/+steps/remove_duplicates.m`
  - [ ] `src/+narwc/+processing/+steps/standardize_coordinates.m`
  - [ ] `src/+narwc/+processing/+steps/standardize_species_codes.m`
  - [ ] `src/+narwc/+processing/+steps/calculate_derived_fields.m`
  - [ ] `src/+narwc/+processing/+steps/flag_outliers.m`
  - [ ] `src/+narwc/+processing/+steps/fill_missing_values.m`

### 3.2 Processing Framework
- [ ] Create `src/+narwc/+processing/SurveyProcessor.m`
  - [ ] Pipeline architecture
  - [ ] Step registration
  - [ ] Change tracking
  - [ ] Logging all transformations
- [ ] Create `src/+narwc/+processing/DataCleaner.m`
  - [ ] Standardize formats
  - [ ] Handle NULL values
  - [ ] Trim whitespace
- [ ] Create `src/+narwc/+processing/DataTransformer.m`
  - [ ] Transform between formats
  - [ ] Map columns
  - [ ] Convert data types
- [ ] Create `src/+narwc/+processing/QualityControl.m`
  - [ ] Flag suspicious values
  - [ ] Statistical outlier detection
  - [ ] Data quality scores

### 3.3 Testing
- [ ] Write `tests/unit/test_processors.m`
- [ ] Test each processing step individually
- [ ] Test full pipeline on sample data
- [ ] Verify no data loss

**Deliverable**: Automated data processing pipeline with change tracking

---

## Phase 4: Format Parsers
**Goal**: Support multiple incoming survey formats

### 4.1 Parser Framework
- [ ] Create `src/+narwc/+io/+parsers/BaseParser.m` (abstract)
  - [ ] Define parser interface
  - [ ] Common parsing utilities
  - [ ] Error handling
- [ ] Create `src/+narwc/+io/+parsers/ParserFactory.m`
  - [ ] Auto-detect format
  - [ ] Return appropriate parser
  - [ ] Configuration-driven

### 4.2 Format-Specific Parsers
- [ ] Document each format in `docs/format_specifications/`
- [ ] Create parsers:
  - [ ] `src/+narwc/+io/+parsers/StandardFormat.m`
  - [ ] `src/+narwc/+io/+parsers/LegacyFormat.m`
  - [ ] `src/+narwc/+io/+parsers/NEAQFormat.m`
  - [ ] `src/+narwc/+io/+parsers/CCSFormat.m`
  - [ ] `src/+narwc/+io/+parsers/NOAAFormat.m`
- [ ] Create `config/format_definitions.json`

### 4.3 Universal Reader
- [ ] Create `src/+narwc/+io/SurveyReader.m`
  - [ ] Use ParserFactory
  - [ ] Handle CSV and Excel
  - [ ] Return standardized format
- [ ] Test with sample files from each source

### 4.4 Testing
- [ ] Create test fixtures for each format
- [ ] Write `tests/unit/test_parsers.m`
- [ ] Test format auto-detection
- [ ] Test error handling

**Deliverable**: Multi-format survey reader with auto-detection

---

## Phase 5: Database I/O
**Goal**: Upload and export survey data

### 5.1 Upload System
- [ ] Create `src/+narwc/+io/SurveyUploader.m`
  - [ ] Check for existing surveys
  - [ ] Compare for differences
  - [ ] Overwrite option
  - [ ] Transaction support
  - [ ] Batch upload capability
- [ ] Create `src/+narwc/+db/Transaction.m`
  - [ ] Transaction wrapper
  - [ ] Rollback on error

### 5.2 Export System
- [ ] Create `src/+narwc/+io/SurveyExporter.m`
  - [ ] Export to CSV
  - [ ] Export to Excel
  - [ ] Query-based export
- [ ] Create `src/+narwc/+io/SurveyWriter.m`
  - [ ] Write standardized format
  - [ ] Preserve metadata

### 5.3 Query Builder
- [ ] Create `src/+narwc/+db/QueryBuilder.m`
  - [ ] Build SELECT queries
  - [ ] Filter by date range
  - [ ] Filter by species
  - [ ] Filter by location
  - [ ] Export query results

### 5.4 Scripts
- [ ] Write `scripts/import/import_single_survey.m`
- [ ] Write `scripts/import/batch_import_surveys.m`
- [ ] Write `scripts/import/process_and_import.m`
- [ ] Write `scripts/import/validate_survey_folder.m`

### 5.5 Testing
- [ ] Write `tests/unit/test_db_operations.m`
- [ ] Test upload with conflicts
- [ ] Test transaction rollback
- [ ] Test export functionality
- [ ] Write `tests/integration/test_import_pipeline.m`

**Deliverable**: Complete database I/O with error handling

---

## Phase 6: Report Generation
**Goal**: Generate comprehensive reports for all operations

### 6.1 Report Templates
- [ ] Design HTML templates
  - [ ] `src/+narwc/+reports/+templates/processing_template.html`
  - [ ] `src/+narwc/+reports/+templates/validation_template.html`
  - [ ] `src/+narwc/+reports/+templates/summary_template.html`
- [ ] Add CSS styling
- [ ] Create plots/visualizations

### 6.2 Report Generators
- [ ] Create `src/+narwc/+reports/ProcessingReport.m`
  - [ ] Log of all processing steps
  - [ ] Changes made to data
  - [ ] Statistics (before/after)
  - [ ] Flagged records
- [ ] Create `src/+narwc/+reports/ValidationReport.m`
  - [ ] List of errors by category
  - [ ] List of warnings
  - [ ] Records affected
  - [ ] Actionable recommendations
- [ ] Create `src/+narwc/+reports/ChangeLog.m`
  - [ ] Detailed change tracking
  - [ ] Field-level changes
  - [ ] Audit trail
- [ ] Create `src/+narwc/+reports/SummaryStatistics.m`
  - [ ] Survey metadata
  - [ ] Species counts
  - [ ] Spatial coverage
  - [ ] Temporal coverage
  - [ ] Data quality metrics

### 6.3 Report Manager
- [ ] Create `src/+narwc/+reports/ReportManager.m`
  - [ ] Generate all reports for a survey
  - [ ] Package reports for distribution
  - [ ] Email reports (optional)

### 6.4 Testing
- [ ] Write `tests/unit/test_report_generation.m`
- [ ] Generate sample reports
- [ ] Review report usability

**Deliverable**: Professional HTML reports for all operations

---

## Phase 7: GUI Applications
**Goal**: Create user-friendly interfaces

### 7.1 Main Application
- [ ] Design `apps/NARWCDatabaseApp.mlapp`
  - [ ] Dashboard view
  - [ ] Quick access to all functions
  - [ ] Status display
  - [ ] Recent activity log
- [ ] Implement main app
- [ ] Test all workflows through GUI

### 7.2 Survey Browser
- [ ] Design `apps/SurveyBrowser.mlapp`
  - [ ] Search/filter surveys
  - [ ] View survey details
  - [ ] Plot survey tracks on map
  - [ ] Export selected surveys
- [ ] Implement browser
- [ ] Add map visualization

### 7.3 Survey Importer
- [ ] Design `apps/SurveyImporter.mlapp`
  - [ ] File selection wizard
  - [ ] Format detection/selection
  - [ ] Preview data
  - [ ] Run validation
  - [ ] Review validation results
  - [ ] Configure processing options
  - [ ] Execute import
  - [ ] View reports
- [ ] Implement importer wizard
- [ ] Test complete import workflow

### 7.4 Validation Viewer
- [ ] Design `apps/ValidationViewer.mlapp`
  - [ ] Display validation results
  - [ ] Filter by error type
  - [ ] Show affected records
  - [ ] Allow manual corrections
- [ ] Implement viewer

### 7.5 Report Viewer
- [ ] Design `apps/ReportViewer.mlapp`
  - [ ] Display HTML reports
  - [ ] Export reports
  - [ ] Print reports
- [ ] Implement viewer

### 7.6 Data Entry Form (Optional)
- [ ] Design `apps/DataEntryForm.mlapp`
  - [ ] Manual data entry
  - [ ] Edit existing records
  - [ ] Real-time validation
- [ ] Implement form

### 7.7 Testing
- [ ] User acceptance testing
- [ ] UI/UX improvements
- [ ] Error handling in GUI

**Deliverable**: Complete GUI suite for all operations

---

## Phase 8: Testing & Documentation
**Goal**: Comprehensive testing and documentation

### 8.1 Unit Tests
- [ ] Complete unit test coverage
  - [ ] All parsers
  - [ ] All validators
  - [ ] All processors
  - [ ] Database operations
  - [ ] Report generation
- [ ] Achieve >80% code coverage
- [ ] Document test cases

### 8.2 Integration Tests
- [ ] Write `tests/integration/test_import_pipeline.m`
  - [ ] End-to-end import test
- [ ] Write `tests/integration/test_migration_pipeline.m`
  - [ ] Test historical migration
- [ ] Write `tests/integration/test_end_to_end.m`
  - [ ] Complete workflow test

### 8.3 Performance Testing
- [ ] Benchmark large survey imports
- [ ] Optimize slow operations
- [ ] Test database performance
- [ ] Memory profiling

### 8.4 Documentation
- [ ] Complete `docs/user_guide.md`
  - [ ] Installation
  - [ ] Getting started
  - [ ] Common tasks
  - [ ] Troubleshooting
- [ ] Complete `docs/developer_guide.md`
  - [ ] Architecture overview
  - [ ] Adding new parsers
  - [ ] Adding validation rules
  - [ ] Contributing guidelines
- [ ] Complete `docs/database_schema.md`
  - [ ] Table definitions
  - [ ] Relationships
  - [ ] Indexes
- [ ] Complete `docs/validation_rules.md`
  - [ ] All validation rules
  - [ ] Examples
  - [ ] Configuration
- [ ] Document each format in `docs/format_specifications/`
- [ ] Generate API documentation

### 8.5 Examples & Tutorials
- [ ] Create example scripts in `resources/examples/`
- [ ] Create video tutorials (optional)
- [ ] Create quick reference guide

**Deliverable**: Fully tested and documented system

---

## Phase 9: Deployment & Training
**Goal**: Deploy system and train users

### 9.1 Deployment
- [ ] Set up production database
- [ ] Configure production settings
- [ ] Migrate to production
- [ ] Set up backups
- [ ] Create `scripts/maintenance/backup_database.m`
- [ ] Create `scripts/maintenance/optimize_database.m`

### 9.2 Training
- [ ] Create training materials
- [ ] Conduct user training sessions
- [ ] Create video walkthroughs
- [ ] Gather user feedback

### 9.3 Handoff
- [ ] Create operations manual
- [ ] Document maintenance procedures
- [ ] Set up monitoring/alerting
- [ ] Plan for ongoing support

**Deliverable**: Production system with trained users

---

## Phase 10: Maintenance & Enhancement
**Goal**: Ongoing support and improvements

### 10.1 Bug Fixes & Improvements
- [ ] Set up issue tracking
- [ ] Regular bug fix releases
- [ ] Performance improvements
- [ ] User-requested features

### 10.2 New Features
- [ ] Additional format parsers as needed
- [ ] Enhanced visualization
- [ ] Advanced queries
- [ ] Export to other formats
- [ ] Integration with other systems

### 10.3 Data Quality
- [ ] Regular database validation
- [ ] Data quality monitoring
- [ ] Automated quality reports

**Deliverable**: Maintained and evolving system

---

## Priority Quick Reference

### Critical Path (Must Have)
1. Phase 0: Setup ⭐
2. Phase 1: Historical Migration ⭐⭐⭐
3. Phase 2: Validation ⭐⭐⭐
4. Phase 4: Parsers ⭐⭐
5. Phase 5: Database I/O ⭐⭐
6. Phase 6: Reports ⭐⭐

### Important (Should Have)
7. Phase 3: Processing Pipeline ⭐
8. Phase 7: GUI Applications ⭐

### Nice to Have
9. Phase 8: Advanced Testing
10. Phase 9: Deployment Support

---

## Milestones

**Milestone 1**: Historical migration complete ✓  
**Milestone 2**: Can import one modern survey ✓  
**Milestone 3**: Full validation and reporting ✓  
**Milestone 4**: GUI applications functional ✓  
**Milestone 5**: Production ready ✓