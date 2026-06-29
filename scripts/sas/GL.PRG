PUBLIC M_gl
GO 1
STORE ' ' TO M_gl
DO WHILE .NOT. EOF()
do case
   case glarel=' '
        replace glarel with m_gl
        skip
   case glarel <> ' '
        m_gl = glarel
        skip
endcase
ENDDO
RETURN
