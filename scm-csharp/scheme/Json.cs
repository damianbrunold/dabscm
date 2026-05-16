using System.Collections;
using System.Text;

namespace scheme;

public class JsonParser
{
    private Lexer lexer;
    private string listId = "data";
    private string status = "start";

    public JsonParser(string data)
    {
        lexer = new Lexer(new StringReader(data));
    }

    public JsonParser(TextReader reader)
    {
        lexer = new Lexer(reader);
    }

    public JsonParser WithListId(string listId)
    {
        this.listId = listId;
        return this;
    }

    public void Close()
    {
        this.lexer.Close();
    }

    public JsonObject? NextObject()
    {
        if (status == "start")
        {
            string? token = lexer.NextToken();
            if (token != null && token.Equals("{"))
            {
                token = lexer.NextToken();
                if (token != null && token.Equals("\"" + listId + "\""))
                {
                    lexer.MatchToken(":");
                    lexer.MatchToken("[");
                    status = "reading";
                    return ParseObject();
                }
                else if (token != null)
                {
                    lexer.PutBackToken(token);
                    lexer.PutBackToken("{");
                    status = "reading";
                    return ParseObject();
                }
            }
            else if (token != null && token.Equals("["))
            {
                status = "reading";
                return ParseObject();
            }
            return null;
        }
        else if (status == "reading")
        {
            string? token = lexer.NextToken();
            // optionally skip ,
            if (token != null && token.Equals(","))
            {
                token = lexer.NextToken();
            }
            // if ] found, we are at the end
            if (token == null ||token.Equals("]"))
            {
                status = "end";
                return null;
            }
            lexer.PutBackToken(token);
            return ParseObject();
        }
        else
        {
            return null;
        }
    }

    public string? NextToken()
    {
        return lexer.NextToken();
    }

    public void MatchToken(string token)
    {
        lexer.MatchToken(token);
    }

    public void PutBackToken(string token)
    {
        lexer.PutBackToken(token);
    }

    public JsonObject ParseObject()
    {
        JsonObject result = new();
        lexer.MatchToken("{");
        string? token = lexer.NextToken();
        if (token == null) throw new Exception("Unexpected end of tokens");
        if (token == "}") return result;
        while (true)
        {
            if (!token.StartsWith("\""))
            {
                throw new Exception("Expected string but got " + token);
            }
            string name = token.Substring(1, token.Length - 2);
            lexer.MatchToken(":");
            token = lexer.NextToken();
            if (token == "null")
            {
                result.entries[name] = new JsonNull();
            }
            else if (token == "true")
            {
                result.entries[name] = new JsonTrue();
            }
            else if (token == "false")
            {
                result.entries[name] = new JsonFalse();
            }
            else if (token == "{")
            {
                lexer.PutBackToken("{");
                result.entries[name] = ParseObject();
            }
            else if (token == "[")
            {
                lexer.PutBackToken("[");
                result.entries[name] = ParseList();
            }
            else if (token?.StartsWith("\"") ?? false)
            {
                result.entries[name] = new JsonString(token.Substring(1, token.Length - 2));
            }
            else if (token != null) 
            {
                result.entries[name] = new JsonNumber(Double.Parse(token));
            }
            token = lexer.NextToken();
            if (token == null) throw new Exception("Unexpected end of tokens");
            if (token == "}") break;
            if (token != ",") throw new Exception("Expected comma or end of object but got " + token);
            token = lexer.NextToken();
            if (token == null) throw new Exception("Unexpected end of tokens");
        }
        return result;
    }

    public JsonList ParseList()
    {
        JsonList result = new();
        lexer.MatchToken("[");
        string? token = lexer.NextToken();
        if (token == null) throw new Exception("Unexpected end of tokens");
        if (token == "]") return result;
        while (true)
        {
            if (token == "null")
            {
                result.elements.Add(new JsonNull());
            }
            else if (token == "true")
            {
                result.elements.Add(new JsonTrue());
            }
            else if (token == "false")
            {
                result.elements.Add(new JsonFalse());
            }
            else if (token == "{")
            {
                lexer.PutBackToken("{");
                result.elements.Add(ParseObject());
            }
            else if (token == "[")
            {
                lexer.PutBackToken("[");
                result.elements.Add(ParseList());
            }
            else if (token.StartsWith("\""))
            {
                result.elements.Add(new JsonString(token.Substring(1, token.Length - 2)));
            }
            else
            {
                result.elements.Add(new JsonNumber(Double.Parse(token)));
            }
            token = lexer.NextToken();
            if (token == null) throw new Exception("Unexpected end of tokens");
            if (token == "]") break;
            if (token != ",") throw new Exception("Expected comma or end of list but got " + token);
            token = lexer.NextToken();
            if (token == null) throw new Exception("Unexpected end of tokens");
        }
        return result;
    }

}

public abstract class JsonValue
{
    public virtual bool IsFalse() { return false; }
    public virtual bool IsTrue() { return false; }
    public virtual bool IsNull() { return false; }
    public virtual bool IsNumber() { return false; }
    public virtual bool IsString() { return false; }
    public virtual bool IsList() { return false; }
    public virtual bool IsObject() { return false; }

    public JsonString AsString() { return (JsonString)this; }
    public JsonNumber AsNumber() { return (JsonNumber)this; }
    public JsonList AsList() { return (JsonList)this; }
    public JsonObject AsObject() { return (JsonObject)this; }

}


public class JsonFalse : JsonValue
{

    public override bool IsFalse() { return true; }

    public override string ToString()
    {
        return "false";
    }
}

public class JsonList : JsonValue, IEnumerable<JsonValue>
{
    public List<JsonValue> elements = new();

    public IEnumerator<JsonValue> GetEnumerator()
    {
        return ((IEnumerable<JsonValue>)elements).GetEnumerator();
    }

    public override bool IsList() { return true; }

    public override string ToString()
    {
        var result = new StringBuilder("[");
        if (elements.Count > 0)
        {
            for (int i = 0; i < elements.Count - 1; i++)
            {
                result.Append(elements[i]).Append(", ");
            }
            result.Append(elements[elements.Count - 1]);
        }
        result.Append("]");
        return result.ToString();
    }

    IEnumerator IEnumerable.GetEnumerator()
    {
        return ((IEnumerable)elements).GetEnumerator();
    }
}

public class JsonNull : JsonValue
{
    public override bool IsNull() { return true; }

    public override string ToString()
    {
        return "null";
    }
}

public class JsonNumber : JsonValue
{

    public double value;

    public JsonNumber(double value)
    {
        this.value = value;
    }

    public override bool IsNumber() { return true; }

    public override string ToString()
    {
        if (value == Math.Floor(value)) return ((int)value).ToString();
        return value.ToString();
    }
}

public class JsonObject : JsonValue, IEnumerable<string>
{
    public Dictionary<string, JsonValue> entries = new();

    public override bool IsObject() { return true; }

    public bool HasEntry(string name)
    {
        return entries.ContainsKey(name);
    }

    public string GetString(string name, string defaultValue)
    {
        if (!entries.ContainsKey(name)) return defaultValue;
        return entries[name].AsString().value;
    }

    public string GetString(string name)
    {
        if (!entries.ContainsKey(name)) return "";
        return entries[name].AsString().value;
    }

    public double GetNumber(string name, double defaultValue)
    {
        if (!entries.ContainsKey(name)) return defaultValue;
        return entries[name].AsNumber().value;
    }

    public int GetInt(string name, int defaultValue)
    {
        if (!entries.ContainsKey(name)) return defaultValue;
        return (int)entries[name].AsNumber().value;
    }

    public bool GetBool(string name, bool defaultValue)
    {
        if (!entries.ContainsKey(name)) return defaultValue;
        if (entries[name].IsTrue()) return true;
        return false;
    }

    public JsonList GetList(string name)
    {
        if (!entries.ContainsKey(name)) return new JsonList();
        return entries[name].AsList();
    }

    public override string ToString()
    {
        StringBuilder result = new StringBuilder("{");
        if (entries.Count > 0)
        {
            foreach (string name in entries.Keys)
            {
                result.Append("\"" + name.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\": ");
                result.Append(entries[name]);
                result.Append(", ");
            }
            result.Length = result.Length - 2;
        }
        result.Append("}");
        return result.ToString();
    }

    IEnumerator<string> IEnumerable<string>.GetEnumerator()
    {
        return ((IEnumerable<String>)entries.Keys).GetEnumerator();
    }

    IEnumerator IEnumerable.GetEnumerator()
    {
        return ((IEnumerable)entries.Keys).GetEnumerator();
    }
}

public class JsonString : JsonValue
{
    public string value;

    public JsonString(string value)
    {
        this.value = value;
    }

    public override bool IsString() { return true; }

    public override string ToString()
    {
        return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", "\\r") + "\"";
    }
}

public class JsonTrue : JsonValue
{
    public override bool IsTrue() { return true; }

    public override string ToString()
    {
        return "true";
    }
}

public class Lexer
{
    private TextReader reader;
    private List<string> tokens = new();
    private int cUnread = -1;

    public Lexer(string data)
    {
        reader = new StringReader(data);
    }

    public Lexer(TextReader reader)
    {
        this.reader = reader;
    }

    public void Close()
    {
        reader.Close();
    }

    public void PutBackToken(string token)
    {
        tokens.Add(token);
    }

    public string? NextToken()
    {
        if (tokens.Count > 0)
        {
            var val = tokens[tokens.Count - 1];
            tokens.RemoveAt(tokens.Count - 1);
            return val;
        }
        var result = new StringBuilder();
        int state = 0;
        int c;
        if (cUnread != -1) {
            c = cUnread;
            cUnread = -1;
        } else {
            c = reader.Read();
        }
        while (c != -1)
        {
            char ch = (char)c;
            switch (state)
            {
                case 0: // skip whitespace
                    if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n')
                    {
                        break;
                    }
                    else if (ch == '"')
                    {
                        state = 1;
                        result.Append(ch);
                    }
                    else if (('0' <= ch && ch <= '9') || ch == '+' || ch == '-')
                    {
                        state = 2;
                        result.Append(ch);
                    }
                    else if (ch == ':' || ch == ',' || ch == '{' || ch == '}' || ch == '[' || ch == ']')
                    {
                        result.Append(ch);
                        state = -1;
                    }
                    else
                    {
                        state = 3;
                        result.Append(ch);
                    }
                    break;

                case 1: // string
                    if (ch == '\\')
                    {
                        state = 4;
                    }
                    else if (ch == '"')
                    {
                        result.Append(ch);
                        state = -1;
                    }
                    else
                    {
                        result.Append(ch);
                    }
                    break;

                case 2: // integer
                    if ('0' <= ch && ch <= '9')
                    {
                        result.Append(ch);
                    }
                    else if (ch == '.')
                    {
                        result.Append(ch);
                        state = 21;
                    }
                    else
                    {
                        cUnread = c;
                        state = -1;
                    }
                    break;

                case 21: // floating point
                    if ('0' <= ch && ch <= '9')
                    {
                        result.Append(ch);
                    }
                    else
                    {
                        cUnread = c;
                        state = -1;
                    }
                    break;

                case 3: // keyword
                    if ('a' <= ch && ch <= 'z')
                    {
                        result.Append(ch);
                    }
                    else
                    {
                        cUnread = c;
                        state = -1;
                    }
                    break;

                case 4: // escape
                    if (ch == '\\')
                    {
                        result.Append(ch);
                    }
                    else if (ch == '\"')
                    {
                        result.Append('\"');
                    }
                    else if (ch == 'b')
                    {
                        result.Append('\b');
                    }
                    else if (ch == 'f')
                    {
                        result.Append('\f');
                    }
                    else if (ch == 'n')
                    {
                        result.Append('\n');
                    }
                    else if (ch == 'r')
                    {
                        result.Append('\r');
                    }
                    else if (ch == 't')
                    {
                        result.Append('\t');
                    }
                    else if (ch == 'u')
                    {
                        c = reader.Read();
                        if (c != -1)
                        {
                            char ch1 = (char)c;
                            c = reader.Read();
                            if (c != -1)
                            {
                                char ch2 = (char)c;
                                c = reader.Read();
                                if (c != -1)
                                {
                                    char ch3 = (char)c;
                                    c = reader.Read();
                                    if (c != -1)
                                    {
                                        char ch4 = (char)c;
                                        string s = "" + ch1 + ch2 + ch3 + ch4;
                                        result.Append(char.ConvertFromUtf32(Convert.ToInt32(s, 16)));
                                    }
                                }
                            }
                        }
                    }
                    else
                    {
                        result.Append("\\").Append(ch);
                    }
                    state = 1;
                    break;
            }
            if (state == -1) break;
            if (cUnread != -1)
            {
                c = cUnread;
                cUnread = -1;
            }
            else
            {
                c = reader.Read();
            }
        }
        if (result.Length > 0)
        {
            return result.ToString();
        }
        else
        {
            return null;
        }
    }

    public void MatchToken(string token)
    {
        string? nexttoken = NextToken();
        if (token != nexttoken)
        {
            throw new Exception("Expected " + token + " but got " + nexttoken);
        }
    }
}
