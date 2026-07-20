     IF GLAREL > 3 THEN DO;
        FLAG = 'LEFT GLARE OUT OF RANGE';
        BADVALUE = GLAREL;
        OUTPUT;
        END;
     IF GLARER > 3 THEN DO;
        FLAG = 'RIGHT GLARE OUT OF RANGE';
        BADVALUE = GLARER;
        OUTPUT;
        END;
     IF (BLOCK NE 'NB' AND BLOCK NE 'NE' AND BLOCK NE 'NO' AND
        BLOCK NE 'GS' AND BLOCK NE 'S5' AND BLOCK NE 'S6' AND
        BLOCK NE 'S7' AND BLOCK NE 'S8' AND BLOCK NE 'S9' AND
        BLOCK NE ' ' AND BLOCK NE 'SE' AND BLOCK NE 'MV' AND 
        BLOCK NE 'MC' AND BLOCK NE 'MN') THEN DO;
        FLAG = 'UNKNOWN SURVEY BLOCK';
        BADVALUE = BLOCK;
        OUTPUT;
        END;
     IF (PORTOBS NE '7' AND PORTOBS NE 'F' AND PORTOBS NE 'H' AND
        PORTOBS NE 'AK' AND PORTOBS NE 'AV' AND
        PORTOBS NE 'BF' AND PORTOBS NE 'CS' AND
        PORTOBS NE 'GK' AND PORTOBS NE 'JC' AND
        PORTOBS NE 'JV' AND PORTOBS NE 'NF' AND
        PORTOBS NE 'RP' AND PORTOBS NE 'SK' AND
        PORTOBS NE 'JH' AND PORTOBS NE '  ') THEN DO;
        FLAG = 'UNKNOWN PORT OBSERVER';
        BADVALUE = PORTOBS;
        OUTPUT;
        END;
     IF (STAROBS NE '7' AND STAROBS NE 'F' AND STAROBS NE 'H' AND
        STAROBS NE 'AK' AND STAROBS NE 'AV' AND
        STAROBS NE 'BF' AND STAROBS NE 'CS' AND
        STAROBS NE 'GK' AND STAROBS NE 'JC' AND
        STAROBS NE 'JV' AND STAROBS NE 'NF' AND
        STAROBS NE 'RP' AND STAROBS NE 'SK' AND
        STAROBS NE 'JH' AND STAROBS NE '  ') THEN DO;
        FLAG = 'UNKNOWN STARBOARD OBSERVER';
        BADVALUE = STAROBS;
        OUTPUT;
        END;
     IF (STRATUM NE 'A' AND STRATUM NE 'B' AND
        STRATUM NE 'X' AND STRATUM NE 'Y' AND
        STRATUM NE 'Z' AND STRATUM NE '0' AND
        STRATUM NE ' ' AND STRATUM NE 'M' AND
        STRATUM NE 'R') THEN DO;
        FLAG = 'UNKNOWN STRATUM';
        BADVALUE = STRATUM;
        OUTPUT;
        END;
     IF (LEGTYPE=2 OR LEGTYPE=4) AND STRATUM=' ' THEN DO;
        FLAG = 'STRATUM MISSING';
        BADVALUE = STRATUM;
        OUTPUT;
        END;
        ELSE IF LEGTYPE=3 AND STRATUM NE ' ' THEN DO;
             FLAG = 'STRATUM ASSIGNED ON CROSS-LEG';
             BADVALUE = STRATUM;
             OUTPUT;
             END;
        ELSE IF LEGTYPE=1 AND STRATUM NE ' ' THEN DO;
             FLAG = 'STRATUM ASSIGNED ON TRANSIT';
             BADVALUE = STRATUM;
             OUTPUT;
             END;
     IF (SIGHTOBS NE '7' AND SIGHTOBS NE 'F' AND SIGHTOBS NE 'H' AND
        SIGHTOBS NE 'AK' AND SIGHTOBS NE 'AV' AND
        SIGHTOBS NE 'BF' AND SIGHTOBS NE 'CS' AND
        SIGHTOBS NE 'GK' AND SIGHTOBS NE 'JC' AND
        SIGHTOBS NE 'JV' AND SIGHTOBS NE 'NF' AND
        SIGHTOBS NE 'RP' AND SIGHTOBS NE 'SK' AND
        SIGHTOBS NE 'JH' AND SIGHTOBS NE '  ') THEN DO;
           FLAG = 'UNKNOWN SIGHTING OBSERVER';
           BADVALUE = SIGHTOBS;
           OUTPUT;
           END;
        IF (SIGHTNO>0 AND LEGTYPE=2 AND LEGSTAGE=2 AND STRIP=. AND 
            S_LAT NE . AND S_LONG NE .) THEN DO;
           FLAG = 'STRIP NUMBER MISSING';
           BADVALUE = ' ';
           OUTPUT;
           END;
        IF (STRIP GT 16 OR STRIP=0 OR (PLATFORM NE 626 AND STRIP GT 14))
           THEN DO;
           FLAG = 'STRIP NUMBER OUT OF RANGE';
           BADVALUE = STRIP;
           OUTPUT;
           END;
     LAT = (LATDEG + LATMIN/60)/57.29678;
     LONG = (LONGDEG + LONGMIN/60)/57.29678;
     IF TIME < 2400 THEN DO;
        TIMEHR = INT(TIME/100);
        TIMEMIN = TIME - 100*TIMEHR;
        TIMESEC = 0;
        END;
     ELSE IF TIME > 2400 THEN DO;
        TIMEHR = INT(TIME/10000);
        TIMEMIN = INT((TIME - TIMEHR*10000)/100) ;
        TIMESEC = TIME - 10000*TIMEHR - 100*TIMEMIN;
        END;
     IF TIMEMIN GT 59 THEN DO;
        FLAG = 'TIME MINUTES OUT OF RANGE';
        BADVALUE = TIME;
        OUTPUT;
        END;
     IF TIMESEC GT 59 THEN DO;
        FLAG = 'TIME SECONDS OUT OF RANGE';
        BADVALUE = TIME;
        OUTPUT;
        END;
     TIME2 = TIMEHR + TIMEMIN/60 + TIMESEC/3600;
     PREVLAT = LAG(LAT);
     PREVLONG = LAG(LONG);
     PREVTIME = LAG(TIME2);
     PREVALT  = LAG(ALT);
     DISTANCE = 60 * 57.29678 * ARCOS((SIN(PREVLAT) *
                SIN(LAT)) + (COS(PREVLAT) * COS(LAT)) *
                COS(LONG - PREVLONG));
     ETIME = TIME2 - PREVTIME;
     IF (ETIME NE . AND ETIME LT 0) THEN DO;
        FLAG = 'TIMES OUT OF ORDER';
        BADVALUE = ETIME;
        OUTPUT;
        END;
     ELSE IF ETIME>0.166 THEN DO;
        FLAG = '>10 MINUTES WITHOUT A POSITION';
        BADVALUE = ETIME*60;
        OUTPUT;
        END;
     SPEED = DISTANCE/ETIME;
     IF ETIME = 0 THEN DO;
        DELTA = round(((ALT - PREVALT)*0.0546833)/0.000278);
        END;
     ELSE IF ETIME > 0 THEN DO;
        DELTA = round(((ALT - PREVALT)*0.0546833)/etime);
        END;        
        IF ALT = . THEN DO;
           FLAG = 'ALTITUDE MISSING';
           BADVALUE = ' ';
           OUTPUT;
           END;
        ELSE IF (ALT LT 60 OR ALT GT 750) THEN DO;
           FLAG = 'ALT OUT OF RANGE';
           BADVALUE = ALT;
           OUTPUT;
           END;
        IF DELTA > 1200 AND PLATFORM = 649 THEN DO;
           FLAG = 'CLIMB > 1200 FT/MIN';
           BADVALUE = DELTA;
           OUTPUT;
           END;
        ELSE IF DELTA < -1800 AND PLATFORM = 649 THEN DO;
           FLAG = 'DESCENT > 1800 FT/MIN';
           BADVALUE = DELTA;
           OUTPUT;
           END;
        ELSE IF DELTA > 1200 AND (PLATFORM=633 or PLATFORM=653) THEN DO;
           FLAG = 'CLIMB > 1600 FT/MIN';
           BADVALUE = DELTA;
           OUTPUT;
           END;
        ELSE IF DELTA < -2400 AND (PLATFORM=633 or PLATFORM=653) THEN DO;
           FLAG = 'DESCENT > 2400 FT/MIN';
           BADVALUE = DELTA;
           OUTPUT;
           END;
        ELSE IF DELTA > 1000 and platform ne 649 and platform ne 633
             and platform ne 653 THEN DO;
           FLAG = 'CLIMB > 1000 FT/MIN';
           BADVALUE = DELTA;
           OUTPUT;
           END;
        ELSE IF DELTA < -1500 and platform ne 649 and platform ne 633
             and platform ne 653 THEN DO;
           FLAG = 'DESCENT > 1500 FT/MIN';
           BADVALUE = DELTA;
           OUTPUT;
           END;
        IF DAY = . THEN DO;
           FLAG = 'DAY MISSING';
           BADVALUE = ' ';
           OUTPUT;
           END;
        IF TIME = . THEN DO;
           FLAG = 'TIME MISSING';
           BADVALUE = ' ';
           OUTPUT;
           END;
        IF LEGTYPE = . THEN DO;
           FLAG = 'LEGTYPE MISSING';
           BADVALUE = ' ';
           OUTPUT;
           END;
        ELSE IF LEGTYPE=2 THEN DO;
           IF BEAUFORT = . THEN DO;
              FLAG = 'BEAUFORT MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
           IF BLOCK = ' ' THEN DO;
              FLAG = 'BLOCK MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
           IF CLOUD = . THEN DO;
              FLAG = 'CLOUD COVER MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
           IF VISIBLTY = . THEN DO;
              FLAG = 'VISIBILITY MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
     *      IF LEGGOOD = . THEN DO;
     *         FLAG = 'LEGGOOD MISSING';
     *         BADVALUE = ' ';
     *         OUTPUT;
     *         END;
           IF LEGNO = . THEN DO;
              FLAG = 'LEG NUMBER MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
     *      IF PORTOBS = ' ' THEN DO;
     *         FLAG = 'PORT OBSERVER MISSING';
     *         BADVALUE = ' ';
     *         OUTPUT;
     *         END;
     *      IF STAROBS = ' ' THEN DO;
     *         FLAG = 'STARBOARD OBSERVER MISSING';
     *         BADVALUE = ' ';
     *         OUTPUT;
     *         END;
           IF STRATUM = ' ' THEN DO;
              FLAG = 'STRATUM MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
           IF GLAREL = . THEN DO;
              FLAG = 'LEFT GLARE MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
           IF GLARER = . THEN DO;
              FLAG = 'RIGHT GLARE MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
           IF HEADING = . THEN DO;
              FLAG = 'HEADING MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
           IF LEGSTAGE = . THEN DO;
              FLAG = 'LEG STAGE MISSING';
              BADVALUE = ' ';
              OUTPUT;
              END;
           END;
     *   IF (LEGGOOD = 0 OR LEGGOOD GT 2) THEN DO;
     *      FLAG = 'LEGGOOD OUT OF RANGE';
     *      BADVALUE = LEGGOOD;
     *      OUTPUT;
     *      END;
        IF LEGTYPE GT 4 THEN DO;
           FLAG = 'LEGTYPE OUT OF RANGE';
           BADVALUE = LEGTYPE;
           OUTPUT;
           END;
        IF (LEGTYPE=2 AND (LEGSTAGE GT 7 OR ((LAG(LEGSTAGE)=1
           OR LAG(LEGSTAGE)=2 OR LAG(LEGSTAGE=6) OR LAG(LEGSTAGE=7)) AND
           (LEGSTAGE=1 OR LEGSTAGE=4)) OR (LAG(LEGSTAGE)=4 AND
           LEGSTAGE=1) OR (LAG(LEGSTAGE)=5 AND
           (2 LE LEGSTAGE LE 7)) OR (LAG(LEGSTAGE)=3 AND
           LEGSTAGE NE 4) OR (LEGSTAGE=4 AND (LAG(LEGSTAGE) NE 3
           AND LAG(LEGTYPE) NE 4)) OR (LEGSTAGE=1 AND
           (LAG(LEGSTAGE) NE 5 AND LAG(LEGSTAGE) NE .)))) OR
           (LEGTYPE=4 AND (LAG(LEGTYPE) NE 4 AND
           LAG(LEGSTAGE) NE 3)) THEN DO;
           FLAG = 'LEG STAGE OUT OF RANGE';
           BADVALUE = LEGSTAGE;
           OUTPUT;
           END;
        IF LAST.FILEID AND (LEGSTAGE NE 5 AND LEGSTAGE NE .)
           THEN DO;
           FLAG = 'LEG STAGE OUT OF RANGE';
           BADVALUE = LEGSTAGE;
           OUTPUT;
           END;
        ELSE IF (LEGTYPE NE 2 AND (LEGSTAGE NE . AND LEGSTAGE NE 7)) THEN DO;
           FLAG = 'LEG STAGE ON NON-CENSUS LEG';
           BADVALUE = LEGSTAGE;
           OUTPUT;
           END;
        IF ETIME = 0 AND DISTANCE = 0 THEN DO;
           FLAG = 'DUPLICATE LOCATION & TIME';
           OUTPUT;
           END;
        ELSE IF ETIME > 0 AND DISTANCE = 0 THEN DO;
           FLAG = 'SAME LOCATION, DIFF. TIME';
           OUTPUT;
           END;
        ELSE IF ETIME = 0 AND DISTANCE > 0 THEN DO;
           SPEED = DISTANCE / 0.000278;
           END;
        IF SPEED GT 225 THEN DO;
           FLAG = 'SPEED TOO HIGH';
           BADVALUE = SPEED;
           OUTPUT;
           END;
        ELSE IF (0.5 LE SPEED < 50) AND DISTANCE > 0 THEN DO;
           FLAG = 'SPEED TOO LOW';
           BADVALUE = SPEED;
           OUTPUT;
           END;
        ELSE IF (0 < SPEED < 0.5) AND ETIME=0 THEN DO;
           FLAG = 'DUPLICATE LOCATION & TIME';
           OUTPUT;
           END;
        ELSE IF (0 < SPEED < 0.5) AND ETIME>0 THEN DO;
           FLAG = 'SAME LOCATION, DIFF. TIME';
           OUTPUT;
           END;
        IF (PLATFORM LT 626 OR PLATFORM GT 649) THEN DO;
           FLAG = 'PLATFORM NUMBER OUT OF RANGE';
           BADVALUE = PLATFORM;
           OUTPUT;
           END;
        IF LEGSTAGE=7 AND PHOTOS=1 THEN DO;
           FLAG = 'NO PHOTOS BUT LEGSTAGE=7';
           BADVALUE = PHOTOS;
           OUTPUT;
           END;
        IF SIGHTNO GE 300 AND LEGSTAGE NE 7 THEN DO;
           FLAG = 'SIGHTNO>299 BUT LEGSTAGE NOT 7';
           BADVALUE = LEGSTAGE;
           OUTPUT;
           END;
        IF SIGHTNO GE 300 AND PHOTOS=1 THEN DO;
           FLAG = 'SIGHTNO>299 BUT NO PHOTOS';
           BADVALUE = PHOTOS;
           OUTPUT;
           END;