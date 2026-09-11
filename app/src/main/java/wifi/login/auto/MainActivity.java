package wifi.login.auto;
import android.app.Activity;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.widget.*;
public class MainActivity extends Activity {
 @Override public void setContentView(android.view.View content){
 getWindow().setStatusBarColor(0xff172a35);getWindow().setNavigationBarColor(0xff172a35);getWindow().getDecorView().setSystemUiVisibility(0);
 if(android.os.Build.VERSION.SDK_INT>=30){
 getWindow().setDecorFitsSystemWindows(false);
 android.widget.FrameLayout safe=new android.widget.FrameLayout(this);
 safe.setBackgroundColor(0xff172a35);
 content.setBackgroundColor(0xfffafcfc);
 safe.addView(content,new android.widget.FrameLayout.LayoutParams(-1,-1));
 safe.setOnApplyWindowInsetsListener((v,insets)->{
 android.graphics.Insets bars=insets.getInsets(android.view.WindowInsets.Type.systemBars()|android.view.WindowInsets.Type.displayCutout()|android.view.WindowInsets.Type.ime());
 v.setPadding(bars.left,bars.top,bars.right,bars.bottom);
 return android.view.WindowInsets.CONSUMED;
 });
 super.setContentView(safe);safe.requestApplyInsets();
 }else{super.setContentView(content);}
 }
 boolean busy, showingError;
 int dp(int n){return (int)(n*getResources().getDisplayMetrics().density);}
 public void onCreate(Bundle b){super.onCreate(b); if(android.os.Build.VERSION.SDK_INT>=25){new Thread(()->{android.content.pm.ShortcutManager shortcuts=getSystemService(android.content.pm.ShortcutManager.class); shortcuts.setDynamicShortcuts(java.util.Collections.singletonList(new android.content.pm.ShortcutInfo.Builder(this,"settings").setShortLabel("Settings").setIcon(android.graphics.drawable.Icon.createWithResource(this,android.R.drawable.ic_menu_preferences)).setIntent(new android.content.Intent(this,MainActivity.class).setAction(android.content.Intent.ACTION_VIEW).putExtra("settings",true)).build()));},"LauncherShortcut").start();}if(!AutoLogin.prefs(this).getString("username","").isEmpty()&&!getIntent().getBooleanExtra("settings",false)&&(!AutoLogin.prefs(this).getBoolean("enabled",false)||getIntent().getBooleanExtra("retry",false)))login();else settings();}
 @Override protected void onNewIntent(android.content.Intent i){super.onNewIntent(i);setIntent(i);if(i.getBooleanExtra("retry",false))login();else if(i.getBooleanExtra("settings",false))settings();}
 final int ink=0xff172a35, muted=0xff657782, accent=0xff167568;
 TextView label(String text,int size,int color){TextView v=new TextView(this);v.setText(text);v.setTextSize(size);v.setTextColor(color);return v;}
 android.graphics.drawable.GradientDrawable surface(int color,int radius){android.graphics.drawable.GradientDrawable d=new android.graphics.drawable.GradientDrawable();d.setColor(color);d.setCornerRadius(dp(radius));return d;}
 LinearLayout.LayoutParams row(int height,int top){LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,height<0?height:dp(height));p.topMargin=dp(top);return p;}
 EditText field(String value,String hint,boolean password){EditText e=new EditText(this);e.setSingleLine(true);e.setTextSize(17);e.setTextColor(ink);e.setHintTextColor(muted);e.setHint(hint);e.setInputType(password?(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_PASSWORD):android.text.InputType.TYPE_CLASS_TEXT|android.text.InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);e.setText(value);e.setPadding(dp(16),0,dp(16),0);e.setBackground(surface(0xffedf2f3,12));return e;}
 void settings(){showingError=false;
 getWindow().setStatusBarColor(0xff172a35);getWindow().setNavigationBarColor(0xff172a35);
 getWindow().getDecorView().setSystemUiVisibility(0);
 getWindow().setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE|android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN);
 ScrollView scroll=new ScrollView(this);scroll.setFillViewport(true);scroll.setBackgroundColor(0xfffafcfc);
 LinearLayout box=new LinearLayout(this);box.setOrientation(LinearLayout.VERTICAL);box.setFocusableInTouchMode(true);box.setFocusable(true);box.setGravity(Gravity.CENTER_VERTICAL);box.setPadding(dp(28),dp(24),dp(28),dp(24));scroll.addView(box);
 TextView title=label("Campus Wi-Fi",28,ink);title.setTypeface(android.graphics.Typeface.DEFAULT,android.graphics.Typeface.BOLD);box.addView(title);
 box.addView(label("Username",13,muted),row(-2,32));
 EditText user=field(AutoLogin.prefs(this).getString("username",""),"Enter username",false);user.setImeOptions(android.view.inputmethod.EditorInfo.IME_ACTION_NEXT);box.addView(user,row(56,8));
 box.addView(label("Password",13,muted),row(-2,20));
 EditText pass=field(AutoLogin.prefs(this).getString("password",""),"Enter password",true);pass.setImeOptions(android.view.inputmethod.EditorInfo.IME_ACTION_DONE);box.addView(pass,row(56,8));
 LinearLayout modeRow=new LinearLayout(this);modeRow.setGravity(Gravity.CENTER_VERTICAL);modeRow.setPadding(0,dp(12),0,dp(12));
 LinearLayout words=new LinearLayout(this);words.setOrientation(LinearLayout.VERTICAL);TextView modeTitle=label("Automatic login",17,ink);words.addView(modeTitle);TextView detail=label("",13,muted);words.addView(detail,row(-2,4));modeRow.addView(words,new LinearLayout.LayoutParams(0,-2,1));
 Switch mode=new Switch(this);mode.setContentDescription("Automatic login");mode.setChecked(AutoLogin.prefs(this).getBoolean("enabled",false));
 mode.setThumbTintList(new android.content.res.ColorStateList(new int[][]{new int[]{android.R.attr.state_checked},new int[]{}},new int[]{accent,0xff89969c}));
 detail.setText(mode.isChecked()?"Sign in when Wi-Fi connects":"Open the app to sign in");modeTitle.setText(mode.isChecked()?"Automatic login":"One-tap login");
 mode.setOnCheckedChangeListener((v,on)->{modeTitle.setText(on?"Automatic login":"One-tap login");detail.setText(on?"Sign in when Wi-Fi connects":"Open the app to sign in");});modeRow.addView(mode);box.addView(modeRow,row(-2,24));
 Button save=new Button(this);save.setText("Save");save.setAllCaps(false);save.setTextSize(16);save.setTextColor(0xffffffff);save.setBackgroundTintList(android.content.res.ColorStateList.valueOf(accent));box.addView(save,row(56,16));
 Button signIn=new Button(this);signIn.setText("Login");signIn.setAllCaps(false);signIn.setTextSize(16);signIn.setTextColor(accent);signIn.setBackgroundTintList(android.content.res.ColorStateList.valueOf(0xffedf2f3));box.addView(signIn,row(56,8));setContentView(scroll);box.requestFocus();
 save.setOnClickListener(v->{if(user.getText().toString().trim().isEmpty()){user.setError("Enter username");user.requestFocus();return;}if(pass.length()==0){pass.setError("Enter password");pass.requestFocus();return;}AutoLogin.prefs(this).edit().putString("username",user.getText().toString().trim()).putString("password",pass.getText().toString()).putBoolean("enabled",mode.isChecked()).remove("lastNetwork").apply();((android.view.inputmethod.InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(pass.getWindowToken(),0);if(!mode.isChecked())login();else Toast.makeText(this,"Saved",Toast.LENGTH_SHORT).show();});
 signIn.setOnClickListener(v->{if(user.getText().toString().trim().isEmpty()){user.setError("Enter username");user.requestFocus();return;}if(pass.length()==0){pass.setError("Enter password");pass.requestFocus();return;}AutoLogin.prefs(this).edit().putString("username",user.getText().toString().trim()).putString("password",pass.getText().toString()).putBoolean("enabled",mode.isChecked()).remove("lastNetwork").apply();((android.view.inputmethod.InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(pass.getWindowToken(),0);login();});
 pass.setOnEditorActionListener((v,action,event)->{if(action==android.view.inputmethod.EditorInfo.IME_ACTION_DONE){save.performClick();return true;}return false;});
 }
 Button actionButton(String text,boolean primary){Button b=new Button(this);b.setText(text);b.setAllCaps(false);b.setTextSize(16);b.setTextColor(primary?0xffffffff:accent);b.setBackgroundTintList(android.content.res.ColorStateList.valueOf(primary?accent:0xffedf2f3));return b;}
 void loginError(){
 showingError=true;
 ScrollView scroll=new ScrollView(this);scroll.setFillViewport(true);
 LinearLayout box=new LinearLayout(this);box.setOrientation(LinearLayout.VERTICAL);box.setGravity(Gravity.CENTER_VERTICAL);box.setPadding(dp(28),dp(24),dp(28),dp(24));scroll.addView(box);
 TextView symbol=label("!",30,0xffac3434);symbol.setGravity(Gravity.CENTER);symbol.setTypeface(android.graphics.Typeface.DEFAULT,android.graphics.Typeface.BOLD);symbol.setBackground(surface(0xfffaeaea,28));symbol.setImportantForAccessibility(android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO);LinearLayout.LayoutParams badge=new LinearLayout.LayoutParams(dp(56),dp(56));badge.gravity=Gravity.CENTER_HORIZONTAL;box.addView(symbol,badge);
 TextView title=label("Couldn't sign in",26,ink);title.setGravity(Gravity.CENTER);title.setTypeface(android.graphics.Typeface.DEFAULT,android.graphics.Typeface.BOLD);box.addView(title,row(-2,20));
 TextView message=label("Check your campus Wi-Fi connection and try again.",15,muted);message.setGravity(Gravity.CENTER);message.setLineSpacing(dp(3),1);box.addView(message,row(-2,10));
 Button retry=actionButton("Retry",true);retry.setOnClickListener(v->login());box.addView(retry,row(56,28));
 Button back=actionButton("Back",false);back.setOnClickListener(v->settings());box.addView(back,row(56,8));
 setContentView(scroll);
 }
 @Override public void onBackPressed(){if(showingError){settings();return;}super.onBackPressed();}
 void login(){if(busy)return;showingError=false;busy=true;TextView status=label("Connecting…",25,ink);status.setGravity(Gravity.CENTER);setContentView(status);
 new Thread(()->{boolean ok=AutoLogin.login(this,AutoLogin.campusNetwork(this),true);runOnUiThread(()->{busy=false;if(isFinishing()||isDestroyed())return;if(ok){finishAndRemoveTask();overridePendingTransition(0,0);}else loginError();});},"OneTapLogin").start();}
}


