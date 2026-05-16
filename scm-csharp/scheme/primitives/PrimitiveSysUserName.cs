namespace scheme;

public class PrimitiveSysUserName : Primitive
{
    public override string Name()
    {
        return "sys-user-name";
    }

    public override string Info()
    {
        return
            "Syntax: (sys-user-name)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the name of the currently logged-in user as a string.\n" +
            "Example:\n" +
            "  (sys-user-name) => \"alice\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return Environment.UserName.ToCharArray();
    }
}
