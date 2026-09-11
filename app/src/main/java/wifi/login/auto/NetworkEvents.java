package wifi.login.auto;
import android.content.*;import android.os.Build;
final class NetworkEvents {
 static final String ACTION="wifi.login.auto.WIFI_AVAILABLE";
 static void sync(Context c){Intent i=new Intent(c,WifiMonitorService.class);if(!AutoLogin.prefs(c).getBoolean("enabled",false)){c.stopService(i);return;}try{if(Build.VERSION.SDK_INT>=26)c.startForegroundService(i);else c.startService(i);}catch(RuntimeException e){AutoLogin.record(c,"Listener failed: "+e.getClass().getSimpleName());}}
}
