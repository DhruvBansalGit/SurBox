package ai.surbox;

import java.util.concurrent.atomic.AtomicIntegerArray;

/** Allocation-free rendering after initialization. Acoustic samples, 60ms loop
 * crossfade, 10ms attack / 55ms release. Original synthesized fallback is only
 * used when no recordings loaded, and the UI reports that explicitly. */
public final class ReedMixer {
    public static final int RATE=48000;
    private final AtomicIntegerArray gates=new AtomicIntegerArray(128);
    private final float[][] pcm=new float[128][];
    private final int[] start=new int[128],end=new int[128],sample=new int[128];
    private final double[] position=new double[128],phase=new double[128],step=new double[128];
    private final float[] envelope=new float[128],reed=new float[4096];
    private final boolean[] gated=new boolean[128];
    public volatile float pressure=.2f,volume=.48f;
    public volatile boolean muted=true;
    private float air=.2f,gain=0,normalization=1;
    public volatile int count=0;
    public ReedMixer(){
        for(int i=0;i<4096;i++){double v=0;for(int h=1;h<=12;h++)v+=Math.sin(2*Math.PI*i/4096*h+.07*h)/Math.pow(h,1.35)*(h%2==1?1:.70);reed[i]=(float)(v*.32);}
        for(int i=0;i<128;i++)sample[i]=-1;
    }
    public void load(int midi,float[] data,int loopStart,int loopEnd){
        if(midi<0||midi>127||data.length<256||loopStart<0||loopEnd>data.length||loopEnd-loopStart<256)throw new IllegalArgumentException("Invalid recording metadata");
        if(pcm[midi]==null)count++;pcm[midi]=data;start[midi]=loopStart;end[midi]=loopEnd;
    }
    public void note(int midi,boolean on){if(midi>=0&&midi<128)gates.set(midi,on?1:0);}
    public void panic(){for(int i=0;i<128;i++)gates.set(i,0);}
    public void render(float[] out,int frames){
        java.util.Arrays.fill(out,0,frames,0f);int active=0;
        float attack=(float)(1-Math.exp(-1/(RATE*.010))),release=(float)(1-Math.exp(-1/(RATE*.055)));
        for(int m=0;m<128;m++){
            float target=gates.get(m)!=0?.78f:0;
            if(target>0&&!gated[m]){
                gated[m]=true;position[m]=0;phase[m]=0;int distance=999;sample[m]=-1;
                for(int k=0;k<128;k++)if(pcm[k]!=null&&Math.abs(k-m)<distance){distance=Math.abs(k-m);sample[m]=k;}
                step[m]=sample[m]>=0?Math.pow(2,(m-sample[m])/12.0)*44100/RATE:440*Math.pow(2,(m-69)/12.0)/RATE;
            }else if(target==0)gated[m]=false;
            if(target==0&&envelope[m]<.00001){envelope[m]=0;continue;}active++;
            int s=sample[m];
            for(int i=0;i<frames;i++){
                envelope[m]+=(target-envelope[m])*(target>envelope[m]?attack:release);float value;
                if(s>=0){
                    int fade=Math.min(2646,(end[s]-start[s])/4);
                    if(position[m]>=end[s])position[m]=start[s]+fade+(position[m]-end[s])%(end[s]-start[s]-fade);
                    int idx=(int)position[m];float f=(float)(position[m]-idx);
                    value=pcm[s][idx]*(1-f)+pcm[s][Math.min(idx+1,end[s]-1)]*f;
                    if(position[m]>end[s]-fade){double p=start[s]+position[m]-(end[s]-fade);int j=(int)p;float jf=(float)(p-j);float other=pcm[s][j]*(1-jf)+pcm[s][j+1]*jf;float x=(float)((position[m]-(end[s]-fade))/fade);value=value*(1-x)+other*x;}
                    position[m]+=step[m];
                }else{value=reed[((int)(phase[m]*4096))&4095];phase[m]+=step[m];phase[m]-=Math.floor(phase[m]);}
                out[i]+=value*envelope[m];
            }
        }
        float targetGain=muted?0:volume,targetAir=pressure,norm=(float)(1/Math.sqrt(Math.max(1,active)));
        float smooth=(float)(1-Math.exp(-1/(RATE*.022)));
        for(int i=0;i<frames;i++){air+=(targetAir-air)*smooth;gain+=(targetGain-gain)*smooth;normalization+=(norm-normalization)*smooth;float x=out[i]*air*gain*normalization*.78f;out[i]=x/(1+Math.abs(x));}
    }
}
