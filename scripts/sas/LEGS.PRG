PUBLIC M_LS
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
   case legstage='3'
        m_ls = ' '
        skip
   case legstage='4'
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