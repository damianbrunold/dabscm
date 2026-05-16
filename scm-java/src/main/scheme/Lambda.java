package scheme;

import java.util.List;

public class Lambda {
    public String name;
    public String doc;
    public Object env;
    public List<Instruction> code;

    public Lambda(Object env, List<Instruction> code) {
        this.env = env;
        this.code = code;
    }

    @Override
    public String toString() {
        return "#<" + (name == null ? "lambda" : name ) + ">";
    }
}
