pico-8 cartridge // http://www.pico-8.com
version 16
__lua__


-- constants
k_pixmap = 1.0 / 8.0 -- 1 pixel in map coords
k_grav = 0.1 -- gravitation accel
k_buoyancy = 0.002

-- sprite flags
k_sprflg_solid = 1
k_sprflg_death = 2
k_sprflg_pickup = 3
k_sprflg_water = 4  
k_sprflg_breakable = 5

-- special tiles
k_tile_back = 0 	-- tile to use for background replace
k_tile_block = 66 	-- tile to use to block movement

-- map scroll values
map_off_x = 0
map_off_y = 0
global_tick = 0

actor_create={} -- actor creation table - is indexed by tile type

-- register actor creation with factory
function register_actors()
 
 actor_create[17] = create_player
 actor_create[64] = create_platform -- up/down
 actor_create[65] = create_platform -- left/right
 actor_create[5] = create_enemy

end

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
 a.platform = false
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


-- animated tiles
anim_tiles={}
anim_tiles[9] = { frames = {9,10} }
anim_tiles[11] = { frames = {11,12,13,14,15,15,15,15,14,13,12,11} }



-- iterate through map and create actors for each actor tile
function setup_map()

 -- first pass
 for mx = 0,128 do
  for my=0,32 do
   tile = mget(mx,my) -- get tile
   
   -- look up creation function for tile
   local create_fn = actor_create[tile]
   if create_fn != nil then 
	mset(mx,my,k_tile_back)	-- clear tile
	create_fn(mx+0.5,my+0.5,tile) -- create actor
   end
   
   -- look up animated tiles
   local anim_tile = anim_tiles[tile]
   if anim_tile != nil then
    if anim_tile.list == nil then anim_tile.list = {} end
    add(anim_tile.list,{mx,my})
   end
   
  end
 end
 
 -- second pass
 for mx = 0,128 do
  for my=0,32 do
   tile = mget(mx,my) -- get tile
   if(tile == k_tile_block) mset(mx,my,k_tile_back)
  end
 end
end

function _init()
  
 register_actors()
 setup_map()

 
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
	mset(x,y, k_tile_back)
	spawn_pickup_effect(x,y)
	sfx(0)
	return tile
 end
 
end

-- check if we are overlapping another actor
-- dx,dy are optional offsets that can be used for prediction
function overlapping_actor(a, dx, dy)
 local xp = a.x
 local yp = a.y
 if(dx != nil) xp += dx
 if(dy != nil) yp += dy
 
  for a2 in all(actors) do
   if a2 != a then
    local x = xp - a2.x
    local y = yp - a2.y

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
 
 local overlap = overlapping_actor(a, dx, dy) 
 if(overlap!=nil and overlap.solid == true) return true
 
 return false
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
  if(overlap.deadly == true) death = true
  --if(overlap.solid == true) death = true
 end
 
 if check_map(a.x,a.y,k_sprflg_death) then death = true end
 
 -- squashed?
 if solid_a(a, 0, 0) then death = true end
 
 if death == true and a.alive == true then 
  --kill actor
  spawn_sprite_explosion(a.spr,a.x - a.w,a.y - a.h)
  a.alive = false
  a.solid = false
  a.death_timer = 100
  a.dy -= 2
 end
end

function actor_apply_vel(a,dx,dy)
 -- apply x vel first
 if not solid_a(a, dx, 0) then
  a.x += dx -- no collision, we're good to move
 else   
  local step = sgn(dx) * k_pixmap -- single pixel step
  
  while not solid_a(a, step, 0) do
   a.x += step
  end
  
  a.dx = 0
  if a.grounded == true then
  	sfx(2)
  end
 end

 -- then apply y velocity
 if a.alive==false or not solid_a(a, 0, dy) then
  a.y += dy
  a.grounded = false
 else
  -- landed?
  if dy > 0 and a.grounded == false then
   a.grounded = true
   sfx(2)
  end
  
  local step = sgn(dy) * k_pixmap -- single pixel step
  
  while not solid_a(a, 0, step) do
   a.y += step
  end
  
  a.dy = 0
  a.jump_timer = 0
 end 
end

-- move actor with collision & gravity
function move_solid_actor(a)

 if a.platform != nil then
  actor_apply_vel(a,a.platform.dx,a.platform.dy)
  a.grounded = true
 end
 
 actor_apply_vel(a,a.dx,a.dy)
 
 -- check for water
 local player_tile = mget(a.x,a.y);
 if fget(player_tile, k_sprflg_water) then
  player_tile = mget(a.x,a.y - (1.0/8));
  if fget(player_tile, k_sprflg_water) == false then
   a.on_surface = true
   a.dy = 0
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
   a.dy *= 0.2
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
 
 -- update animation
 --a.frame += abs(a.dx) * 4
 --a.frame += abs(a.dy) * 4
 --a.frame %= a.frames

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
 if a.draw != nil then
  a.draw(a)
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
 
  if pl.rope != nil then
   local dx = (pl.x - pl.rope.anchor.x)-- / pl.rope.length 
   local dy = (pl.y - pl.rope.anchor.y)-- / pl.rope.length 
   local ang = atan2(dy,dx)
   print("ang "..ang,0,120,7)
   --[[timeval = 1
   local angle = ang * cos(sqrt(k_grav/pl.rope.length) * timeval)
   
   local x1 = ((pl.rope.anchor.x - map_off_x) * 8) 
   local y1 = ((pl.rope.anchor.y - map_off_y) * 8) 
   local x2 = x1 + sin(angle) * 80
   local y2 = y1 + cos(angle) * 80
   
   line(x1,y1,x2,y2,10)
   ]]

  else
   print("x "..pl.x,0,120,7)
   print("y "..pl.y,64,120,7)
  end
  -- player states
  if pl.grounded == true then print("g",100,120,7) end
  if pl.alive == true then  print("a",108,120,7) end
  if pl.platform != nil then  print("p",116,120,7) end
 end
end

-->8

-- individual actor code here

-- player code
function create_player(x,y,spr)
 pl = create_actor(x,y)
 pl.spr = 17
 pl.restart_x = x
 pl.restart_y = y
 pl.jump_timer = 0
 pl.update = update_player
 pl.draw = draw_player
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


-- called when player dies
function restart_player()
 pl.x = pl.restart_x
 pl.y = pl.restart_y
 pl.dx = 0
 pl.dy = 0
 pl.alive = true
 pl.solid = true
end



function update_player(pl)

 local accel = 0.1
 -- how fast to accelerate
 if pl.in_water == true then 
  accel *= 0.5
 end
 
 -- controls
 if pl.alive == true then
 
  -- left/right movement
  -- todo: different movement controls on rope
  --[[if pl.rope != nil then
   local dx = pl.x - pl.rope.anchor.x 
   local dy = pl.y - pl.rope.anchor.y
   local ang = atan2(dx,dy)
   --[[if btn(0) == true then
    ang += 0.01
   elseif btn(1) == true then
    ang -= 0.02
   end]]
   
   pl.x = (pl.rope.anchor.x + (sin(ang) * pl.rope.length)) -- - pl.x
   pl.y = (pl.rope.anchor.y + (cos(ang) * pl.rope.length)) -- - pl.y
   
  else]]
   if btn(0) == true then 
    pl.dx -= accel 
   elseif btn(1) == true then 
    pl.dx += accel 
   else --if pl.rope == nil then
    pl.dx *= pl.vel_damp 
   end
  --end
  
  -- apply velocity clamp
  local xvelmax = 0.3
  if(abs(pl.dx) > xvelmax) pl.dx=sgn(pl.dx) * xvelmax

  -- jump controls
  if (btn(5)) then
   if pl.grounded == true or pl.on_surface == true then
    pl.dy -= 0.4
    pl.jump_timer = 10
    pl.grounded = false
    if pl.on_surface == true then
    	spawn_splash(pl.x,pl.y,0.5)
    end
   end 
	
   -- allow additional jump boost early on in the jump
   if pl.jump_timer > 0 then
    pl.dy -= 0.1
   end
  end
  
  -- swim up/down
  if pl.in_water == true then
   if btn(2) and pl.on_surface == false then pl.dy -= 0.02 end --up
   if btn(3) then pl.dy += 0.02 end --down
  end
  
  local yvelmax = 0.4
  if(abs(pl.dy) > yvelmax) pl.dy=sgn(pl.dy) * yvelmax

  
  -- use action
  if btnp(4) and pl.action.fire != nill then
   pl.action.fire(pl)
  end
  
 end -- alive
 
 
  
 -- update jump timer
 if (pl.grounded == false) pl.jump_timer-=1
 
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
 
 if(pl.alive == true) actor_check_death(pl)
 
 -- death state
 if pl.alive == false then
  pl.death_timer -= 1
  if pl.death_timer < 0 then
	  restart_player()
  end
 end
 
 move_solid_actor(pl)
 
 if pl.action.update != nil then
  pl.action.update(pl)
 end
 
end

function draw_player(a)
 local sx = ((a.x - map_off_x) * 8) - 4
 local sy = ((a.y - map_off_y) * 8) - 4
 local flip_x = false	-- todo: flip left/right based on vel
 local flip_y = false
 
 if(a.alive == false) return -- don't render dead player
 
 -- flip actor l/r based on vel
 if (a.dx < 0) flip_x = true 
 spr(a.spr + a.frame, sx, sy,1,1,flip_x,flip_y)
 
 -- draw action 
 if a.action != nill and a.action.draw != nil then
  a.action.draw(a)
 end
end

-- rope code
function fire_bullet_action(pl)
   local b_vel = sgn(pl.dx) * 0.5
   b = create_bullet(pl,pl.x,pl.y,b_vel,0)
end

function fire_rope_action(pl)
 if (pl.rope != nil) return -- already have a rope deployed
 if (pl.in_water == true) return -- rope doesn't work in the water
 local xdir = 0
 local ydir = -10
 if btn(2) == true then	-- diagonals
  if(btn(1)) xdir += 10
  if(btn(0)) xdir -=10
 end
 local hit,rx,ry = map_line_check(pl.x,pl.y,pl.x + xdir,pl.y + ydir,k_sprflg_solid)
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
 if btn(4) == false or pl.in_water == true then
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
 
 pl.dx *= 0.9
 pl.dy *= 0.9
 
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
   spawn_sprite_explosion(new_tile,flr(b.x),flr(b.y))
   new_tile = k_tile_back
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

-- check if an actor is standing on a platform
function check_actor_platform(a)
 for p in all(platforms) do
  -- check if platform is below actor
  local x=p.x - a.x
  local y=p.y - a.y

  -- on top of?
  if ((abs(x) < (a.w + p.w)) and y > 0 and (y < (a.h + p.h + k_pixmap))) then 
    a.platform = p
	a.y = p.y - (a.h + p.h + k_pixmap) -- snap on top of platform
	
	if a.rope!=nil then -- re-lengthen rope
	 local dx = a.rope.anchor.x - a.x
	 local dy = a.rope.anchor.y - a.y
	 a.rope.length = sqrt((dx * dx) + (dy * dy)) -- store initial rop length
	end
  else
   a.platform = nil
  end
 end
end

-- calculate an outcode for a givven point
function calc_outcode(p,x,y)
 local outcode = 0
 if(x < p.x - p.w) outcode = bor(outcode, 1 )
 if(x > p.x + p.w) outcode = bor(outcode, 2 )
 if(y < p.y - p.h) outcode = bor(outcode, 4 )
 if(y > p.y + p.h) outcode = bor(outcode, 8 )
 return outcode
end

-- check if a line intersects a platform
-- returns platform (nil if none) & intersection position
function check_line_platform(x1,y1,x2,y2)
 local platform = nil
 local closest_dist_2 = 100 * 100
 
 for p in all(platforms) do
  -- check line against platform AABB
  -- calc outcodes
  local outa = calc_outcode(p,x1,y1)
  local outb = calc_outcode(p,x2,y2)
  
  -- does line go through AABB?
  if band(outa,outb)==0 then
  
  end
  
 end
 
 return platform,x2,y2
end

-- check_func is a function which returns if a position (x,y) is blocked
function calc_movement_range(x,y,xdir,size,check_func)
 local res = {}
 local max_range =0
 local start_pos = 0
 if xdir == true then 
  max_range = 127 
  start_pos = x
 else 
  max_range = 34 
  start_pos = y
 end
 local min_val = start_pos
 local max_val = start_pos + size
 
 while res.min == nil or res.max == nil do
  
  if res.min == nil then
   local xp = x
   local yp = y
   if xdir == true then xp = min_val else yp = min_val end
   if(check_func(xp,yp) == true) res.min = min_val + 1
   min_val -= 1
   if (min_val <= 0) res.min = 1 + 0.5
  end
  
  if res.max == nil then
   local xp = x
   local yp = y
   if xdir == true then xp = max_val else yp = max_val end
   if(check_func(xp,yp) == true) res.max = max_val - 1
   max_val += 1
   if (max_val >= max_range) res.max = max_range - 1
  end
 end
 return res
end

-- returns if position is blocked for platforms
function platform_move_check(xp,yp)
 local tval = mget(xp,yp)
 if(fget(tval,k_sprflg_solid) == true or tval == k_tile_block) return true
 return false
end


function create_platform(x,y,spr)
 p = create_actor(x,y)
 p.spr = 25
 p.solid = true
 p.platform = true
 p.speed = 0.06
 p.xdir = false
 p.draw = draw_platform
 if(spr == 65) p.xdir = true

 -- calc movement range
 local size = 1
 local range = calc_movement_range(x,y,p.xdir,size,platform_move_check)
 if p.xdir == false then -- vertical
  p.miny = range.min
  p.maxy = range.max
  p.dy = p.speed
 else -- horizontal
  p.minx = range.min
  p.maxx = range.max
  p.dx = p.speed
 end
 
 add(platforms,p)
 return p
end

function move_platform(p)
 local overlap = overlapping_actor(p,p.dx,p.dy)
 if overlap != nil and overlap.solid == true and overlap.platform == false then
  overlap.x+=p.dx
  overlap.y+=p.dy
 end
 
 p.x += p.dx
 p.y += p.dy
 
 if p.minx!=nil and p.x <= p.minx then
  p.dx = p.speed
 end
 if p.maxx!=nil and p.x >= p.maxx then
  p.dx = -p.speed
 end
 if p.miny!=nil and p.y <= p.miny then
  p.dy = p.speed
 end
 if p.maxy!=nil and p.y >= p.maxy then
  p.dy = -p.speed
 end
 
end

function draw_platform(a)
 local sx,sy = world_to_screen(a.x,a.y)
 spr(a.spr + a.frame, sx-4, sy-4)

end

-- enemy

-- returns if position is blocked for platforms
function enemy_move_check(xp,yp)
 local tval = mget(xp,yp)
 local tbelow = mget(xp,yp+1)
 if(fget(tval,k_sprflg_solid) == true or fget(tbelow,k_sprflg_solid) == false) return true
 return false
end

function create_enemy(x,y,spr)
 a = create_actor(x,y)
 a.update = enemy_update
 a.draw = enemy_draw
 a.spr = spr
 a.speed = 0.5 * k_pixmap
 a.xdir = true
 a.deadly = true
 a.pause_timer = 0
 a.turn_pause = 10
 
 -- calc movement range
 local size = 1
 local range = calc_movement_range(x,y,a.xdir,size,enemy_move_check)
 if a.xdir == false then -- vertical
  a.miny = range.min
  a.maxy = range.max
  a.dy = a.speed
 else -- horizontal
  a.minx = range.min
  a.maxx = range.max
  a.dx = a.speed
 end
 
 return p
end

function enemy_update(a)

 if a.pause_timer > 0 then
  a.pause_timer-=1
  return
 end
 
 a.x += a.dx
 a.y += a.dy
 
 if a.minx!=nil and a.x <= a.minx then
  a.dx = a.speed
  a.pause_timer = a.turn_pause
 end
 if a.maxx!=nil and a.x >= a.maxx then
  a.dx = -a.speed
  a.pause_timer = a.turn_pause
 end
 if a.miny!=nil and a.y <= a.miny then
  a.dy = p.speed
  a.pause_timer = a.turn_pause
 end
 if a.maxy!=nil and a.y >= a.maxy then
  a.dy = -a.speed
  a.pause_timer = a.turn_pause
 end
end

function enemy_draw(a)
 local sx = ((a.x - map_off_x) * 8) - 4
 local sy = ((a.y - map_off_y) * 8) - 4
 local flip_x = false	
 local flip_y = false
 
 if(a.alive == false) return -- don't render dead player
 
 -- flip actor l/r based on vel
 if (a.dx < 0) flip_x = true 
 spr(a.spr + a.frame, sx, sy,1,1,flip_x,flip_y)
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
  local sx,sy = world_to_screen(p.x,p.y)
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

function spawn_pickup_effect(x,y)
 local no_parts = 16
 local ang = rnd(1)
 local delta = 1/no_parts
 local speed = 0.2
 for i=1,no_parts do
  p = add_particle()
  p.life = 10
  p.x = x
  p.y = y
  p.dx = sin(rnd(1)) * (speed)
  p.dy = cos(rnd(1)) * (speed)
  p.grav = 0
  p.col = 10
  ang+=delta
 end
end

function spawn_sprite_explosion(n,x,y)
 local sx = 8 * (n % 16)
 local sy = 8 * flr(n / 16)
 for xoff=0,8 do
  for yoff=0,8 do
   local col = sget(sx + xoff,sy + yoff)
   if col != 0 then
    p = add_particle()
    p.life = 30
    p.x = x + (xoff * k_pixmap)
    p.y = y + (yoff * k_pixmap)
    p.dx = -0.5 + rnd(1.0)
    p.dy = -0.5 + rnd(1.0) 
    p.grav = 0--k_grav * 0.2
	p.col = col
   end 
  end
 end
end

-->8

-- misc graphics routines
function world_to_screen(x,y)
 local sx = ((x - map_off_x) * 8) 
 local sy = ((y - map_off_y) * 8) 
 return sx,sy
end

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
aaaaaaaa004444000044440000aaaa00cccccccc000000006ccccccc6ccccccc6c0cccc077777775000000000000000000000000000000000000000000000000
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
77777777700000077000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000707007070700007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07070700770000770070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070000777777770007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070000770000770007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07070700707007070070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000700000070700007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777700000077000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0002020200040404040404040404040000000008100022222202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0300000000000005131313000000000000000000001616160314141414141403030303030303031414030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000003030303030000000000000000001616160314141414141414141414141414141414030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
031100004241000000000000000042000b0b0b00001616160314141414141414141414141414141403030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030303090909090909090909030303030303030303030303030303030303030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0002000009050080500805001000010001105011050100501500015000150001b0501a0501b0502a0002b0002c0002705027050270502e0002e0002e0002e0502d0502d0502d0002d0002c0003f0503f0503e050
000100000c55012540075100050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100003073020750217201171000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
