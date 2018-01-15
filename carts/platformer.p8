pico-8 cartridge // http://www.pico-8.com
version 15
__lua__


-- constants
k_pixmap = 1.0 / 8.0 -- 1 pixel in map coords
k_grav = 0.1 -- gravitation accel
k_buoyancy = 0.02

k_sprflg_solid = 1
k_sprflg_death = 2
k_sprflg_pickup = 3
k_sprflg_water = 4  
k_sprflg_breakable = 5

-- map scroll values
map_off_x = 0
map_off_y = 0
global_tick = 0

actors = {} --all actors in world

-- make an actor
-- and add to global collection
-- x,y means center of the actor
-- in map tiles (not pixels)
function create_actor(x, y)
 a={}
 a.x = x
 a.y = y
 a.dx = 0
 a.dy = 0
 a.spr = 16
 a.frame = 0
 a.t = 0
 a.vel_damp = 0.6
 a.bounce  = 1
 a.frames=2
 a.solid = false
 a.grounded = false
 a.in_water = false
 a.on_surface = false
 a.gravity = false
 a.alive = true
 a.death_timer = 0
 -- half-width and half-height
 a.w = 0.5
 a.h = 0.5
 
 add(actors,a)
 
 return a
end

function kill_actor(a)
 del(actors,a)
end

-- actor creation table - is indexed by tile type
actor_create={}

-- animated tiles
anim_tiles={}
anim_tiles[9] = { frames = {9,10} }
anim_tiles[11] = { frames = {11,12,13,14,15,15,15,15,14,13,12,11} }

-- tile to use for background replace
background_tile = 0

-- iterate through map and create actors for each actor tile
function setup_map()

 for mx = 0,128 do
  for my=0,32 do
   tile = mget(mx,my) -- get tile
   
   -- look up creation function for tile
   local create_fn = actor_create[tile]
   if create_fn != nil then 
	mset(mx,my,0)	-- clear tile
	create_fn(mx+0.5,my+0.5) -- create actor
   end
   
   -- look up animated tiles
   local anim_tile = anim_tiles[tile]
   if anim_tile != nil then
    if anim_tile.list == nil then anim_tile.list = {} end
    add(anim_tile.list,{mx,my})
   end
   
  end
 end

end

function _init()
  
 setup_map()
 
 -- make a bouncy ball
 --[[local ball = make_actor(8.5,7.5)
 ball.spr = 33
 ball.dx=0.05
 ball.dy=-0.1
 ball.vel_damp=0.5
 
 local ball = make_actor(7,5)
 ball.spr = 49
 ball.dx=-0.1
 ball.dy=0.15
 ball.vel_damp=1
 ball.bounce = 0.8
 
 
 -- tiny guy
 
 a = make_actor(7,5)
 a.spr=5
 a.frames=4
 a.dx=1/8
 a.vel_damp=0.8
 ]]
 
 
end

-- check map square for flag
function check_map(x, y, flag)
 val=mget(x, y) -- get map cell
 return fget(val, flag) -- flag 1 is solid 
end

-- area needs to be less than 1 tile in size
function check_map_area(x,y,w,h,flag)

 return 
  check_map(x-w,y-h,flag) or
  check_map(x+w,y-h,flag) or
  check_map(x-w,y+h,flag) or
  check_map(x+w,y+h,flag)
end

-- check area for pickups
function check_pickup(x,y)

 local tile = mget(x,y)
 if fget(tile, k_sprflg_pickup) then
	mset(x,y, background_tile)
	return tile
 end
 
end

-- true if a we hit another
-- solid actor after moving dx,dy
function solid_actor(a, dx, dy)

 for a2 in all(actors) do
  if a2 != a then
   local x=(a.x+dx) - a2.x
   local y=(a.y+dy) - a2.y

   -- overlapping?
   if ((abs(x) < (a.w+a2.w)) and (abs(y) < (a.h+a2.h))) and (a2.solid == true) then 
  	
    -- moving together?
    -- this allows actors to
    -- overlap initially 
    -- without sticking together    
    if (dx != 0 and abs(x) < abs(a.x-a2.x)) then
     --v=a.dx + a2.dy
     --a.dx = v/2
     --a2.dx = v/2
     return true 
    end
    
    if (dy != 0 and abs(y) < abs(a.y-a2.y)) then
     --v=a.dy + a2.dy
     --a.dy=v/2
     --a2.dy=v/2
     return true 
    end
    
   end
  end
 end

 return false
end

-- check if we are overlapping another actor
function overlapping_actor(a)
  for a2 in all(actors) do
   if a2 != a then
    local x=a.x - a2.x
    local y=a.y - a2.y

    -- overlapping?
    if ((abs(x) < (a.w+a2.w)) and (abs(y) < (a.h+a2.h))) then 
     return a2
    end
   end
  end
  
  return nil
end

-- checks both walls and actors
function solid_a(a, dx, dy)
 -- 1 is the solid flag
 if check_map_area(a.x+dx,a.y+dy,a.w,a.h,k_sprflg_solid) then
    return true 
 end
 return solid_actor(a, dx, dy) 
end

-- do a line check across the map
function map_line_check(x1,y1,x2,y2,flags)
 local steps = ceil(max(abs(x1-x2),abs(y1-y2)))
 local stepx = (x2 - x1) / steps
 local stepy = (y2 - y1) / steps
 local hit = false
 
 for i=1,steps do
  local t = mget(x1,y1)
  if fget(t,k_sprflg_solid) then
   hit = true
   break
  end
   
  x1 += stepx
  y1 += stepy
 end
 
 return hit,x1,y1
 
end

-- check for death from environment & other actors
function actor_check_death(a)
 
 local death = false
 local overlap = overlapping_actor(a)
 if overlap != nil then
 end
 
 if check_map(a.x,a.y,k_sprflg_death) then death = true end
 --if check_map_area(a.x + a.dx,a.y + a.dy, a.w, a.h, k_sprflg_death) then death = true end
 
 -- squashed?
 if solid_a(a, 0, 0) then death = true end
 
 if death == true and a.alive == true then 
  --kill actor
  a.alive = false
  a.death_timer = 100
  a.dy -= 2
 end
end

-- move actor with collision & gravity
function move_solid_actor(a)

 if a.platform != nil then
  a.x += a.platform.dx
  a.y += a.platform.dy
  a.grounded = true
 end
 
 -- apply x vel first
 if not solid_a(a, a.dx, 0) then
  a.x += a.dx -- no collision, we're good to move
 else   
  local step = sgn(a.dx) * (1.0/8.0) -- single pixel step
  --if a.dx > 0 then step = 0.1 else step = -0.1 end
  
  while not solid_a(a, step, 0) do
   a.x += step
  end
  
  a.dx = 0
  if a.grounded == true then
  	sfx(2)
  end
 end

 -- then apply y velocity
 if a.alive==false or not solid_a(a, 0, a.dy) then
  a.y += a.dy
  a.grounded = false
 else
		-- landed?
  if a.dy > 0 and a.grounded == false then
			a.grounded = true
			sfx(2)
  end
  
  if a.dy > 0 then step = 0.1 else step = -0.1 end
  
  while not solid_a(a, 0, step) do
   a.y += step
  end
  
  a.dy = 0
  
  --a.dy *= -a.bounce
 end
 
 -- check for water
 local player_tile = mget(a.x,a.y);
 if fget(player_tile, k_sprflg_water) then
  player_tile = mget(a.x,a.y - (1.0/8));
  if fget(player_tile, k_sprflg_water) == false then
   a.on_surface = true
   -- surface splash
   if abs(a.dx) > 0 and (a.t % 4) == 0 then 
    spawn_splash(a.x,a.y,abs(a.dx * 0.5))
   end
  else
   a.dy -= k_buoyancy
   a.on_surface = false
  end
  if a.in_water == false then
   spawn_splash(a.x,a.y,a.dy * 2)
  end
  a.in_water = true
 else
  a.in_water = false
  a.on_surface = false
  -- gravity 
  if a.gravity == true then
   a.dy += k_grav
  end
 end
 -- apply velocity damper
 a.dx *= a.vel_damp
 a.dy *= a.vel_damp
 
 -- update animation
 a.frame += abs(a.dx) * 4
 a.frame += abs(a.dy) * 4
 a.frame %= a.frames

 a.t += 1
 
end

function update_map()
 -- update map offset around player
 if pl != nil and pl.alive == true then
  map_off_x += ((pl.x - 8) - map_off_x) * 0.4
  if map_off_x < 0 then map_off_x = 0 end
  if map_off_x > 120 then map_off_x = 120 end
 
  map_off_y += ((pl.y - 7) - map_off_y) * 0.04
  if map_off_y < 0 then map_off_y = 0 end
  if map_off_y > 17 then map_off_y = 17 end
 end 
 
 -- animate tiles
 off = { 0,1 }
 for k,v in pairs(anim_tiles) do
	local anim_index = flr((global_tick/4) % #v.frames)
	local frame = v.frames[anim_index+1]
	for t in all(v.list) do
		mset(t[1],t[2],frame)
	end
 end
end

-- call actor's update function
function update_actor(actor)
	if actor.update != nil then
		actor.update(actor)
	end	
end

-- update game
function _update()

 update_platforms() -- update platforms first
 foreach(actors, update_actor)
 
 update_map()
 update_particles()
 
 global_tick += 1	-- global timer
end

function draw_actor(a)
 local sx = ((a.x - map_off_x) * 8) - 4
 local sy = ((a.y - map_off_y) * 8) - 4
 local flip_x = false	-- todo: flip left/right based on vel
 local flip_y = false
 
 -- flip actor on death - player only?
 if a.alive == false and a.dy > 0 then flip_y = true end
 spr(a.spr + a.frame, sx, sy,1,1,flip_x,flip_y)
 
 -- draw action - should probably be in a player render method
 if a.action != nill and a.action.draw != nil then
  a.action.draw(a)
 end
end

function _draw()
 cls()
 clip(0,0,128,120)
 -- map
 local mscrx = (map_off_x - flr(map_off_x)) * 8
 local mscry = (map_off_y - flr(map_off_y)) * 8
 map(map_off_x,map_off_y,-mscrx,-mscry,17,17)
 
 -- actors
 foreach(actors,draw_actor)
 
 render_particles()
 
 clip(0,0,128,128)
 -- player debug
 if pl == nil then
  print("no player",0,120)
 else
  print("x "..pl.x,0,120,7)
  print("y "..pl.y,64,120,7)
 
  -- player states
  if pl.grounded == true then print("g",100,120,7) end
  if pl.alive == true then  print("a",108,120,7) end
  if pl.platform != nil then  print("p",116,120,7) end
 end
end

-->8

-- individual actor code here

-- player code
function create_player(x,y)
 pl = create_actor(x,y)
 pl.spr = 17
 pl.restart_x = x
 pl.restart_y = y
 pl.jump_timer = 0
 pl.update = update_player
 pl.w = 0.4 -- slightly less to allow us to fit through walls
 pl.h = 0.4
 
 --pl.action = { fire = fire_bullet_action}
 pl.action = { fire = fire_rope_action, update = update_rope, draw = draw_rope}
 
 pl.solid = true
 pl.gravity = true
 pl.pickups = 0
 -- init map pos
 map_off_x = pl.x - 8
 map_off_y = pl.y - 8
 
 add_platform_actor(pl)
 return pl
end

-- register with factory
actor_create[17] = create_player

-- called when player dies
function restart_player()
 pl.x = pl.restart_x
 pl.y = pl.restart_y
 pl.dx = 0
 pl.dy = 0
 pl.alive = true
end

function fire_bullet_action(pl)
   local b_vel = sgn(pl.dx) * 0.5
   b = create_bullet(pl,pl.x,pl.y,b_vel,0)
end

function fire_rope_action(pl)
 if (pl.rope != nil) return -- already have a rope deployed
 local hit,rx,ry = map_line_check(pl.x,pl.y,pl.x,pl.y - 10,k_sprflg_solid)
 if hit == true then
  local r = {}
  r.anchor = {}
  r.anchor.x = rx
  r.anchor.y = ry
  local dx = rx - pl.x
  local dy = ry - pl.y
  r.length = sqrt((dx * dx) + (dy * dy)) -- store initial rop length
  pl.rope = r
 end
end

function update_rope(pl)
 if (pl.rope == nil) return 
 if btn(4) == false then
  pl.rope = nil
  return
 end
 
 -- update rope constraint
 local dx = pl.x - pl.rope.anchor.x
 local dy = pl.y - pl.rope.anchor.y
 local length = sqrt((dx * dx) + (dy * dy))
 local springconst = 1.0
 local frictionconstant = 0.2
 local force_x = -(dx / length) * (length - pl.rope.length) * springconst
 local force_y = -(dy / length) * (length - pl.rope.length) * springconst
 
 --force_x += -pl.dx * frictionconstant;
 --force_y += -pl.dy * frictionconstant;
 pl.dx += force_x
 pl.dy += force_y
 
 -- change rope length with up/down
 if (btn(2)) pl.rope.length -= 0.1
 if (btn(3)) pl.rope.length += 0.1
 
 -- check for rope snags
 local hit,rx,ry = map_line_check(pl.x,pl.y,pl.rope.anchor.x,pl.rope.anchor.y,k_sprflg_solid)
 if hit == true then
  local r = {}
  r.anchor = {}
  r.anchor.link = pl.rope.anchor
  r.anchor.x = rx
  r.anchor.y = ry
  local dx = rx - pl.x
  local dy = ry - pl.y
  r.length = sqrt((dx * dx) + (dy * dy)) -- store initial rop length
  pl.rope = r
 else 
  -- check for free path to link if there is one
  if pl.rope.anchor.link != nil then
   local hit,rx,ry = map_line_check(pl.x,pl.y,pl.rope.anchor.link.x,pl.rope.anchor.link.y,k_sprflg_solid)
   if hit == false then
    pl.rope.anchor = pl.rope.anchor.link
    local dx = pl.rope.anchor.x - pl.x
    local dy = pl.rope.anchor.y - pl.y
    pl.rope.length = sqrt((dx * dx) + (dy * dy)) -- store initial rop length
   end
  end
     
 end
 
 
end

function draw_rope(pl)
 if (pl.rope == nil) return 
 
 local x1 = ((pl.x - map_off_x) * 8) 
 local y1 = ((pl.y - map_off_y) * 8) 
 
 local anchor = pl.rope.anchor
 while anchor != nill do
  local x2 = ((anchor.x - map_off_x) * 8) 
  local y2 = ((anchor.y - map_off_y) * 8) 

  line(x1,y1,x2,y2,7)
  anchor = anchor.link
  x1 = x2
  y1 = y2
 end
end

function update_player(pl)

 -- how fast to accelerate
 if pl.in_water == true then 
  accel = 0.05
 else
  accel = 0.1
 end
 
 -- controls
 if pl.alive == true then
  -- left/right movement
  if (btn(0)) pl.dx -= accel 
  if (btn(1)) pl.dx += accel 

  -- jump controls
  if (btn(5)) then
   if pl.grounded == true or pl.on_surface == true then
    pl.dy -= 0.50
    pl.jump_timer = 0
    pl.grounded = false
    if pl.on_surface == true then
    	spawn_splash(pl.x,pl.y,0.5)
    end
   end 
	
   -- allow additional jump boost early on in the jump
   if pl.jump_timer < 10 then
    pl.dy -= 0.1
   end
  end
  
  -- swim up/down
  if pl.in_water == true then
   if btn(2) and pl.on_surface == false then pl.dy -= 0.05 end --up
   if btn(3) then pl.dy += 0.05 end --down
  end
  
  -- use action
  if btnp(4) and pl.action.fire != nill then
   pl.action.fire(pl)
  end
  
 end
 
 if pl.action.update != nil then
  pl.action.update(pl)
 end
  
 -- update jump timer
 if (pl.grounded == false) pl.jump_timer+=1
 
 -- play a sound if moving
 -- (every 4 ticks)
 if (abs(pl.dx)+abs(pl.dy) > 0.1
     and (pl.t%4) == 0) and pl.grounded == true then
  sfx(1)
 end
 
 -- check for pickups
 local pickup = check_pickup(pl.x, pl.y)
 if pickup != nill then
  pl.pickups += 1
  -- todo: sfx
 end
 
 actor_check_death(pl)
 
 -- death state
 if pl.alive == false then
  pl.death_timer -= 1
  if pl.death_timer < 0 then
	  restart_player()
  end
 end
 
 move_solid_actor(pl)
 
end

-- bullet
function create_bullet(owner,x,y,xvel,yvel)
 b = create_actor(x,y)
 b.dx = xvel
 b.dy = yvel
 b.update = update_bullet
 b.spr = 21
 b.life = 30
 b.owner = owner
 return b
end

function update_bullet(b)
 b.x += b.dx
 b.y += b.dy
 b.life -= 1
 
 local dead = false
 local impact = false
 
 -- check collision with world
 local hit_tile = mget(b.x,b.y)
 
 -- breakable tiles
 if fget(hit_tile, k_sprflg_breakable) == true then
  local new_tile = hit_tile + 1
  if fget(new_tile, k_sprflg_breakable) == false then
   new_tile = background_tile
  end
  mset(b.x,b.y,new_tile)
  impact = true
 elseif fget(hit_tile, k_sprflg_solid) == true then
  impact = true
 end
 
 -- todo: check collision with actors
 local hit_actor = overlapping_actor(b)
 if hit_actor != nil and hit_actor != b.owner then
  impact = true
 end
 
 if impact == true then
  -- spawn impact effect
  dead = true
  spawn_impact_effect(b.x,b.y,-sgn(b.dx) * 0.2,0)
 end
 
 if b.life == 0 then
  dead = true
 end
  
 if dead == true then
  kill_actor(b)
 end
end

-- moving platform
platforms = {} -- list of all our platform
platform_actors = {} -- list of actors affected by platforms

-- step 1: check if actors are on platforms
-- step 2: move platforms
-- step 3: apply platforms vel to actors on platforms
-- step 4: apply actor movement

function add_platform_actor(a)
 add(platform_actors,a)
end

function remove_platform_actor(a)
 del(platform_actors,a)
end

function update_platforms()
 for a in all (platform_actors) do
  if a.alive == true then 
   check_actor_platform(a)
  end
 end
 for p in all(platforms) do
  move_platform(p)
 end
end

function check_actor_platform(a)
 for p in all(platforms) do
  -- check if platform is below actor
  local x=p.x - a.x
  local y=p.y - a.y

  -- on top of?
  if ((abs(x) < (a.w + p.w)) and y > 0 and (y < (a.h + p.h + k_pixmap))) then 
    a.platform = p
	a.y = p.y - (a.h + p.h + k_pixmap) -- snap on top of platform
  else
   a.platform = nil
  end
 end
end

function create_platform(x,y)
 p = create_actor(x,y)
 --p.update = move_platform
 p.spr = 25
 p.solid = true
 
 --vertical movement range
 --move this into a util function
 local miny = y
 local maxy = y
 while p.miny == nil or p.maxy == nil do
  
  if p.miny == nil then
   local tval = mget(x,miny)
   if fget(tval,k_sprflg_solid) == true then 
    p.miny = miny + 1
   end
   miny -= 1
   if (miny <= 0) p.miny = 0.5
  end
  
  if p.maxy == nil then
   local tval = mget(x,maxy)
   if fget(tval,k_sprflg_solid) == true then 
    p.maxy = maxy - 1
   end
   maxy += 1
   if (maxy >= 34) p.maxy = 33
  end
 end
 
 p.speed = 0.06
 p.dy = p.speed
 
 add(platforms,p)
 return p
end
-- register with factory
actor_create[25] = create_platform

function move_platform(p)
 p.x += p.dx
 p.y += p.dy
 if p.miny!=nil and p.y <= p.miny then
  p.dy = p.speed
 end
 if p.maxy!=nil and p.y >= p.maxy then
  p.dy = -p.speed
 end
 
end

-->8
-- particle system

particles = {}

function add_particle()
	part = {}
	part.x = 0
	part.y = 0
	part.dx = 0
	part.dy = 0
	part.grav = 0
	part.life = 0
	part.col = 0
		
	add(particles,part)
	return part
end

function update_particles()
 for p in all(particles) do
 
  p.x += p.dx
  p.y += p.dy
  
  p.dy += p.grav 
  p.life-=1
  if p.life < 0 then del(particles,p) end -- dead particle
 end
end

function render_particles()
 for p in all(particles) do
  local sx = ((p.x - map_off_x) * 8) 
  local sy = ((p.y - map_off_y) * 8) 
  pset(sx,sy,p.col)
 end
end

function spawn_splash(x,y,scale)
	local no_parts = 8
	local xrange = 0.4 * scale
	local dx = -xrange/2
	
	for i=1,no_parts do
	 p = add_particle()
	 p.life = 10
	 p.x = x
	 p.y = y
	 p.dx = dx
	 p.dy = -0.25 - rnd(scale) 
	 p.grav = k_grav
	 p.col = 12
	 dx += xrange / no_parts 
	end
end

function spawn_impact_effect(x,y,xvel,yvel)
 local no_parts = 8
 for i=1,no_parts do
  p = add_particle()
  p.life = 10
  p.x = x
  p.y = y
  p.dx = xvel * rnd(1)
  p.dy = -0.2 + rnd(0.4) 
  p.grav = k_grav * 0.2
  p.col = 8 + ceil(rnd(2))
  --dx += xrange / no_parts 
 end
end

-->8
-- misc graphics routines

-- draw scaled sprite
-- n - sprite no
-- w - width
-- h - height
function zspr(n,x,y,scale,w,h)

  sx = 8 * (n % 16)
  sy = 8 * flr(n / 16)
  sw = 8 * w
  sh = 8 * h
  dw = sw * dz
  dh = sh * dz
  
  sspr(sx,sy,sw,sh, x,y,w,h)
end

__gfx__
000000003bbbbbb7dccccc770cccccc00000000000ccc70000ccc70000ccc70000ccc70000880008080080000600060000000000000000000000000000000000
000000003000000bd0000077d000007c101110100cccccc00cccccc00cccccc00cccccc008888088088080800600060000000000000000000000000000000000
000000003000070bd000000cd000770c000000000cffffc00cffffc00cffffc00cffffc088888888888888800600060006000600000000000000000000000000
000000003000000bd000000cd000770c000000000c5ff5c00c5ff5c00c5ff5c00c5ff5c089889998889998980600060006000600000000000000000000000000
000000003000000bd000000cd000000c000000000cffffc00cffffcc0cffffc0ccffffc099999999999999996660666006000600000000000000000000000000
000000003000000bd000000cd000000c00101101ccccccccccccccc0cccccccc0cccccccaa99aaaa99aa9aa96660666006000600060006000000000000000000
000000003000000bd000000cd000000c000000000cccccc00cccccc00cccccc00cccccc0aaaaaaaaaaaaaaaa6660666066606660060006000600060000000000
00000000111111115111111101111110000000000c0000c0c00000c00c0000c00c00000caaaaaaaaaaaaaaaa6666666666666666666066606660666066606660
aaaaaaaa00ffff0000ffff0000aaaa00cccccccc000000006ccccccc6ccccccc6c0cccc077777775000000000000000000000000000000000000000000000000
a000000a00dffd0000dffd000aaaaaa0cccccccc0000000061111111611111116110101176666665000000000000000000000000000000000000000000000000
a000000a00ffff0000ffff009aaa77aacccccccc000a800061111111611111010011010176666665000000000000000000000000000000000000000000000000
a000000a0882288ff88228809aaa77aacccccccc00a9980061111111610011116100100176666665000000000000000000000000000000000000000000000000
a000000af08228000082280f9aaaaaaacccccccc00a9980061111111611001116110010176666665000000000000000000000000000000000000000000000000
a000000a00855800008558009aaaaaaacccccccc000a800061111111611101100001011076666665000000000000000000000000000000000000000000000000
a000000a005005000500005009aaaaa0cccccccc0000000061111111611111116011110176666665000000000000000000000000000000000000000000000000
aaaaaaaa066006606600006600999900cccccccc0000000061111111610111116101010155555555000000000000000000000000000000000000000000000000
0000000000aaaa000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000a0000a00700007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000a000770a7000770700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000a000770a7000770700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000a000000a7000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000a000000a7000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000a0000a00700007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaaa000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000008888000088880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088888800888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000288888882888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000002e8e8e8e28e8e8e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000002e8e8e8e28e8e8e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000228888882288888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000022888800228888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000002222000022220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0002020200000000000404040404040000000008100022222202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0202020202020202030302020203030302030303030202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000003000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302020200000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100040000000000000100001300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200020000040000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000400000013000200030000000003000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000416000200030000000003141414140300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0304000202020000001616000000020b0b0b0b03141414140300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000202020000000400000200020202020203030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202000000000002000000000204020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0309090909090909090909090909030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302020202030202020202020203020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000001616160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000001616160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000303030303030303030303030303030303030303030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000001300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0313000000000000030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030000001300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030000030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030000000000000000000000000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030303030303030303030303030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000303030303030000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000001300001300000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000003030303030303000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000003030303030303000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000003030303030303030000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000300000000000003030303030303030000030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000131313000000000000000000001616160314141414141403030303030303031414030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000003030303030000000000000000001616160314141414141414141414141414141414030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
031100191900000000000000000000000b0b0b00001616160314141414141414141414141414141403030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030303090909090909090909030303030303030303030303030303030303030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000c55012540075100050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100003073020750217201171000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
