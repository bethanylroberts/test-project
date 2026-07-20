PUBLIC M_SS
GO 1
STORE ' ' TO M_SS
DO WHILE .NOT. EOF()
do case
   case beaufort=' '
        replace beaufort with m_ss
        skip
   case beaufort <> ' '
        m_ss = beaufort
        skip
endcase
ENDDO
RETURN
