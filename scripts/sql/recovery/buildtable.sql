CREATE TABLE Master (
-- SOURCE INFORMATION
FILEID	nvarchar(8) NOT NULL,	--survey file identification code
DDSOURCE nchar(3) NOT NULL,	--direct data source
IDSOURCE nchar(3) NOT NULL,	--indirect data source
PLATFORM smallint NOT NULL,	--survey platform from look up table
BLOCK nvarchar(2),		--2 char code specifying a predefined block
STRATUM nchar(1),		--1 digit code for depth stratum
-- EVENT INFORMATION
EVENTNO	int NOT NULL,		--event number within survey
[YEAR] smallint NOT NULL,	--4 digit year
[MONTH] tinyint,		--calendar month of year (1-12)
[DAY] tinyint,		--calendar day of month (1-31)
[TIME] smallint, 		--HHmmss in 24 hour time format
LAT_DD numeric(11,8),	--survey platform latitude
LONG_DD numeric(11,8),	--survey platform longitude
ALTITUDE smallint,		--survey aircraft altitude in meters
HEADING	smallint,		--survey aircraft or vessel heaidng (0-359)
SURFTEMP numeric,		--sea surface temperature in degrees celsius
-- WATCH INFORMATION
LEGNO smallint,			--survey leg number
LEGSTAGE smallint,		--1 digit code for stage of leg
LEGTYPE	smallint,		--1 digit code for line type
WX nchar(1),		--1 digit code for weather observation
CLOUD smallint,			--0-9 cloud cover from look up table
BEAUFORT smallint,		--sea state on beaufort scale
GLAREL	smallint, --glare affecting left side observer from look up table (0-3)
GLARER	smallint, --glare affecting right side observer from look up table (0-3)
VISIBLTY smallint,		--estimated visibility (negatives represent old codes)
-- SIGHTING INFORMATION
SIGHTNO	smallint,		--sighting number within survey
SPECCODE nchar(4),		--code for species
IDREL smallint,	      --sighting identification (SPECCODE) reliability
TAXCODE smallint,     --0-9 code for taxonomy code
[NUMBER] smallint,	--estimate of number of animals sighted
CONFIDNC smallint, --0-11 confidence in animal count (NUMBER) from look up table
ANHEAD smallint,	  --sighted animal heading as category (00-22)
NUMCALF smallint,	--number of calfs sighted
PHOTOS smallint,	--1-5 (really 1-2) code of what photos are available
STRIP smallint,		--2 digit code representing distances
S_LAT numeric(11,8),	--exact position of sighting after verification
S_LONG numeric(11,8),	--exact position of sighting after verification
S_TIME smallint,	--HHmmss of exact location sighting
BEHAV1 smallint,	--behaviour code from look up table
BEHAV2 smallint,
BEHAV3 smallint,
BEHAV4 smallint,
BEHAV5 smallint,
BEHAV6 smallint,
BEHAV7 smallint,
BEHAV8 smallint,
BEHAV9 smallint,
BEHAV10 smallint,
BEHAV11 smallint,
BEHAV12 smallint,
BEHAV13 smallint,
BEHAV14 smallint,
BEHAV15 smallint,
);
