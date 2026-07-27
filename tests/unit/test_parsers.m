classdef test_parsers < matlab.unittest.TestCase
    % TEST_PARSERS Unit tests for format parsers

    % Removed tests for code marked FIXME: DELETE:
    %   testTabDeliminatedFormatDetection  -- TabDeliminatedFormat is deleted
    %   testTabDeliminatedFormatParsing    -- TabDeliminatedFormat is deleted
    %   testSurveyReaderWithHint           -- SurveyReader is deleted

    properties
        test_file
    end

    methods (TestMethodSetup)
        function createTestFile(testCase)
            testCase.test_file = [tempname '.csv'];
        end
    end

    methods (TestMethodTeardown)
        function cleanupTestFile(testCase)
            if exist(testCase.test_file, 'file')
                delete(testCase.test_file);
            end
        end
    end

    methods (Test)
        function testBaseParserStatics(testCase)
            fields = narwc.io.parsers.BaseParser.getStandardFieldsStatic();
            testCase.verifyEqual(length(fields), 55);

            testCase.verifyTrue(narwc.io.parsers.BaseParser.isNumericField('LAT_DD'));
            testCase.verifyFalse(narwc.io.parsers.BaseParser.isNumericField('SPECCODE'));
        end

        function testStandardFormatDetection(testCase)
            data = TestFixtures.generate_mock_survey(3);
            writetable(data, testCase.test_file, 'Delimiter', ',', 'FileType', 'text');

            confidence = narwc.io.parsers.StandardFormat.detectFormat(testCase.test_file);
            testCase.verifyGreaterThan(confidence, 0);
        end

        function testParserFactoryCreateByName(testCase)
            parser = narwc.io.parsers.ParserFactory.createByName('StandardFormat');

            testCase.verifyClass(parser, 'narwc.io.parsers.StandardFormat');
            testCase.verifyEqual(parser.FORMAT_NAME, 'Standard NARWC Format');
        end

        function testClearSpuriousSightnoBlanksRowsWithoutSpeccode(testCase)
            % SIGHTNO gets auto-logged by the GPS/survey software on any
            % marker-button press, not just sightings (curator-confirmed) --
            % clearSpuriousSightno must blank SIGHTNO wherever SPECCODE is
            % blank, and leave real sightings (SPECCODE populated) alone.
            data = TestFixtures.generate_mock_survey(3);
            data.SIGHTNO = [1; 2; 3];
            data.SPECCODE = {'RIWH'; ''; 'HUWH'};

            result = narwc.io.parsers.StandardFormat.clearSpuriousSightno(data);

            testCase.verifyEqual(result.SIGHTNO(1), 1, ...
                'Real sighting (SPECCODE populated) must keep its SIGHTNO');
            testCase.verifyTrue(isnan(result.SIGHTNO(2)), ...
                'Row with no SPECCODE must have SIGHTNO cleared');
            testCase.verifyEqual(result.SIGHTNO(3), 3, ...
                'Real sighting (SPECCODE populated) must keep its SIGHTNO');
        end

        function testClearSpuriousSightnoNoOpWithoutRequiredColumns(testCase)
            data = table();
            data.EVENTNO = [1; 2];

            result = narwc.io.parsers.StandardFormat.clearSpuriousSightno(data);

            testCase.verifyEqual(result, data);
        end
    end
end