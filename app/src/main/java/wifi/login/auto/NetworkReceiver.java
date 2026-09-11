package wifi.login.auto;
import android.content.*;
import android.net.*;
import android.os.*;
import java.util.concurrent.atomic.AtomicBoolean;
public class NetworkReceiver extends BroadcastReceiver {
 private static final AtomicBoolean waiting=new AtomicBoolean();
 @Override public void onReceive(Context c,Intent i){
  if(!ConnectivityManager.CONNECTIVITY_ACTION.equals(i.getAction())&&!android.net.wifi.WifiManager.NETWORK_STATE_CHANGED_ACTION.equals(i.getAction()))return;
  if(!AutoLogin.prefs(c).getBoolean("enabled",false))return;
  Network n=AutoLogin.campusNetwork(c);
  android.util.Log.i("WifiAutoLogin","Network event: "+i.getAction()+" campusIp="+(n!=null));
  if(n!=null){PendingResult p=goAsync();new Thread(()->{try{AutoLogin.login(c,n,false);}finally{p.finish();}},"CampusLogin").start();return;}
  NetworkInfo info=i.getParcelableExtra(android.net.wifi.WifiManager.EXTRA_NETWORK_INFO);
  if(info!=null&&(info.getState()==NetworkInfo.State.DISCONNECTED||info.getState()==NetworkInfo.State.DISCONNECTING))return;
  if(!waiting.compareAndSet(false,true))return;
  PendingResult pending=goAsync();ConnectivityManager cm=AutoLogin.cm(c);Handler handler=new Handler(Looper.getMainLooper());AtomicBoolean finished=new AtomicBoolean();
  ConnectivityManager.NetworkCallback callback=new ConnectivityManager.NetworkCallback(){
   void check(Network network){if(!AutoLogin.campus(c,network)||!finished.compareAndSet(false,true))return;try{cm.unregisterNetworkCallback(this);}catch(Exception ignored){}waiting.set(false);android.util.Log.i("WifiAutoLogin","Campus IP arrived through temporary callback");new Thread(()->{try{AutoLogin.login(c,network,false);}finally{pending.finish();}},"CampusLogin").start();}
   @Override public void onAvailable(Network network){check(network);}
   @Override public void onLinkPropertiesChanged(Network network,LinkProperties lp){check(network);}
  };
  try{NetworkRequest request=new NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build();if(Build.VERSION.SDK_INT>=26)cm.registerNetworkCallback(request,callback,handler);else cm.registerNetworkCallback(request,callback);}
  catch(RuntimeException e){finished.set(true);waiting.set(false);pending.finish();return;}
  handler.postDelayed(()->{if(finished.compareAndSet(false,true)){try{cm.unregisterNetworkCallback(callback);}catch(Exception ignored){}waiting.set(false);pending.finish();}},8000);
 }
}
