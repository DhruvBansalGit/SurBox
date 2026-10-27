#pragma once
#include <algorithm>
#include <cmath>
#include <map>
#include <set>
#include <string>

// Deterministic state shared by the Windows renderer and host-side tests.
struct Instrument {
    static constexpr double closed=.07,open=.92;
    double angle=closed,reserve=.28,pressure=.22,velocity=0,previous=closed;
    double volume=.48,minimum=.20,sensitivity=1.25;
    int octave=3,tonic=0,scale=0;
    bool muted=false,sa=false,pa=false;
    std::map<int,int> owners;
    int first()const{return (octave+1)*12;}
    void setAngle(double a){if(std::isfinite(a))angle=std::clamp(a,closed,open);}
    std::set<int> notes()const{std::set<int> result;for(auto p:owners)result.insert(p.second);return result;}
    void note(int source,int midi){if(midi>=0&&midi<128)owners[source]=midi;}
    void release(int source){owners.erase(source);}
    void panic(){owners.clear();sa=pa=false;}
    void drones(){release(1000);release(1001);if(sa)note(1000,first()+tonic);if(pa)note(1001,first()+tonic+7);}
    void shift(int n){panic();octave=std::clamp(octave+n,2,5);}
    void tick(double dt){
        if(!std::isfinite(dt)||dt<=0)return;dt=std::min(.1,dt);
        double speed=std::min(5.,std::abs(angle-previous)/dt);previous=angle;
        velocity+=(speed-velocity)*(1-std::exp(-dt/.065));
        double pump=std::min(3.,speed*sensitivity*.85),consumption=.20+std::min(size_t(16),notes().size())*.025;
        reserve=std::clamp(reserve+(pump-consumption*(.25+reserve))*dt,0.,1.);
        double target=minimum+(1-minimum)*std::min(1.,reserve*.9+velocity*.09);
        pressure+=(target-pressure)*(1-std::exp(-dt/(target>pressure?.06:.30)));
    }
    bool inScale(int midi)const{
        if(scale==0)return true;int n=(midi-tonic+120)%12;
        static const int scales[3][7]={{0,2,4,5,7,9,11},{0,2,3,5,7,9,10},{0,1,4,5,7,8,11}};
        for(int i:scales[std::clamp(scale,1,3)-1])if(i==n)return true;return false;
    }
};
