PUBLIC M_CC
GO 1
STORE ' ' TO M_cc
DO WHILE .NOT. EOF()
do case
   case cloud=' '
        replace cloud with m_cc
        skip
   case cloud <> ' '
        m_cc = cloud
        skip
endcase
ENDDO
RETURN
