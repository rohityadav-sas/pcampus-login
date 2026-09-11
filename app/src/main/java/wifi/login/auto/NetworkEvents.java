package wifi.login.auto;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.os.Build;

/** System-owned subscription survives ordinary app process death. */
final class NetworkEvents {
    static final String ACTION = "wifi.login.auto.WIFI_AVAILABLE";

    static void sync(Context context) {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        // ConnectivityManager must attach the Network and NetworkRequest extras.
        if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
        PendingIntent event = PendingIntent.getBroadcast(context, 40,
                new Intent(context, NetworkReceiver.class).setAction(ACTION), flags);
        try {
            if (AutoLogin.prefs(context).getBoolean("enabled", false)) {
                // Do not require VALIDATED or CAPTIVE_PORTAL: either would delay login.
                NetworkRequest request = new NetworkRequest.Builder()
                        .addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build();
                AutoLogin.cm(context).registerNetworkCallback(request, event);
            } else {
                AutoLogin.cm(context).unregisterNetworkCallback(event);
            }
        } catch (RuntimeException error) {
            AutoLogin.record(context, "Could not update Wi-Fi event registration: "
                    + error.getClass().getSimpleName());
        }
    }
}
