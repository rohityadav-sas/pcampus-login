package wifi.login;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ObjectAnimator;
import android.app.Activity;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserFactory;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.StringReader;
import java.net.URL;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

public class MainActivity extends Activity {
    private TextView tv;
    private ImageView retryBtn;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);

        FrameLayout root = new FrameLayout(this);
        
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        container.setGravity(Gravity.CENTER);
        
        tv = new TextView(this);
        tv.setText("Connecting...");
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 25);
        tv.setGravity(Gravity.CENTER);
        int pad = (int) (16 * getResources().getDisplayMetrics().density);
        tv.setPadding(pad, pad, pad, pad);
        
        retryBtn = new ImageView(this);
        retryBtn.setImageResource(R.drawable.ic_retry);
        retryBtn.setVisibility(View.GONE);
        retryBtn.setPadding(pad, pad, pad, pad);
        
        retryBtn.setClickable(true);
        retryBtn.setFocusable(true);

        retryBtn.setOnClickListener(v -> {
            // Spin 360 deg
            ObjectAnimator spin = ObjectAnimator.ofFloat(retryBtn, "rotation", 0f, 360f);
            spin.setDuration(300);
            spin.addListener(new AnimatorListenerAdapter() {
                @Override
                public void onAnimationEnd(Animator animation) {
                    retryBtn.setVisibility(View.GONE);
                    retryBtn.setRotation(0f); // Reset for next time
                    performLogin();
                }
            });
            spin.start();
        });

        container.addView(tv);
        container.addView(retryBtn);
        
        root.addView(container, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 
                ViewGroup.LayoutParams.MATCH_PARENT, 
                Gravity.CENTER));
        
        setContentView(root);

        performLogin();
    }

    private void performLogin() {
        tv.setText("Connecting...");
        new Thread(() -> {
            String result;
            try {
                URL url = new URL("https://10.100.1.1:8090/login.xml");
                HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();

                // --- INSECURE: trust all certs + disable hostname verification (testing only) ---
                SSLContext sc = SSLContext.getInstance("TLS");
                sc.init(null, new TrustManager[]{new X509TrustManager() {
                    @Override public void checkClientTrusted(X509Certificate[] chain, String authType) { }
                    @Override public void checkServerTrusted(X509Certificate[] chain, String authType) { }
                    @Override public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
                }}, new SecureRandom());
                conn.setSSLSocketFactory(sc.getSocketFactory());
                conn.setHostnameVerifier(new HostnameVerifier() {
                    @Override public boolean verify(String hostname, SSLSession session) { return true; }
                });
                // ------------------------------------------------------------------------------

                conn.setRequestMethod("POST");
                conn.setDoOutput(true);
                conn.setConnectTimeout(10000);
                conn.setReadTimeout(10000);
                conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");

                String payload = "mode=191&username=rakesh&password=rakesh&a=1768662579596&producttype=0";
                byte[] data = payload.getBytes("UTF-8");
                conn.setFixedLengthStreamingMode(data.length);

                OutputStream os = conn.getOutputStream();
                os.write(data);
                os.flush();
                os.close();

                int code = conn.getResponseCode();
                InputStream is = (code >= 200 && code < 400) ? conn.getInputStream() : conn.getErrorStream();

                BufferedReader br = new BufferedReader(new InputStreamReader(is, "UTF-8"));
                StringBuilder bodySb = new StringBuilder();
                String line;
                while ((line = br.readLine()) != null) bodySb.append(line).append('\n');
                br.close();
                conn.disconnect();

                String body = bodySb.toString();
                String msg = parseFirstTagText(body, "message");
                boolean ok = (code >= 200 && code < 400) && isLoginSuccessful(msg);

                if (ok) {
                    result = "Login successful";
                    finish();
                    return;
                } else if (msg != null && msg.length() > 0) {
                    result = msg;
                } else {
                    result = "HTTP " + code + "\n\n" + body;
                }

            } catch (Exception e) {
                result = (e instanceof java.net.SocketTimeoutException) ? "Request timeout" : e.toString();
            }

            final String show = result;
            runOnUiThread(() -> {
                tv.setText(show);
                retryBtn.setVisibility(View.VISIBLE);
            });
        }).start();
    }

    private static boolean isLoginSuccessful(String message) {
        if (message == null) return false;
        String m = message.toLowerCase();
        return m.contains("success") || m.contains("signed in");
    }

    private static String parseFirstTagText(String xml, String tagName) throws Exception {
        XmlPullParserFactory factory = XmlPullParserFactory.newInstance();
        factory.setNamespaceAware(false);
        XmlPullParser parser = factory.newPullParser();
        parser.setInput(new StringReader(xml));

        int event = parser.getEventType();
        while (event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.START_TAG && tagName.equals(parser.getName())) {
                return parser.nextText(); // handles CDATA too
            }
            event = parser.next();
        }
        return null;
    }
}
