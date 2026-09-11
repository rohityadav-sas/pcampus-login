package wifi.login.auto;
import android.content.*;
public class BootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context c, Intent i) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(i.getAction()) && !Intent.ACTION_MY_PACKAGE_REPLACED.equals(i.getAction())) return;
        AutoLogin.prefs(c).edit().remove("lastNetwork").apply();
    }
}

