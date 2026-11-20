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
ic=Image.open("assets/icon.png").convert("RGBA")
px=ic.load()
for y in range(ic.height):
    for x in range(ic.width):
        r,g,b,a=px[x,y]
        d=max(r,g,b)
        if d<40: px[x,y]=(r,g,b,0)
        elif d<90: px[x,y]=(r,g,b,int(a*(d-40)/50))
ic.thumbnail((170,170))
f=ImageFont.truetype("assets/fonts/Inter.ttf",66)
f.set_variation_by_axes([32,800])
t="MinouFlix"; d=ImageDraw.Draw(bg)
tw=d.textlength(t,font=f); gap=14; total=ic.width+gap+tw
x=(W-total)/2
bg.alpha_composite(ic,(int(x),(H-ic.height)//2))
d.text((x+ic.width+gap,H/2+2),t,font=f,fill=(255,255,255,255),anchor="lm")
bg.convert("RGB").save(__import__("sys").argv[1])
