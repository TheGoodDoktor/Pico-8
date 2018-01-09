pico-8 cartridge // http://www.pico-8.com
version 15
__lua__
stars={}
no_stars=1000
z_range = 2000
speed = 20
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

	ang = 0
	delta = 1 / no_stars
	
	for i=1,no_stars do
		s = {}
		--s.x = 64 - rnd(128)
		--s.y = 64 - rnd(128)
		ang += delta
		s.x = sin(ang) * 64
		s.y = cos(ang) * 64
		s.z = rnd(z_range)
		s.line = true
		s.cols = fade_col[(i%6)+1];
		add(stars,s)
	end

end

function _update()
	for s in all(stars) do
		s.z -= speed;
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

function project(x,y,z)
		local scr_x = 64 + (256 * (x + off_x)) / z
		local scr_y = 64 + (256 * (y + off_y)) / z
		return scr_x,scr_y
end

function _draw()
	cls()
	for s in all(stars) do
		col = s.cols[flr(s.z / (z_range/4))+1]
		scr_x,scr_y = project(s.x,s.y,s.z)
		
		--scr_x = 64 + (256 * s.x) / s.z
		--scr_y = 64 + (256 * s.y) / s.z
		
		if s.line == true then
		 line_x,line_y = project(s.x,s.y,s.z+speed) 
		 line(scr_x,scr_y,line_x,line_y,col)
		else
			pset(scr_x,scr_y,col)
		end
		
	end

end
