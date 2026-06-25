PUBLIC M_LS M_LT M_LG
GO 1
STORE '   ' TO M_LG
DO WHILE .NOT. EOF()
DO CASE
   CASE LEGNO <> '   '
        M_LG = LEGNO
        SKIP
   CASE LEGNO = '   '
        REPLACE LEGNO WITH M_LG
        M_LG = LEGNO
        SKIP
   ENDCASE
ENDDO
GO 1
STORE ' ' TO M_LT
DO WHILE .NOT. EOF()
DO CASE 
   CASE LEGTYPE <> ' '
        M_LT = LEGTYPE
        SKIP
   CASE LEGTYPE=' '
        REPLACE LEGTYPE WITH M_LT
        M_LT = LEGTYPE
        SKIP
   ENDCASE 
ENDDO
GO 1
STORE ' ' TO M_LS
DO WHILE .NOT. EOF()
do case
   case legstage='1'
        m_ls = '2' 
        skip
   case legstage='2'
        m_ls = '2'
        skip
   case legstage='5'
        m_ls = ' '
        skip
   case legstage=' '
        replace legstage with m_ls
        m_ls = legstage
        skip
   endcase
ENDDO
RETURN
