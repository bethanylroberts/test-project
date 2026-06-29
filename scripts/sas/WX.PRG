PUBLIC M_wx
GO 1
STORE ' ' TO M_wx
DO WHILE .NOT. EOF()
do case
   case wx=' '
        replace wx with m_wx
        skip
   case wx <> ' '
        m_wx = wx
        skip
endcase
ENDDO
RETURN
