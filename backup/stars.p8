pico-8 cartridge // http://www.pico-8.com
version 15
__lua__
stars={}
no_stars=100
star_speed=10
lines={}
no_lines=1000
z_range = 2000
line_speed = 20
off_x=0
off_y=0
off_range = 60
fade_col = {
	{7,6,5},
	{10,9,5},
	{12,1,2},
	{11,3,5},
	{13,2,5},
	{15,4,5}
}

function _init()

	-- tunnel of lines
	ang = 0
	delta = 1 / no_lines
	
	for i=1,no_lines do
		l = {}
		ang += delta
		l.x = sin(ang) * 64
		l.y = cos(ang) * 64
		l.z = rnd(z_range)
		l.cols = fade_col[(i%6)+1];
		add(lines,l)
	end
	
	--stars
	for i=1,no_stars do
		s = {}
		s.x = 64 - rnd(128)
		s.y = 64 - rnd(128)
		s.z = rnd(z_range)
		s.cols = {7,6,5}
		add(stars,s)
	end

end

function _update()

	-- lines
	for l in all(lines) do
		l.z -= line_speed;
		if l.z < 1 then
			l.z=z_range
		end
	end
	
	-- stars
	for s in all(stars) do
		s.z -= star_speed;
		if s.z < 1 then
			s.z=z_range
		end
	end
	
	if btn(0) then
		off_x += 1
	end
	if btn(1) then
		off_x -= 1
	end
	if btn(2) then
		off_y += 1
	end
	if btn(3) then
		off_y -= 1
	end
	
	if off_x > off_range then
		off_x=off_range
	end
	if off_x < -off_range then
		off_x=-off_range
	end
	if off_y > off_range then
		off_y=off_range
	end
	if off_y < -off_range then
		off_y=-off_range
	end
end

-- project a 3d point onto the screen
function project(x,y,z)
		local scr_x = 64 + (256 * (x + off_x)) / z
		local scr_y = 64 + (256 * (y + off_y)) / z
		return scr_x,scr_y
end

function _draw()
	cls()
	
	-- stars
	for s in all(stars) do
		local col = s.cols[flr(s.z / (z_range/4))+1]
		local scr_x,scr_y = project(s.x,s.y,s.z)
		--pset(scr_x,scr_y,col)
		circfill(scr_x,scr_y,256 / s.z)
	end	
	
	-- lines
	for l in all(lines) do
		local col = l.cols[flr(l.z / (z_range/4))+1]
		local x1,y1 = project(l.x,l.y,l.z)
		local x2,y2 = project(l.x,l.y,l.z+line_speed) 
		line(x1,y1,x2,y2,col)
	end

end
