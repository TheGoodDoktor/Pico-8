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
test_model = {
	x = [10,10,10,10],
	y = [20,20,20,20],
	lines = [
		[1,2],
		[2,3],
		[3,4]
	]
}

function draw_model(x,y,scale,angle,model)
 for line in all(model.lines)
  local col = 7 -- white
  local x1 = model.x[line[1]] * scale
  local y1 = model.y[line[1]] * scale
  local x2 = model.x[line[2]] * scale
  local y2 = model.y[line[2]] * scale
  -- todo: transform into screen space
  line(x1,y1,x2,y2,col)
 end
end

-->8
function create_player(x,y)
 player = create_actor(x,y)
end
-->8
function _init()
 create_player(100,100)
end

function _update()
 update_actors()
end

function _draw()
 draw_actors()
end



