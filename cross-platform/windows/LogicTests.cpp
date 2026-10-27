#include "Instrument.h"
#include "SurBoxDSP.h"
#include <iostream>
#include <vector>
#include <stdexcept>
int main(){int n=0;auto check=[&](bool ok,const char*name){if(!ok)throw std::runtime_error(name);n++;std::cout<<"PASS "<<name<<"\n";};
Instrument s;s.setAngle(-10);check(s.angle==s.closed,"Closed stop");s.setAngle(10);check(s.angle==s.open,"Open stop");s.note(1,60);s.note(2,60);s.release(2);check(s.notes().count(60)==1,"Note ownership");s.note(3,64);s.note(4,67);check(s.notes().size()==3,"Chord");s.panic();check(s.notes().empty(),"Panic");s=Instrument{};double r=s.reserve;for(int i=0;i<30;i++){s.setAngle(.07+i*.02);s.tick(.02);}check(s.reserve>r,"Opening supplies air");r=s.reserve;for(int i=0;i<30;i++){s.setAngle(.65-i*.02);s.tick(.02);}check(s.reserve>r,"Closing supplies air");s.minimum=0;for(int i=0;i<4000;i++)s.tick(.02);check(s.pressure<.00001,"Resting decay");s.minimum=.2;for(int i=0;i<1000;i++)s.tick(.02);check(std::abs(s.pressure-.2)<.00001,"Air assist");s.tonic=2;s.sa=s.pa=true;s.drones();check(s.notes().count(50)&&s.notes().count(57),"Relative drones");s.shift(1);check(s.notes().empty()&&s.first()==60,"Octave clears old notes");
SBEngine* e=sb_create(48000);std::vector<float> audio(48000);sb_controls(e,.8,.5,0);for(int m:{48,52,55})sb_note(e,m,.8);sb_render(e,audio.data(),48000);float peak=0;for(float v:audio)peak=std::max(peak,std::abs(v));check(peak>.03&&peak<1,"Native shared DSP polyphony");sb_panic(e);sb_render(e,audio.data(),48000);check(std::abs(audio.back())<.00001,"Native DSP release");sb_destroy(e);std::cout<<"RESULT "<<n<<" C++ logic/DSP checks passed on host (not Windows UI)\n";
}
