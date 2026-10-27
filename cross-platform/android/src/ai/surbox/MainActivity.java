package ai.surbox;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowInsets;
import android.widget.*;
import java.util.Set;

public final class MainActivity extends Activity {
    public final Instrument state=new Instrument();
    public HarmoniumAudio audio;
    public HarmoniumView instrument;
    public boolean foreground=false,hasAudioFocus=false;
    private TextView status,range;
    private AudioManager manager;
    private AudioFocusRequest focus;
    private SharedPreferences prefs;
    private BroadcastReceiver noisy;
    private boolean ready=false;
    static final int[] CODES={KeyEvent.KEYCODE_A,KeyEvent.KEYCODE_W,KeyEvent.KEYCODE_S,KeyEvent.KEYCODE_E,KeyEvent.KEYCODE_D,KeyEvent.KEYCODE_F,KeyEvent.KEYCODE_T,KeyEvent.KEYCODE_G,KeyEvent.KEYCODE_Y,KeyEvent.KEYCODE_H,KeyEvent.KEYCODE_U,KeyEvent.KEYCODE_J,KeyEvent.KEYCODE_K,KeyEvent.KEYCODE_O,KeyEvent.KEYCODE_L,KeyEvent.KEYCODE_P,KeyEvent.KEYCODE_SEMICOLON,KeyEvent.KEYCODE_APOSTROPHE};
    @Override public void onCreate(Bundle saved){
        super.onCreate(saved);prefs=getSharedPreferences("instrument",MODE_PRIVATE);
        state.volume=Math.max(0,Math.min(1,prefs.getFloat("volume",.48f)));state.minimumAir=Math.max(0,Math.min(.5,prefs.getFloat("minimum",.2f)));state.sensitivity=Math.max(.2,Math.min(3,prefs.getFloat("sensitivity",1.25f)));state.octave=Math.max(2,Math.min(5,prefs.getInt("octave",3)));state.tonic=Math.floorMod(prefs.getInt("tonic",0),12);state.scale=Math.max(0,Math.min(3,prefs.getInt("scale",0)));
        manager=(AudioManager)getSystemService(AUDIO_SERVICE);
        focus=new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()).setOnAudioFocusChangeListener(change->{hasAudioFocus=change==AudioManager.AUDIOFOCUS_GAIN;if(!hasAudioFocus)panic();}).build();
        LinearLayout root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setBackgroundColor(Color.rgb(17,21,19));
        root.setOnApplyWindowInsetsListener((v,insets)->{if(android.os.Build.VERSION.SDK_INT>=30){android.graphics.Insets bars=insets.getInsets(WindowInsets.Type.systemBars()|WindowInsets.Type.displayCutout());v.setPadding(bars.left,bars.top,bars.right,bars.bottom);}else v.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());return insets;});
        LinearLayout header=new LinearLayout(this);header.setGravity(android.view.Gravity.CENTER_VERTICAL);header.setPadding(dp(14),dp(6),dp(10),dp(3));
        TextView title=label("SURBOX",17);title.setLetterSpacing(.15f);header.addView(title,new LinearLayout.LayoutParams(0,dp(42),1));
        Button settings=button("Settings",v->settings());header.addView(settings);
        Button stop=button("Stop",v->panic());stop.setContentDescription("Release all notes and drones");header.addView(stop);root.addView(header);
        LinearLayout toolbar=new LinearLayout(this);toolbar.setPadding(dp(10),0,dp(10),0);toolbar.setGravity(android.view.Gravity.CENTER_VERTICAL);
        Button down=button("−",v->{state.octave(-1);syncNotes();updateRange();});down.setContentDescription("Lower octave");toolbar.addView(down,new LinearLayout.LayoutParams(dp(42),dp(42)));
        range=label("",12);range.setGravity(android.view.Gravity.CENTER);toolbar.addView(range,new LinearLayout.LayoutParams(dp(73),dp(42)));
        Button up=button("+",v->{state.octave(1);syncNotes();updateRange();});up.setContentDescription("Higher octave");toolbar.addView(up,new LinearLayout.LayoutParams(dp(42),dp(42)));
        TextView vol=label("Vol",11);toolbar.addView(vol);SeekBar volume=new SeekBar(this);volume.setMax(100);volume.setProgress((int)(state.volume*100));volume.setContentDescription("Master volume");volume.setOnSeekBarChangeListener(seek(value->{state.volume=value/100.0;}));toolbar.addView(volume,new LinearLayout.LayoutParams(0,dp(40),1));root.addView(toolbar);
        status=label("Loading acoustic recordings…",10);status.setPadding(dp(16),0,dp(16),dp(6));
        audio=new HarmoniumAudio(getAssets(),(text,failed)->runOnUiThread(()->{status.setText(text);ready=!failed;}));
        instrument=new HarmoniumView(this,state);root.addView(instrument,new LinearLayout.LayoutParams(-1,0,1));root.addView(status,new LinearLayout.LayoutParams(-1,dp(34)));setContentView(root);updateRange();audio.start();
        noisy=new BroadcastReceiver(){public void onReceive(Context c,Intent i){panic();}};registerReceiver(noisy,new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY));
    }
    private int dp(int n){return (int)(n*getResources().getDisplayMetrics().density+.5f);}
    private TextView label(String text,int size){TextView v=new TextView(this);v.setText(text);v.setTextColor(Color.rgb(212,223,212));v.setTextSize(size);v.setGravity(android.view.Gravity.CENTER_VERTICAL);return v;}
    private Button button(String text,View.OnClickListener click){Button b=new Button(this);b.setText(text);b.setAllCaps(false);b.setTextSize(12);b.setMinWidth(0);b.setMinimumWidth(0);b.setPadding(dp(10),0,dp(10),0);b.setOnClickListener(click);return b;}
    private interface Value{void set(int value);}
    private SeekBar.OnSeekBarChangeListener seek(Value value){return new SeekBar.OnSeekBarChangeListener(){public void onProgressChanged(SeekBar b,int p,boolean user){if(user)value.set(p);}public void onStartTrackingTouch(SeekBar b){}public void onStopTrackingTouch(SeekBar b){save();}};}
    private void updateRange(){range.setText("C"+state.octave+" – C"+(state.octave+3));save();}
    public void syncNotes(){Set<Integer> notes=state.notes();for(int i=0;i<128;i++)audio.mixer.note(i,notes.contains(i));}
    public void panic(){state.clear();if(instrument!=null)instrument.cancel();if(audio!=null)audio.mixer.panic();}
    private void save(){prefs.edit().putFloat("volume",(float)state.volume).putFloat("minimum",(float)state.minimumAir).putFloat("sensitivity",(float)state.sensitivity).putInt("octave",state.octave).putInt("tonic",state.tonic).putInt("scale",state.scale).apply();}
    private void settings(){
        panic();LinearLayout panel=new LinearLayout(this);panel.setOrientation(LinearLayout.VERTICAL);panel.setPadding(dp(24),dp(8),dp(24),dp(10));
        TextView detail=label("Touch bellows and keys with separate fingers for chords. Physical laptop-lid control is not available on Android.",12);panel.addView(detail);
        addSlider(panel,"Minimum airflow",(int)(state.minimumAir*100),50,p->{state.minimumAir=p/100.0;});addSlider(panel,"Pumping sensitivity",(int)(state.sensitivity*100),300,p->{state.sensitivity=Math.max(.2,p/100.0);});
        panel.addView(label("Sa / tonic",12));Spinner tonic=new Spinner(this);tonic.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,Instrument.WESTERN));tonic.setSelection(state.tonic);tonic.setOnItemSelectedListener(select(p->{state.tonic=p;state.drones();syncNotes();save();}));panel.addView(tonic);
        panel.addView(label("Practice guide (never blocks notes)",12));Spinner scales=new Spinner(this);scales.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"Free play","Bilawal","Kafi","Bhairav"}));scales.setSelection(state.scale);scales.setOnItemSelectedListener(select(p->{state.scale=p;save();}));panel.addView(scales);
        Switch sa=new Switch(this);sa.setText("Sa drone");sa.setOnCheckedChangeListener((b,on)->{state.droneSa=on;state.drones();syncNotes();});panel.addView(sa);
        Switch pa=new Switch(this);pa.setText("Pa drone");pa.setOnCheckedChangeListener((b,on)->{state.dronePa=on;state.drones();syncNotes();});panel.addView(pa);
        Switch mute=new Switch(this);mute.setText("Mute");mute.setChecked(state.muted);mute.setOnCheckedChangeListener((b,on)->state.muted=on);panel.addView(mute);
        LinearLayout pump=new LinearLayout(this);pump.addView(button("Open bellows",v->{state.angle(state.angle+.12);instrument.invalidate();}));pump.addView(button("Close bellows",v->{state.angle(state.angle-.12);instrument.invalidate();}));panel.addView(pump);
        panel.addView(button("Retry Audio",v->audio.start()));panel.addView(label("Acoustic recordings: Donya Quick, Freesound #330410, CC0. HQ MP3-derived notes; no separate reed-stop claims. No internet or microphone permission.",10));
        ScrollView scroll=new ScrollView(this);scroll.addView(panel);new AlertDialog.Builder(this).setTitle("Instrument settings").setView(scroll).setPositiveButton("Done",(d,w)->save()).setNeutralButton("Reset",(d,w)->{panic();state.reset();save();updateRange();}).show();
    }
    private void addSlider(LinearLayout panel,String name,int value,int max,Value apply){panel.addView(label(name,12));SeekBar b=new SeekBar(this);b.setMax(max);b.setProgress(value);b.setContentDescription(name);b.setOnSeekBarChangeListener(seek(apply));panel.addView(b);}
    private AdapterView.OnItemSelectedListener select(Value value){return new AdapterView.OnItemSelectedListener(){public void onItemSelected(AdapterView<?> a,View v,int p,long id){value.set(p);}public void onNothingSelected(AdapterView<?> a){}};}
    @Override protected void onResume(){super.onResume();foreground=true;hasAudioFocus=manager.requestAudioFocus(focus)==AudioManager.AUDIOFOCUS_REQUEST_GRANTED;if(instrument!=null)instrument.invalidate();}
    @Override protected void onPause(){foreground=false;panic();save();manager.abandonAudioFocusRequest(focus);hasAudioFocus=false;super.onPause();}
    @Override protected void onDestroy(){audio.stop();unregisterReceiver(noisy);super.onDestroy();}
    @Override public boolean onKeyDown(int code,KeyEvent e){if(e.isCtrlPressed()||e.isAltPressed())return super.onKeyDown(code,e);if(e.getRepeatCount()>0)return true;for(int n=0;n<CODES.length;n++)if(code==CODES[n]){state.note("key-"+code,state.first()+n);syncNotes();return true;}if(code==KeyEvent.KEYCODE_SPACE){instrument.space=true;return true;}if(code==KeyEvent.KEYCODE_ESCAPE){panic();return true;}if(code==KeyEvent.KEYCODE_DPAD_LEFT){state.octave(-1);syncNotes();updateRange();return true;}if(code==KeyEvent.KEYCODE_DPAD_RIGHT){state.octave(1);syncNotes();updateRange();return true;}return super.onKeyDown(code,e);}
    @Override public boolean onKeyUp(int code,KeyEvent e){for(int n:CODES)if(code==n){state.release("key-"+code);syncNotes();return true;}if(code==KeyEvent.KEYCODE_SPACE){instrument.space=false;return true;}return super.onKeyUp(code,e);}
}
