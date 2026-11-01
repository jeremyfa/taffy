package;

/**
 * Minimal file system access for the test runner (Node.js or sys targets)
 */
class FileIO {

    public static function readFile(path:String):String {
        #if js
        return js.Syntax.code("require('fs').readFileSync({0}, 'utf8')", path);
        #else
        return sys.io.File.getContent(path);
        #end
    }

    public static function exists(path:String):Bool {
        #if js
        return js.Syntax.code("require('fs').existsSync({0})", path);
        #else
        return sys.FileSystem.exists(path);
        #end
    }

    public static function readDirectory(path:String):Array<String> {
        #if js
        final list:Array<String> = js.Syntax.code("require('fs').readdirSync({0})", path);
        list.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return list;
        #else
        final list = sys.FileSystem.readDirectory(path);
        list.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return list;
        #end
    }

    public static function writeFile(path:String, content:String):Void {
        #if js
        js.Syntax.code("require('fs').writeFileSync({0}, {1})", path, content);
        #else
        sys.io.File.saveContent(path, content);
        #end
    }

    public static function args():Array<String> {
        #if js
        final argv:Array<String> = js.Syntax.code("process.argv.slice(2)");
        return argv;
        #else
        return Sys.args();
        #end
    }

    public static function env(name:String):Null<String> {
        #if js
        return js.Syntax.code("process.env[{0}]", name);
        #else
        return Sys.getEnv(name);
        #end
    }

    public static function println(s:String):Void {
        #if js
        js.Syntax.code("console.log({0})", s);
        #else
        Sys.println(s);
        #end
    }

    public static function exit(code:Int):Void {
        #if js
        js.Syntax.code("process.exit({0})", code);
        #else
        Sys.exit(code);
        #end
    }

}
