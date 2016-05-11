--[[

Copyright (C) 2016 Aftermoth, Zolan Davis

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation; either version 2.1 of the License,
or (at your option) version 3 of the License.

http://www.gnu.org/licenses/lgpl-2.1.html


--]]
nudger = {}

-- ======== FYI ======== 

minetest.register_alias("nudger", "nudger:nudger")

minetest.register_craft({
	output = "nudger:nudger",
	recipe = {
		{"default:copper_ingot"},
		{"group:stick"}
	}
})

-- ======== Chat ======== 

local menu0 = {
	"Nudge clockwise.",
	"Nudge leftwards.",
	"Nudge downwards.",
	"Nudge anticlockwise.",
	"Nudge rightwards.",
	"Nudge upwards.",
}

local menu1 = {
	"Reverse rotations.",
	"Store a node's rotation.",
	"Equip stored rotation.",
	"Toggle chat level.",
	"Buy nudgiquin for 20% tool wear.",  -- "i" for less ambiguous pronunciation.
	"",

	"Nudge to stored rotation.",
	"Store ...",
	"",
}
local infos = {
	"Reversed.",
	"Stored.",
	"* Apply mode is active *",
	"More chat.",
	"Less chat.",
	"Shift+click to cycle options.",
	"Right click to toggle menu.",
	"Sorry, this nudger's too damaged.",
	"Nudgiquin can be nudged freely with no tool damage.",
}


-- ======== Helpers ======== 

local function say(msg, plr)
	local name
	if minetest.is_singleplayer() then name = "singleplayer" else name = plr:get_player_name() end
	minetest.chat_send_player(name, msg)
end

local function edit_ok(pos, plr)
	if minetest.is_protected(pos, plr:get_player_name()) then
		minetest.record_protection_violation(pos, plr:get_player_name())
		return
	end
	return true
end

local function node_ok(pos)
	local node = minetest.get_node_or_nil(pos)
	local ndef = minetest.registered_nodes[node.name]
	if not ndef or not ndef.paramtype2 == "facedir" or node.param2 == nil
	or (ndef.drawtype == "nodebox" and not ndef.node_box.type == "fixed") then
		say("Target can't be nudged.", plr)
		return
	end
	return node
end

local function tool_use(istk, cost, pos)
	if not pos or minetest.get_node_or_nil(pos).name ~= "nudger:nudgiquin" then
		local wear = tonumber(istk:get_wear()) + 327*cost
		if wear > 65535 then istk:clear()
		else istk:set_wear(wear)
		end
	end
	return istk
end


-- ======== Rotation ======== 

-- == Choose axis of rotation ==

local function face(ptd)
	local a, u = ptd.above.x, ptd.under.x
	if a > u then return 0,1
	elseif u > a then return 0,-1
	else
		a, u = ptd.above.y, ptd.under.y
		if a > u then return 1,1
		elseif u > a then return 1,-1
		else
			a, u = ptd.above.z, ptd.under.z
			if a > u then return 2,1
			elseif u > a then return 2,-1
			end
		end
	end
end

local function axsgn(d)
	if d%2 == 0 then return 2, 1-d
	else return 0, 2-d
	end
end
local function choose_axis(plr,ptd,mode)
	local axis, sign = face(ptd)
	if mode == 0 then return axis, sign
	elseif axis ~= 1 then
		if mode == 1 then return 1, 1
		else return 2-axis, (axis-1)*sign 
		end
	else
		local hdir = (5 - math.floor(plr:get_look_yaw()/1.571+.5))%4
		if mode == 2 then return axsgn((hdir+3)%4)
		elseif sign == 1 then
			return axsgn(hdir)
		else
			return axsgn((hdir+2)%4)
		end
	end

end

-- == Do rotation ==

local map = {
	{  -- x
		{0, 1, 3, -1, -2, 2},
		{0, 4, 20, 8},
		{0, 0, 2, 0}, 12, 20,
	},
	{  --y
		{-1, 0, 2, 1, 3, -2},
		{4, 12, 8, 16},
		{0, 3, 2, 1}, 0, 24,
	},
	{  --z
		{0, -1, -2, 3, 1, 2},
		{0, 16, 20, 12},
		{0, 0, 0, 0}, 4, 12,
	},
}

local function rotate(istk,plr,ptd,mode,sgn)
	local pos = ptd.under
	local node = node_ok(pos)
	if not node then return end
	local p = (node.param2)%24
	local a, s = choose_axis(plr,ptd,mode)
	local t = map[a+1]
	local q, r = math.floor(p/4), p%4
	local k = t[1][q+1]
	s = s*sgn
	if k == -1 then p = t[4] + (p+4+s)%4
	elseif k == -2 then p = t[5] - (t[5]-p+3+s)%4 - 1
	else
		local o, i = t[3], (k+4+s)%4+1
		p = t[2][i] + (r + o[k+1] + 4 - o[i])%4
	end
	node.param2 = p
	minetest.swap_node(pos, node)
	return tool_use(istk, 1, pos)
end

-- == Store / Apply ==

local function store(istk,pos)
	local node = node_ok(pos)
	if not node then return end
	return tool_use(istk, 4, pos), node.param2
end

local function apply(istk,pos,p2)
	local node = node_ok(pos)
	if not node then return end
	node.param2 = p2
	minetest.swap_node(pos, node)
	return tool_use(istk, 1, pos)
end


-- ======== Interface ======== 

local function shop(istk,plr)
	if tonumber(istk:get_wear()) > 52428 then
		say(infos[8],plr)
	else
		tool_use(istk,40,nil)
		local inv = plr:get_inventory()
		local stk = inv:add_item("main",ItemStack("nudger:nudgiquin"))
		if not stk:is_empty() then
			minetest.item_drop(stk,plr,plr:get_pos())
		end
		say(infos[9],plr)
	end
end

local function reset(istk, plr)
	say(infos[6], plr)
	say(infos[7], plr)
	istk:set_name("nudger:nudger0")
	return 0
end

local function do_on_use(istk, plr, ptd)
	local m = tonumber(istk:get_metadata())
	if not m then m = reset(istk, plr) end
	-- unpack metadata
	local p2 = math.floor(m/120)
	local sh = math.floor((m%120)/60)
	local mm = math.floor((m%60)/6)
	local rm = m%6
	local sr, dr = math.floor(rm/3), rm%3
-- options
	if plr:get_player_control().sneak then
		if mm == 0 then			-- change axis
			dr = (dr + 1)%3
			rm = 3*sr + dr
		elseif mm < 6 then		-- main submenu
			mm = mm%5 + 1
		elseif mm < 9 then		-- apply submenu
			mm = 15 - mm
		end
		
		if mm == 0 then
			if sh==0 then say(menu0[rm + 1], plr) end
			istk:set_name("nudger:nudger"..rm)
		else
			say(menu1[mm], plr)
			if mm == 2 or mm == 8 then istk:set_name("nudger:nudger6")
			elseif mm == 3 then istk:set_name("nudger:nudger")
			elseif mm == 7 then istk:set_name("nudger:nudger7")
			end
		end
-- actions
	else
		local tmp
		local once = true
		if mm == 1 then		-- change sign
			sr = 1 - sr
			rm = 3*sr + dr
			if sh==0 then say(infos[1], plr) end
		elseif mm == 4 then		-- toggle chat
			sh = 1 - sh
			say(infos[4+sh], plr)
			-- 5	help
		elseif mm == 5 then		-- buy nudgiquin
			shop(istk,plr)
		else
			-- 
			once = false
		end
		local pos = (ptd.type == "node" and ptd.under) or false
		if pos and not once then
			if mm == 0 then
				if edit_ok(pos,plr) then
					istk = rotate(istk,plr,ptd,dr,1-2*sr)
				end
			elseif mm == 2 or mm == 3 or mm == 8 then
				if mm == 2 or mm == 8 then		--store
					istk, tmp = store(istk,pos)
					if tmp then p2 = tmp end
					if sh==0 then say(infos[2], plr) end
				end
					-- switch to apply mode and menu
				if sh==0 and not mm == 8 then say(infos[3], plr) end
				mm = 7
				istk:set_name("nudger:nudger7")
				say(menu1[7], plr)
			elseif mm == 7 then		-- apply
				if edit_ok(pos,plr) then
					istk =  apply(istk,pos,p2)
				end
			end
		end
		
		if once then
			mm = 0
			istk:set_name("nudger:nudger"..rm)
		end
		
	end
	istk:set_metadata(120*p2 + 60*sh + 6*mm + rm)
	return istk
end

local function do_on_place(istk, plr) 
	local m = tonumber(istk:get_metadata())
	if not m then m = reset(istk, plr)
	else
		local mh = math.floor(m/60)
		local sh = mh%2
		local mm = math.floor((m%60)/6)
		local rm = m%6
		mm = (mm == 0 and 1) or 0
		if mm == 1 then
			if sh==0 then say(menu1[1], plr) end
			istk:set_name("nudger:nudger")
		else
			istk:set_name("nudger:nudger"..rm)
		end
		m = 60*mh + 6*mm + rm
	end
	
	istk:set_metadata(m)
	return istk
end


-- ======== Registration ======== 

minetest.register_tool("nudger:nudger", {
	description = "Nudger",
	inventory_image = "nudger.png",
	on_use = function(istk, plr, ptd)
		return do_on_use(istk, plr, ptd)
	end,
	on_place = function(istk, plr, ptd)
		return do_on_place(istk, plr)
	end,
})

local adj={"+cw","lf","dn","-cw","rt","up","copy","paste"}

for i = 0, 7 do
	minetest.register_tool("nudger:nudger"..i, {
		description = "Nudger ("..adj[i+1]..")",
		inventory_image = "nudger.png^nudge"..i..".png",
		wield_image = "nudger.png",
		groups = {not_in_creative_inventory=1},
		on_use = function(istk, plr, ptd)
			return do_on_use(istk, plr, ptd)
		end,
	on_place = function(istk, plr, ptd)
		return do_on_place(istk, plr)
	end,
	})
end

minetest.register_node("nudger:nudgiquin", {
	
	description = "Nudgiquin",
	drop = "nudger:nudgiquin",
	tiles = {"nudgiquin_up.png","nudgiquin_dn.png","nudgiquin_rt.png","nudgiquin_lf.png","nudgiquin_fc.png","nudgiquin_bk.png"},
	paramtype2 = "facedir",
	is_ground_content = false,
	sunlight_propagates = true,
	groups = {dig_immediate=3},
})
