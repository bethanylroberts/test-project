# How to Create New Validation Rules

1. Identify Your Validation Logic

Look at your existing code and identify discrete validation rules:

    Coordinate checks
    Date/time checks
    Species code checks
    etc.

2. Create Rule Functions

For each type of validation, create a rule function:

```matlab

function your_existing_rule(data, collector, config)
    % PORT YOUR EXISTING LOGIC HERE
    
    % Example: If you had something like:
    % invalid_lat = data.LAT_DD < 35 | data.LAT_DD > 50;
    
    % Convert to:
    invalid_idx = find(data.LAT_DD < config.survey_lat_min | ...
                       data.LAT_DD > config.survey_lat_max);
    
    if ~isempty(invalid_idx)
        collector.addError('LAT_DD', invalid_idx, ...
            'Latitude outside survey area', 'warning');
    end
end
```
3. Register Rules in SurveyValidator

Add your rule to the runValidationRules method:

```matlab

function runValidationRules(obj, data)
    % Existing rules
    narwc.validation.rules.coordinate_rules(data, obj.collector, obj.config);
    
    % Your ported rule
    narwc.validation.rules.your_custom_rule(data, obj.collector, obj.config);
end
```
4. Write Tests

For each rule you port, write a test:

```matlab

function testYourCustomRule(testCase)
    data = create_test_data_with_known_issues();
    collector = narwc.validation.ErrorCollector();
    narwc.validation.rules.your_custom_rule(data, collector);
    
    testCase.verifyGreaterThan(collector.getErrorCount(), 0);
end
```