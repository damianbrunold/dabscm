package scheme;

import java.io.File;

public class ModuleSource {
    private final String filePath;
    private final String content;
    private final String directory;
    private final String fileName;

    private ModuleSource(String filePath, String content, String directory, String fileName) {
        this.filePath = filePath;
        this.content = content;
        this.directory = directory;
        this.fileName = fileName;
    }

    public static ModuleSource fromFile(String filePath) {
        var dir = new File(filePath).getAbsoluteFile().getParent();
        return new ModuleSource(filePath, null, dir, filePath);
    }

    public static ModuleSource fromZip(String content, String zipPath, String entryName) {
        var dir = new File(zipPath).getAbsoluteFile().getParent();
        return new ModuleSource(null, content, dir, zipPath + "!/" + entryName);
    }

    public String getFilePath() { return filePath; }
    public String getContent() { return content; }
    public String getDirectory() { return directory; }
    public String getFileName() { return fileName; }
}
