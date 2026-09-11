package wifi.login.auto;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;

final class LoginNotifications {
    private static final int ID = 100;
    private static final String CHANNEL = "login_alerts";
    private static final Handler handler = new Handler(Looper.getMainLooper());
    private static String owner;
    private static long revision;

    private static Notification.Builder builder(Context context) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(CHANNEL, "Login results", NotificationManager.IMPORTANCE_HIGH);
            channel.enableVibration(true);
            manager.createNotificationChannel(channel);
            builder = new Notification.Builder(context, CHANNEL);
        } else {
            builder = new Notification.Builder(context);
        }
        PendingIntent settings = PendingIntent.getActivity(context, 30,
                new Intent(context, MainActivity.class).putExtra("settings", true),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        return builder.setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentIntent(settings).setDefaults(Notification.DEFAULT_ALL)
                .setPriority(Notification.PRIORITY_HIGH).setOnlyAlertOnce(false);
    }

    private static void publish(Context context, Notification.Builder builder, long timeout) {
        long current = ++revision;
        if (Build.VERSION.SDK_INT >= 26 && timeout > 0) builder.setTimeoutAfter(timeout);
        context.getSystemService(NotificationManager.class).notify(ID, builder.build());
        if (Build.VERSION.SDK_INT < 26 && timeout > 0) {
            Context app = context.getApplicationContext();
            handler.postDelayed(() -> { synchronized (LoginNotifications.class) {
                if (revision == current) clear(app);
            } }, timeout);
        }
    }

    static synchronized void starting(Context context, String network) {
        owner = network;
        publish(context, builder(context).setContentTitle("Signing in to campus Wi-Fi…"), 30000);
    }

    static synchronized void show(Context context, String network, boolean success) {
        if (!network.equals(owner)) return;
        owner = null;
        Notification.Builder builder = builder(context)
                .setContentTitle(success ? "Campus Wi-Fi signed in" : "Campus Wi-Fi login failed")
                .setContentText(success ? "Automatic login successful" : "Tap Retry to sign in again")
                .setAutoCancel(true);
        if (!success) {
            PendingIntent retry = PendingIntent.getActivity(context, 31,
                    new Intent(context, MainActivity.class).putExtra("retry", true),
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            builder.addAction(new Notification.Action.Builder(android.R.drawable.ic_popup_sync, "Retry", retry).build());
        }
        publish(context, builder, success ? 5000 : 0);
    }

    static synchronized void clear(Context context) {
        owner = null;
        revision++;
        context.getSystemService(NotificationManager.class).cancel(ID);
    }
}
