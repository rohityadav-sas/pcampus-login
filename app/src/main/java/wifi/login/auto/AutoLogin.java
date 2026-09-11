package wifi.login.auto;

import android.content.*;
import android.net.*;
import android.util.Log;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.cert.*;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.*;
import javax.net.ssl.*;

final class AutoLogin {
    static final String URL_STRING = "https://10.100.1.1:8090/login.xml";
    static SharedPreferences prefs(Context c) { return c.getSharedPreferences("settings", 0); }
    static ConnectivityManager cm(Context c) { return c.getSystemService(ConnectivityManager.class); }
    static void disable(Context c) {
        prefs(c).edit().putBoolean("enabled", false).apply();
        NetworkEvents.sync(c);
    }
    static Network campusNetwork(Context c) {
        for (Network n : cm(c).getAllNetworks()) if (campus(c, n)) return n;
        return null;
    }
    static boolean campus(Context c, Network n) {
        if (n == null) return false;
        NetworkCapabilities caps = cm(c).getNetworkCapabilities(n);
        LinkProperties lp = cm(c).getLinkProperties(n);
        if (caps == null || !caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) || lp == null) return false;
        for (LinkAddress a : lp.getLinkAddresses()) {
            byte[] ip = a.getAddress().getAddress();
            if (ip.length == 4 && (ip[0] & 255) == 10 && (ip[1] & 255) == 100) return true;
        }
        return false;
    }
    // Verification is deliberately disabled for this fixed campus endpoint.
    // HTTPS still encrypts traffic, but does not authenticate the server.
    @android.annotation.SuppressLint("CustomX509TrustManager")
    static HttpsURLConnection connection(Network n) throws Exception {
        SSLContext tls = SSLContext.getInstance("TLS");
        tls.init(null, new TrustManager[]{new X509TrustManager() {
            public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
            public void checkClientTrusted(X509Certificate[] chain, String auth) throws CertificateException { throw new CertificateException(); }
            @android.annotation.SuppressLint("TrustAllX509TrustManager")
            public void checkServerTrusted(X509Certificate[] chain, String auth) { }
        }}, new SecureRandom());
        HttpsURLConnection con = (HttpsURLConnection)n.openConnection(new URL(URL_STRING));
        con.setSSLSocketFactory(tls.getSocketFactory());
        con.setHostnameVerifier((host, session) -> "10.100.1.1".equals(host));
        con.setInstanceFollowRedirects(false);
        con.setConnectTimeout(6000); con.setReadTimeout(6000);
        return con;
    }
    static synchronized void record(Context c, String status) {
        String line = new SimpleDateFormat("HH:mm:ss", Locale.US).format(new Date()) + "  " + status;
        String old = prefs(c).getString("history", "");
        String all = line + "\n" + old;
        if (all.length() > 2400) all = all.substring(0, 2400);
        prefs(c).edit().putString("history", all).apply();
        Log.i("WifiAutoLogin", status);
    }
    private static final java.util.Set<String> active = new java.util.HashSet<>();
    static boolean login(Context c, Network n, boolean manual) {
        if ((!manual && !prefs(c).getBoolean("enabled", false)) || !campus(c,n)) return false;
        String id=n.toString();
        synchronized(AutoLogin.class) {
            if(active.contains(id)) return false;
            if(!manual && id.equals(prefs(c).getString("lastNetwork", ""))) return false;
            if(!manual && prefs(c).getInt("attempts_"+id,0)>=2) return false;
            active.add(id);
        }
        try {
            // Send immediately on a campus IP, regardless of Android validation state.
            if(!manual)LoginNotifications.starting(c,id);
            boolean success=false;
            for(int i=0;i<(manual?1:2);i++) {
                if(!campus(c,n)) break;
                if(!manual) prefs(c).edit().putInt("attempts_"+id,prefs(c).getInt("attempts_"+id,0)+1).apply();
                long began=android.os.SystemClock.elapsedRealtime();
                success=attempt(c,n);
                record(c,"Request finished in "+(android.os.SystemClock.elapsedRealtime()-began)+" ms");
                if(success)break;
                if(!manual && i==0)try{Thread.sleep(400);}catch(InterruptedException e){Thread.currentThread().interrupt();break;}
            }
            if(success) prefs(c).edit().putString("lastNetwork",id).apply();
            if(!manual)LoginNotifications.show(c,id,success);else if(success)LoginNotifications.clear(c);
            return success;
        } finally { synchronized(AutoLogin.class){active.remove(id);} }
    }
    static boolean attempt(Context c, Network n) {
        record(c,"Signing in");
        HttpsURLConnection con = null;
        ScheduledExecutorService deadline = Executors.newSingleThreadScheduledExecutor();
        try {
            con = connection(n);
            final HttpsURLConnection active = con;
            deadline.schedule(active::disconnect, 8, TimeUnit.SECONDS);
            String body = "mode=191&username=" + URLEncoder.encode(prefs(c).getString("username", ""), "UTF-8")
                    + "&password=" + URLEncoder.encode(prefs(c).getString("password", ""), "UTF-8")
                    + "&a=1768662579596&producttype=0";
            byte[] data = body.getBytes(StandardCharsets.UTF_8);
            con.setRequestMethod("POST"); con.setDoOutput(true);
            con.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
            con.setFixedLengthStreamingMode(data.length);
            try (OutputStream out = con.getOutputStream()) { out.write(data); }
            int code = con.getResponseCode();
            if (code != 200) throw new IOException("Portal returned HTTP " + code);
            StringBuilder response = new StringBuilder();
            try (Reader reader = new InputStreamReader(con.getInputStream(), StandardCharsets.UTF_8)) {
                char[] buf = new char[512]; int count;
                while ((count = reader.read(buf)) != -1) {
                    response.append(buf, 0, count);
                    if (response.length() > 16384) throw new IOException("Unexpected portal response");
                }
            }
            org.xmlpull.v1.XmlPullParser parser = org.xmlpull.v1.XmlPullParserFactory.newInstance().newPullParser();
            parser.setInput(new StringReader(response.toString()));
            String message = "";
            for (int event=parser.getEventType(); event != org.xmlpull.v1.XmlPullParser.END_DOCUMENT; event=parser.next()) {
                if (event == org.xmlpull.v1.XmlPullParser.START_TAG && "message".equals(parser.getName())) { message=parser.nextText().toLowerCase(Locale.ROOT); break; }
            }
            if ((message.contains("success") && !message.contains("unsuccess")) || message.contains("signed in") || message.contains("already logged")) {
                record(c, "Login successful");
                cm(c).reportNetworkConnectivity(n, true);  return true;
            } else record(c, "Portal did not confirm login. Open the app to retry.");
        } catch (Exception e) {
            record(c, "Login failed (" + e.getClass().getSimpleName() + "). Tap Log in now to retry.");
        } finally {
            if (con != null) con.disconnect();
            deadline.shutdownNow();
        }

        return false;
    }
}
