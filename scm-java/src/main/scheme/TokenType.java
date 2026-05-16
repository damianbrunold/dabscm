package scheme;

public enum TokenType
{
    OPENPAR,
    CLOSEPAR,
    SHARPOPENPAR,
    DOT,
    QUOTE,
    BACKQUOTE,
    COMMA,
    COMMAAT,
    DOTDOTDOT,
    CHARACTER,
    STRING,
    SYMBOL,
    INTEGER,
    REAL,
    RATIONAL,
    COMPLEX,
    TRUE,
    FALSE,
    BYTEVECTOROPENPAR,
    LABELDEFINITION,   // #N=  (token.value = decimal N)
    LABELREFERENCE,    // #N#  (token.value = decimal N)
    DATUMCOMMENT,      // #;   (datum comment — skip next datum)
    SYNTAX,            // #'
    QUASISYNTAX,       // #`
    UNSYNTAX,          // #,
    UNSYNTAXSPLICING   // #,@
}
