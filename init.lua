-- ======== FYI ======== 

minetest.register_craft({
	output = "nudger:nudger",
	recipe = {
		{"default:copper_ingot"},
		{"group:stick"}
	}
})

nudger = {}
local transforms = {}

nudger.register_transforms = function(prefix, suffixes, cost, callback)
--[[
	prefix = string. First common part of node names. Longer is better. Can be ''.
	suffixes = table of strings. Remainders of node names with prefix removed. Can include ''.
	cost = integer. How many rotations worth of tool wear should one transform cost for this group.
	callback = function, called with (pos). In case other adjustments are needed after transforming. Can be nil.
--]]
	local l, n = string.len(prefix), 0
	for i,j in ipairs(transforms) do
		if string.len(j[1]) <= l then break end
		n=i
	end
	table.insert(transforms,n+1,{prefix, suffixes, cost, callback})
end

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
	"Reverse directions.",
	"Store orientation.",
	"Equip orientation.",
	"Transform.",
	"Toggle chat level.",
	"Get sixel node for 20% tool wear.",
	"",
-- submenu
	"Nudge to orientation.",
	"Store ...",
}


-- ======== Helpers ======== 

local function say(msg, plr, sh)
	if sh ~= 1 then minetest.chat_send_player(plr and plr:get_player_name() or "singleplayer", msg) end
end

local function edit_ok(pos, plr)
	if minetest.is_protected(pos, plr:get_player_name()) then
		minetest.record_protection_violation(pos, plr:get_player_name())
		return
	end
	return true
end

local function node_ok(pos, plr)
	local node = minetest.get_node(pos)
	local ndef = minetest.registered_nodes[node.name]
	if not ndef or not (ndef.paramtype2 == "facedir") or node.param2 == nil
	or (ndef.drawtype == "nodebox" and not (ndef.node_box.type == "fixed")) then
		if plr then say("Target can't be nudged.", plr) end
		return
	end
	return node
end

local function is_sixel(pos)
	return minetest.get_node(pos).name:sub(1,12) == "nudger:sixel"
end
local function tool_use(istk, cost, pos)
	if not pos or not is_sixel(pos) then
		local wear = tonumber(istk:get_wear()) + 257*cost
		if wear > 65534 then istk:clear()
		else istk:set_wear(wear)
		end
	end
end


-- ======== Actions ======== 

-- Choose axis of rotation

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
local function choose_axis(plr, ptd, mode)
	local axis, sign = face(ptd)
	if mode == 0 then return axis, sign
	elseif axis ~= 1 then
		if mode == 1 then return 1, 1
		else return 2-axis, (axis-1)*sign 
		end
	else
		local hdir = (5 - math.floor(plr:get_look_yaw()/1.571+.5))%4
		if mode == 2 then return axsgn((hdir+3)%4)
		elseif sign == 1 then return axsgn(hdir)
		else return axsgn((hdir+2)%4)
		end
	end

end

-- == Rotate ==

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

local function rotate(istk, plr, ptd, mode, sgn)
	local pos = ptd.under
	local node = node_ok(pos, plr)
	if not node then return end
	local p = (node.param2)%24
	local q, r = math.floor(p/4), p%4
	local a, s = choose_axis(plr,ptd,mode)
	local t = map[a+1]
	local k = t[1][q+1]
	s = s*sgn
	if k == -1 then p = t[4] + (p + 4 + s)%4
	elseif k == -2 then p = t[5] - (t[5] - p + 3 + s)%4 - 1
	else
		local o, i = t[3], (k + 4 + s)%4 + 1
		p = t[2][i] + (r + o[k+1] + 4 - o[i])%4
	end
	node.param2 = p
	minetest.swap_node(pos, node)
	tool_use(istk, 1, pos)
	return p
end

-- == Store / Apply Orientation ==

local function store(istk, pos)
	local node = node_ok(pos)
	if not node then return 0 end
	tool_use(istk, 8, pos)
	return node.param2
end

local function apply(istk, pos, plr, p2)
	local node = node_ok(pos, plr)
	if not node then return end
	node.param2 = p2
	minetest.swap_node(pos, node)
	tool_use(istk, 1, pos)
	return p2
end

-- == Transform == 

local function transform(istk,pos,plr)
	local node = minetest.get_node(pos)
	local name = node.name
	for i,j in ipairs(transforms) do
		if string.match(name,'^'..j[1]) then
			s = string.sub(name, string.len(j[1])+1)
			jj = j[2]
			for k,t in ipairs(jj) do
				if t == s then
					node.name=j[1]..jj[k%#jj+1]
					minetest.swap_node(pos,node)
					if j[4] then j[4](pos) end
					tool_use(istk,j[3])
					return
				end
			end
		end
	end
	say("Target can't transform.",plr)
end


-- ======== Sixel ======== 

local function sixel(istk,plr)
	if tonumber(istk:get_wear()) > 52428 then
		say("Sorry, this nudger is too damaged.",plr)
	else
		tool_use(istk,51,nil)
		local inv = plr:get_inventory()
		local stk = inv:add_item("main",ItemStack("nudger:sixel"))
		if not stk:is_empty() then
			minetest.item_drop(stk,plr,plr:get_pos())
		end
		say("Sixel can be nudged without tool damage,",plr)
		say(" and reports its param2 with 'More chat.'",plr)
	end
end


-- ======== Interface ======== 

local function do_on_use(istk, plr, ptd, rt)
	local m = tonumber(istk:get_metadata())
	if m then
	-- unpack metadata
		local p2 = math.floor(m/120)
		local sh = math.floor((m%120)/60)
		local mm = math.floor((m%60)/6)
		local rm = m%6
		local sr, dr = math.floor(rm/3), rm%3
	-- Switch menus
		if rt then
			mm = (mm == 0 and 1) or 0
			if mm == 1 then
				say(menu1[1], plr, sh)
				istk:set_name("nudger:nudger")
			else
				istk:set_name("nudger:nudger"..rm)
			end
	-- Cycle menu options
		elseif plr:get_player_control().sneak then
			if mm == 0 then
				rm = 3*sr + (dr + 1)%3
			elseif mm < 7 then
				mm = mm%6 + 1
			elseif mm < 10 then
				mm = 17 - mm
			end
			-- show correct tool
			if mm == 0 then
				say(menu0[rm + 1], plr, sh)
				istk:set_name("nudger:nudger"..rm)
			else
				say(menu1[mm], plr)
				if mm == 3 or mm == 5 then istk:set_name("nudger:nudger")
				elseif mm == 2 or mm == 9 then istk:set_name("nudger:nudger6")
				elseif mm == 4 then istk:set_name("nudger:nudger8")
				elseif mm == 8 then istk:set_name("nudger:nudger7")
				end
			end
	-- Apply menu actions
		else
			local once = true
			if mm == 1 then
				rm = 3*(1 - sr) + dr
				say("Reversed.", plr, sh)
			elseif mm == 5 then
				sh = 1 - sh
				say(((sh==0 and "More") or "Less").." chat.", plr)
			elseif mm == 6 then
				sixel(istk,plr)
			else
				local pos = ptd.type == "node" and ptd.under
				if pos then
					if mm == 2 or mm == 3 or mm == 9 then
						if mm ~= 3 then
							p2 = store(istk, pos)
							say(p2.." Stored.", plr, sh)
						end
						if mm ~= 9 then say("  * storage submenu *", plr, sh) end
						mm = 8
						istk:set_name("nudger:nudger7")
						say(menu1[8], plr)
					elseif edit_ok(pos, plr) then
						local qp2
						if mm == 0 then
							qp2 = rotate(istk, plr, ptd, dr, 1-2*sr)
						elseif mm == 4 then
							transform(istk,pos,plr)
						elseif mm == 8 then
							qp2 = apply(istk, pos, plr, p2)
						end
						if qp2 and is_sixel(pos) then
							say("sixel: "..qp2, plr, sh)
						end
					end
				end
				once = false
			end
			if once then
				mm = 0
				istk:set_name("nudger:nudger"..rm)
			end
		end
		m = 120*p2 + 60*sh + 6*mm + rm
	else m = 0
		say("Shift click to cycle menu options.", plr)
		say("Right click to switch menus.", plr)
		istk:set_name("nudger:nudger0")
	end
	istk:set_metadata(m)
	return istk
end


-- ======== Registration ======== 

-- * Tools *

minetest.register_tool("nudger:nudger", {
	description = "Nudger",
	inventory_image = "nudger.png",
	on_use = function(istk, plr, ptd)
		return do_on_use(istk, plr, ptd)
	end,
	on_place = function(istk, plr, ptd)
		return do_on_use(istk, plr, ptd, 1)
	end,
})

local adj={"+cw","lf","dn","-cw","rt","up","store","apply"}

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
			return do_on_use(istk, plr, ptd, 1)
		end,
	})
end

minetest.register_tool("nudger:nudger8", {
	description = "Gerund",
	inventory_image = "nudger.png^[transform1",
	on_use = function(istk, plr, ptd)
		return do_on_use(istk, plr, ptd)
	end,
	on_place = function(istk, plr, ptd)
		return do_on_use(istk, plr, ptd, 1)
	end,
})

-- * Nodes *

minetest.register_node("nudger:sixel", {
	description = "Sixel",
	drop = "nudger:sixel",
	tiles = {"sixel_tp.png","sixel_bt.png","sixel_rt.png","sixel_lf.png","sixel_ft.png","sixel_bk.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	sunlight_propagates = true,
	groups = {dig_immediate=3},
})

minetest.register_node("nudger:sixel_t", {
	description = "Sixel t",
	drop = "nudger:sixel",
	tiles = {"sixel_t2.png","sixel_t2.png","sixel_t1.png","sixel_t3.png","sixel_t1.png","sixel_t3.png",},
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	sunlight_propagates = true,
	groups = {dig_immediate=3,not_in_creative_inventory=1},
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.3, -0.3},
			{-0.3, -0.3, -0.5, -0.1, 0.5, -0.3},
			{-0.5, -0.3, -0.5, -0.3, -0.1, 0.5},
		},
	},
})

-- * Transforms *

local function example(pos)
	say('Sixel transformed at '..pos.x..','..pos.y..','..pos.z)
end

nudger.register_transforms('nudger:sixel', {'','_t'}, 0, example)
