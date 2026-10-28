package ai.surbox;

/** Android touch-first keyboard geometry (density-independent dimensions).
 * User feedback: the original 37 perspective keys were too thin to play.
 * Show 13 notes / eight broad naturals by default, without foreshortening.
 * Hit regions stay fixed while pressed visuals move; no invisible overlap or
 * tiny dead gaps. The lower white-key area never triggers a black key.
 */
public final class TouchKeyboardLayout {
    public static final int COUNT=13;
    public static final class Key {
        public final int offset; public final boolean black;
        public final float left,top,right,bottom;
        Key(int n,boolean b,float l,float t,float r,float d){offset=n;black=b;left=l;top=t;right=r;bottom=d;}
        public boolean contains(float x,float y){return x>=left&&x<right&&y>=top&&y<=bottom;}
        public float width(){return right-left;}
        public float height(){return bottom-top;}
    }
    public final Key[] keys=new Key[COUNT];
    public final float left,right,top,bottom,whiteWidth,blackWidth,blackBottom;
    public TouchKeyboardLayout(float width,float height,float density){
        float margin=12*density;
        left=margin;right=width-margin;
        // Bellows occupy only the upper third; the playable keys get most of
        // the available instrument height, not a thin perspective strip.
        float proposedTop=Math.max(72*density,height*.33f);
        bottom=height-12*density;
        top=bottom-proposedTop<100*density?Math.max(48*density,bottom-100*density):proposedTop;
        whiteWidth=(right-left)/8;
        blackWidth=Math.min(whiteWidth*.72f,Math.max(48*density,whiteWidth*.62f));
        blackBottom=top+(bottom-top)*.55f;
        int natural=0;
        for(int n=0;n<COUNT;n++){
            if(!isBlack(n)){keys[n]=new Key(n,false,left+natural*whiteWidth,top,left+(natural+1)*whiteWidth,bottom);natural++;}
            else {float center=left+natural*whiteWidth;keys[n]=new Key(n,true,center-blackWidth/2,top,center+blackWidth/2,blackBottom);}
        }
    }
    public static boolean isBlack(int n){int p=n%12;return p==1||p==3||p==6||p==8||p==10;}
    public int hit(float x,float y){
        if(x<left||x>right||y<top||y>bottom)return -1;
        for(Key key:keys)if(key.black&&key.contains(x,y))return key.offset;
        for(Key key:keys)if(!key.black&&key.contains(x,y))return key.offset;
        return x==right?12:-1;
    }
    public int hitWithHysteresis(float x,float y,int previous,float density){
        int next=hit(x,y);
        if(next==previous||previous<0||next<0)return next;
        Key old=keys[previous];
        // Only adjacent naturals at their lower exposed faces use a small
        // boundary margin. Black/white transitions remain exact and immediate.
        if(!old.black&&!keys[next].black&&y>blackBottom+4*density&&
           x>=old.left-3*density&&x<=old.right+3*density)return previous;
        return next;
    }
}
