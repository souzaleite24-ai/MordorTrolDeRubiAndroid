package com.mordor.trolrubi

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.util.Log
import android.view.MotionEvent
import android.view.View
import kotlin.math.*
import kotlin.random.Random

private data class Orc(var x: Float, var y: Float, var hp: Int = 3)
private data class Animal(var x: Float, var y: Float, val kind: String, var tame: Boolean = false)

class GameView(context: Context) : View(context) {
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rng = Random(12)
    private val orcs = mutableListOf<Orc>()
    private val animals = mutableListOf<Animal>()
    private val rocks = mutableListOf<RectF>()
    private var px = 0f; private var py = 0f
    private var sx = 0f; private var sy = 0f
    private var hp = 100f; private var kills = 0
    private var attack = 0f; private var shield = 0f; private var leap = 0f; private var dash = 0f
    private var crouch = false; private var over = false
    private var time = 480f; private var day = 1
    private var last = System.nanoTime()
    private var pointer = -1
    init {
        repeat(45) {
            val x = rng.nextFloat()*1700f-850f; val y = rng.nextFloat()*1100f-550f
            rocks.add(RectF(x,y,x+30+rng.nextFloat()*65,y+18+rng.nextFloat()*35))
        }
        animals.add(Animal(-210f,-80f,"LOBO"))
        animals.add(Animal(210f,120f,"CERVO"))
        animals.add(Animal(-100f,240f,"RAPOSA"))
        repeat(6) { spawn() }
    }
    private fun spawn() {
        val a=rng.nextFloat()*6.283f; val r=380f+rng.nextFloat()*170f
        orcs.add(Orc(px+cos(a)*r,py+sin(a)*r))
    }
    private var renderError: String? = null

    override fun onDraw(c: Canvas) {
        super.onDraw(c)
        try {
            val now=System.nanoTime()
            val dt=((now-last)/1e9).toFloat().coerceIn(0f,.04f)
            last=now
            update(dt)
            render(c)
        } catch (t: Throwable) {
            Log.e("MordorTrolRubi", "Falha durante a inicializacao/renderizacao do jogo", t)
            renderError = t.javaClass.simpleName + ": " + (t.message ?: "sem detalhes")
            p.color = Color.BLACK
            c.drawColor(Color.BLACK)
            p.color = Color.WHITE
            p.textSize = 22f
            p.typeface = Typeface.DEFAULT_BOLD
            c.drawText("ERRO AO INICIAR O JOGO", 24f, 48f, p)
            p.textSize = 14f
            c.drawText(renderError!!.take(100), 24f, 78f, p)
            c.drawText("Envie uma foto desta tela para a equipe.", 24f, 108f, p)
        }
        postInvalidateOnAnimation()
    }
    private fun update(dt: Float) {
        if(over) return
        time+=dt*3f; if(time>=1440f){time-=1440f;day++}
        attack=(attack-dt).coerceAtLeast(0f); shield=(shield-dt).coerceAtLeast(0f)
        leap=(leap-dt).coerceAtLeast(0f); dash=(dash-dt).coerceAtLeast(0f)
        val speed=when {dash>0f->430f;crouch->105f;else->245f}
        px+=sx*speed*dt; py+=sy*speed*dt
        animals.forEach { a ->
            val dx=px-a.x; val dy=py-a.y; val d=hypot(dx,dy).coerceAtLeast(1f)
            if(a.tame && d>90f){a.x+=dx/d*125f*dt;a.y+=dy/d*125f*dt}
            else if(a.kind=="LOBO" && d<260f){a.x+=dx/d*90f*dt;a.y+=dy/d*90f*dt;if(d<42f&&shield<=0&&leap<=0)hp-=6f*dt}
        }
        orcs.forEach { o ->
            val dx=px-o.x; val dy=py-o.y; val d=hypot(dx,dy).coerceAtLeast(1f)
            if(d>50f){o.x+=dx/d*78f*dt;o.y+=dy/d*78f*dt}
            else if(shield<=0f&&leap<=0f) hp-=11f*dt
            if(attack>0f&&d<130f)o.hp-=1
        }
        val dead=orcs.filter{it.hp<=0}; kills+=dead.size; orcs.removeAll(dead.toSet())
        if(orcs.isEmpty())repeat(6+kills/5){spawn()}
        if(hp<=0f){hp=0f;over=true}
    }
    private fun render(c: Canvas) {
        val w=width.toFloat(); val h=height.toFloat(); val night=time<360f||time>1140f
        c.drawColor(if(night)Color.rgb(12,14,35) else Color.rgb(105,58,45))
        p.color=if(night)Color.LTGRAY else Color.rgb(220,35,25); c.drawCircle(w*.8f,h*.18f,28f,p)
        p.color=Color.rgb(37,47,34); c.drawRect(0f,h*.5f,w,h,p)
        c.save();c.translate(w/2f-px*.72f,h/2f-py*.72f)
        rocks.forEachIndexed{i,r->p.color=if(i%4==0)Color.rgb(95,54,33) else Color.rgb(69,70,55);c.drawRoundRect(r,5f,5f,p)}
        animals.forEach{a->
            p.color=if(a.tame)Color.GREEN else if(a.kind=="LOBO")Color.DKGRAY else if(a.kind=="CERVO")Color.rgb(120,145,95) else Color.rgb(180,100,45)
            c.drawOval(a.x-25,a.y-16,a.x+25,a.y+18,p);c.drawCircle(a.x,a.y-18,14f,p)
            if(a.tame){p.color=Color.YELLOW;c.drawCircle(a.x,a.y-40,5f,p)}
        }
        orcs.forEach{o->p.color=Color.rgb(110,85,54);c.drawRoundRect(o.x-22,o.y-35,o.x+22,o.y+30,10f,10f,p);p.color=Color.RED;c.drawCircle(o.x-8,o.y-22,3f,p);c.drawCircle(o.x+8,o.y-22,3f,p)}
        drawTroll(c)
        c.restore()
        boxText(c,"TROL DE RUBI",18f,18f,250f,74f)
        text(c,"VIDA ${hp.toInt()}   ORCS: $kills",30f,58f,15f,Color.WHITE)
        text(c,"DIA $day  •  %02d:%02d".format((time/60).toInt()%24,(time%60).toInt()),w-175f,34f,15f,Color.WHITE)
        text(c,"COMPANHEIROS: ${animals.count{it.tame}}",w-220f,58f,13f,Color.GREEN)
        controls(c)
        if(over){p.color=Color.argb(220,0,0,0);c.drawRect(0f,0f,w,h,p);center(c,"O TROL CAIU",w/2,h/2,34f,Color.WHITE);center(c,"TOQUE PARA RECOMECAR",w/2,h/2+35,18f,Color.YELLOW)}
    }
    private fun drawTroll(c:Canvas){
        val x=px;val y=py;val lift=if(leap>0)sin((1-leap/.6f)*PI).toFloat()*45f else 0f
        c.save();c.translate(0f,-lift);p.color=Color.rgb(48,83,52)
        c.drawOval(x-42,y-28,x+42,y+34,p);c.drawRoundRect(x-58,y-76,x+58,y+12,22f,22f,p);c.drawCircle(x,y-91,37f,p)
        p.color=Color.RED;c.drawCircle(x-14,y-98,6f,p);c.drawCircle(x+14,y-98,6f,p)
        p.color=Color.WHITE;c.drawCircle(x-14,y-98,2f,p);c.drawCircle(x+14,y-98,2f,p)
        p.color=Color.rgb(92,57,27);c.drawRoundRect(x+37,y-120,x+62,y+20,8f,8f,p);c.drawCircle(x+50,y-115,20f,p)
        if(shield>0){p.color=Color.argb(100,150,210,160);c.drawCircle(x,y-45,80f,p)}
        c.restore()
    }
    private fun controls(c:Canvas){
        val w=width.toFloat();val h=height.toFloat()
        p.color=Color.argb(90,220,225,220);c.drawCircle(100f,h-100f,70f,p)
        p.color=Color.WHITE;c.drawCircle(100f+sx*40,h-100f+sy*40,25f,p)
        val labels=listOf("PULAR","ABAIXAR","DEFENDER","ATACAR","ADESTRAR","ESQUIVA")
        labels.forEachIndexed{i,s->
            val x=w-250f+(i%3)*82f;val y=h-130f+(i/3)*62f
            p.color=when(i){2->Color.rgb(50,100,60);3->Color.rgb(130,45,35);4->Color.rgb(30,110,65);else->Color.rgb(38,48,43)}
            c.drawRoundRect(x,y,x+76,y+54,10f,10f,p);center(c,s,x+38,y+33,10f,Color.WHITE)
        }
    }
    private fun boxText(c:Canvas,s:String,l:Float,t:Float,r:Float,b:Float){p.color=Color.argb(180,5,10,8);c.drawRoundRect(l,t,r,b,12f,12f,p);text(s,l+12,t+25,16f,Color.WHITE)}
    private fun text(s:String,x:Float,y:Float,size:Float,color:Int){p.color=color;p.textSize=size;p.typeface=Typeface.DEFAULT_BOLD}
    private fun text(c:Canvas,s:String,x:Float,y:Float,size:Float,color:Int){p.color=color;p.textSize=size;p.typeface=Typeface.DEFAULT_BOLD;c.drawText(s,x,y,p)}
    private fun center(c:Canvas,s:String,x:Float,y:Float,size:Float,color:Int){p.textSize=size;p.typeface=Typeface.DEFAULT_BOLD;text(c,s,x-p.measureText(s)/2,y,size,color)}
    override fun onTouchEvent(e:MotionEvent):Boolean{
        val w=width.toFloat();val h=height.toFloat()
        when(e.actionMasked){
            MotionEvent.ACTION_DOWN,MotionEvent.ACTION_POINTER_DOWN->{
                val i=e.actionIndex;val x=e.getX(i);val y=e.getY(i)
                if(over){reset();return true}
                if(x<w*.34f&&y>h*.55f){pointer=e.getPointerId(i);stick(x,y);return true}
                val col=((x-(w-250f))/82f).toInt();val row=((y-(h-130f))/62f).toInt()
                if(col in 0..2&&row in 0..1)when(row*3+col){
                    0->leap=.6f;1->crouch=!crouch;2->shield=.7f;3->{attack=.3f;val o=orcs.minByOrNull{hypot(it.x-px,it.y-py)};if(o!=null&&hypot(o.x-px,o.y-py)<140f)o.hp--};4->animals.filter{!it.tame}.minByOrNull{hypot(it.x-px,it.y-py)}?.let{if(hypot(it.x-px,it.y-py)<160f)it.tame=true};5->dash=.4f
                }
            }
            MotionEvent.ACTION_MOVE->{for(i in 0 until e.pointerCount)if(e.getPointerId(i)==pointer)stick(e.getX(i),e.getY(i))}
            MotionEvent.ACTION_UP,MotionEvent.ACTION_POINTER_UP,MotionEvent.ACTION_CANCEL->{if(e.getPointerId(e.actionIndex)==pointer){pointer=-1;sx=0f;sy=0f}}
        };return true
    }
    private fun stick(x:Float,y:Float){sx=((x-100f)/70f).coerceIn(-1f,1f);sy=((y-(height-100f))/70f).coerceIn(-1f,1f)}
    private fun reset(){hp=100f;px=0f;py=0f;kills=0;over=false;orcs.clear();repeat(6){spawn()};animals.forEach{it.tame=false}}
}
