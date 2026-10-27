#ifndef UNICODE
#define UNICODE
#endif
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <windowsx.h>
#include <commctrl.h>
#include <mmsystem.h>
#include <shellapi.h>
#include <array>
#include <atomic>
#include <fstream>
#include <filesystem>
#include <thread>
#include <vector>
#include <sstream>
#include <chrono>
#include <cstring>
#include "Instrument.h"
#include "SurBoxDSP.h"

namespace fs=std::filesystem;
static HWND window,volumeSlider,airSlider,sensSlider,tonicCombo,scaleCombo,saButton,paButton,muteButton;
static Instrument state;
static bool foreground=true,spacePump=false,panelDrag=false,keyDrag=false;
static double direction=1,lastY=0,zoom=1,cx=0,cy=0;
static RECT sceneRect{};
static SBEngine* dsp=nullptr;
static std::atomic<bool> runAudio{true};
static std::atomic<int> audioStatus{0};
static std::atomic<int> sampleCount{0};
static std::thread audioThread;
static fs::path appDir,prefsPath;
static const wchar_t* western[]={L"C",L"C#",L"D",L"Eb",L"E",L"F",L"F#",L"G",L"Ab",L"A",L"Bb",L"B"};
static const wchar_t* saNames[]={L"Sa",L"re",L"Re",L"ga",L"Ga",L"Ma",L"Ma#",L"Pa",L"dha",L"Dha",L"ni",L"Ni"};
struct Key {int offset;bool black;std::array<POINT,4> points;};
static std::vector<Key> keys;
static std::array<POINT,4> panel;
static bool black(int n){int x=n%12;return x==1||x==3||x==6||x==8||x==10;}
static POINT point(double x,double y,double z){return {LONG(cx+(x+.13*y)*zoom),LONG(cy+(.42*y-.9*z)*zoom)};}
static std::array<POINT,4> quad(double x1,double x2,double y1,double y2,double z){return {point(x1,y1,z),point(x2,y1,z),point(x2,y2,z),point(x1,y2,z)};}
static void poly(HDC dc,const std::array<POINT,4>& p,COLORREF color){HBRUSH b=CreateSolidBrush(color);HPEN pen=CreatePen(PS_SOLID,1,RGB(24,28,23));auto oldB=SelectObject(dc,b),oldP=SelectObject(dc,pen);Polygon(dc,p.data(),4);SelectObject(dc,oldB);SelectObject(dc,oldP);DeleteObject(b);DeleteObject(pen);}
static void fill(HDC dc,RECT r,COLORREF color){HBRUSH b=CreateSolidBrush(color);FillRect(dc,&r,b);DeleteObject(b);}
static void text(HDC dc,const std::wstring&s,int x,int y,int size,COLORREF color){HFONT f=CreateFontW(-size,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Segoe UI");auto old=SelectObject(dc,f);SetBkMode(dc,TRANSPARENT);SetTextColor(dc,color);TextOutW(dc,x,y,s.c_str(),int(s.size()));SelectObject(dc,old);DeleteObject(f);}
static bool inside(const std::array<POINT,4>& p,int x,int y){bool b=false;for(int i=0,j=3;i<4;j=i++)if(((p[i].y>y)!=(p[j].y>y))&&(x<(p[j].x-p[i].x)*double(y-p[i].y)/(p[j].y-p[i].y)+p[i].x))b=!b;return b;}
static int hit(int x,int y){for(auto it=keys.rbegin();it!=keys.rend();++it)if(inside(it->points,x,y))return it->offset;return -1;}
static void syncNotes(){auto active=state.notes();for(int i=0;i<128;i++)sb_note(dsp,i,active.count(i)?.78f:0.f);}
static void controls(){sb_controls(dsp,float(state.pressure),float(state.volume),state.muted||!foreground);}
static void panic(){state.panic();sb_panic(dsp);spacePump=panelDrag=keyDrag=false;ReleaseCapture();if(saButton)SendMessageW(saButton,BM_SETCHECK,BST_UNCHECKED,0);if(paButton)SendMessageW(paButton,BM_SETCHECK,BST_UNCHECKED,0);}
static void save(){
    auto set=[](const wchar_t*k,int v){auto s=std::to_wstring(v);WritePrivateProfileStringW(L"Instrument",k,s.c_str(),prefsPath.c_str());};
    set(L"volume",int(state.volume*100));set(L"air",int(state.minimum*100));set(L"sensitivity",int(state.sensitivity*100));set(L"octave",state.octave);set(L"tonic",state.tonic);set(L"scale",state.scale);
}
static void loadSamples(){
    // Manifest is generated from the authoritative sample metadata by build.sh.
    std::ifstream manifest(appDir/L"samples"/L"manifest.txt");int midi,begin,end;std::string file;
    while(manifest>>midi>>begin>>end>>file){
        std::ifstream in(appDir/L"samples"/fs::path(file),std::ios::binary);if(!in)continue;
        std::vector<unsigned char> bytes((std::istreambuf_iterator<char>(in)),{});if(bytes.size()<44)continue;
        auto u16=[&](size_t p){return unsigned(bytes[p])|(unsigned(bytes[p+1])<<8);};
        auto u32=[&](size_t p){return unsigned(bytes[p])|(unsigned(bytes[p+1])<<8)|(unsigned(bytes[p+2])<<16)|(unsigned(bytes[p+3])<<24);};
        if(std::memcmp(bytes.data(),"RIFF",4)||std::memcmp(bytes.data()+8,"WAVE",4))continue;
        bool format=false;
        for(size_t p=12;p+8<=bytes.size();){size_t size=u32(p+4);if(p+8+size>bytes.size())break;
            if(!std::memcmp(bytes.data()+p,"fmt ",4)&&size>=16)format=u16(p+8)==1&&u16(p+10)==1&&u32(p+12)==44100&&u16(p+22)==16;
            if(!std::memcmp(bytes.data()+p,"data",4)&&format){std::vector<float> pcm(size/2);for(size_t j=0;j<pcm.size();j++)pcm[j]=int16_t(u16(p+8+j*2))/32768.f;sb_load_sample(dsp,midi,pcm.data(),int(pcm.size()),44100,begin,end);break;}
            p+=8+size+(size&1);
        }
    }
    sampleCount=sb_sample_count(dsp);
}
static void audioLoop(){
    if(sampleCount==0)loadSamples();
    HANDLE event=CreateEventW(nullptr,FALSE,FALSE,nullptr);HWAVEOUT output=nullptr;
    WAVEFORMATEX format{};format.wFormatTag=WAVE_FORMAT_PCM;format.nChannels=1;format.nSamplesPerSec=48000;format.wBitsPerSample=16;format.nBlockAlign=2;format.nAvgBytesPerSec=96000;
    MMRESULT result=waveOutOpen(&output,WAVE_MAPPER,&format,DWORD_PTR(event),0,CALLBACK_EVENT);
    if(result!=MMSYSERR_NOERROR){audioStatus=-1;CloseHandle(event);return;}
    std::array<std::array<int16_t,256>,4> data{};std::array<WAVEHDR,4> headers{};std::array<float,256> block{};
    for(int i=0;i<4;i++){headers[i].lpData=reinterpret_cast<LPSTR>(data[i].data());headers[i].dwBufferLength=sizeof(data[i]);waveOutPrepareHeader(output,&headers[i],sizeof(WAVEHDR));headers[i].dwFlags|=WHDR_DONE;}
    audioStatus=1;
    while(runAudio){
        for(int b=0;b<4;b++)if(headers[b].dwFlags&WHDR_DONE){sb_render(dsp,block.data(),256);for(int i=0;i<256;i++)data[b][i]=int16_t(std::clamp(block[i],-1.f,1.f)*32767);if(waveOutWrite(output,&headers[b],sizeof(WAVEHDR))!=MMSYSERR_NOERROR){audioStatus=-1;runAudio=false;break;}}
        WaitForSingleObject(event,25);
    }
    waveOutReset(output);for(auto &h:headers)waveOutUnprepareHeader(output,&h,sizeof(h));waveOutClose(output);CloseHandle(event);
}
static void restartAudio(){runAudio=false;if(audioThread.joinable())audioThread.join();panic();runAudio=true;audioStatus=0;audioThread=std::thread(audioLoop);}
static void draw(HDC dc,RECT client){
    fill(dc,client,RGB(17,21,19));text(dc,L"S U R B O X",24,19,20,RGB(225,230,216));
    text(dc,L"Acoustic harmonium  /  native Windows",220,24,13,RGB(157,170,158));
    text(dc,L"Drag the rear panel. Hold keyboard notes. Physical laptop-lid tracking is not available on Windows.",24,127,13,RGB(154,169,157));
    sceneRect={12,151,client.right-12,client.bottom-70};
    zoom=std::min((sceneRect.right-sceneRect.left)/720.,(sceneRect.bottom-sceneRect.top)/430.);
    cx=client.right*.49;cy=sceneRect.top+(sceneRect.bottom-sceneRect.top)*.63;
    poly(dc,{point(-309,224,0),point(309,224,0),point(309,224,93),point(-309,224,93)},RGB(91,65,43));
    poly(dc,{point(309,-160,0),point(309,224,0),point(309,224,100),point(309,-160,100)},RGB(70,49,34));
    poly(dc,quad(-309,309,-160,224,92),RGB(47,37,29));poly(dc,quad(-310,-288,-160,224,128),RGB(108,78,53));poly(dc,quad(288,310,-160,224,128),RGB(108,78,53));poly(dc,quad(-288,288,-160,70,135),RGB(81,59,41));
    double a=state.angle;
    for(int i=0;i<24;i++){
        double a0=a*i/24,a1=a*(i+1)/24,r0=i%2==0?204:194,r1=(i+1)%2==0?204:194;
        double y0=-150+r0*cos(a0),z0=137+r0*sin(a0),y1=-150+r1*cos(a1),z1=137+r1*sin(a1);
        poly(dc,{point(-284,y0,z0),point(284,y0,z0),point(284,y1,z1),point(-284,y1,z1)},i%2==0?RGB(82,95,83):RGB(41,50,43));
    }
    panel={point(-289,-150,145),point(289,-150,145),point(289,-150+208*cos(a),145+208*sin(a)),point(-289,-150+208*cos(a),145+208*sin(a))};poly(dc,panel,RGB(104,78,54));
    for(int j=0;j<3;j++){double x0=-266+j*180,x1=x0+172;poly(dc,{point(x0,-150+20*cos(a),149+20*sin(a)),point(x1,-150+20*cos(a),149+20*sin(a)),point(x1,-150+180*cos(a),149+180*sin(a)),point(x0,-150+180*cos(a),149+180*sin(a))},RGB(40,48,42));}
    poly(dc,quad(-288,288,63,82,120),RGB(104,76,52));
    keys.clear();auto active=state.notes();double width=560./22;int index=0;
    for(int n=0;n<37;n++)if(!black(n)){double x=-280+index*width,z=active.count(state.first()+n)?96:100;auto q=quad(x+.6,x+width-.6,83,213,z);poly(dc,q,active.count(state.first()+n)?RGB(151,173,154):RGB(220,216,196));keys.push_back({n,false,q});POINT label=point(x+width*.2,185,z+1);text(dc,saNames[(state.first()+n-state.tonic+120)%12],label.x,label.y,int(std::max(8.,9*zoom)),state.inScale(state.first()+n)?RGB(65,71,61):RGB(144,147,131));index++;}
    index=0;for(int n=0;n<37;n++){if(!black(n)){index++;continue;}double x=-280+index*width;auto q=quad(x-width*.3,x+width*.3,84,159,active.count(state.first()+n)?114:118);poly(dc,q,active.count(state.first()+n)?RGB(89,115,94):RGB(13,18,15));keys.push_back({n,true,q});}
    int bottom=client.bottom-53;text(dc,L"AIR RESERVE",24,bottom,11,RGB(152,169,155));fill(dc,{118,bottom+3,238,bottom+8},RGB(48,59,50));fill(dc,{118,bottom+3,118+LONG(120*state.reserve),bottom+8},RGB(166,186,168));
    text(dc,L"C"+std::to_wstring(state.octave)+L" – C"+std::to_wstring(state.octave+3)+L"   |   "+(state.angle<=.072?L"Folded · open to pump":state.angle>=.918?L"Open limit · reverse":L"Bellows "+std::to_wstring(int(a*180/3.141592653589793))+L"°"),270,bottom-1,12,RGB(152,169,155));
    std::wstring status=audioStatus<0?L"Audio unavailable — use Retry audio":audioStatus==0?L"Preparing recordings…":sampleCount>0?L"Acoustic harmonium · "+std::to_wstring(sampleCount.load())+L" recorded notes":L"Synthesized reed fallback · recordings unavailable";
    text(dc,status,24,client.bottom-25,11,RGB(144,162,147));text(dc,L"A W S E D F T G Y H U J K O L P ; '    SPACE pump    ESC stop",client.right-470,client.bottom-25,10,RGB(144,162,147));
}
static HWND control(const wchar_t*cls,const wchar_t*name,DWORD style,int x,int y,int width,int height,int id){HWND h=CreateWindowW(cls,name,WS_CHILD|WS_VISIBLE|style,x,y,width,height,window,HMENU(INT_PTR(id)),nullptr,nullptr);SendMessageW(h,WM_SETFONT,WPARAM(GetStockObject(DEFAULT_GUI_FONT)),TRUE);return h;}
static void createControls(){
    control(L"BUTTON",L"− octave",BS_PUSHBUTTON,24,58,75,27,101);control(L"BUTTON",L"+ octave",BS_PUSHBUTTON,105,58,75,27,102);
    muteButton=control(L"BUTTON",L"Mute",BS_AUTOCHECKBOX,191,58,55,27,103);
    control(L"STATIC",L"Volume",0,255,64,50,20,0);volumeSlider=control(TRACKBAR_CLASSW,L"Master volume",TBS_HORZ,305,57,110,30,104);SendMessageW(volumeSlider,TBM_SETRANGE,TRUE,MAKELONG(0,100));SendMessageW(volumeSlider,TBM_SETPOS,TRUE,int(state.volume*100));
    tonicCombo=control(L"COMBOBOX",L"Tonic",CBS_DROPDOWNLIST|WS_VSCROLL,430,58,68,200,105);for(auto s:western)SendMessageW(tonicCombo,CB_ADDSTRING,0,LPARAM(s));SendMessageW(tonicCombo,CB_SETCURSEL,state.tonic,0);
    scaleCombo=control(L"COMBOBOX",L"Practice scale",CBS_DROPDOWNLIST,508,58,105,160,106);for(auto s:{L"Free play",L"Bilawal",L"Kafi",L"Bhairav"})SendMessageW(scaleCombo,CB_ADDSTRING,0,LPARAM(s));SendMessageW(scaleCombo,CB_SETCURSEL,state.scale,0);
    saButton=control(L"BUTTON",L"Sa drone",BS_AUTOCHECKBOX,626,58,82,27,107);paButton=control(L"BUTTON",L"Pa drone",BS_AUTOCHECKBOX,713,58,82,27,108);
    control(L"STATIC",L"Air assist",0,24,100,65,20,0);airSlider=control(TRACKBAR_CLASSW,L"Minimum airflow",TBS_HORZ,90,93,125,28,109);SendMessageW(airSlider,TBM_SETRANGE,TRUE,MAKELONG(0,50));SendMessageW(airSlider,TBM_SETPOS,TRUE,int(state.minimum*100));
    control(L"STATIC",L"Sensitivity",0,235,100,70,20,0);sensSlider=control(TRACKBAR_CLASSW,L"Pumping sensitivity",TBS_HORZ,308,93,125,28,110);SendMessageW(sensSlider,TBM_SETRANGE,TRUE,MAKELONG(20,300));SendMessageW(sensSlider,TBM_SETPOS,TRUE,int(state.sensitivity*100));
    control(L"BUTTON",L"Reset",BS_PUSHBUTTON,460,94,70,27,111);control(L"BUTTON",L"Retry audio",BS_PUSHBUTTON,540,94,90,27,112);control(L"BUTTON",L"Help / credits",BS_PUSHBUTTON,640,94,105,27,113);
}
static void pointer(int x,int y){int n=hit(x,y);if(n>=0)state.note(999,state.first()+n);else state.release(999);syncNotes();}
static int keyOffset(WPARAM key){static const int codes[]={'A','W','S','E','D','F','T','G','Y','H','U','J','K','O','L','P',VK_OEM_1,VK_OEM_7};for(int i=0;i<18;i++)if(key==WPARAM(codes[i]))return i;return -1;}
static LRESULT CALLBACK procedure(HWND h,UINT message,WPARAM w,LPARAM l){
    switch(message){
    case WM_CREATE:window=h;createControls();SetTimer(h,1,16,nullptr);return 0;
    case WM_GETMINMAXINFO:reinterpret_cast<MINMAXINFO*>(l)->ptMinTrackSize={870,620};return 0;
    case WM_ERASEBKGND:return 1;
    case WM_PAINT:{PAINTSTRUCT ps;HDC dc=BeginPaint(h,&ps);RECT r;GetClientRect(h,&r);HDC buffer=CreateCompatibleDC(dc);HBITMAP bitmap=CreateCompatibleBitmap(dc,r.right,r.bottom);auto old=SelectObject(buffer,bitmap);draw(buffer,r);BitBlt(dc,0,0,r.right,r.bottom,buffer,0,0,SRCCOPY);SelectObject(buffer,old);DeleteObject(bitmap);DeleteDC(buffer);EndPaint(h,&ps);return 0;}
    case WM_TIMER:{static auto last=std::chrono::steady_clock::now();auto now=std::chrono::steady_clock::now();double dt=std::chrono::duration<double>(now-last).count();last=now;if(spacePump&&foreground){if(state.angle>=Instrument::open)direction=-1;if(state.angle<=Instrument::closed)direction=1;state.setAngle(state.angle+std::min(.1,dt)*.65*direction);}state.tick(dt);controls();InvalidateRect(h,nullptr,FALSE);return 0;}
    case WM_LBUTTONDOWN:{SetFocus(h);int x=GET_X_LPARAM(l),y=GET_Y_LPARAM(l);SetCapture(h);if(inside(panel,x,y)){panelDrag=true;lastY=y;}else{keyDrag=true;pointer(x,y);}return 0;}
    case WM_MOUSEMOVE:if(panelDrag){int y=GET_Y_LPARAM(l);state.setAngle(state.angle-(y-lastY)/std::max(60.,220*zoom));lastY=y;}else if(keyDrag)pointer(GET_X_LPARAM(l),GET_Y_LPARAM(l));return 0;
    case WM_LBUTTONUP:panelDrag=keyDrag=false;state.release(999);syncNotes();ReleaseCapture();return 0;
    case WM_CANCELMODE:panic();return 0;
    case WM_CAPTURECHANGED:panelDrag=keyDrag=false;state.release(999);syncNotes();return 0;
    case WM_ACTIVATE:foreground=LOWORD(w)!=WA_INACTIVE;if(!foreground)panic();controls();return 0;
    case WM_KILLFOCUS:panic();return 0;
    case WM_KEYDOWN:if(l&(1L<<30))return 0;if(keyOffset(w)>=0){state.note(int(w),state.first()+keyOffset(w));syncNotes();}else if(w==VK_SPACE)spacePump=true;else if(w==VK_ESCAPE)panic();else if(w==VK_LEFT){state.shift(-1);syncNotes();}else if(w==VK_RIGHT){state.shift(1);syncNotes();}return 0;
    case WM_KEYUP:if(keyOffset(w)>=0){state.release(int(w));syncNotes();}if(w==VK_SPACE)spacePump=false;return 0;
    case WM_HSCROLL:state.volume=SendMessageW(volumeSlider,TBM_GETPOS,0,0)/100.;state.minimum=SendMessageW(airSlider,TBM_GETPOS,0,0)/100.;state.sensitivity=SendMessageW(sensSlider,TBM_GETPOS,0,0)/100.;save();return 0;
    case WM_COMMAND:switch(LOWORD(w)){
        case 101:state.shift(-1);syncNotes();break;case 102:state.shift(1);syncNotes();break;
        case 103:state.muted=SendMessageW(muteButton,BM_GETCHECK,0,0)==BST_CHECKED;break;
        case 105:if(HIWORD(w)==CBN_SELCHANGE){state.tonic=int(SendMessageW(tonicCombo,CB_GETCURSEL,0,0));state.drones();syncNotes();}break;
        case 106:if(HIWORD(w)==CBN_SELCHANGE)state.scale=int(SendMessageW(scaleCombo,CB_GETCURSEL,0,0));break;
        case 107:state.sa=SendMessageW(saButton,BM_GETCHECK,0,0)==BST_CHECKED;state.drones();syncNotes();break;
        case 108:state.pa=SendMessageW(paButton,BM_GETCHECK,0,0)==BST_CHECKED;state.drones();syncNotes();break;
        case 111:panic();state=Instrument{};SendMessageW(volumeSlider,TBM_SETPOS,TRUE,48);SendMessageW(airSlider,TBM_SETPOS,TRUE,20);SendMessageW(sensSlider,TBM_SETPOS,TRUE,125);SendMessageW(tonicCombo,CB_SETCURSEL,0,0);SendMessageW(scaleCombo,CB_SETCURSEL,0,0);SendMessageW(muteButton,BM_SETCHECK,0,0);break;
        case 112:restartAudio();break;
        case 113:panic();MessageBoxW(h,L"Drag the rear panel up/down to pump air. Click/drag keys, or play chords with A W S E D F T G Y H U J K O L P ; '. Hold Space to pump; Escape releases all notes.\n\nAir assist defaults to 20%. Set it to zero for manual air. Choose your Sa reference and optional tonic/fifth drones.\n\nWindows uses mouse/keyboard pumping. Physical laptop-lid angle tracking is NOT supported.\n\n39 acoustic samples: Donya Quick, Freesound #330410, CC0. HQ MP3 derivatives, not the original lossless WAV. Missing recordings use a labeled synthesized fallback. No account or network required.\n\nEngineering preview: Windows hardware/audio acceptance and accessibility review may remain outstanding; see platform testing report.",L"SurBox — controls and credits",MB_OK);break;
        }save();InvalidateRect(h,nullptr,FALSE);return 0;
    case WM_CLOSE:save();DestroyWindow(h);return 0;
    case WM_DESTROY:KillTimer(h,1);panic();runAudio=false;PostQuitMessage(0);return 0;
    }return DefWindowProcW(h,message,w,l);
}
static int selfTest(){
    dsp=sb_create(48000);loadSamples();std::vector<float> pcm(48000);sb_controls(dsp,.8f,.5f,0);sb_note(dsp,48,.8f);sb_note(dsp,52,.8f);sb_note(dsp,55,.8f);sb_render(dsp,pcm.data(),int(pcm.size()));float peak=0;for(float v:pcm)peak=std::max(peak,std::abs(v));sb_panic(dsp);sb_render(dsp,pcm.data(),int(pcm.size()));bool pass=sampleCount==39&&peak>.01f&&peak<1&&std::abs(pcm.back())<.00001f;
    std::ofstream report(appDir/L"windows-self-test.txt");report<<(pass?"PASS":"FAIL")<<" Windows process loads 39 recordings, mixes chord and releases to silence; peak="<<peak<<"\n";sb_destroy(dsp);return pass?0:1;
}
static int uiTest(){
    std::ofstream report(appDir/L"windows-ui-test.txt");int failures=0,count=0;
    auto check=[&](bool ok,const char*name){count++;if(!ok)failures++;report<<(ok?"PASS ":"FAIL ")<<name<<"\n";};
    auto refresh=[](){InvalidateRect(window,nullptr,FALSE);UpdateWindow(window);};
    loadSamples();audioStatus=1;refresh();check(keys.size()==37,"Native window paints 37 key polygons");
    SendMessageW(window,WM_KEYDOWN,'A',0);SendMessageW(window,WM_KEYDOWN,'D',0);SendMessageW(window,WM_KEYDOWN,'G',0);check(state.notes().size()==3,"Native key messages produce C/E/G chord");
    SendMessageW(window,WM_KEYDOWN,'A',1L<<30);check(state.owners.size()==3,"Auto-repeat does not duplicate notes");
    SendMessageW(window,WM_KEYUP,'A',0);SendMessageW(window,WM_KEYUP,'D',0);SendMessageW(window,WM_KEYUP,'G',0);check(state.notes().empty(),"Native key releases clear chord");
    int x=0,y=0;for(auto p:panel){x+=p.x/4;y+=p.y/4;}
    SendMessageW(window,WM_LBUTTONDOWN,MK_LBUTTON,MAKELPARAM(x,y));check(panelDrag,"Native panel hit testing starts drag");
    SendMessageW(window,WM_MOUSEMOVE,MK_LBUTTON,MAKELPARAM(x,y-100));SendMessageW(window,WM_LBUTTONUP,0,MAKELPARAM(x,y-100));check(state.angle>.3,"Native mouse movement opens hinge");refresh();
    double r=state.reserve;state.tick(.05);check(state.reserve>r,"Hinge movement charges reserve");
    SendMessageW(volumeSlider,TBM_SETPOS,TRUE,63);SendMessageW(window,WM_HSCROLL,0,LPARAM(volumeSlider));check(std::abs(state.volume-.63)<.001,"Native volume slider wiring");
    SendMessageW(tonicCombo,CB_SETCURSEL,2,0);SendMessageW(window,WM_COMMAND,MAKEWPARAM(105,CBN_SELCHANGE),LPARAM(tonicCombo));check(state.tonic==2,"Native tonic selector wiring");
    SendMessageW(saButton,BM_SETCHECK,BST_CHECKED,0);SendMessageW(window,WM_COMMAND,107,LPARAM(saButton));check(state.notes().count(50),"Native drone control");
    SendMessageW(window,WM_KEYDOWN,VK_ESCAPE,0);check(state.notes().empty(),"Escape releases drones and keys");
    SendMessageW(window,WM_KEYDOWN,'A',0);SendMessageW(window,WM_ACTIVATE,WA_INACTIVE,0);check(state.notes().empty(),"Deactivation releases held keys");foreground=true;
    state.setAngle(.62);state.note('A',48);state.note('D',52);state.note('G',55);syncNotes();refresh();
    RECT rct;GetClientRect(window,&rct);HDC dc=GetDC(window),mem=CreateCompatibleDC(dc);HBITMAP bm=CreateCompatibleBitmap(dc,rct.right,rct.bottom);auto old=SelectObject(mem,bm);PrintWindow(window,mem,PW_CLIENTONLY);SelectObject(mem,old);
    BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=rct.right;info.bmiHeader.biHeight=rct.bottom;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;
    std::vector<unsigned char> pixels(size_t(rct.right)*rct.bottom*4);int lines=GetDIBits(dc,bm,0,rct.bottom,pixels.data(),&info,DIB_RGB_COLORS);check(lines==rct.bottom,"Native Windows screenshot captured");
    BITMAPFILEHEADER header{};header.bfType=0x4d42;header.bfOffBits=sizeof(header)+sizeof(info.bmiHeader);header.bfSize=DWORD(header.bfOffBits+pixels.size());std::ofstream image(appDir/L"windows-ui.bmp",std::ios::binary);image.write(reinterpret_cast<char*>(&header),sizeof(header));image.write(reinterpret_cast<char*>(&info.bmiHeader),sizeof(info.bmiHeader));image.write(reinterpret_cast<char*>(pixels.data()),pixels.size());
    DeleteObject(bm);DeleteDC(mem);ReleaseDC(window,dc);report<<"RESULT "<<count<<" native Windows UI checks; failures="<<failures<<"\n";report<<"Hardware speaker output, device changes and physical input remain unverified.\n";return failures?1:0;
}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,LPWSTR command,int show){
    wchar_t path[32768];GetModuleFileNameW(nullptr,path,32768);appDir=fs::path(path).parent_path();
    if(std::wstring(command).find(L"--self-test")!=std::wstring::npos)return selfTest();
    SetProcessDPIAware();wchar_t local[32768];DWORD n=GetEnvironmentVariableW(L"LOCALAPPDATA",local,32768);prefsPath=n?fs::path(local)/L"SurBox":appDir;std::error_code ec;fs::create_directories(prefsPath,ec);prefsPath/=L"settings.ini";
    auto setting=[](const wchar_t*k,int value){return int(GetPrivateProfileIntW(L"Instrument",k,value,prefsPath.c_str()));};state.volume=std::clamp(setting(L"volume",48),0,100)/100.;state.minimum=std::clamp(setting(L"air",20),0,50)/100.;state.sensitivity=std::clamp(setting(L"sensitivity",125),20,300)/100.;state.octave=std::clamp(setting(L"octave",3),2,5);state.tonic=std::clamp(setting(L"tonic",0),0,11);state.scale=std::clamp(setting(L"scale",0),0,3);
    dsp=sb_create(48000);INITCOMMONCONTROLSEX cc{sizeof(cc),ICC_BAR_CLASSES};InitCommonControlsEx(&cc);
    WNDCLASSW wc{};wc.lpfnWndProc=procedure;wc.hInstance=instance;wc.lpszClassName=L"SurBoxInstrument";wc.hCursor=LoadCursorW(nullptr,IDC_ARROW);RegisterClassW(&wc);
    window=CreateWindowExW(0,wc.lpszClassName,L"SurBox — native harmonium",WS_OVERLAPPEDWINDOW|WS_CLIPCHILDREN,CW_USEDEFAULT,CW_USEDEFAULT,1120,800,nullptr,nullptr,instance,nullptr);
    if(!window){sb_destroy(dsp);return 1;}ShowWindow(window,show);UpdateWindow(window);
    if(std::wstring(command).find(L"--ui-test")!=std::wstring::npos){int result=uiTest();DestroyWindow(window);sb_destroy(dsp);return result;}
    audioThread=std::thread(audioLoop);
    MSG msg;while(GetMessageW(&msg,nullptr,0,0)>0){TranslateMessage(&msg);DispatchMessageW(&msg);}runAudio=false;if(audioThread.joinable())audioThread.join();sb_destroy(dsp);return 0;
}
