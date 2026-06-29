        IF CONFIDNC = . THEN DO;
           FLAG = 'MISSING CONFIDENCE CODE';
           OUTPUT;
           END;
        ELSE IF CONFIDNC GT 11 THEN DO;
           FLAG = 'CONFIDENCE CODE OUT OF RANGE';
           BADVALUE = CONFIDNC;
           OUTPUT;
           END;
        ELSE IF (NUMBER=1 AND (2 LE CONFIDNC LE 8)) OR
           (NUMBER=2 AND (2 LE CONFIDNC LE 8)) OR
           ((3 LE NUMBER LE 7) AND (3 LE CONFIDNC LE 8)) OR
           ((8 LE NUMBER LE 14) AND (4 LE CONFIDNC LE 8)) OR
           ((15 LE NUMBER LE 40) AND (5 LE CONFIDNC LE 8)) OR
           ((41 LE NUMBER LE 80) AND (6 LE CONFIDNC LE 8)) OR
           ((81 LE NUMBER LE 120) AND (7 LE CONFIDNC LE 8)) OR
           ((121 LE NUMBER LE 1499) AND (CONFIDNC=8)) THEN DO;
           FLAG = 'CONFIDENCE CODE TOO LARGE FOR NUMBER';
           BADVALUE = CONFIDNC;
           OUTPUT;
           END;
        ELSE IF (NUMBER=1 AND CONFIDNC=1) THEN DO;
           FLAG = '+/-1 CONFIDENCE CODE ILLOGICAL FOR NUMBER=1';
           BADVALUE = CONFIDNC;
           OUTPUT;
           END;
        ELSE IF CONFIDNC=11 AND NUMBER NE . THEN DO;
           FLAG = 'NUMBER - CONFIDENCE CODE MISMATCH';
           BADVALUE = CONFIDNC;
           OUTPUT;
           END;
        ELSE IF NUMBER>20 AND CONFIDNC=0 AND SPECCODE NE 'RECV' 
           AND SPECCODE NE 'SPFV' THEN DO;
           FLAG = 'EXACT COUNT FOR >20 ANIMALS';
           BADVALUE = NUMBER;
           OUTPUT;
           END;
        IF DEPTH GT 2000 THEN DO;
           FLAG = 'DEPTH OVER 2000 M';
           BADVALUE = DEPTH;
           OUTPUT;
           END;
        IF IDREL = . THEN DO;
           FLAG = 'ID RELIABILITY CODE MISSING';
           BADVALUE = ' ';
           OUTPUT;
           END;
        ELSE IF IDREL=0 OR (4 LE IDREL LE 8) THEN DO;
           FLAG = 'ID RELIABILITY OUT OF RANGE';
           BADVALUE = IDREL;
           OUTPUT;
           END;
        ELSE IF SUBSTR(SPECCODE,1,2)='UN' AND IDREL=1 THEN DO;
           FLAG = 'IDREL TOO LOW FOR UNID. SPECIES';
           BADVALUE = IDREL;
           OUTPUT;
           END;
        IF (NUMBER=. AND CONFIDNC NE 11) THEN DO;
           FLAG = 'NUMBER OF ANIMALS MISSING';
           BADVALUE = NUMBER;
           OUTPUT;
           END;
        IF NUMBER=0 THEN DO;
           FLAG = 'NUMBER OF ANIMALS = ZERO';
           BADVALUE = NUMBER;
           OUTPUT;
           END;
        ELSE IF (NUMBER GT 30 AND (TAXCODE=1 OR TAXCODE=2))  OR
           (NUMBER GT 5 AND TAXCODE=5) OR
           (NUMBER GT 5 AND TAXCODE=4 and substr(speccode,3,2) ne 'SE') OR
           (NUMBER GT 100 AND (TAXCODE=6 OR TAXCODE=7) AND
             SPECCODE NE 'CNRA' AND SPECCODE NE 'UNRA' and
             speccode ne 'TUNS' and speccode ne 'BFTU' ) OR
           (NUMBER GT 500 AND TAXCODE=3) THEN DO;
           FLAG = 'NUMBER OF ANIMALS TOO HIGH';
           BADVALUE = NUMBER;
           OUTPUT;
           END;
        IF NUMCALF GE 5 THEN DO;
           FLAG = 'NUMBER OF CALVES TOO HIGH';
           BADVALUE = NUMCALF;
           OUTPUT;
           END;
        IF (NUMBER-NUMCALF LT 1) AND NUMCALF NE . THEN DO;
           FLAG = 'NUMCALF NOT LESS THAN NUMBER';
           BADVALUE = NUMCALF;
           OUTPUT;
           END;
        IF PHOTOS = . THEN DO;
           FLAG = 'PHOTOS CODE MISSING';
           BADVALUE = ' ';
           OUTPUT;
           END;
        ELSE IF PHOTOS GT 5 THEN DO;
           FLAG = 'PHOTOS CODE OUT OF RANGE';
           BADVALUE = PHOTOS;
           OUTPUT;
           END;
