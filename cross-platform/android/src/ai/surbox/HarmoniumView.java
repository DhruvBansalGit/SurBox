package ai.surbox;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.view.MotionEvent;
import android.view.View;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/** Native Canvas 2.5D perspective: each fold is a separate projected facet,
 * with a fixed pivot. No WebView, image animation or fake device sensor. */
public final class HarmoniumView extends View {
    private final MainActivity host;
    private final Instrument state;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final ArrayList<Key> keys=new ArrayList<>();
    private final Map<Integer,Boolean> pointers=new HashMap<>();
    private float[] panel;
    private double scale,horizontalScale,cx,cy;
    private int pump=-1;
    private float lastY;
    public boolean space=false;
    private double direction=1;
    private long last=System.nanoTime();
    private static class Key{int offset;boolean black;float[] polygon;Key(int n,boolean b,float[] p){offset=n;black=b;polygon=p;}}
    public HarmoniumView(MainActivity c,Instrument state){super(c);host=c;this.state=state;setFocusable(true);setFocusableInTouchMode(true);setContentDescription("Harmonium. Touch and hold keys for chords. Drag the rear panel upward or downward to pump. Use Settings for accessible controls.");}
    public void cancel(){pointers.clear();pump=-1;space=false;state.clear();host.syncNotes();invalidate();}
    @Override public void onWindowFocusChanged(boolean focus){super.onWindowFocusChanged(focus);if(!focus)cancel();}
    private float[] p(double x,double y,double z){return new float[]{(float)(cx+(x+.13*y)*horizontalScale),(float)(cy+(.42*y-.9*z)*scale)};}
    private float[] quad(double x1,double x2,double y1,double y2,double z){return polygon(new double[][]{{x1,y1,z},{x2,y1,z},{x2,y2,z},{x1,y2,z}});}
    private float[] polygon(double[][] pts){float[] out=new float[pts.length*2];for(int i=0;i<pts.length;i++){float[] a=p(pts[i][0],pts[i][1],pts[i][2]);out[i*2]=a[0];out[i*2+1]=a[1];}return out;}
    private void fill(Canvas c,float[] points,int color){Path path=new Path();path.moveTo(points[0],points[1]);for(int i=2;i<points.length;i+=2)path.lineTo(points[i],points[i+1]);path.close();paint.setStyle(Paint.Style.FILL);paint.setColor(color);c.drawPath(path,paint);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth((float)Math.max(.6,scale*.8));paint.setColor(Color.argb(110,8,10,8));c.drawPath(path,paint);paint.setStyle(Paint.Style.FILL);}
    private static int rgb(int r,int g,int b){return Color.rgb(r,g,b);}
    private void text(Canvas c,String s,float x,float y,float size,int color){paint.setColor(color);paint.setTextSize(size);paint.setStyle(Paint.Style.FILL);c.drawText(s,x,y,paint);}
    @Override protected void onDraw(Canvas c){
        super.onDraw(c);c.drawColor(rgb(18,22,21));
        long now=System.nanoTime();double dt=Math.min(.1,(now-last)/1e9);last=now;
        if(space){if(state.angle>=Instrument.OPEN)direction=-1;if(state.angle<=Instrument.CLOSED)direction=1;state.angle(state.angle+dt*.65*direction);}
        if(host.foreground)state.step(dt);
        host.audio.mixer.pressure=(float)state.pressure;host.audio.mixer.volume=(float)state.volume;host.audio.mixer.muted=state.muted||!host.foreground||!host.hasAudioFocus;
        scale=Math.min(getWidth()/700.0,getHeight()/440.0);horizontalScale=Math.min(getWidth()/700.0,scale*1.85);cx=getWidth()*.49;cy=getHeight()*.60;
        float density=getResources().getDisplayMetrics().density;
        if(getWidth()<getHeight())text(c,"MOVE THE BELLOWS. HOLD A NOTE.",18*density,29*density,10*density,rgb(154,168,158));
        if(getWidth()<getHeight())text(c,"Touch / mouse pumping · no physical lid sensor",18*density,48*density,9*density,rgb(128,143,134));
        // Stationary soundbox and front rail.
        fill(c,polygon(new double[][]{{-309,224,0},{309,224,0},{309,224,93},{-309,224,93}}),rgb(91,65,43));
        fill(c,polygon(new double[][]{{309,-160,0},{309,224,0},{309,224,100},{309,-160,100}}),rgb(70,49,34));
        fill(c,quad(-309,309,-160,224,92),rgb(47,37,29));
        fill(c,quad(-310,-288,-160,224,128),rgb(108,78,53));fill(c,quad(288,310,-160,224,128),rgb(108,78,53));
        fill(c,quad(-288,288,-160,70,135),rgb(81,59,41));
        // Twelve fan-folds span a wedge from the fixed rear hinge.
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
        fill(c,quad(-288,288,63,82,120),rgb(104,76,52));
        // Two octaves in portrait for comfortable fingers; three in landscape.
        int count=getWidth()<getHeight()?25:37;
        int whites=count==25?15:22;double w=560.0/whites;keys.clear();Set<Integer> active=state.notes();
        int index=0;
        for(int n=0;n<count;n++)if(!black(n)){
            double x=-280+index*w,z=active.contains(state.first()+n)?96:100;
            float[] q=quad(x+.6,x+w-.6,83,213,z);fill(c,q,active.contains(state.first()+n)?rgb(151,173,154):rgb(220,216,196));keys.add(new Key(n,false,q));
            float[] label=p(x+w*.21,194,z+1);String name=Instrument.SA[(state.first()+n-state.tonic+120)%12];
            text(c,name,label[0],label[1],(float)Math.max(8,Math.min(14,10*horizontalScale)),state.inScale(state.first()+n)?rgb(65,71,61):rgb(144,147,131));index++;
        }
        index=0;
        for(int n=0;n<count;n++){if(!black(n)){index++;continue;}double x=-280+index*w;float[] q=quad(x-w*.3,x+w*.3,84,159,active.contains(state.first()+n)?114:118);fill(c,q,active.contains(state.first()+n)?rgb(89,115,94):rgb(13,18,15));keys.add(new Key(n,true,q));}
        float bottom=getHeight()-29*density;
        text(c,"AIR",18*density,bottom,10*density,rgb(148,162,152));paint.setColor(rgb(51,61,54));c.drawRect(48*density,bottom-7*density,145*density,bottom-3*density,paint);paint.setColor(rgb(159,183,163));c.drawRect(48*density,bottom-7*density,(float)((48+97*state.reserve)*density),bottom-3*density,paint);
        String limit=state.angle<=Instrument.CLOSED+.002?"Folded · open to pump":state.angle>=Instrument.OPEN-.002?"Open limit · reverse":"Bellows "+(int)(a*180/Math.PI)+"°";
        text(c,limit,160*density,bottom,10*density,rgb(156,172,160));
        if(host.foreground)postInvalidateOnAnimation();
    }
    public float[] testPanelPoint(){if(panel==null)return new float[]{0,0};float x=0,y=0;for(int i=0;i<panel.length;i+=2){x+=panel[i]/4;y+=panel[i+1]/4;}return new float[]{x,y};}
    public float[] testKeyPoint(int offset){for(Key k:keys)if(k.offset==offset){float[] p=k.polygon;return new float[]{(p[0]+p[2]+p[4]+p[6])/4,((p[1]+p[3])*.15f+(p[5]+p[7])*.85f)/2};}return new float[]{0,0};}
    private boolean black(int n){int x=n%12;return x==1||x==3||x==6||x==8||x==10;}
    private boolean inside(float[] poly,float x,float y){if(poly==null)return false;boolean c=false;for(int i=0,j=poly.length-2;i<poly.length;j=i,i+=2)if(((poly[i+1]>y)!=(poly[j+1]>y))&&(x<(poly[j]-poly[i])*(y-poly[i+1])/(poly[j+1]-poly[i+1])+poly[i]))c=!c;return c;}
    private int hit(float x,float y){for(int i=keys.size()-1;i>=0;i--)if(inside(keys.get(i).polygon,x,y))return keys.get(i).offset;return -1;}
    private void pointer(int id,float x,float y){int n=hit(x,y);if(n>=0)state.note("touch-"+id,state.first()+n);else state.release("touch-"+id);host.syncNotes();}
    @Override public boolean onTouchEvent(MotionEvent e){
        int action=e.getActionMasked(),i=e.getActionIndex(),id=e.getPointerId(i);
        if(action==MotionEvent.ACTION_DOWN||action==MotionEvent.ACTION_POINTER_DOWN){requestFocus();if(pump==-1&&inside(panel,e.getX(i),e.getY(i))){pump=id;lastY=e.getY(i);pointers.put(id,true);}else{pointers.put(id,false);pointer(id,e.getX(i),e.getY(i));}}
        else if(action==MotionEvent.ACTION_MOVE){for(i=0;i<e.getPointerCount();i++){id=e.getPointerId(i);if(id==pump){state.angle(state.angle-(e.getY(i)-lastY)/Math.max(60,220*scale));lastY=e.getY(i);}else if(pointers.containsKey(id))pointer(id,e.getX(i),e.getY(i));}}
        else if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_POINTER_UP){if(id==pump)pump=-1;pointers.remove(id);state.release("touch-"+id);host.syncNotes();performClick();}
        else if(action==MotionEvent.ACTION_CANCEL)cancel();invalidate();return true;
    }
    @Override public boolean performClick(){super.performClick();return true;}
}
