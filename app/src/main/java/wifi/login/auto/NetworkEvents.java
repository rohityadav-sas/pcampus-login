package wifi.login.auto;
import android.content.*;
import java.io.*;
import java.nio.charset.StandardCharsets;

final class NetworkEvents {
 static final String ACTION="wifi.login.auto.WIFI_AVAILABLE";
 static synchronized void sync(Context context){
  Context app=context.getApplicationContext();
  new Thread(()->configure(app),"RootListenerSetup").start();
 }
 private static synchronized void configure(Context c){
  try{
   String pkg=c.getPackageName();
   String dir="/data/local/tmp/"+pkg;
   String action="am broadcast --user 0 --include-stopped-packages -n "+pkg+"/wifi.login.auto.NetworkReceiver -a "+ACTION+" </dev/null >/dev/null 2>&1";
   // Netlink blocks until the kernel reports an address change; there is no timer.
   String script="#!/system/bin/sh\n"+
    "echo $$ > "+dir+"/pid\n"+
    "trap 'kill $monitor 2>/dev/null; rm -f "+dir+"/pid "+dir+"/events' EXIT\n"+
    "rm -f "+dir+"/events\nmkfifo "+dir+"/events\n"+
    "ip monitor address > "+dir+"/events &\nmonitor=$!\n"+
    action+"\n"+
    "while IFS= read -r event; do\n case \"$event\" in *wlan*) "+action+" ;; esac\ndone < "+dir+"/events\n";
   File source=new File(c.getFilesDir(),"root-listener.sh");
   try(FileOutputStream out=new FileOutputStream(source)){out.write(script.getBytes(StandardCharsets.UTF_8));}
   boolean enabled=AutoLogin.prefs(c).getBoolean("enabled",false);
   String command="mkdir -p "+dir+"; chmod 700 "+dir+"; "+
    "if [ -f "+dir+"/pid ]; then old=$(cat "+dir+"/pid); "+
    "if [ -r /proc/$old/cmdline ] && tr '\\0' ' ' < /proc/$old/cmdline | grep -q '"+dir+"/listener.sh'; then "+(enabled?"exit 0":"kill $old")+"; fi; fi; "+
    (enabled?"cp "+source.getAbsolutePath()+" "+dir+"/listener.sh; chmod 700 "+dir+"/listener.sh; nohup sh "+dir+"/listener.sh </dev/null >"+dir+"/log 2>&1 &":"");
   Process process=new ProcessBuilder("su","-c",command).redirectErrorStream(true).start();
   try(InputStream in=process.getInputStream()){while(in.read()!=-1){}}
   int result=process.waitFor();
   AutoLogin.record(c,result==0?(enabled?"Root Wi-Fi listener started":"Root Wi-Fi listener stopped"):"Root access denied; automatic login unavailable");
  }catch(Exception e){AutoLogin.record(c,"Root listener failed: "+e.getClass().getSimpleName());}
 }
}
