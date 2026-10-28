package ai.surbox;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.view.MotionEvent;
import android.view.View;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/** Native touch-first instrument. Preserve the fixed-hinge 2.5D bellows, but
 * remove perspective compression from the playable keys. User feedback says
 * accurate finger placement matters more than fitting all 37 keys on a phone.
 */
public final class HarmoniumView extends View {
    private final MainActivity host;
    private final Instrument state;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path=new Path();
    private final Map<Integer,Integer> pointers=new HashMap<>();
    private TouchKeyboardLayout keyboard;
    private float[] panel;
    private double scale,horizontalScale,cx,cy;
    private float density,pumpRight,pumpBottom;
    private int pump=-1;
    private float lastY;
    public boolean space=false;
    private double direction=1;
    private long last=System.nanoTime();
    public HarmoniumView(MainActivity c,Instrument s){super(c);host=c;state=s;density=getResources().getDisplayMetrics().density;setFocusable(true);setFocusableInTouchMode(true);setContentDescription("Large harmonium keyboard. One octave with wide keys. Use the octave minus and plus controls for other notes. Drag the bellows above the keys to pump while holding notes with other fingers.");}
    public void cancel(){pointers.clear();pump=-1;space=false;state.clear();host.syncNotes();invalidate();}
    public void clearTouches(){pointers.clear();pump=-1;space=false;state.clear();host.syncNotes();invalidate();}
    @Override public void onWindowFocusChanged(boolean focus){super.onWindowFocusChanged(focus);if(!focus)cancel();}
    @Override protected void onSizeChanged(int w,int h,int oldW,int oldH){super.onSizeChanged(w,h,oldW,oldH);if(oldW>0&&oldH>0)cancel();keyboard=new TouchKeyboardLayout(w,h,density);}
    private float[] p(double x,double y,double z){return new float[]{(float)(cx+(x+.13*y)*horizontalScale),(float)(cy+(.42*y-.9*z)*scale)};}
    private float[] quad(double x1,double x2,double y1,double y2,double z){return polygon(new double[][]{{x1,y1,z},{x2,y1,z},{x2,y2,z},{x1,y2,z}});}
    private float[] polygon(double[][] pts){float[] out=new float[pts.length*2];for(int i=0;i<pts.length;i++){float[] a=p(pts[i][0],pts[i][1],pts[i][2]);out[i*2]=a[0];out[i*2+1]=a[1];}return out;}
    private void fill(Canvas c,float[] points,int color){path.reset();path.moveTo(points[0],points[1]);for(int i=2;i<points.length;i+=2)path.lineTo(points[i],points[i+1]);path.close();paint.setStyle(Paint.Style.FILL);paint.setColor(color);c.drawPath(path,paint);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(Math.max(.6f,density*.5f));paint.setColor(Color.argb(120,8,10,8));c.drawPath(path,paint);paint.setStyle(Paint.Style.FILL);}
    private static int rgb(int r,int g,int b){return Color.rgb(r,g,b);}
    private void text(Canvas c,String s,float x,float y,float size,int color){paint.setColor(color);paint.setTextSize(size);paint.setTextAlign(Paint.Align.LEFT);paint.setStyle(Paint.Style.FILL);c.drawText(s,x,y,paint);}
    private void centered(Canvas c,String s,float x,float y,float size,int color){paint.setColor(color);paint.setTextSize(size);paint.setTextAlign(Paint.Align.CENTER);paint.setStyle(Paint.Style.FILL);c.drawText(s,x,y,paint);paint.setTextAlign(Paint.Align.LEFT);}
    private void rect(Canvas c,float l,float t,float r,float b,int color){paint.setColor(color);paint.setStyle(Paint.Style.FILL);c.drawRect(l,t,r,b,paint);}
    @Override protected void onDraw(Canvas c){
        super.onDraw(c);c.drawColor(rgb(18,22,21));if(keyboard==null)return;
        long now=System.nanoTime();double dt=Math.min(.1,(now-last)/1e9);last=now;
        if(space){if(state.angle>=Instrument.OPEN)direction=-1;if(state.angle<=Instrument.CLOSED)direction=1;state.angle(state.angle+dt*.65*direction);}
        if(host.foreground)state.step(dt);
        host.audio.mixer.pressure=(float)state.pressure;host.audio.mixer.volume=(float)state.volume;host.audio.mixer.muted=state.muted||!host.foreground||!host.hasAudioFocus;
        drawBellows(c);
        drawKeyboard(c);
        if(host.foreground)postInvalidateOnAnimation();
    }
    private void drawBellows(Canvas c){
        // Compact live preview above the keys. Its hinge remains fixed, and the
        // full left band is an easy grab target; it never overlaps a key.
        pumpRight=getWidth()*.57f;pumpBottom=keyboard.top-8*density;
        float bandHeight=Math.max(35*density,pumpBottom-10*density);
        horizontalScale=Math.max(.1,(pumpRight-24*density)/660.0);
        scale=bandHeight/225.;cx=pumpRight*.5;cy=6*density+300*scale;
        c.save();c.clipRect(8*density,0,pumpRight,pumpBottom);
        fill(c,quad(-306,306,-160,66,133),rgb(82,60,42));
        double a=state.angle;
        for(int i=0;i<24;i++){
            double a0=a*i/24,a1=a*(i+1)/24,r0=i%2==0?204:194,r1=(i+1)%2==0?204:194;
            double y0=-150+r0*Math.cos(a0),z0=137+r0*Math.sin(a0),y1=-150+r1*Math.cos(a1),z1=137+r1*Math.sin(a1);
            fill(c,polygon(new double[][]{{-284,y0,z0},{284,y0,z0},{284,y1,z1},{-284,y1,z1}}),i%2==0?rgb(82,95,83):rgb(41,50,43));
            fill(c,polygon(new double[][]{{284,-150,137},{284,y0,z0},{284,y1,z1}}),i%2==0?rgb(65,75,65):rgb(37,44,38));
        }
        panel=polygon(new double[][]{{-289,-150,145},{289,-150,145},{289,-150+208*Math.cos(a),145+208*Math.sin(a)},{-289,-150+208*Math.cos(a),145+208*Math.sin(a)}});
        fill(c,panel,rgb(104,78,54));
        for(int j=0;j<3;j++){
            double x0=-266+j*180,x1=x0+172;
            fill(c,polygon(new double[][]{{x0,-150+20*Math.cos(a),149+20*Math.sin(a)},{x1,-150+20*Math.cos(a),149+20*Math.sin(a)},{x1,-150+180*Math.cos(a),149+180*Math.sin(a)},{x0,-150+180*Math.cos(a),149+180*Math.sin(a)}}),rgb(40,48,42));
        }
        c.restore();
        float tx=pumpRight+12*density,mid=Math.max(23*density,pumpBottom*.35f);
        text(c,"DRAG BELLOWS ↑↓",tx,mid,11*density,rgb(186,201,188));
        String limit=state.angle<=Instrument.CLOSED+.002?"Folded · drag up":state.angle>=Instrument.OPEN-.002?"Open limit · reverse":"Pumping range · "+(int)(a*180/Math.PI)+"°";
        text(c,limit,tx,mid+18*density,10*density,rgb(144,162,149));
        float meterY=mid+32*density,meterWidth=Math.min(110*density,getWidth()-tx-36*density);
        rect(c,tx,meterY,tx+meterWidth,meterY+4*density,rgb(51,61,54));rect(c,tx,meterY,tx+(float)(meterWidth*state.reserve),meterY+4*density,rgb(159,183,163));
        text(c,"Air "+(int)(state.pressure*100)+"%",tx+meterWidth+8*density,meterY+5*density,10*density,rgb(144,162,149));
    }
    private void drawKeyboard(Canvas c){
        Set<Integer> active=state.notes();
        rect(c,keyboard.left-4*density,keyboard.top-6*density,keyboard.right+4*density,keyboard.bottom+6*density,rgb(83,61,43));
        for(TouchKeyboardLayout.Key key:keyboard.keys)if(!key.black){
            boolean pressed=active.contains(state.first()+key.offset);float inset=.65f*density,shift=pressed?3*density:0;
            rect(c,key.left+inset,key.top,key.right-inset,key.bottom,rgb(137,129,108));
            rect(c,key.left+inset,key.top+shift,key.right-inset,key.bottom-5*density+shift,pressed?rgb(158,185,163):rgb(233,228,207));
            float x=(key.left+key.right)/2;
            String note=Instrument.WESTERN[(state.first()+key.offset)%12]+((state.first()+key.offset)/12-1);
            String solfege=Instrument.SA[(state.first()+key.offset-state.tonic+120)%12];
            int label=state.inScale(state.first()+key.offset)?rgb(63,72,59):rgb(126,132,114);
            centered(c,solfege,x,key.bottom-32*density+shift,16*density,label);
            centered(c,note,x,key.bottom-14*density+shift,11*density,label);
        }
        for(TouchKeyboardLayout.Key key:keyboard.keys)if(key.black){
            boolean pressed=active.contains(state.first()+key.offset);float shift=pressed?3*density:0;
            rect(c,key.left-1*density,key.top+3*density,key.right+2*density,key.bottom+3*density,rgb(88,83,69));
            rect(c,key.left,key.top+shift,key.right,key.bottom+shift,pressed?rgb(66,99,74):rgb(22,28,24));
            rect(c,key.left+2*density,key.top+shift,key.right-2*density,key.top+5*density+shift,pressed?rgb(93,124,100):rgb(47,56,48));
            float x=(key.left+key.right)/2;
            centered(c,Instrument.SA[(state.first()+key.offset-state.tonic+120)%12],x,key.bottom-27*density+shift,13*density,rgb(209,218,207));
            centered(c,Instrument.WESTERN[(state.first()+key.offset)%12],x,key.bottom-11*density+shift,10*density,rgb(172,187,175));
        }
    }
    public float[] testPanelPoint(){return new float[]{pumpRight*.5f,pumpBottom*.5f};}
    public float[] testKeyPoint(int offset){TouchKeyboardLayout.Key key=keyboard.keys[offset];return new float[]{(key.left+key.right)/2,key.black?(key.top+key.bottom)/2:keyboard.blackBottom+(key.bottom-keyboard.blackBottom)*.65f};}
    public TouchKeyboardLayout testKeyboardLayout(){return keyboard;}
    private void pointer(int id,float x,float y){int previous=pointers.containsKey(id)?pointers.get(id):-1;int n=keyboard.hitWithHysteresis(x,y,previous,density);pointers.put(id,n);if(n>=0)state.note("touch-"+id,state.first()+n);else state.release("touch-"+id);host.syncNotes();}
    @Override public boolean onTouchEvent(MotionEvent e){
        if(keyboard==null)return true;
        int action=e.getActionMasked(),i=e.getActionIndex(),id=e.getPointerId(i);
        if(action==MotionEvent.ACTION_DOWN||action==MotionEvent.ACTION_POINTER_DOWN){
            requestFocus();if(pump==-1&&e.getX(i)>=8*density&&e.getX(i)<pumpRight&&e.getY(i)>=0&&e.getY(i)<pumpBottom){pump=id;lastY=e.getY(i);}else pointer(id,e.getX(i),e.getY(i));
        }else if(action==MotionEvent.ACTION_MOVE){for(i=0;i<e.getPointerCount();i++){id=e.getPointerId(i);if(id==pump){state.angle(state.angle-(e.getY(i)-lastY)/(130*density));lastY=e.getY(i);}else if(pointers.containsKey(id))pointer(id,e.getX(i),e.getY(i));}}
        else if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_POINTER_UP){if(id==pump)pump=-1;pointers.remove(id);state.release("touch-"+id);host.syncNotes();performClick();}
        else if(action==MotionEvent.ACTION_CANCEL)cancel();invalidate();return true;
    }
    @Override public boolean performClick(){super.performClick();return true;}
}
