package com.mordor.trolrubi

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.media.AudioManager
import android.media.ToneGenerator
import android.content.SharedPreferences
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
    private var weaponIndex = 0
    private var darkMagic = 0f
    private val weapons = listOf("MACHADO", "ESPADA", "MARTELO", "CAJADO SOMBRIO")
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
    private val prefs: SharedPreferences = context.getSharedPreferences("mordor_settings", Context.MODE_PRIVATE)
    private var settingsOpen = false
    private var settingsPage = 0
    private var soundOn = prefs.getBoolean("sound", true)
    private var musicOn = prefs.getBoolean("music", true)
    private var effectsOn = prefs.getBoolean("effects", true)
    private var quality = prefs.getInt("quality", 2).coerceIn(0, 2)
    private var joystickScale = prefs.getFloat("stick_scale", 1f).coerceIn(.75f, 1.35f)
    private var buttonScale = prefs.getFloat("button_scale", 1f).coerceIn(.8f, 1.25f)
    private var sensitivity = prefs.getFloat("sensitivity", 1f).coerceIn(.6f, 1.5f)
    private var tone: ToneGenerator? = try { ToneGenerator(AudioManager.STREAM_MUSIC, 55) } catch (_: Throwable) { null }
    private fun saveSettings() {
        prefs.edit().putBoolean("sound", soundOn).putBoolean("music", musicOn).putBoolean("effects", effectsOn)
            .putInt("quality", quality).putFloat("stick_scale", joystickScale)
            .putFloat("button_scale", buttonScale).putFloat("sensitivity", sensitivity).apply()
    }
    private fun sfx(type: Int = ToneGenerator.TONE_PROP_BEEP) {
        if (soundOn && effectsOn) try { tone?.startTone(type, 90) } catch (_: Throwable) {}
    }

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
        leap=(leap-dt).coerceAtLeast(0f); dash=(dash-dt).coerceAtLeast(0f); darkMagic=(darkMagic-dt).coerceAtLeast(0f)
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
            if(attack>0f&&d<when(weaponIndex){2->145f;3->205f;else->130f})o.hp-=if(weaponIndex==2)2 else 1
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
        if(darkMagic>0f){p.color=Color.argb((95f*darkMagic/.8f).toInt().coerceIn(0,95),145,35,210);c.drawCircle(px,py-35f,235f*(1.15f-darkMagic),p);p.color=Color.argb(210,190,115,255);c.drawCircle(px,py-35f,28f+darkMagic*35f,p)}
        c.restore()
        boxText(c,"TROL DE RUBI",18f,18f,250f,74f)
        text(c,"VIDA ${hp.toInt()}   ORCS: $kills",30f,58f,15f,Color.WHITE)
        text(c,"DIA $day  •  %02d:%02d".format((time/60).toInt()%24,(time%60).toInt()),w-175f,34f,15f,Color.WHITE)
        text(c,"COMPANHEIROS: ${animals.count{it.tame}}",w-220f,58f,13f,Color.GREEN)
        controls(c)
        drawSettingsButton(c)
        if(settingsOpen) drawSettings(c)
        if(over){p.color=Color.argb(220,0,0,0);c.drawRect(0f,0f,w,h,p);center(c,"O TROL CAIU",w/2,h/2,34f,Color.WHITE);center(c,"TOQUE PARA RECOMECAR",w/2,h/2+35,18f,Color.YELLOW)}
    }
    private fun drawTroll(c:Canvas){
        val x=px;val y=py;val lift=if(leap>0)sin((1-leap/.6f)*PI).toFloat()*45f else 0f
        c.save();c.translate(0f,-lift);p.color=Color.rgb(48,83,52)
        c.drawOval(x-42,y-28,x+42,y+34,p);c.drawRoundRect(x-58,y-76,x+58,y+12,22f,22f,p);c.drawCircle(x,y-91,37f,p)
        p.color=Color.RED;c.drawCircle(x-14,y-98,6f,p);c.drawCircle(x+14,y-98,6f,p)
        p.color=Color.WHITE;c.drawCircle(x-14,y-98,2f,p);c.drawCircle(x+14,y-98,2f,p)
        p.color=Color.rgb(92,57,27)
        when(weaponIndex){
            0->{c.drawRoundRect(x+37,y-120,x+62,y+20,8f,8f,p);p.color=Color.LTGRAY;c.drawOval(x+45,y-135,x+85,y-92,p)}
            1->{c.drawRoundRect(x+43,y-145,x+53,y+20,5f,5f,p);p.color=Color.LTGRAY;c.drawRect(x+35,y-135,x+61,y-128,p)}
            2->{c.drawRoundRect(x+37,y-120,x+62,y+20,8f,8f,p);p.color=Color.GRAY;c.drawRoundRect(x+25,y-145,x+76,y-105,7f,7f,p)}
            else->{p.color=Color.rgb(65,35,90);c.drawRoundRect(x+43,y-145,x+55,y+20,5f,5f,p);p.color=Color.rgb(175,75,255);c.drawCircle(x+49,y-148,22f,p);p.color=Color.argb(110,185,80,255);c.drawCircle(x+49,y-148,31f,p)}
        }
        center(c,weapons[weaponIndex],x,y+58f,12f,if(weaponIndex==3)Color.rgb(205,145,255) else Color.WHITE)
        if(shield>0){p.color=Color.argb(100,150,210,160);c.drawCircle(x,y-45,80f,p)}
        c.restore()
    }
    private fun drawSettingsButton(c:Canvas) {
        val w=width.toFloat()
        p.color=Color.argb(210,28,25,22);c.drawRoundRect(w-92f,76f,w-20f,126f,10f,10f,p)
        center(c,"CFG",w-56f,108f,17f,Color.rgb(225,190,115))
    }
    private fun drawSettings(c:Canvas) {
        val w=width.toFloat();val h=height.toFloat()
        p.color=Color.argb(225,8,9,10);c.drawRect(0f,0f,w,h,p)
        p.color=Color.rgb(105,65,35);c.drawRoundRect(w*.18f,h*.10f,w*.82f,h*.90f,18f,18f,p)
        p.color=Color.rgb(24,25,23);c.drawRoundRect(w*.185f,h*.105f,w*.815f,h*.895f,16f,16f,p)
        center(c,"CRONICAS DE MORDOR",w/2,h*.18f,25f,Color.rgb(220,178,105))
        center(c,"CONFIGURACOES",w/2,h*.24f,17f,Color.WHITE)
        listOf("CONTROLES","AUDIO","VIDEO").forEachIndexed { i,label ->
            val x=w*.25f+i*w*.17f
            p.color=if(settingsPage==i)Color.rgb(125,75,35) else Color.rgb(48,48,44)
            c.drawRoundRect(x,h*.29f,x+w*.15f,h*.37f,8f,8f,p)
            center(c,label,x+w*.075f,h*.34f,12f,Color.WHITE)
        }
        val rows=when(settingsPage){
            0->listOf("Tamanho joystick: "+(joystickScale*100).toInt()+"%","Tamanho botoes: "+(buttonScale*100).toInt()+"%","Sensibilidade: "+(sensitivity*100).toInt()+"%")
            1->listOf("Audio geral: "+(if(soundOn)"LIGADO" else "DESLIGADO"),"Efeitos: "+(if(effectsOn)"LIGADOS" else "DESLIGADOS"),"Musica: "+(if(musicOn)"LIGADA" else "DESLIGADA"))
            else->listOf("Qualidade: "+listOf("BAIXA","MEDIA","ALTA")[quality],"Efeitos visuais: "+(if(quality>0)"LIGADOS" else "REDUZIDOS"),"Desempenho: "+(if(quality==0)"MAXIMO FPS" else "EQUILIBRADO"))
        }
        rows.forEachIndexed { i,label ->
            val y=h*.47f+i*h*.105f
            p.color=Color.rgb(45,44,39);c.drawRoundRect(w*.25f,y-25f,w*.75f,y+20f,8f,8f,p)
            text(c,label,w*.28f,y+6f,15f,Color.WHITE)
            center(c,if(settingsPage==0)"−       +" else "ALTERAR",w*.69f,y+6f,14f,Color.rgb(230,190,120))
        }
        p.color=Color.rgb(110,55,35);c.drawRoundRect(w*.40f,h*.82f,w*.60f,h*.88f,8f,8f,p)
        center(c,"VOLTAR AO JOGO",w/2,h*.86f,13f,Color.WHITE)
    }
    private fun adjustSetting(row:Int,direction:Int) {
        when(settingsPage) {
            0 -> when(row) {
                0 -> joystickScale=(joystickScale+direction*.1f).coerceIn(.75f,1.35f)
                1 -> buttonScale=(buttonScale+direction*.1f).coerceIn(.8f,1.25f)
                2 -> sensitivity=(sensitivity+direction*.1f).coerceIn(.6f,1.5f)
            }
            1 -> when(row) { 0->soundOn=!soundOn;1->effectsOn=!effectsOn;2->musicOn=!musicOn }
            else -> quality=(quality+1)%3
        }
        saveSettings();sfx()
    }
    private fun stickCenterX():Float= (78f*joystickScale+20f).coerceAtMost(width*.28f)
    private fun stickCenterY():Float= height-(78f*joystickScale+20f)
    private fun actionRect(i:Int):RectF {
        val size=(min(width*.145f,height*.19f).coerceAtLeast(43f)*buttonScale).coerceAtMost(76f)
        val gap=7f
        val col=i%3;val row=i/3
        val right=width-12f
        val left=(right-size)-(2-col)*(size+gap)
        val top=height-12f-size-row*(size+gap)
        return RectF(left,top,left+size,top+size)
    }
    private fun controls(c:Canvas){
        val cx=stickCenterX();val cy=stickCenterY();val stickR=70f*joystickScale
        p.color=Color.argb(95,220,225,220);c.drawCircle(cx,cy,stickR,p)
        p.color=Color.WHITE;c.drawCircle(cx+sx*40f*joystickScale,cy+sy*40f*joystickScale,25f*joystickScale,p)
        val labels=listOf("PULAR","DEFESA","ARMA","ATAQUE","MAGIA","ADESTRAR","ESQUIVA")
        labels.forEachIndexed{i,label->
            val r=actionRect(i);val cx2=r.centerX();val cy2=r.centerY()
            p.color=when(i){2->Color.rgb(75,55,110);3->Color.rgb(145,45,35);4->Color.rgb(105,35,155);5->Color.rgb(30,110,65);else->Color.rgb(38,48,43)}
            c.drawOval(r,p)
            p.color=Color.argb(100,255,255,255);c.drawOval(RectF(r.left+3,r.top+3,r.right-3,r.bottom-3),p)
            center(c,label,cx2,cy2+4f,(r.width()*.17f).coerceAtLeast(8f),Color.WHITE)
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
                if(settingsOpen) {
                    if(y>=h*.29f && y<=h*.37f) settingsPage=when { x<w*.42f->0; x<w*.59f->1; else->2 }
                    else if(y>=h*.82f && y<=h*.90f) { settingsOpen=false;saveSettings() }
                    else if(y>=h*.43f && y<=h*.75f) {
                        val row=((y-h*.43f)/(h*.105f)).toInt().coerceIn(0,2)
                        adjustSetting(row,if(settingsPage==0 && x<w*.5f) -1 else 1)
                    }
                    return true
                }
                if(x>w-105f && y<145f){settingsOpen=true;settingsPage=0;sfx();return true}
                if(x<w*.34f&&y>h*.55f){pointer=e.getPointerId(i);stick(x,y);return true}
                val hit=(0..6).firstOrNull{actionRect(it).contains(x,y)}
                if(hit!=null)when(hit){
                    0->{leap=.6f;sfx(ToneGenerator.TONE_PROP_ACK)}
                    1->{shield=.7f;sfx(ToneGenerator.TONE_PROP_NACK)}
                    2->{weaponIndex=(weaponIndex+1)%weapons.size;sfx()}
                    3->{attack=.3f;sfx(ToneGenerator.TONE_PROP_ACK);val o=orcs.minByOrNull{hypot(it.x-px,it.y-py)};if(o!=null&&hypot(o.x-px,o.y-py)<when(weaponIndex){2->145f;3->205f;else->140f})o.hp-=if(weaponIndex==2)2 else 1}
                    4->{if(weaponIndex==3){darkMagic=.8f;orcs.filter{hypot(it.x-px,it.y-py)<235f}.forEach{it.hp-=3};sfx(ToneGenerator.TONE_PROP_NACK)}else{sfx(ToneGenerator.TONE_PROP_NACK)}}
                    5->{animals.filter{!it.tame}.minByOrNull{hypot(it.x-px,it.y-py)}?.let{if(hypot(it.x-px,it.y-py)<160f)it.tame=true};sfx()}
                    6->{dash=.4f;sfx()}
                }
            }
            MotionEvent.ACTION_MOVE->{for(i in 0 until e.pointerCount)if(e.getPointerId(i)==pointer)stick(e.getX(i),e.getY(i))}
            MotionEvent.ACTION_UP,MotionEvent.ACTION_POINTER_UP,MotionEvent.ACTION_CANCEL->{if(e.getPointerId(e.actionIndex)==pointer){pointer=-1;sx=0f;sy=0f}}
        };return true
    }
    private fun stick(x:Float,y:Float){sx=(((x-stickCenterX())/(70f*joystickScale))*sensitivity).coerceIn(-1f,1f);sy=(((y-stickCenterY())/(70f*joystickScale))*sensitivity).coerceIn(-1f,1f)}
    private fun reset(){hp=100f;px=0f;py=0f;kills=0;over=false;orcs.clear();repeat(6){spawn()};animals.forEach{it.tame=false}}
}
