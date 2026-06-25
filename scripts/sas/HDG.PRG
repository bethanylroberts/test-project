PUBLIC M_hh
GO 1
STORE ' ' TO M_hh
DO WHILE .NOT. EOF()
do case
   case heading=' '
        replace heading with m_hh
        skip
   case heading <> ' '
        m_hh = heading
        skip
endcase
ENDDO
RETURN
