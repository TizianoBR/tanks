pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
--tanks
--tbr

--this cart is for online play
--with pico-socket

--you can try the game here:
--https://tanks-thec.onrender.com

function _init()
 connect()

	plr_id=peek(0x5f81)
	
	copy_map(1)
	
 --constants
 
 --object sizes
 t_sz=6 --tank(side)
 b_sz=4 --bullet(side)
 m_sz=5 --mine(side)
 e_sz=32 --explosion(diameter)
 mt_sz=24 --mine trigger(diameter)
 w_sz=8 --breakable wall(side)
 
 --object speed
 t_spd=0.8
 b_spd=1
 
 --dynamic explosion colors
 expl_col={}
 for i=1,6 do
  add(expl_col,{9,2})
 end
 
 --lookup tables for sprite id
 --offset depending on direction
 s8={
  {1,false,false},
  {2,false,true},
  {0,false,true},
  {2,true,true},
  {1,true,false},
  {2,true,false},
  {0,false,false},
  {2,false,false}}

 s16={
  {1,false,false},
  {3,false,true},
  {2,false,true},
  {4,false,false},
  {0,false,true},
  {4,true,false},
  {2,true,true},
  {3,true,true},
  {1,true,false},
  {3,true,false},
  {2,true,false},
  {4,true,true},
  {0,false,false},
  {4,false,true},
  {2,false,false},
  {3,false,false}}
 
 --tank color paletes
 tank_pal={
  {8,2,13},
  {12,1,6},
  {11,3,13},
--  {10,9,5},
  {6,13,5},
  {13,5,6},
  {14,2,6}}
end

function _update()
 get_data()
 
 timer_tick()

 update_plr()
 update_bullets()
 update_mine()
 update_walls()
 
 upload_data()
end

function _draw()
 cls(15)
 map(0,0,0,0,16,16,1)
 ?plr_id
 
 --any elements at 0,0 are not
 --drawn. this happens in every
 --function
 draw_mines()
 draw_tanks()
 draw_bullets()
 draw_mine_explosions()
 draw_reticle()
end

--copies a screen onto the first
--section of the map. id 0 is
--where the map is copied to
function copy_map(map_id)
 for i=0,15 do
	 memcpy(0x2000+128*i,0x2000
	  +(16*(map_id%8))
	  +(2048*(map_id\8))
	  +128*i,16)
 end
 
 --set breakable wall coordinates
 local i=1
 for x=0,15 do for y=0,15 do
  if mget(x,y)==15 then
   walls[i]={x=x,y=y};i+=1
  end
 end end
 --create plr and upload walls
 spawn()
 upload_data()
end

--tracks the atribute "timer"
--for every object that has it
--and advances it
function timer_tick()
 for t in all(tanks) do
  if t.timer then
   if t.timer>=0 then
    t.timer-=1
   else
    t.timer=nil
   end
  end
 end
 
 for i in all(bullets) do
  for b in all(i) do
   if b.timer then
	   if b.timer>=0 then
	    b.timer-=1
	   else
	    b.timer=nil
	   end
	  end
  end
 end
 
 for m in all(mines) do
  if m.timer then
   if m.timer>=0 then
    m.timer-=1
   else
    m.timer=nil
   end
  end
 end
end
-->8
--netcode

--lookup table for better
--readability on gpio access
lookup={
 --tank data (*6)
 tank_x=0x5f82,
 tank_y=0x5f83,
 tank_dir=0x5f84,
 --mine data
 mine_x=0x5f85,
 mine_y=0x5f86,
 mine_state=0x5f87,
 --bullet data (*4)
 bull_x=0x5f88,
 bull_y=0x5f89,
 bull_dir_state=0x5f8a,
 
 --next tank starts at 0x5f94
 --last tank ends at 0x5fed
 
 --breakable walls (*16)
 --4 bits:x, 4 bits:y
 wall_coor=0x5fee,
 
 --last wall ends at 0x5ffd
 
 control=0x5ffe
}

--fetches data from gpio onto
--local tables for easy handling
function get_data()
 --get tanks
 tanks={}
 for i=0,5 do
  if i+1==plr_id then
   add(tanks,plr)
  else
	  add(tanks,{
	   x=peek(lookup.tank_x+18*i),
	   y=peek(lookup.tank_y+18*i),
	   dir=peek(lookup.tank_dir+18*i)
	    /16})
	 end
 end
 
 --get mines
 mines={}
 for i=0,5 do
  if i+1==plr_id then
   add(mines,mine)
  else
	  add(mines,{
	   x=peek(lookup.mine_x+18*i),
	   y=peek(lookup.mine_y+18*i),
	   explode=peek(lookup.mine_state
	    +18*i)==1})
  end
 end

 --get bullets
 bullets={}
 for i=0,5 do
  if i+1==plr_id then
   add(bullets,bull)
  else
	  local plr_bullets={}
	  for j=0,3 do
	   add(plr_bullets,{
	    x=peek(lookup.bull_x+
	     3*j+18*i),
	    y=peek(lookup.bull_y+
	     3*j+18*i),
	    --lower 3 bits
	    dir=peek(lookup.bull_dir_state
	     +3*j+18*i)/8,
	    --higher bit
	    explode=peek(lookup.bull_dir_state
	     +3*j+18*i)>=128})
	  end
	  add(bullets,plr_bullets)
	 end
 end

 --get breakable walls
 walls={}
 for i=0,15 do
	 add(walls,{
	  x=peek(lookup.wall_coor+i)
	   \16,
	  y=peek(lookup.wall_coor+i)
	   %16})
	end
end

--uploads data from local tables
--back to the gpio
function upload_data()
 --upload tank
 poke(lookup.tank_x+18*plr_id-18
  ,plr.x)
 poke(lookup.tank_y+18*plr_id-18
  ,plr.y)
 poke(lookup.tank_dir+18*plr_id-18
  ,flr(plr.dir*16))
 
 --upload mine
 poke(lookup.mine_x+18*plr_id-18
  ,mine.x)
 poke(lookup.mine_y+18*plr_id-18
  ,mine.y)
 poke(lookup.mine_state
  +18*plr_id-18,
  mine.explode and 1 or 0)
 
 --upload bullets
 for i=1,4 do
  if i>#bull then
   memset(lookup.bull_x+18*plr_id
	   -18+3*i-3,0,3)
  else
   local b=bull[i]
	  poke(lookup.bull_x+18*plr_id
	   -18+3*i-3,b.x)
	  poke(lookup.bull_y+18*plr_id
	   -18+3*i-3,b.y)
	  poke(lookup.bull_dir_state
	   +18*plr_id-18+3*i-3,
	   flr(b.dir*8)
	   +(b.explode
	   and 128 or 0))
	 end
 end
 
 --upload breakable walls
 if plr_id==1 then
  for i,w in ipairs(walls) do
   poke(lookup.wall_coor+i-1,
    w.x*16+w.y)
  end
 end
end

function connect()
 if peek(0x5f80)==0 then
	 poke(0x5f80,1)
	 poke(0x5f81,0)
	 run()
	end
	
 for i=1,10 do
  flip()
 end
 
 get_data()
 for i,t in ipairs(tanks) do
	 if t.x==0 and t.y==0 then
	  poke(0x5f81,i)
	  break
	 end
 end
end
-->8
--tank and entity functions

--input handler
function update_plr()
 if plr.timer==29 then
  --play death sfx
 end
 
 if plr.timer==0 then
  plr.x=255;plr.y=255
 end
 
 if not plr.timer then
	 if btn(⬆️) and
	  not btn(⬇️) then
	  move_plr(t_spd)
	 elseif btn(⬇️) and
	  not btn(⬆️) then
	  move_plr(-t_spd)
	 elseif btn(⬅️) and
	  not btn(➡️) then
	  plr.dir=(plr.dir+0.01)%1
	 elseif btn(➡️) and
	  not btn(⬅️) then
	  plr.dir=(plr.dir-0.01)%1
	 end
	 
	 --max 4 bullets per player
	 --at once
	 if btnp(❎) and #bull<4 then
	  add(bull,{
	   x=plr.x+cos(plr.dir)*7,
	   y=plr.y+sin(plr.dir)*7,
	   dir=plr.dir,
	   explode=false,
	   bounce=false})
	 end
	 
	 --max 1 mine per player at once
	 if btnp(🅾️) and mine.x==0
	  and mine.y==0 then
	  mine={x=plr.x,y=plr.y,
	   explode=false,ready=false}
	 end
	 
	 local e=e_collide(plr,t_sz)
	 if e[1]=="b" or e[1]=="e" then
	  plr.timer=30
	 end
 end
end

--movement handler
function move_plr(speed)
 local pos=plr.x
 plr.x+=cos(plr.dir)*speed
 if m_collide(plr,t_sz,0) then
  plr.x=pos
 end
 
 pos=plr.y
 plr.y+=sin(plr.dir)*speed
 if m_collide(plr,t_sz,0) then
  plr.y=pos
 end
end

--set local varibles for self
function spawn()
 for i=1,14 do
  for j=1,14 do
   if mget(i,j)==plr_id then
    local x=i*8+4
    local y=j*8+4
			 plr={
			  x=x,
			  y=y,
			  dir=atan2(64-x,64-y)}
			end
		end
	end
 bull={}
 mine={x=0,y=0,explode=false}
end

--map collision
--flag 0 for plr
--flag 1 for bullets
function m_collide(e,size,flag)
 size/=2
 for i=-1,1,2 do for j=-1,1,2 do
   if fget(mget((e.x+size*i)/8
    ,(e.y+size*j)/8),flag) then
		  return true
		 end
 end end
 return false
end

--entity collision
--returns a table with the type
--of entity and the entity
function e_collide(e,size)
 for i in all(bullets) do
  for b in all(i) do
   if b~=e and
    e_collide_sqr(e,size,b,b_sz)
    then return {"b",b} end
  end
 end
 
 for m in all(mines) do
  if not m.explode then
   if m~=e and
    e_collide_sqr(e,size,m,m_sz)
    then return {"m",m} end
  else
   if e_collide_cir(e,size,m,e_sz)
    then return {"e",m} end
  end
 end
 
 for t in all(tanks) do
  if t~=e and
   e_collide_sqr(e,size,t,t_sz)
   then return {"t",t} end
 end
 
 return {""}
end

--square-square collision
function e_collide_sqr(e1,size1,
 e2,size2,second)
 size1/=2;size2/=2
 for i=-1,1,2 do for j=-1,1,2 do
  local x=e1.x+size1*i
  local y=e1.y+size1*j
  if x>=e2.x-size2 and
   x<=e2.x+size2 and
   y>=e2.y-size2 and
   y<=e2.y+size2 then
   return true
  end
 end end
 
 --invert e1, e2 and try again
 if not second then
  return e_collide_sqr(e2,size2,
   e1,size1,true)
 end
 
 return false
end

--square-circle collision
function e_collide_cir(e1,size1,
 e2,size2)
 size1/=2
 for i=-1,1,2 do for j=-1,1,2 do
  if ((e1.x+size1*i-e2.x)^2+
   (e1.y+size1*j-e2.y)^2)^0.5
   <=size2/2 then
   return true end
 end end
 
 return false
end
-->8
--draw to screen

function draw_tanks()
 for i,t in ipairs(tanks) do
  if t.x~=0 and t.y~=0 then
	  pal(13,tank_pal[i][3])
	  pal(8,tank_pal[i][1])
	  pal(2,tank_pal[i][2])
	  
		 local dir16=flr(
		  ((t.dir+0.03125)%1)*16)+1
		 spr(1+s16[dir16][1],
		  t.x-4,t.y-4,1,1,
		  s16[dir16][2],s16[dir16][3])
	  
	  pal()
  end
 end
end

function draw_bullets()
 for i in all(bullets) do
  for b in all(i) do
   if b.x~=0 and b.y~=0 then
    if b.explode then
     spr(16,b.x-4,b.y-4)
    else
			  local dir8=flr(
				  ((b.dir+0.0625)%1)*8)+1
			  spr(6+s8[dir8][1],
			   b.x-4,b.y-4,1,1,
			   s8[dir8][2],s8[dir8][3])
		  end
	  end
	 end
 end
end

function draw_mines()
 for m in all(mines) do
  if m.x~=0 and m.y~=0 and 
   not m.explode then
	  spr(9,m.x-4,m.y-4)
  end
 end
end

function draw_mine_explosions()
 for i,m in ipairs(mines) do
  if m.x~=0 and m.y~=0 and 
   m.explode then
   if expl_col[i][2]==1 then
	   expl_col[i][2]=2
		  expl_col[i][1]=
		   expl_col[i][1]==9
		   and 7 or 9
		 else
		  expl_col[i][2]-=1
		 end
		 
   circfill(m.x,m.y,e_sz/2,
    expl_col[i][1])
  end
 end
end

function draw_reticle()
 pal(13,tank_pal[plr_id][3])
 pal(8,tank_pal[plr_id][1])
 pal(2,tank_pal[plr_id][2])
 
 if not plr.timer then
	 pset(plr.x+cos(plr.dir)*9,
	  plr.y+sin(plr.dir)*9,8)
	 spr(0,plr.x+cos(plr.dir-0.005)
	  *17-4,
	  plr.y+sin(plr.dir-0.005)*17-4)
 end
 
 pal()
end
-->8
--bullets, mine and walls

function update_bullets()
 for b in all(bull) do
  if not b.timer then
   move_bullet(b)
   local e=e_collide(b,b_sz)
   if e[1]~="" then
    b.x=e[2].x;b.y=e[2].y
    if e[1]=="t" then b.timer=30
    else b.timer=15
    end
    b.explode=true
   end
  elseif b.timer==0 then
   del(bull,b)
  end
 end
end

--move and reflect
function move_bullet(b)
 local pos=b.x
 b.x+=cos(b.dir)*b_spd
 if m_collide(b,b_sz,1) then
  if b.bounce then
   b.timer=15
   b.explode=true
  else
   --reflect on x
   b.x+=(pos-b.x)*2
   b.dir=((-((b.dir-0.25)%1))
    +0.25)%1
   b.bounce=true
  end
 end
 
 pos=b.y
 b.y+=sin(b.dir)*b_spd
 if m_collide(b,b_sz,1) then
  if b.bounce then
   b.timer=15
   b.explode=true
  else
   --reflect on y
   b.y+=(pos-b.y)*2
   b.dir=(-b.dir)%1
   b.bounce=true
  end
 end
end

function update_mine()
 if not mine.timer then
  if not mine.ready then
   --wait until the player
   --leaves the explosion area
   --before fully activating
   if not e_collide_cir(plr,
    t_sz,mine,e_sz) then
    mine.ready=true
   end
  elseif mine.x~=0 and
   mine.y~=0 then
   --explode when any tank is
   --close enough
   for t in all(tanks) do
    if t.x~=0 and t.y~=0 and
     e_collide_cir(plr,t_sz,
	    mine,mt_sz) then
	    mine.timer=30
	    mine.explode=true
	   end
	  end
  end
  
  local e=e_collide(mine,m_sz)
  if e[1]=="b" and e[2].x~=0
   and e[2].y~=0 then
   mine.timer=30
   mine.explode=true
  end
 elseif mine.timer==0 then
  mine={x=0,y=0,explode=false}
 end
end

function update_walls()
 --delete exploded walls
 if plr_id==1 then
	 for w in all(walls) do
	  for m in all(mines) do
	   --fix coordinates for
	   --collision calculation
	   w.x=w.x*8+4;w.y=w.y*8+4
	   
	   if m.explode and
	    e_collide_cir(w,w_sz,m,e_sz)
	    then
	    w.x=0;w.y=0
	   end
	   
	   --reset coordinates
	   w.x=w.x\8;w.y=w.y\8
	  end
	 end
 end
 
 --remove deleted walls form map
 for x=0,15 do for y=0,15 do
  if mget(x,y)==15 then
   local found=false
   for w in all(walls) do
    if w.x==x and w.y==y then
     found=true
    end
   end
   if (not found) mset(x,y,0)
  end
 end end
end
__gfx__
0000000000000000000000000002220002222000022088000000000000000000000000000d0000d0444444444444444444444444444444440000000011111111
0800008002200220022222200008822002882222028dd8800000000000ddd0000000d000d6d99d6d499999944999999999999999999999940000000012122221
00800800028888200288882000888822008888820288dd220dddddd000d66d00000d6d000d9aa9d0496996944969999999699699999996940055550012211221
0000000002888820008888d828888882008888d0228888820d6666d000d666d000d666d009aaaa90499999944999999999999999999999940555555012222121
0000000002888820008888d82888888208888dd8288888220d6666d000d666d00d6666d009aaaa90499999944999969999999999996999940555555012222221
00800800028888200288882022888dd028888d882888882000d66d0000d66d0000d66d000d9aa9d0499999944999999449999994499999940055550011111111
08000080022dd2200222222002288d882222828022008820000dd00000ddd000000dd000d6d99d6d499999944999999449999994499999940000000012212221
0000000000088000000000000022208000022200000002200000000000000000000000000d0000d0499999944999999449999994499999940000000011111111
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999449999994499999940000000000000000
00550000000000000000000000000000000000000000000000000000000000000000000000000000499999944969969999699699996996940000000000000000
05555000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
05556600000000000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
00566660000000000000000000000000000000000000000000000000000000000000000000000000499999944969969999699699996996940000000000000000
00066660000000000000000000000000000000000000000000000000000000000000000000000000499999944999999449999994499999940000000000000000
00006600000000000000000000000000000000000000000000000000000000000000000000000000499999944999999449999994499999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999449999994499999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999449999994499999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999969999999999996999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000496996944969999999699699999996940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444444444444444444440000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444444444444444444440000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444444444444444444440000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000496996944999999999999999999999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944969969999999999996996940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444444444444444444440000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444444444444444444440000000000000000
__label__
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff222222ffffffffff8ffff8fffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff288882fffffffffff8ff8ffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8888d8ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8888d8fffff8ffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff288882fffffffffff8ff8ffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff222222ffffffffff8ffff8fffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff

__gff__
0000000000000000000003030303010300000000000000000000030303030000000000000000000000000303030300000000000000000000000003030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000000000000b3c3c3c3c3c3c3c3c3c3c3c0c3c3c0d0b3c3c3c3c3c3c3c3c3c3c3c3c3c3c0d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000000e0000000000002a00001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000000e0000000000000f00061a1a00000000000400000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000200000a0003000000003a00001a1a0000000a000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000001a0000000000000000001a1a0002002a0f0f3b3c3c3c3d0000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001b3c3d00002b3d0f0f3b3d0e0000001a1a0000000000000e0e0000000005001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000000000000000000e0000001a1a0000000000000e0e0000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000000000000000000e0000001a1a0000000a00000e0e00000b3d0f0f1a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a0000000e000000000000000000001a1a0f0f3b2d00000e0e00002a0000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a0000000e000000000000000000001a1a0000000000000e0e0000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a0000000e3b3d0f0f3b0d00003b3c1d1a0006000000000e0e0000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a0000000000000000001a000000001a1a0000003b3c3c3c3d0f0f0a0000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a00003a0000000004002a000001001a1a000000000000000000002a0001001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a05000f0000000000000e000000001a1a00000000000000000300000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a00000a0000000000000e000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000002b3c3c2c3c3c3c3c3c3c3c3c3c3c3c2d2b3c3c3c3c3c3c3c3c3c3c3c3c3c3c2d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
