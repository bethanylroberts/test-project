PUBLIC M_viz
GO 1
STORE '    ' TO M_viz
DO WHILE .NOT. EOF()
do case
   case visiblty='    '
        replace visiblty with m_viz
        skip
   case visiblty <> '    '
        m_viz= visiblty
        skip
endcase
ENDDO
RETURN
