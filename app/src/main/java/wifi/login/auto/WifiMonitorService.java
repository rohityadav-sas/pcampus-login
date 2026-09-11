package wifi.login.auto;
import android.app.*;import android.content.*;import android.net.*;import android.os.*;import android.content.pm.ServiceInfo;
public class WifiMonitorService extends Service {
 private ConnectivityManager.NetworkCallback callback;
 private final java.util.Set<Network> submitted=new java.util.HashSet<>();
 public void onCreate(){super.onCreate();Notification.Builder b;
 if(Build.VERSION.SDK_INT>=26){NotificationChannel channel=new NotificationChannel("monitor","Automatic login listener",NotificationManager.IMPORTANCE_LOW);getSystemService(NotificationManager.class).createNotificationChannel(channel);b=new Notification.Builder(this,"monitor");}else b=new Notification.Builder(this);
 b.setContentTitle("Automatic login enabled").setSmallIcon(android.R.drawable.stat_notify_sync).setOngoing(true).setPriority(Notification.PRIORITY_LOW).setContentIntent(PendingIntent.getActivity(this,32,new Intent(this,MainActivity.class).putExtra("settings",true),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE));
 if(Build.VERSION.SDK_INT>=29)startForeground(101,b.build(),ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE);else startForeground(101,b.build());}
 public int onStartCommand(Intent i,int flags,int id){if(!AutoLogin.prefs(this).getBoolean("enabled",false)){stopSelf();return START_NOT_STICKY;}if(callback==null){callback=new ConnectivityManager.NetworkCallback(){
 public void onAvailable(Network n){android.util.Log.i("WifiAutoLogin","FG Wi-Fi available: "+n);if(Build.VERSION.SDK_INT<26)check(n,AutoLogin.cm(WifiMonitorService.this).getLinkProperties(n));}
 public void onLinkPropertiesChanged(Network n,LinkProperties lp){check(n,lp);}
 public void onLost(Network n){submitted.remove(n);AutoLogin.prefs(WifiMonitorService.this).edit().remove("attempts_"+n).remove("lastNetwork").apply();}
 };AutoLogin.cm(this).registerNetworkCallback(new NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build(),callback);android.util.Log.i("WifiAutoLogin","FG listener registered");}return START_STICKY;}
 void check(Network n,LinkProperties lp){if(lp==null||submitted.contains(n))return;for(LinkAddress a:lp.getLinkAddresses()){byte[] ip=a.getAddress().getAddress();if(ip.length==4&&(ip[0]&255)==10&&(ip[1]&255)==100){submitted.add(n);android.util.Log.i("WifiAutoLogin","FG campus IP ready: "+n);new Thread(()->AutoLogin.login(getApplicationContext(),n,false),"CampusLogin").start();return;}}}
 public void onDestroy(){if(callback!=null)AutoLogin.cm(this).unregisterNetworkCallback(callback);stopForeground(true);super.onDestroy();}
 public IBinder onBind(Intent i){return null;}
}
