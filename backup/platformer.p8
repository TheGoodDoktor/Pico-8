pico-8 cartridge // http://www.pico-8.com
version 15
__lua__

-- map scroll values
map_off_x = 0
map_off_y = 0
global_tick = 0

actors = {} --all actors in world

-- make an actor
-- and add to global collection
-- x,y means center of the actor
-- in map tiles (not pixels)
function make_actor(x, y)
 a={}
 a.x = x
 a.y = y
 a.dx = 0
 a.dy = 0
 a.spr = 16
 a.frame = 0
 a.t = 0
 a.inertia = 0.6
 a.bounce  = 1
 a.frames=2
 a.solid = false
 a.grounded = false
 a.alive = true
 a.death_timer = 0
 -- half-width and half-height
 -- slightly less than 0.5 so
 -- that will fit through 1-wide
 -- holes.
 a.w = 0.4
 a.h = 0.4
 
 add(actors,a)
 
 return a
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
	create_fn(mx,my) -- create actor
	mset(mx,my,0)	-- clear tile
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
 -- make player top left
 --pl = create_player(2,2)
 
 setup_map()
 
 -- make a bouncy ball
 --[[local ball = make_actor(8.5,7.5)
 ball.spr = 33
 ball.dx=0.05
 ball.dy=-0.1
 ball.inertia=0.5
 
 local ball = make_actor(7,5)
 ball.spr = 49
 ball.dx=-0.1
 ball.dy=0.15
 ball.inertia=1
 ball.bounce = 0.8
 
 
 -- tiny guy
 
 a = make_actor(7,5)
 a.spr=5
 a.frames=4
 a.dx=1/8
 a.inertia=0.8
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
 if fget(tile, 3) then
	mset(x,y, background_tile)
	return tile
 end
 
end



-- true if a will hit another
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
     v=a.dx + a2.dy
     a.dx = v/2
     a2.dx = v/2
     return true 
    end
    
    if (dy != 0 and abs(y) < abs(a.y-a2.y)) then
     v=a.dy + a2.dy
     a.dy=v/2
     a2.dy=v/2
     return true 
    end
    
    --return true
    
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
 if check_map_area(a.x+dx,a.y+dy,a.w,a.h,1) then
    return true 
 end
 return solid_actor(a, dx, dy) 
end

function actor_check_death(a)
 -- check for death - todo: check for killer actors
 local death = false
 local overlap = overlapping_actor(a)
 if overlap != nil then
 end
 if check_map_area(a.x + a.dx,a.y + a.dy, a.w, a.h, 2) then death = true end
 
 if death == true and a.alive == true then 
  --kill actor
  a.alive = false
  a.death_timer = 100
  a.dy -= 2
 end
end

-- move actor with collision & gravity
function move_solid_actor(a)

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
 
 
 
 -- apply inertia
 a.dx *= a.inertia
 a.dy *= a.inertia
 
 -- update animation
 a.frame += abs(a.dx) * 4
 a.frame += abs(a.dy) * 4
 a.frame %= a.frames

 a.t += 1
 
end


-- call actor's update function
function update_actor(actor)
	if actor.update != nil then
		actor.update(actor)
	end	
end

function update_map()
 -- update map offset around player
 if pl != nil and pl.alive == true then
  map_off_x += ((pl.x - 8) - map_off_x) * 0.4
  if map_off_x < 0 then map_off_x = 0 end
  if map_off_x > 120 then map_off_x = 120 end
 
  map_off_y += ((pl.y - 8) - map_off_y) * 0.04
  if map_off_y < 0 then map_off_y = 0 end
  if map_off_y > 16 then map_off_y = 16 end
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

function _update()
 foreach(actors, update_actor)
 
 update_map()
 
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
end

function _draw()
 cls()
 
 -- map
 local mscrx = (map_off_x - flr(map_off_x)) * 8
 local mscry = (map_off_y - flr(map_off_y)) * 8
 map(map_off_x,map_off_y,-mscrx,-mscry,17,17)
 
 -- actors
 foreach(actors,draw_actor)
 
 -- player debug
 if pl == nil then
  print("no player",0,120)
 else
  print("x "..pl.x,0,120,7)
  print("y "..pl.y,64,120,7)
 
  -- player states
  if pl.grounded == true then print("g",100,120,7) end
  if pl.alive == true then  print("a",108,120,7) end
 end
end

-->8

-- individual actor code here

-- player code

function create_player(x,y)
 pl = make_actor(x,y)
 pl.spr = 17
 pl.restart_x = x
 pl.restart_y = y
 pl.jump_timer = 0
 pl.update = update_player
 pl.solid = true
 pl.pickups = 0
 return pl
end

-- register with factory
actor_create[17] = create_player

function restart_player()
 pl.x = pl.restart_x
 pl.y = pl.restart_y
 pl.dx = 0
 pl.dy = 0
 pl.alive = true
end

function update_player(pl)

 -- how fast to accelerate
 accel = 0.1
 
 -- left/right movement
 if (btn(0)) pl.dx -= accel 
 if (btn(1)) pl.dx += accel 

 -- jump controls
 if (btn(2)) then
	if pl.grounded == true then
		pl.dy -= 0.50
		pl.jump_timer = 0
		pl.grounded = false
	end 
	
	-- allow additional jump boost early on in the jump
	if pl.jump_timer < 10 then
		pl.dy -= 0.1
	end
 end
 
 -- update jump timer
 if (pl.grounded == false) pl.jump_timer+=1
 
 grav = 0.05
 pl.dy += grav

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


__gfx__
000000003bbbbbb7dccccc770cccccc00000000000ccc70000ccc70000ccc70000ccc70000880008080080000600060000000000000000000000000000000000
000000003000000bd0000077d000007c101110100cccccc00cccccc00cccccc00cccccc008888088088080800600060000000000000000000000000000000000
000000003000070bd000000cd000770c000000000cffffc00cffffc00cffffc00cffffc088888888888888800600060006000600000000000000000000000000
000000003000000bd000000cd000770c000000000c5ff5c00c5ff5c00c5ff5c00c5ff5c089889998889998980600060006000600000000000000000000000000
000000003000000bd000000cd000000c000000000cffffc00cffffcc0cffffc0ccffffc099999999999999996660666006000600000000000000000000000000
000000003000000bd000000cd000000c00101101ccccccccccccccc0cccccccc0cccccccaa99aaaa99aa9aa96660666006000600060006000000000000000000
000000003000000bd000000cd000000c000000000cccccc00cccccc00cccccc00cccccc0aaaaaaaaaaaaaaaa6660666066606660060006000600060000000000
00000000111111115111111101111110000000000c0000c0c00000c00c0000c00c00000caaaaaaaaaaaaaaaa6666666666666666666066606660666066606660
aaaaaaaa00ffff0000ffff0000aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000a00dffd0000dffd000aaaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000a00ffff0000ffff009aaa77aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000a0882288ff88228809aaa77aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000af08228000082280f9aaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000a00855800008558009aaaaaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000a005005000500005009aaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aaaaaaaa066006606600006600999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30303030303030303030303030303030303030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0002020200000000000404040404040000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0202020202020202030302020203030302030303030202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000003000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302020200000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200040000000000000100001300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200020000040000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000000000400000013000200030000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000011000000000401000200030000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0304000202020000000101000000020b0b0b0b03000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0200000202020000000400000200020202020203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202000000000002000000000204020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0309090909090909090909090909030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302020202030202020202020203020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000c55012540075100050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100003073020750217201171000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
