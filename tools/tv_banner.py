from PIL import Image, ImageDraw, ImageFont
W,H=640,360
bg=Image.new("RGBA",(W,H),(6,8,13,255))
def blob(cx,cy,r,col,op):
    g=Image.radial_gradient("L").resize((2*r,2*r))
    a=g.point(lambda v:int(max(0,255-v*1.45)*op))
    m=Image.new("L",(W,H),0); m.paste(a,(cx-r,cy-r))
    layer=Image.new("RGBA",(W,H),col+(0,)); layer.putalpha(m)
    bg.alpha_composite(layer)
blob(110,30,340,(91,140,255),0.42)
blob(580,230,320,(255,45,69),0.46)
blob(220,340,280,(122,92,255),0.38)
def cat(px):
    """le chat du logo dessiné directement (mêmes formes que assets/logo.svg) sur fond transparent : plus de carré autour"""
    S=4; N=100*S
    im=Image.new("RGBA",(N,N),(0,0,0,0))
    c0=(255,45,69); c1=(139,0,0)
    grad=Image.new("RGBA",(N,N)); gp=grad.load()
    for y in range(N):
        for x in range(N):
            t=(x+y)/(2*N)
            gp[x,y]=(int(c0[0]+(c1[0]-c0[0])*t),int(c0[1]+(c1[1]-c0[1])*t),int(c0[2]+(c1[2]-c0[2])*t),255)
    mask=Image.new("L",(N,N),0); md=ImageDraw.Draw(mask)
    def ell(d,cx,cy,rx,ry,fill): d.ellipse(((cx-rx)*S,(cy-ry)*S,(cx+rx)*S,(cy+ry)*S),fill=fill)
    ell(md,50,62,28,24,255); ell(md,50,38,22,20,255)
    im.paste(grad,(0,0),mask)
    d=ImageDraw.Draw(im)
    def poly(pts,col): d.polygon([(x*S,y*S) for x,y in pts],fill=col)
    dark=(107,0,0,255); red=(255,45,69,255); ink=(6,6,16,255)
    poly([(30,24),(22,6),(40,18)],dark); poly([(32,22),(26,10),(38,19)],red)
    poly([(70,24),(78,6),(60,18)],dark); poly([(68,22),(74,10),(62,19)],red)
    ell(d,42,36,5,6,ink); ell(d,58,36,5,6,ink)
    hl=Image.new("RGBA",(N,N),(0,0,0,0)); hd=ImageDraw.Draw(hl)
    ell(hd,43.5,34,1.5,2,(255,255,255,153)); ell(hd,59.5,34,1.5,2,(255,255,255,153))
    im.alpha_composite(hl)
    d=ImageDraw.Draw(im)
    ell(d,50,43,3,2,ink)
    for (x1,y1,x2,y2) in [(47,43,28,40),(47,44,28,46),(53,43,72,40),(53,44,72,46)]:
        d.line([(x1*S,y1*S),(x2*S,y2*S)],fill=ink,width=int(1.2*S))
        for (cx,cy) in [(x1,y1),(x2,y2)]: ell(d,cx,cy,0.6,0.6,ink)
    def q(p0,p1,p2,n=14): return [((1-t)**2*p0[0]+2*(1-t)*t*p1[0]+t*t*p2[0],(1-t)**2*p0[1]+2*(1-t)*t*p1[1]+t*t*p2[1]) for t in [i/n for i in range(n+1)]]
    tail=q((78,72),(92,60),(88,45))+q((88,45),(84,38),(80,42))+q((80,42),(84,55),(76,68))
    poly(tail,dark)
    ell(d,36,83,10,6,dark); ell(d,64,83,10,6,dark)
    return im.resize((px,px),Image.LANCZOS)
ic=cat(170)
f=ImageFont.truetype("assets/fonts/Inter.ttf",66)
f.set_variation_by_axes([32,800])
t="MinouFlix"; d=ImageDraw.Draw(bg)
tw=d.textlength(t,font=f); gap=14; total=ic.width+gap+tw
x=(W-total)/2
bg.alpha_composite(ic,(int(x),(H-ic.height)//2))
d.text((x+ic.width+gap,H/2+2),t,font=f,fill=(255,255,255,255),anchor="lm")
bg.convert("RGB").save(__import__("sys").argv[1])
