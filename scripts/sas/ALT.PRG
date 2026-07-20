PUBLIC M_alt
GO 1
STORE '    ' TO M_alt
DO WHILE .NOT. EOF()
do case
   case alt='    '
        replace alt with m_alt
        skip
   case alt <> '    '
        m_alt= alt
        skip
endcase 
enddo
RETURN
