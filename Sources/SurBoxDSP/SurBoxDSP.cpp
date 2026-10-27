#include "SurBoxDSP.h"
#include <atomic>
#include <array>
#include <vector>
#include <cmath>
#include <algorithm>

struct Sample { std::vector<float> data; double rate=44100; int start=0,end=0; };
struct Voice { double position=0, phase=0; float envelope=0; bool gated=false; int sample=-1; };
struct SBEngine {
    double rate;
    std::array<std::atomic<float>,128> gates{};
    std::array<Voice,128> voices{};
    std::array<Sample,128> samples;
    std::atomic<float> pressure{0.2f}, volume{0.48f};
    std::atomic<bool> mute{false};
    std::atomic<uint32_t> panic{0}; uint32_t seenPanic=0;
    float air=0.2f, gain=0.48f, normalization=1;
    std::array<float,4096> reed{};
    SBEngine(double r): rate(r) {
        for (auto &g:gates) g.store(0);
        // Explicitly synthetic fallback: static band-limited reed wavetable,
        // never mislabeled as a recording. No random work in render callback.
        for(int i=0;i<4096;i++) {
            // Standard C++ does not require the non-portable M_PI macro.
            double p=2*3.14159265358979323846*i/4096, v=0;
            for(int h=1;h<=12;h++) v+=sin(p*h+0.07*h)/(pow(h,1.35))*(h%2?1:0.70);
            reed[i]=float(v*0.32);
        }
    }
};
extern "C" {
SBEngine *sb_create(double rate) { return new SBEngine(rate>8000?rate:48000); }
void sb_destroy(SBEngine *e) { delete e; }
int sb_load_sample(SBEngine *e,int midi,const float *data,int n,double rate,int start,int end) {
    if(!e || !data || midi<0 || midi>127 || n<256 || start<0 || end>n || end-start<256 || rate<8000) return 0;
    auto &s=e->samples[midi]; s.data.assign(data,data+n); s.rate=rate; s.start=start; s.end=end; return 1;
}
int sb_sample_count(SBEngine *e) { int n=0; for(auto &s:e->samples) if(!s.data.empty()) ++n; return n; }
void sb_note(SBEngine *e,int midi,float v) { if(e && midi>=0 && midi<128) e->gates[midi].store(std::clamp(v,0.f,1.f),std::memory_order_relaxed); }
void sb_controls(SBEngine *e,float p,float v,int mute) {
    e->pressure.store(std::clamp(p,0.f,1.f),std::memory_order_relaxed);
    e->volume.store(std::clamp(v,0.f,1.f),std::memory_order_relaxed); e->mute.store(mute!=0,std::memory_order_relaxed);
}
void sb_panic(SBEngine *e) { for(auto &g:e->gates) g.store(0,std::memory_order_relaxed); e->panic.fetch_add(1); }
void sb_render(SBEngine *e,float *out,int count) {
    if(!e || !out || count<=0) return;
    std::fill(out,out+count,0.f);
    if(e->seenPanic!=e->panic.load()) { for(auto &v:e->voices) v.gated=false; e->seenPanic=e->panic.load(); }
    const float attack=1-exp(-1/(e->rate*0.010)), release=1-exp(-1/(e->rate*0.055));
    int active=0;
    for(int m=0;m<128;m++) {
        auto &v=e->voices[m]; float target=e->gates[m].load(std::memory_order_relaxed);
        if(target>0 && !v.gated) {
            v.gated=true; v.position=0; v.phase=0; v.sample=-1;
            int distance=999;
            for(int k=0;k<128;k++) if(!e->samples[k].data.empty() && abs(k-m)<distance) { distance=abs(k-m); v.sample=k; }
        } else if(target==0) v.gated=false;
        if(target==0 && v.envelope<0.00001f) { v.envelope=0; continue; }
        ++active;
        double freq=440*pow(2,(m-69)/12.0);
        double step=v.sample>=0 ? pow(2,(m-v.sample)/12.0)*e->samples[v.sample].rate/e->rate : 0;
        for(int i=0;i<count;i++) {
            v.envelope+=(target-v.envelope)*(target>v.envelope?attack:release);
            float value=0;
            if(v.sample>=0) {
                auto &s=e->samples[v.sample];
                int fade=std::min(int(s.rate*0.060),(s.end-s.start)/4);
                if(v.position>=s.end) v.position=s.start+fade+fmod(v.position-s.end,double(s.end-s.start-fade));
                int idx=int(v.position); float f=float(v.position-idx);
                value=s.data[idx]*(1-f)+s.data[std::min(idx+1,s.end-1)]*f;
                if(v.position>s.end-fade) {
                    double pos=s.start+v.position-(s.end-fade); int j=int(pos); float jf=float(pos-j);
                    float other=s.data[j]*(1-jf)+s.data[j+1]*jf;
                    float x=float((v.position-(s.end-fade))/fade);
                    value=value*(1-x)+other*x;
                }
                v.position+=step;
            } else {
                int index=int(v.phase*4096)&4095; value=e->reed[index];
                v.phase+=freq/e->rate; v.phase-=floor(v.phase);
            }
            out[i]+=value*v.envelope;
        }
    }
    const float smooth=1-exp(-1/(e->rate*0.022));
    float p=e->pressure.load(), g=e->mute.load()?0:e->volume.load();
    float norm=1.f/sqrtf(float(std::max(1,active)));
    for(int i=0;i<count;i++) {
        e->air+=(p-e->air)*smooth; e->gain+=(g-e->gain)*smooth; e->normalization+=(norm-e->normalization)*smooth;
        float x=out[i]*e->air*e->gain*e->normalization*0.78f;
        out[i]=x/(1+fabsf(x)); // bounded soft saturation, no clipping
    }
}
}
