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
 plr_id=peek(0x5f81)
 
 timer={}
 
 prev_kp_alv={0,0,0,0,0,0}
 kp_alv_count={0,0,0,0,0,0}
 
 --indicates plr is not
	--currently in a game
	plr={x=255,y=255,dir=0,kp_alv=0}
	mine={x=0,y=0}
	bull={}
 
 if peek(0x5f80)==0 then
  init_main()
 else
	 connect()
		
		if not control or control==0
		 then
		 init_slct()
		end
		
		--copy_map(1)
		
	 --constants
	 
	 --object sizes
	 t_sz=5.5 --tank(side)
	 b_sz=4 --bullet(side)
	 m_sz=5 --mine(side)
	 e_sz=32 --explosion(diameter)
	 mt_sz=24 --mine trigger(diameter)
	 w_sz=8 --breakable wall(side)
	 
	 --object speed
	 t_spd=0.8 --tank
	 b_spd=1.2 --bullet
	 trn_spd=0.011 --turning
	 
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
end

function _update()
 get_data()
 
 timer_tick()
 
 if peek(0x5f80)==0 then
  update_main()
 elseif control==0 then
  if plr.x==0 and plr.y==0
   then
   _init()
  end
  update_slct()
 else
	 --game start
	 if plr.x==254 and plr.y==254
	  then
	  copy_map(level)
	 end
	
	 update_plr()
	 update_bullets()
	 update_mine()
	 update_walls()
	 
	 if plr_id==1 then
		 check_winner()
		end
	end
	
	plr.kp_alv+=1
	upload_data()
	
	check_afk()
end

function _draw()
 cls(15)
 
 if peek(0x5f80)==0 then
  draw_main()
 elseif control==0 then
  draw_slct()
 else
	 map(0,0,0,0,16,16,1)
		
	 --any elements at 0,0 are not
	 --drawn. this happens in every
	 --function
	 draw_mines()
	 draw_tanks()
	 draw_bullets()
	 draw_mine_explosions()
	 draw_reticle()
	 
	 if timer.win then
	  draw_win()
	 end
	 
	 ?control
	end
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
 
 for k,v in pairs(timer) do
  if v>=0 then
   timer[k]-=1
  else
   timer[k]=nil
  end
 end
end

--check if there's only 1 player
--alive and connected
function check_winner()
 winner=0
 for i,t in pairs(tanks) do
  if t.x~=0 and t.y~=0 and
   t.x~=255 and t.y~=255 then
   if winner==0 then winner=i
   else winnner=-1 end
  end
 end
 
 if winner>0 then
  control=winner+10
  if not timer.win then
   timer.win=90
  end
 end
 
 if timer.win==0 then
  control=0
 end
end

--read both inputs for
--left-handed accesibility
function btn2(b)
 return btn(b) or btn(b,1)
end

function btnp2(b)
 return btnp(b) or btnp(b,1)
end
-->8
--netcode

--lookup table for better
--readability on gpio access
lookup={
 --tank data (*6)
 tank_x=0x5f82,
 tank_y=0x5f83,
 --4b: keep alive, 4b: dir
 tank_dir=0x5f84,
 --mine data
 mine_x=0x5f85,
 mine_y=0x5f86,
 mine_state=0x5f87,
 --bullet data (*4)
 bull_x=0x5f88,
 bull_y=0x5f89,
 --1b: explode, 4b: -, 3b: dir
 bull_dir_state=0x5f8a,
 
 --next tank starts at 0x5f94
 --last tank ends at 0x5fed
 
 --breakable walls (*16)
 --4 bits:x, 4 bits:y
 wall_coor=0x5fee,
 
 --last wall ends at 0x5ffd
 
 control=0x5ffe,
 level=0x5fff
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
	   dir=peek(lookup.tank_dir
	    +18*i)%16/16,
	   kp_alv=peek(lookup.tank_dir
	    +18*i)\16})
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
	
	--control bytes
	control=peek(lookup.control)
	level=peek(lookup.level)
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
  ,(plr.kp_alv)%16*16
  +flr(plr.dir*16))
 
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
 
 if plr_id==1 then
  --upload breakable walls
  for i,w in ipairs(walls) do
   poke(lookup.wall_coor+i-1,
    w.x*16+w.y)
  end
  
  --control bytes
  poke(lookup.control,control)
  poke(lookup.level,level)
 end
end

function connect(room)
 if peek(0x5f80)==0 then
	 poke(0x5f80,room)
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
	  plr_id=i
	  break
	 end
 end
 
 --if there's no room, relaunch
 if plr_id==0 then
  poke(0x5f80,0)
  run()
 end
end

function check_afk()
 --keep alive variable should
 --always increase. if it does
 --not for too long, wipe data
 for i=1,6 do
  if i~=plr_id then
   local ka=tanks[i].kp_alv
   if ka==prev_kp_alv[i] then
    kp_alv_count[i]+=1
   else
    kp_alv_count[i]=0
   end
   if kp_alv_count[i]>=150 then
    if i==plr_id-1 then
     memset(0x5f82+18*plr_id-18,
     0,18)
     plr_id-=1
     poke(0x5f81,plr_id)
    end
    memset(0x5f82+18*i-18,
     0,18)
	   kp_alv_count[i]=0
   end
   prev_kp_alv[i]=ka
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
  --die
  plr.x=255;plr.y=255
 end
 
 if not plr.timer and plr.x<255
  and plr.y<255 and control==1
  then
	 if btn2(⬆️) and
	  not btn2(⬇️) then
	  move_plr(t_spd)
	 elseif btn2(⬇️) and
	  not btn2(⬆️) then
	  move_plr(-t_spd)
	 elseif btn2(⬅️) and
	  not btn2(➡️) then
	  plr.dir=(plr.dir+trn_spd)%1
	 elseif btn2(➡️) and
	  not btn2(⬅️) then
	  plr.dir=(plr.dir-trn_spd)%1
	 end
	 
	 --max 4 bullets per player
	 --at once
	 if btnp2(❎) and #bull<4 then
	  add(bull,{
	   x=plr.x+cos(plr.dir)*7,
	   y=plr.y+sin(plr.dir)*7,
	   dir=plr.dir,
	   explode=false,
	   bounce=false})
	 end
	 
	 --max 1 mine per player at once
	 if btnp2(🅾️) and mine.x==0
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
			  dir=atan2(64-x,64-y),
			  kp_alv=0}
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

function draw_win()
 printo("player "..(control-10)..
  "wins!",30,2,tank_pal[control
  -10][1])
end

function printo(t,x,y,c1,c2)
 c2=c2 or 1
	print(t,x+1,y,c2)
	print(t,x-1,y,c2)
	print(t,x,y+1,c2)
	print(t,x,y-1,c2)
 print(t,x,y,c1)
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
-->8
--menus

--main menu
function init_main()
 roomhi=0
 roomlo=0
 cur=0
 sfx(8)
end

function update_main()
 if (btnp2(⬅️)) cur=(cur-1)%3
 if (btnp2(➡️)) cur=(cur+1)%3
 if cur==0 and (btnp2(❎) or
  btnp2(🅾️)) then
  connect(roomhi*16+roomlo)
 end
 if cur==1 then
  if btnp2(⬆️) then
   roomhi=(roomhi+1)%16
  elseif btnp2(⬇️) then
   roomhi=(roomhi-1)%16
  end
 elseif cur==2 then
  if btnp2(⬆️) then
   roomlo=(roomlo+1)%16
  elseif btnp2(⬇️) then
   roomlo=(roomlo-1)%16
  end
 end
end

function draw_main()
 printo("cool title",46,40,6,13)

 local c=cur==0 and 8 or 7
 printo("start",35,70,c)
 
 c=cur==1 and 8 or 7
 if roomhi<10 then
	 printo(roomhi,75,70,c)
	else
	 --print in hex format
	 printo(chr(87+roomhi),75,70,c)
	end
	spr(17,74,64)
	spr(17,74,73,1,1,false,true)
	
 c=cur==2 and 8 or 7
 if roomlo<10 then
	 printo(roomlo,85,70,c)
	else
	 --print in hex format
	 printo(chr(87+roomlo),85,70,c)
	end
	spr(17,84,64)
	spr(17,84,73,1,1,false,true)
	
	printo("choose a room different to 0"
	 ,8,105,6,13)
end

--level select menu
function init_slct()
 poke(lookup.level,1)
 sfx(8)
end

function update_slct()
 plr.x=254;plr.y=254
 
 if plr_id==1 then
  if btnp2(❎) or btnp2(🅾️) then
   control=1
   copy_map(level)
   sfx(8,-2)
  end
  if btnp2(⬅️) then
   level=(level-2)%6+1
  end
  if btnp2(➡️) then
   level=level%6+1
  end
 end
 page=(level-1)\3
end

function draw_slct()
 for i,t in ipairs(tanks) do
  if t.x==254 and t.y==254 then
   pal(13,tank_pal[i][3])
	  pal(8,tank_pal[i][1])
	  pal(2,tank_pal[i][2])
	  
	  local y=i==plr_id and 10 or 4
   spr(1,-8+i*12,y)
   
   pal()
  end
 end
 
 printo((page+1).."/2",
  page<9 and 58 or 54,22,7)
 
-- printo("waiting for player 1 to\n     choose a map"
--  ,18,40,7)
 local x=7+(level-1)%3*40
 rect(x,31,x+33,64,8)
 for i=0,2 do
  --pick the three maps of the
  --current page
	 draw_map_mini(page*3+i+1
	  ,8+i*40,32)
	end
 
 printo("controls",48,70,6,13)
 printo("⬆️⬇️: move forwards/backwards"
  ,6,82,6,13)
 printo("⬅️➡️: turn counterclokwise/"
  ,10,90,6,13)
 printo("clockwise",46,98,6,13)
 printo("❎: shoot",46,106,6,13)
 printo("🅾️: lay down mine",30,
  114,6,13)
end

function draw_map_mini(id,x,y)
 for i=0,15 do for j=0,15 do
  local c
  local tile=mget(i+id%8*16,
   j+id\8*16)
  if tile==14 then
   c=5
  elseif tile==15 then
   c=2
  elseif tile==mid(1,tile,6) then
   c=tank_pal[tile][1]
  elseif tile~=0 then
   c=9
  else
   c=15
  end
  
  --pset(x+i,y+j,c)
  rect(x+i*2,y+j*2,
  x+i*2+1,y+j*2+1,c)
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
00000000001000000000000000000000000000000000000000000000000000000000000000000000499999944999999449999994499999940000000000000000
00550000017100000000000000000000000000000000000000000000000000000000000000000000499999944969969999699699996996940000000000000000
05555000177710000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
05556600111110000000000000000000000000000000000000000000000000000000000000000000499999944999999999999999999999940000000000000000
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
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
49999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999994
49699999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999699699999999999999999999999694
49999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999994
49999699999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999699994
49999994444444444444444444444444444444444444444444444444444444444444444444444444444444444444444449999994444444444444444449999994
49999994999999999999999999999999999999999999999999999999999999999999999999999999999999999999999949999994999999999999999949999994
49999994444444444444444444444444444444444444444444444444444444444444444444444444444444444444444449999994444444444444444449999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffdfffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffff5555fffffd6dffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffff555555fffd666dfffffffffffffffffffffffffffffffffffffffff49699694ffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffff555555ffd6666dfffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffff5555ffffd66dffffffffffffffffffffffffffffffffffffffffff44444444ffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffffffffffffffddfffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44444444ffffffffffffffff49999994
49999994ffffffffffffffffffffffeffffeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff11111111ffffffffffffffff49999994
49999994fffffffffffffffffffffffeffefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff12122221ffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffff5555ffffffffffffffffffffffffffffffffffffffffffffffffff12211221ffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffff555555fffffffffffffffffffffffffffffffffffffffffffffffff12222121ffffffffffffffff49999994
49999994fffffffffffffffffffffffeffeffffff555555ffffffffffffffffffffffffffffff33ff33fffffffffffff12222221ffffffffffffffff49999994
49999994ffffffffffffffffffffffeffffeffffff5555fffffffffffffffffffffffffffffff3bbbb3fffffffffffff11111111ffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3bbbb3fffffffffffff12212221ffffffffffffffff49999994
49999994fffffffff222fffffefffffffffffffffffffffffffffffffffffffffffffffffffff3bbbb3fffffffffffff11111111ffffffffffffffff49999994
49999994ffffff2222e2efffffffffffffffffff44444444fffffffffffffffffffffffffffff3bbbb3fffffffffffff44444444ffffffffffffffff49999994
49999994ffffff2eeee6eeffffffffffffffffff49999994fffffffffffffffffffffffffffff33dd33fffffffffffff49999994ffffffffffffffff49999994
49999994fffffffeeee66effffffffffffffffff49699694fffffffffffffffffffffffffffffffbbfffffffffffffff49699694ffffffffffffffff49999994
49999994ffffffffeeee6fffffffffffffffffff49999994ffffffffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffff49999994
49999994ffffffffeeeee2ffffffffffffffffff49999994ffffffffffffdffffdffffffffffffffffffffffffffffff49999994ffffffffffffffff49999994
49999994fffffff2ee2222ffffffffffffffffff49999994fffffffffffd6d99d6dfffffffffffffffffffffffffffff44444444ffffffffffffffff49999994
49999994fffffff2222fffffffffffffffffffff49999994ffffffffffffd9aa9dffffffffffffffffffffffffffffff49999994ffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff49999994ffffffffffff9aaaa9ffffffffffffffffffffffffffffff44444444ffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff49999994ffffffffffff9aaaa9ffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff49999994ffffffffffffd9aa9dffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff49999994fffffffffffd6d99d6dfffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff49999994ffffffffffffdffffdffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
499999944444444444444444ffffffffffffffff499999944444444411111111111111114444444444444444ffffffffffffffffffffffffffffffff49999994
496996999999999999999994ffffffffffffffff499996999999999412122221121222214999999999999994ffffffffffffffffffffffffffffffff49999994
499999999999999999999994ffffffffffffffff499999999999999412211221122112214999999999999994ff5555ffffffffffffffffffffffffff49999994
499999999999999999699694ffffffffffffffff496999999969969412222121122221214969969999699694f555555fffffffffffffffffffffffff49999994
496996999999999999999994ffffffffffffffff499999999999999412222221122222214999999999999994f555555fffffffffffffffffffffffff49999994
499999944444444444444444ffffffffffffffff444444444444444411111111111111114444444444444444ff5555ffffffffffffffffffffffffff49999994
499999949999999999999994ffffffffffffffff499999999999999412212221122122214999999999999994ffffffffffffffffffffffffffffffff49999994
499999944444444444444444ffffffffffffffff444444444444444411111111111111114444444444444444ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5555ffffffffffddddddffffffffff49999994
49999994fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff555555fffffffffd6666dffffffffff49999994
49999994fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff555555fffffffffd6666dffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5555fffffffffffd66dfffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffddffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffff1111ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffff1cc1111fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffffffffccccc1fffffffffffffffffffffffffffffffffffffff5555ffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffffffffcccc6fffffffffffffffffffffffffffffffffffffff555555fffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffcccc66cffffffffffffffffffffffffffffffffffffff555555fffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffffff1cccc6ccfffffffffffffffffffffffffffffffffffffff5555ffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffffff1111c1cffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffff111fffffffffffffffffffffffffffffffddffffffffffffffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd66dfffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd6666dffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffff5555ffffffffffffffffffffffffffffffffffffffffd666dfffffffffffffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffff555555ffffffffffffffffffffffffffffffffffffffffd6dffffffffffffffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffff555555fffffffffffffffffffffffffffffffffffffffffdfffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffff5555fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff222ffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8282222fffffffffff49999994
49999994fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff88d88882fffffffffff49999994
49999994fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8dd8888ffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd8888fffffffffffff49999994
49999994ffffffffffffffffffffffffff5555fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff288888fffffffffffff49999994
49999994fffffffffffffffffffffffff555555ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2222882ffffffffffff49999994
49999994fffffffffffffffffffffffff555555fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2222ffffffffffff49999994
49999994ffffffffffffffffffffffffff5555ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffff444444444444444411111111111111114444444444444444ffffffffffffffff444444444444444449999994
49999994ffffffffffffffffffffffffffffffff499999999999999412122221121222214999999999999994ffffffffffffffff499999999999999999699694
49999994ffffffffffffffffffffffffff5555ff499999999999999412211221122112214999999999999694ffffffffffffffff499999999999999999999994
49999994fffffffffffffffffffffffff555555f496996999969969412222121122221214969969999999994ffffffffffffffff496996999999999999999994
49999994fffffffffffffffffffffffff555555f499999999999999412222221122222214999999999699994ffffffffffffffff499999999999999999699694
49999994ffffffffffffffffffffffffff5555ff444444444444444411111111111111114444444449999994ffffffffffffffff444444444444444449999994
49999994ffffffffffffffffffffffffffffffff499999999999999412212221122122214999999949999994ffffffffffffffff499999999999999949999994
49999994ffffffffffffffffffffffffffffffff444444444444444411111111111111114444444449999994ffffffffffffffff444444444444444449999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffffffddfffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffd66dffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffffd6666dfffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffffd666dffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffd6dfffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994fffffffffffffffffffffffffffdffffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff44444444ffffffffffffffffffffffffffffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994fffffffffffffffffffff6fdddffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49699694ffffffffffffffffffff66566ddfffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994fffffffffffffffffffff55666ddffffffffffffffffffff49699694ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994ffffffffffffffffffffd666666dffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff44444444ffffffffffffffffffffd666666dffffffffffffffffffff44444444ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994ffffffffffffffffffffdd6666ffffffffffffffffffffff49999994ffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff44444444fffffffffffffffffffffdd66fffffffffffffffffffffff44444444ffffffffffffffffffffffffffffffff49999994
49999994ff55fddfffffffff11111111ffffffffffffffffffffffdddfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ff5d66ddffffffff12122221ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ff5dd6655fffffff12211221fffffffffffffffffffffffffffffffffffffffffdffffdfff5555ffffffffffffffffffffffffffffffffff49999994
49999994f55ddddd5fffffff12222121ffffffffffffffffffffffffffffffffffffffffd6d99d6df555555fffffffffffffffffffffffffffffffff49999994
49999994f5ddddd55fffffff12222221fffffffffffffffffffffffffffffffffffffffffd9aa9dff555555fffffffffffffffffffffffffffffffff49999994
49999994f5ddddd5ffffffff11111111fffffffffffffffffffffffffffffffffffffffff9aaaa9fff5555ffffffffffffffffffffffffffffffffff49999994
49999994f55ffdd5ffffffff12212221fffffffffffffffffffffffffffffffffffffffff9aaaa9fffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffff55ffffffff11111111fffffffffffffffffffffffffffffffffffffffffd9aa9dfffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff44444444ffffffffffffffffffffffffffffffffffffffffd6d99d6dffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994fffffffffffffffffffffffffffffffffffffffffdffffdfffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49699694ffffffffffffffffffffffffffffffffffffffffffffffffff5555ffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994fffffffffffffffffffffffffffffffffffffffffffffffff555555fffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994fffffffffffffffffffffffffffffffffffffffffffffffff555555fffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994ffffffffffffffffffffffffffffffffffffffffffffffffff5555ffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994ffffffffffffffff49999994ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff49999994
49999994444444444444444449999994444444444444444444444444444444444444444444444444444444444444444444444444444444444444444449999994
49999699999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999699994
49999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999994
49699999999999999999999999699699999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999694
49999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999994
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
49999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999994
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444

__gff__
0000000000000000000003030303010300000000000000000000030303030000000000000000000000000303030300000000000000000000000003030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000000000000b3c3c3c3c3c3c3c3c3c3c3c0c3c3c0d0b3c3c3c3c3c3c3c3c3c3c3c3c3c3c0d0b3c3c3c3c3c3c3c3c3c3c3c3c3c3c0d0b3c3c3c3c3c3c3c3c3c3c3c3c3c3c0d0b3c3c3c3c3c3c3c3c3c3c3c3c3c3c0d0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000000e0000000000002a00001a1a00000000000000000000000000001a1a0000000000000e000000000000001a1a00000000000000000000000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000000e0000000000000f00061a1a00000000000400000000000000001a1a0001000000000e000000000003001a1a00000000000000000000000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000200000a0003000000003a00001a1a0000000a000000000000000000001a1a0000000000000000000e000000001a1a000000000a000000000a000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000001a0000000000000000001a1a0002002a0f0f3b3c3c3c3d0000001a1a000000000e000000000e000000001a1a000000002a000002002a000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001b3c3d00002b3d0f0f3b3d0e0000001a1a0000000000000e0e0000000005001a1b3c3d0f0f0e000000000e0f0f3b3c1d1a00000000003b3c3c3d00000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000000000000000000e0000001a1a0000000000000e0e0000000000001a1a000000000e000000000e000000001a1a00000000040f00000f05000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a000000000000000000000e0000001a1a0000000a00000e0e00000b3d0f0f1a1a000000000e0000000e0e000005001a1a00003b3c0d000000000a000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a0000000e000000000000000000001a1a0f0f3b2d00000e0e00002a0000001a1a000600000e0e0000000e000000001a1a000000002a000000002b3c3d00001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a0000000e000000000000000000001a1a0000000000000e0e0000000000001a1a000000000e000000000e000000001a1a00000000060f00000f03000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a0000000e3b3d0f0f3b0d00003b3c1d1a0006000000000e0e0000000000001a1b3c3d0f0f0e000000000e0f0f3b3c1d1a00000000003b3c3c3d00000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a0000000000000000001a000000001a1a0000003b3c3c3c3d0f0f0a0000001a1a000000000e000000000e000000001a1a000000000a000100000a000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a00003a0000000004002a000001001a1a000000000000000000002a0001001a1a000000000e0000000000000000001a1a000000002a000000002a000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a05000f0000000000000e000000001a1a00000000000000000300000000001a1a000400000000000e0000000002001a1a00000000000000000000000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000001a00000a0000000000000e000000001a1a00000000000000000000000000001a1a000000000000000e0000000000001a1a00000000000000000000000000001a1a00000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000002b3c3c2c3c3c3c3c3c3c3c3c3c3c3c2d2b3c3c3c3c3c3c3c3c3c3c3c3c3c3c2d2b3c3c3c3c3c3c3c3c3c3c3c3c3c3c2d2b3c3c3c3c3c3c3c3c3c3c3c3c3c3c2d2b3c3c3c3c3c3c3c3c3c3c3c3c3c3c2d0000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011400202462500000000000000024625000000000018625186250000018625000002462500000000000000018625000000000018625246250000024625000001862500000186250000024625000000000000000
