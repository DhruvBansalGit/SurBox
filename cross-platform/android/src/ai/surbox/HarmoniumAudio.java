package ai.surbox;

import android.content.res.AssetManager;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioTrack;
import android.os.Process;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public final class HarmoniumAudio {
    public interface Status {void changed(String text,boolean failed);}
    public final ReedMixer mixer=new ReedMixer();
    private final AssetManager assets;
    private final Status status;
    private volatile boolean running=true;
    public volatile long renderedFrames=0;
    public volatile boolean outputStarted=false;
    private Thread worker;
    public HarmoniumAudio(AssetManager assets,Status status){this.assets=assets;this.status=status;}
    public synchronized void start(){if(worker!=null&&worker.isAlive())return;running=true;worker=new Thread(this::run,"SurBox audio");worker.start();}
    public void stop(){running=false;mixer.muted=true;mixer.panic();if(worker!=null)worker.interrupt();}
    private byte[] read(String name)throws Exception{
        try(InputStream in=assets.open(name);ByteArrayOutputStream out=new ByteArrayOutputStream()){byte[] block=new byte[16384];int n;while((n=in.read(block))!=-1)out.write(block,0,n);return out.toByteArray();}
    }
    private void load()throws Exception{
        JSONArray records=new JSONArray(new String(read("samples.json"),java.nio.charset.StandardCharsets.UTF_8));
        for(int i=0;i<records.length();i++){
            JSONObject r=records.getJSONObject(i);
            try{
                byte[] bytes=read(r.getString("file"));ByteBuffer b=ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN);
                if(bytes.length<44||b.getInt(0)!=0x46464952||b.getInt(8)!=0x45564157)continue;
                int channels=0,bits=0,rate=0,type=0;
                for(int p=12;p+8<=bytes.length;){int id=b.getInt(p),length=b.getInt(p+4);if(length<0||p+8L+length>bytes.length)break;
                    if(id==0x20746d66&&length>=16){type=b.getShort(p+8);channels=b.getShort(p+10);rate=b.getInt(p+12);bits=b.getShort(p+22);}
                    if(id==0x61746164&&type==1&&channels==1&&bits==16&&rate==44100){float[] pcm=new float[length/2];for(int j=0;j<pcm.length;j++)pcm[j]=b.getShort(p+8+j*2)/32768f;mixer.load(r.getInt("midi"),pcm,r.getInt("loopStart"),r.getInt("loopEnd"));break;}
                    p+=8+length+(length&1);
                }
            }catch(Exception ignored){/* One missing/corrupt note falls back to its nearest valid sample. */}
        }
    }
    private void run(){
        AudioTrack track=null;
        try{
            if(mixer.count==0)try{load();}catch(Exception ignored){}
            int minimum=AudioTrack.getMinBufferSize(ReedMixer.RATE,AudioFormat.CHANNEL_OUT_MONO,AudioFormat.ENCODING_PCM_FLOAT);
            if(minimum<0)throw new IllegalStateException("Audio output format unavailable");
            track=new AudioTrack.Builder().setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setAudioFormat(new AudioFormat.Builder().setSampleRate(ReedMixer.RATE).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).setEncoding(AudioFormat.ENCODING_PCM_FLOAT).build())
                .setBufferSizeInBytes(Math.max(minimum,2048)).setTransferMode(AudioTrack.MODE_STREAM).setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY).build();
            if(track.getState()!=AudioTrack.STATE_INITIALIZED)throw new IllegalStateException("Output initialization failed");
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO);track.play();outputStarted=true;
            status.changed(mixer.count>0?"Acoustic harmonium · "+mixer.count+" recorded notes":"Synthesized reed fallback · recordings unavailable",false);
            float[] block=new float[256];
            while(running){mixer.render(block,block.length);int offset=0;while(running&&offset<block.length){int n=track.write(block,offset,block.length-offset,AudioTrack.WRITE_BLOCKING);if(n<=0)throw new IllegalStateException("Audio device stopped ("+n+")");offset+=n;renderedFrames+=n;}}
        }catch(Exception e){if(running)status.changed("Audio unavailable: "+e.getMessage()+". Use Retry Audio in Settings.",true);}
        finally{outputStarted=false;if(track!=null){try{track.stop();}catch(Exception ignored){}track.release();}}
    }
}
