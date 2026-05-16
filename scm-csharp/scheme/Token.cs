namespace scheme;

public class Token
{
    public string value;
    public TokenType type;
    public SourcePos pos;

    public Token(string value, TokenType type, SourcePos pos)
    {
        this.value = value;
        this.type = type;
	this.pos = pos;
    }

    public object ToSexpr()
    {
	if (pos != null)
	{
	    return new Pair(
		value.ToCharArray(),
		new Pair(
		    type.ToString(),
		    new Pair(
			pos.ToSexpr(),
			Value.NIL)));
	}
	else
	{
	    return new Pair(
		value.ToCharArray(),
		new Pair(
		    type.ToString(),
		    Value.NIL));
	}
    }

    public override string ToString()
    {
        return value + " (" + type + ") @" + pos;
    }
}
