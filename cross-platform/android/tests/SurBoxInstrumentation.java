package ai.surbox;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.KeyEvent;
import android.graphics.Bitmap;
import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;

public final class SurBoxInstrumentation extends Instrumentation {
    private final ArrayList<String> lines=new ArrayList<>();private int failed=0;
    private MainActivity activity;
    private void check(boolean ok,String label){lines.add((ok?"PASS ":"FAIL ")+label);if(!ok)failed++;}
    @Override public void onCreate(Bundle b){super.onCreate(b);start();}
    private void touch(int action,float x,float y){runOnMainSync(()->{long t=SystemClock.uptimeMillis();MotionEvent e=MotionEvent.obtain(t,t,action,x,y,0);activity.instrument.dispatchTouchEvent(e);e.recycle();});}
    private void key(int action,int code){runOnMainSync(()->activity.dispatchKeyEvent(new KeyEvent(action,code)));}
    @Override public void onStart(){
        try{
            Intent intent=new Intent(Intent.ACTION_MAIN).setClassName("ai.surbox","ai.surbox.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity=(MainActivity)startActivitySync(intent);waitForIdleSync();
            for(int i=0;i<80&&activity.audio.mixer.count<39;i++)SystemClock.sleep(250);
            check(activity.audio.mixer.count==39,"Actual APK decodes all 39 bundled recordings");
            // Loading the last sample precedes AudioTrack initialization; wait
            // for the actual output state rather than racing that startup gap.
            for(int i=0;i<40&&!activity.audio.outputStarted;i++)SystemClock.sleep(100);
            long frames=activity.audio.renderedFrames;SystemClock.sleep(400);check(activity.audio.outputStarted&&activity.audio.renderedFrames>frames,"Native AudioTrack accepts continuously rendered PCM frames");
            check(activity.foreground,"Native activity is foreground");check(activity.hasAudioFocus,"Audio focus granted on Android emulator");
            runOnMainSync(()->activity.state.reset());
            key(KeyEvent.ACTION_DOWN,KeyEvent.KEYCODE_A);key(KeyEvent.ACTION_DOWN,KeyEvent.KEYCODE_D);key(KeyEvent.ACTION_DOWN,KeyEvent.KEYCODE_G);
            check(activity.state.notes().size()==3,"Native Android keyboard events produce chord");
            key(KeyEvent.ACTION_UP,KeyEvent.KEYCODE_A);key(KeyEvent.ACTION_UP,KeyEvent.KEYCODE_D);key(KeyEvent.ACTION_UP,KeyEvent.KEYCODE_G);
            check(activity.state.notes().isEmpty(),"Chord key-up releases all notes");
            TouchKeyboardLayout layout=activity.instrument.testKeyboardLayout();float density=activity.getResources().getDisplayMetrics().density;
            check(layout.keys.length==13,"Touch-first layout shows 13 large keys, not 37 thin keys");
            check(layout.whiteWidth/density>=72&&layout.blackWidth/density>=48,"Actual natural keys at least 72dp wide and black keys at least 48dp");
            check((layout.bottom-layout.top)/density>=140&&(layout.bottom-layout.blackBottom)/density>=60,"Actual keys are tall with a separate exposed natural-note area");
            lines.add("INFO key sizes dp: natural width="+(layout.whiteWidth/density)+", height="+((layout.bottom-layout.top)/density)+", black width="+(layout.blackWidth/density)+", height="+((layout.blackBottom-layout.top)/density));
            boolean allKeyPoints=true;
            for(TouchKeyboardLayout.Key k:layout.keys){
                float top=k.black?k.top:layout.blackBottom;
                for(int ix=1;ix<=3;ix++)for(int iy=1;iy<=3;iy++){
                    float tx=k.left+k.width()*ix/4,ty=top+(k.bottom-top)*iy/4;
                    touch(MotionEvent.ACTION_DOWN,tx,ty);
                    if(activity.state.notes().size()!=1||!activity.state.notes().contains(48+k.offset))allKeyPoints=false;
                    touch(MotionEvent.ACTION_UP,tx,ty);
                }
            }
            check(allKeyPoints,"117 distributed real touch positions select the intended natural/black pitch");
            float glideY=layout.bottom-20*density;touch(MotionEvent.ACTION_DOWN,layout.keys[0].left+layout.whiteWidth/2,glideY);
            boolean glides=true;for(TouchKeyboardLayout.Key k:layout.keys)if(!k.black){touch(MotionEvent.ACTION_MOVE,(k.left+k.right)/2,glideY);if(!activity.state.notes().contains(48+k.offset)||activity.state.notes().size()!=1)glides=false;}
            touch(MotionEvent.ACTION_UP,layout.right-10*density,glideY);check(glides&&activity.state.notes().isEmpty(),"Large-key glissando changes pitch accurately and releases cleanly");
            touch(MotionEvent.ACTION_DOWN,layout.keys[0].right-5*density,glideY);touch(MotionEvent.ACTION_MOVE,layout.keys[0].right+2*density,glideY);
            check(activity.state.notes().contains(48),"Small finger boundary jitter does not trigger the next natural");
            touch(MotionEvent.ACTION_MOVE,layout.keys[0].right+6*density,glideY);check(activity.state.notes().contains(50),"Deliberate slide past the boundary selects the adjacent natural");touch(MotionEvent.ACTION_UP,layout.keys[0].right+6*density,glideY);
            touch(MotionEvent.ACTION_DOWN,layout.keys[0].left+layout.whiteWidth/2,glideY);key(KeyEvent.ACTION_DOWN,KeyEvent.KEYCODE_DPAD_RIGHT);key(KeyEvent.ACTION_UP,KeyEvent.KEYCODE_DPAD_RIGHT);
            touch(MotionEvent.ACTION_MOVE,layout.keys[0].left+layout.whiteWidth/2,glideY);check(activity.state.notes().isEmpty()&&activity.state.first()==60,"Octave shift cancels old touches instead of retriggering the held finger");touch(MotionEvent.ACTION_UP,layout.keys[0].left+layout.whiteWidth/2,glideY);
            runOnMainSync(()->{activity.shiftOctave(99);});check(activity.state.first()+12==108,"Highest previous C8 remains reachable with wide keys");runOnMainSync(()->{activity.shiftOctave(-99);});check(activity.state.first()==36,"Lowest previous C2 remains reachable with wide keys");runOnMainSync(()->{activity.state.reset();activity.shiftOctave(0);});
            final float[][] panel={null},key={null};runOnMainSync(()->{panel[0]=activity.instrument.testPanelPoint();key[0]=activity.instrument.testKeyPoint(0);});
            float x=panel[0][0],y=panel[0][1];double before=activity.state.angle;
            touch(MotionEvent.ACTION_DOWN,x,y);for(int i=1;i<=20;i++){touch(MotionEvent.ACTION_MOVE,x,y-i*5);SystemClock.sleep(15);}touch(MotionEvent.ACTION_UP,x,y-100);
            check(activity.state.angle>before+.15,"Actual touch drag opens bellows around fixed pivot");
            check(activity.state.reserve>.15,"Touch pumping supplies actual air reserve");
            runOnMainSync(()->panel[0]=activity.instrument.testPanelPoint());x=panel[0][0];y=panel[0][1];
            touch(MotionEvent.ACTION_DOWN,x,y);for(int i=1;i<=30;i++)touch(MotionEvent.ACTION_MOVE,x,y+i*6);touch(MotionEvent.ACTION_UP,x,y+180);
            check(Math.abs(activity.state.angle-Instrument.CLOSED)<.001,"Reverse touch closes to constrained stop");
            touch(MotionEvent.ACTION_DOWN,key[0][0],key[0][1]);check(activity.state.notes().contains(48),"Native key touch creates note");
            touch(MotionEvent.ACTION_CANCEL,key[0][0],key[0][1]);check(activity.state.notes().isEmpty(),"Touch cancel clears held note");
            // Multiple pointer IDs go through the same production touch handler.
            runOnMainSync(()->{
                float[] p1=activity.instrument.testKeyPoint(0),p2=activity.instrument.testKeyPoint(4);
                long t=SystemClock.uptimeMillis();MotionEvent.PointerProperties a=new MotionEvent.PointerProperties(),b=new MotionEvent.PointerProperties();a.id=0;b.id=1;a.toolType=b.toolType=MotionEvent.TOOL_TYPE_FINGER;
                MotionEvent.PointerCoords c=new MotionEvent.PointerCoords(),d=new MotionEvent.PointerCoords();c.x=p1[0];c.y=p1[1];d.x=p2[0];d.y=p2[1];c.pressure=d.pressure=1;c.size=d.size=1;
                MotionEvent down=MotionEvent.obtain(t,t,MotionEvent.ACTION_DOWN,p1[0],p1[1],0);activity.instrument.dispatchTouchEvent(down);down.recycle();
                MotionEvent two=MotionEvent.obtain(t,t,MotionEvent.ACTION_POINTER_DOWN|(1<<MotionEvent.ACTION_POINTER_INDEX_SHIFT),2,new MotionEvent.PointerProperties[]{a,b},new MotionEvent.PointerCoords[]{c,d},0,0,1,1,0,0,android.view.InputDevice.SOURCE_TOUCHSCREEN,0);activity.instrument.dispatchTouchEvent(two);two.recycle();
            });
            check(activity.state.notes().contains(48)&&activity.state.notes().contains(52),"Two-finger touch chord has independent ownership");runOnMainSync(()->activity.panic());
            key(KeyEvent.ACTION_DOWN,KeyEvent.KEYCODE_SPACE);SystemClock.sleep(650);key(KeyEvent.ACTION_UP,KeyEvent.KEYCODE_SPACE);check(activity.state.angle>.2,"Space assisted pump moves bellows");
            key(KeyEvent.ACTION_DOWN,KeyEvent.KEYCODE_A);runOnMainSync(()->activity.instrument.onWindowFocusChanged(false));check(activity.state.notes().isEmpty(),"Window focus loss clears notes");
            runOnMainSync(()->{activity.state.tonic=2;activity.state.droneSa=true;activity.state.dronePa=true;activity.state.drones();activity.syncNotes();});check(activity.state.notes().contains(50)&&activity.state.notes().contains(57),"Relative Sa and fifth drones");
            runOnMainSync(()->{activity.panic();activity.state.tonic=0;activity.state.angle(.62);activity.state.note("test-a",48);activity.state.note("test-b",52);activity.state.note("test-c",55);activity.syncNotes();});SystemClock.sleep(150);
            File directory=new File(activity.getExternalFilesDir(null),"verification");directory.mkdirs();
            Bitmap screenshot=getUiAutomation().takeScreenshot();try(FileOutputStream out=new FileOutputStream(new File(directory,"android-playing.png"))){screenshot.compress(Bitmap.CompressFormat.PNG,100,out);}check(screenshot.getWidth()>0,"Actual Android screen capture");
            runOnMainSync(()->activity.panic());
            // Separate loaded production mixer output check without racing the live mixer.
            ReedMixer mixer=new ReedMixer();float[] sample=new float[96000];for(int i=0;i<sample.length;i++)sample[i]=(float)(.4*Math.sin(i*2*Math.PI*261.625/44100));mixer.load(60,sample,20000,90000);mixer.muted=false;mixer.pressure=.8f;mixer.note(60,true);float[] out=new float[48000];mixer.render(out,out.length);float peak=0;for(float v:out)peak=Math.max(peak,Math.abs(v));check(peak>.01&&peak<1,"Production Android mixer emits bounded nonzero PCM");mixer.panic();mixer.render(out,out.length);check(Math.abs(out[out.length-1])<.00001,"Android mixer release reaches silence");
            check(activity.getPackageManager().checkPermission("android.permission.INTERNET","ai.surbox")==android.content.pm.PackageManager.PERMISSION_DENIED,"APK has no Internet permission");
            int assertions=0;for(String line:lines)if(line.startsWith("PASS ")||line.startsWith("FAIL "))assertions++;
            lines.add("RESULT "+assertions+" Android checks, failures="+failed);lines.add("Physical-device touch comfort, latency, speaker listening, accessibility and battery acceptance remain unverified.");
            try(FileOutputStream f=new FileOutputStream(new File(directory,"android-results.txt"))){f.write(String.join("\n",lines).getBytes(java.nio.charset.StandardCharsets.UTF_8));}
        }catch(Throwable e){failed++;lines.add("FAIL "+e.toString());}
        Bundle result=new Bundle();result.putString("stream",String.join("\n",lines)+"\n");finish(failed==0?-1:0,result);
    }
}
