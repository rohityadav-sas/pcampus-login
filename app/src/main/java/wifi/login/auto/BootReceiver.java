package wifi.login.auto;
import android.content.*;
public class BootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context c, Intent i) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(i.getAction()) && !Intent.ACTION_MY_PACKAGE_REPLACED.equals(i.getAction())) return;
        // Network IDs are reused after reboot; old retry limits must not survive it.
        android.content.SharedPreferences.Editor edit = AutoLogin.prefs(c).edit().remove("lastNetwork").remove("pin");
        for (String key : AutoLogin.prefs(c).getAll().keySet()) {
            if (key.startsWith("attempts_")) edit.remove(key);
        }
        edit.apply();
        NetworkEvents.sync(c);
    }
}

