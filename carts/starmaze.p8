pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- actor system
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
 a.alive = true
 a.death_timer = 0
 -- half-width and half-height
 a.w = 0.5
 a.h = 0.5
 
 add(actors,a)
 
 return a
end

-- kill actor and remove from actor list
function kill_actor(a)
 del(actors,a)
end

-- update all actors that have an update function
function update_actors()
 for actor in all(actors) do
	if actor.update != nil then
		actor.update(actor)
	end	
 end
end

-- draw all actors that have a draw function
function draw_actors()
 for actor in all(actors) do
  if actor.draw != nil then
   actor.draw(actor)
  end
 end
end

-- test model definition
ship_model = {
	x = {0,4,-4,3,-3},
	y = {-8,8,8,4,4},
	lines = {
		{1,2},
		{1,3},
		{4,5}
	}
}

function rotate_2d_point(x,y,angle)
 local rx = x * cos(angle) - y * sin(angle)
 local ry = y * cos(angle) + x * sin(angle)
 return rx,ry
end

function draw_model(x,y,scale,angle,model)
 for l in all(model.lines) do
  local col = 7 -- white
  local x1 = model.x[l[1]] * scale
  local y1 = model.y[l[1]] * scale
  local x2 = model.x[l[2]] * scale
  local y2 = model.y[l[2]] * scale
  
  -- rotate
  x1,y1 = rotate_2d_point(x1,y1,angle)
  x2,y2 = rotate_2d_point(x2,y2,angle)
  
  line(x1 + x,y1 + y,x2 + x,y2 + y,col)
 end
end

-->8
function create_game_actor(x,y)
 local actor = create_actor(x,y)
 -- TODO: specific setup for our game actors
 return actor
end

function create_player(x,y)
 local pl = create_game_actor(x,y)
 pl.update = update_player
 pl.draw = draw_player
 pl.scale = 0.5
 pl.angle = 0
 return pl
end

function update_player(pl)
 pl.angle +=0.01
end

function draw_player(pl)
 draw_model(pl.x,pl.y,pl.scale,pl.angle,ship_model)
end

-->8
function _init()
 create_player(100,100)
end

function _update()
 update_actors()
end

function _draw()
 cls()
 draw_actors()
end



