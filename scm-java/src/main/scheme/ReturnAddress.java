package scheme;

public class ReturnAddress {

    public int ip;
    public Lambda fn;
    public Object env;

    public ReturnAddress(int ip, Lambda fn, Object env) {
        this.ip = ip;
        this.fn = fn;
        this.env = env;
    }

    @Override
    public String toString() {
        return "#<RETADDR:" + ip + ">";
    }
}
