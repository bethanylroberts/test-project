**********************************************************************
*****                                                            *****
*****     THIS MACRO CHECKS FOR DUPLICATE SIGHTING NUMBERS       *****
*****     WITHIN ANY DATA FILE.  THIS FILE IS READ-ONLY,         *****
*****     WHICH MUST BE CHANGED (IN WINDOWS EXPLORER) TO EDIT.   *****
*****     THE FILE IS INVOKED FROM WITHIN THE SAS QUALITY        *****
*****     CONTROL PROCESS.                                       *****
*****                                                            *****
*****               PROGRAMMER:  R. D. KENNEY                    *****
*****          LATEST REVISION:  8 OCTOBER 2002                  *****
*****                                                            *****
**********************************************************************;

     LENGTH BADVALUE $ 8 FLAG $ 40;
     KEEP EVENTNO SIGHTNO BADVALUE FLAG;
     IF SIGHTNO=. THEN DELETE;
     PREV = LAG(SIGHTNO);
     IF SIGHTNO=PREV THEN DO;
        FLAG = 'DUPLICATE SIGHTING NUMBER';
        BADVALUE = SIGHTNO;
        OUTPUT;
        END;
