PUBLIC M_gr
GO 1
STORE ' ' TO M_gr
DO WHILE .NOT. EOF()
do case
   case glarer=' '
        replace glarer with m_gr
        skip
   case glarer <> ' '
        m_gr = glarer
        skip
endcase
ENDDO
RETURN
