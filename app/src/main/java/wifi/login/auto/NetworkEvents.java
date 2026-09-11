package wifi.login.auto;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.net.NetworkCapabilities;
import android.net.ConnectivityManager;
import android.net.NetworkRequest;
import android.os.Build;

/** Live callback plus a one-shot wake-up subscription; no persistent service. */
final class NetworkEvents {
    static final String ACTION = "wifi.login.auto.WIFI_AVAILABLE";

    private static ConnectivityManager.NetworkCallback live;
    private static final java.util.Set<android.net.Network> submitted = java.util.Collections.newSetFromMap(new java.util.concurrent.ConcurrentHashMap<android.net.Network, Boolean>());

    static synchronized void sync(Context context) {
        attach(context);
        arm(context);
    }

    static synchronized void attach(Context context) {
        Context app = context.getApplicationContext();
        if (!AutoLogin.prefs(app).getBoolean("enabled", false)) {
            if (live != null) AutoLogin.cm(app).unregisterNetworkCallback(live);
            live = null;
            submitted.clear();
        } else if (live == null) {
            live = new ConnectivityManager.NetworkCallback() {
                @Override public void onAvailable(android.net.Network network) {
                    android.util.Log.i("WifiAutoLogin", "Live Wi-Fi event: " + network);
                    if (Build.VERSION.SDK_INT < 26) check(network, AutoLogin.cm(app).getLinkProperties(network));
                }
                @Override public void onLinkPropertiesChanged(android.net.Network network, android.net.LinkProperties properties) {
                    check(network, properties);
                }
                private void check(android.net.Network network, android.net.LinkProperties properties) {
                    if (properties == null || submitted.contains(network) || !AutoLogin.prefs(app).getBoolean("enabled", false)) return;
                    for (android.net.LinkAddress address : properties.getLinkAddresses()) {
                        byte[] ip = address.getAddress().getAddress();
                        if (ip.length == 4 && (ip[0] & 255) == 10 && (ip[1] & 255) == 100) {
                            submitted.add(network);
                            new Thread(() -> AutoLogin.login(app, network, false), "LiveCampusLogin").start();
                            return;
                        }
                    }
                }
                @Override public void onLost(android.net.Network network) {
                    submitted.remove(network);
                    android.content.SharedPreferences.Editor edit = AutoLogin.prefs(app).edit().remove("attempts_" + network);
                    if (network.toString().equals(AutoLogin.prefs(app).getString("lastNetwork", ""))) edit.remove("lastNetwork");
                    edit.apply();
                    arm(app);
                }
            };
            AutoLogin.cm(app).registerNetworkCallback(new NetworkRequest.Builder()
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build(), live);
        }
    }

    private static void arm(Context context) {
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

