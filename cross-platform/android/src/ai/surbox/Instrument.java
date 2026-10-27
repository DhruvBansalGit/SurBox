package ai.surbox;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/** Deterministic native mobile state. Units: hinge radians, MIDI note numbers.
 * Both strokes charge a virtual air reservoir; no phone or Windows lid sensor
 * is implied. Pointer/key ownership prevents cross-input stuck notes. */
public final class Instrument {
    public static final double CLOSED=.07, OPEN=.92;
    public double angle=CLOSED, reserve=.28, pressure=.22, velocity=0;
    public double volume=.48, sensitivity=1.25, minimumAir=.20;
    public int octave=3, tonic=0, scale=0;
    public boolean muted=false, droneSa=false, dronePa=false;
    private double previousAngle=CLOSED;
    private final Map<String,Integer> owners=new HashMap<>();
    public static final String[] WESTERN={"C","C#","D","Eb","E","F","F#","G","Ab","A","Bb","B"};
    public static final String[] SA={"Sa","re","Re","ga","Ga","Ma","Ma#","Pa","dha","Dha","ni","Ni"};
    public synchronized int first(){return (octave+1)*12;}
    public synchronized void angle(double a){if(Double.isFinite(a)) angle=Math.max(CLOSED,Math.min(OPEN,a));}
    public synchronized void note(String source,int note){if(note>=0&&note<128)owners.put(source,note);}
    public synchronized void release(String source){owners.remove(source);}
    public synchronized Set<Integer> notes(){return new HashSet<>(owners.values());}
    public synchronized void clear(){owners.clear();droneSa=false;dronePa=false;}
    public synchronized void drones(){
        owners.remove("drone-sa");owners.remove("drone-pa");
        if(droneSa)owners.put("drone-sa",first()+tonic);
        if(dronePa)owners.put("drone-pa",first()+tonic+7);
    }
    public synchronized void octave(int delta){clear();octave=Math.max(2,Math.min(5,octave+delta));}
    public synchronized void step(double dt){
        if(!Double.isFinite(dt)||dt<=0)return;dt=Math.min(.1,dt);
        double speed=Math.min(Math.abs(angle-previousAngle)/dt,5);previousAngle=angle;
        velocity+=(speed-velocity)*(1-Math.exp(-dt/.065));
        double pump=Math.min(3,speed*sensitivity*.85);
        double consumption=.20+Math.min(owners.size(),16)*.025;
        reserve=Math.max(0,Math.min(1,reserve+(pump-consumption*(.25+reserve))*dt));
        double target=minimumAir+(1-minimumAir)*Math.min(1,reserve*.9+velocity*.09);
        pressure+=(target-pressure)*(1-Math.exp(-dt/(target>pressure?.06:.30)));
    }
    public synchronized boolean inScale(int note){
        if(scale==0)return true;
        int n=(note-tonic+120)%12;
        int[][] scales={{},{0,2,4,5,7,9,11},{0,2,3,5,7,9,10},{0,1,4,5,7,8,11}};
        for(int i:scales[scale])if(n==i)return true;return false;
    }
    public synchronized void reset(){clear();angle=CLOSED;previousAngle=CLOSED;reserve=.28;pressure=.22;velocity=0;volume=.48;sensitivity=1.25;minimumAir=.20;octave=3;tonic=0;scale=0;muted=false;}
}
