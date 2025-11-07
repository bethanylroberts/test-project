%% Auto-detect format and read

reader = narwc.io.SurveyReader('data/raw/pending/survey_2025.csv');
[data, metadata] = reader.read();

fprintf('Format: %s\n', metadata.format);
fprintf('Records: %d\n', height(data));

%% Specify format explicitly

reader = narwc.io.SurveyReader('data/raw/survey.csv', 'FormatHint', 'LegacyFormat');
data = reader.read();

%% List available formats

narwc.io.parsers.ParserFactory.listFormats();

%% Parse and process

reader = narwc.io.SurveyReader('survey.csv');
[raw_data, ~] = reader.read();

% Process
processor = narwc.processing.SurveyProcessor();
[processed_data, tracker] = processor.process(raw_data);

% Validate
validator = narwc.validation.SurveyValidator();
[is_valid, results] = validator.validate(processed_data);

% Upload
if is_valid
    conn = narwc.db.Connection.create();
    conn.insert('Master', processed_data);
    conn.close();
end
