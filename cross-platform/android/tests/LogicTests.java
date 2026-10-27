import ai.surbox.Instrument;
import ai.surbox.ReedMixer;
public class LogicTests {
    static int count=0;
    static void check(boolean ok,String name){if(!ok)throw new AssertionError(name);count++;System.out.println("PASS "+name);}
    public static void main(String[] args){
        Instrument s=new Instrument();s.angle(-9);check(s.angle==Instrument.CLOSED,"Closed limit");s.angle(9);check(s.angle==Instrument.OPEN,"Open limit");s.angle(Double.NaN);check(s.angle==Instrument.OPEN,"Reject nonfinite angle");s.reset();
        s.note("a",60);s.note("pointer",60);s.release("pointer");check(s.notes().contains(60),"Independent source ownership");s.note("b",64);s.note("c",67);check(s.notes().size()==3,"Chord polyphony");s.clear();check(s.notes().isEmpty(),"Panic clears notes");
        s.reset();double r=s.reserve;for(int i=0;i<30;i++){s.angle(.07+i*.02);s.step(.02);}check(s.reserve>r,"Opening pumps");r=s.reserve;for(int i=0;i<30;i++){s.angle(.65-i*.02);s.step(.02);}check(s.reserve>r,"Closing pumps");
        s.minimumAir=0;for(int i=0;i<4000;i++)s.step(.02);check(s.pressure<.00001,"Resting air drains");s.minimumAir=.2;for(int i=0;i<1000;i++)s.step(.02);check(Math.abs(s.pressure-.2)<.00001,"Air assist floor");
        s.tonic=2;s.droneSa=true;s.dronePa=true;s.drones();check(s.notes().contains(50)&&s.notes().contains(57),"Tonic and fifth drones");s.octave(1);check(s.notes().isEmpty()&&s.first()==60,"Octave clears old notes");
        ReedMixer m=new ReedMixer();float[] out=new float[48000];m.render(out,out.length);check(out[100]==0,"DSP begins silent");m.muted=false;m.pressure=.8f;m.volume=.5f;m.note(48,true);m.note(52,true);m.note(55,true);m.render(out,out.length);float peak=0;for(float v:out)peak=Math.max(peak,Math.abs(v));check(peak>.03&&peak<.9,"Fallback polyphony bounded");m.panic();m.render(out,out.length);check(Math.abs(out[out.length-1])<.00001,"Release reaches silence");
        float[] sample=new float[96000];for(int i=0;i<sample.length;i++)sample[i]=(float)(.4*Math.sin(i*2*Math.PI*261.625/44100));m.load(60,sample,20000,90000);m.note(60,true);for(int i=0;i<8;i++)m.render(out,out.length);peak=0;for(float v:out){checkFinite(v);peak=Math.max(peak,Math.abs(v));}check(m.count==1&&peak>.01&&peak<.9,"Sample transposition and repeated loops");
        System.out.println("RESULT "+count+" deterministic Java checks passed");
    }
    static void checkFinite(float f){if(!Float.isFinite(f))throw new AssertionError("Nonfinite DSP output");}
}
