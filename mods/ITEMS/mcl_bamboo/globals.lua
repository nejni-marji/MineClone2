---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by michieal.
--- DateTime: 12/29/22 12:34 PM -- Restructure Date
--- Copyright (C) 2022 - 2023, Michieal. See License.txt

local DEBUG = false

local rand = math.random
math.randomseed((os.time() + 31) * 31415) -- try to make a valid seed
local BAMBOO_MAX_HEIGHT = 16 -- base height check.

local BAMBOO_SOIL_DIST = BAMBOO_MAX_HEIGHT * -1
local BAM_MAX_HEIGHT_STPCHK = BAMBOO_MAX_HEIGHT - 5
local BAM_MAX_HEIGHT_TOP = BAMBOO_MAX_HEIGHT - 1

local GROW_DOUBLE_CHANCE = 32

--Bamboo can be planted on moss blocks, grass blocks, dirt, coarse dirt, rooted dirt, gravel, mycelium, podzol, sand, red sand, or mud
mcl_bamboo.bamboo_dirt_nodes = {
	"mcl_core:redsand",
	"mcl_core:sand",
	"mcl_core:dirt",
	"mcl_core:coarse_dirt",
	"mcl_core:dirt_with_grass",
	"mcl_core:podzol",
	"mcl_core:mycelium",
	"mcl_lush_caves:rooted_dirt",
	"mcl_lush_caves:moss",
	"mcl_mud:mud",
}

function mcl_bamboo.is_dirt(node_name)
	return table.indexof(mcl_bamboo.bamboo_dirt_nodes, node_name) ~= -1
end

mcl_bamboo.bamboo_index = {
	"mcl_bamboo:bamboo",
	"mcl_bamboo:bamboo_1",
	"mcl_bamboo:bamboo_2",
	"mcl_bamboo:bamboo_3",
}

function mcl_bamboo.is_bamboo(node_name)
	return table.indexof(mcl_bamboo.bamboo_index, node_name)
end

--- pos: node position; placer: ObjectRef that is placing the item
--- returns: true if protected, otherwise false.
function mcl_bamboo.is_protected(pos, placer)
	local name = placer:get_player_name()
	if minetest.is_protected(pos, name) then
		minetest.record_protection_violation(pos, name)
		return true
	end
	return false
end

local BAMBOO_ENDCAP_NAME = "mcl_bamboo:bamboo_endcap"

function mcl_bamboo.grow_bamboo(pos, bonemeal_applied)
	local node_above = minetest.get_node(vector.offset(pos, 0, 1, 0))
	mcl_bamboo.mcl_log("Grow bamboo called; bonemeal: " .. tostring(bonemeal_applied))

	if not bonemeal_applied and mcl_bamboo.is_bamboo(node_above.name) == true then
		return false -- short circuit this function if we're trying to grow (std) the bamboo and it's not the top shoot.
	end
	if minetest.get_node_light(pos) < 8 then
		return false
	end

	-- variables used in more than one spot.
	local first_shoot
	local chk_pos
	local soil_pos
	local node_name = ""
	local dist = 0
	local node_below
	-- -------------------

	mcl_bamboo.mcl_log("Grow bamboo; checking for soil: ")
	-- the soil node below.
	for py = -1, BAMBOO_SOIL_DIST, -1 do
		chk_pos = vector.offset(pos, 0, py, 0)
		node_name = minetest.get_node(chk_pos).name
		if mcl_bamboo.is_dirt(node_name) then
			soil_pos = chk_pos
			break
		else
			if mcl_bamboo.is_bamboo(node_name) == false then
				break
			end
		end
	end
	-- requires knowing where the soil node is.
	if soil_pos == nil then
		return false -- returning false means don't use up the bonemeal.
	end

	mcl_bamboo.mcl_log("Grow bamboo; soil found. ")
	local grow_amount = rand(1, GROW_DOUBLE_CHANCE)
	grow_amount = rand(1, GROW_DOUBLE_CHANCE)
	grow_amount = rand(1, GROW_DOUBLE_CHANCE) -- because yeah, not truly random, or even a good prng.
	grow_amount = rand(1, GROW_DOUBLE_CHANCE)
	local init_height = rand(BAM_MAX_HEIGHT_STPCHK + 1, BAM_MAX_HEIGHT_TOP + 1)
	mcl_bamboo.mcl_log("Grow bamboo; random height: " .. init_height)

	node_name = ""

	-- update: add randomized max height to first node's meta data.
	first_shoot = vector.offset(soil_pos, 0, 1, 0)
	local meta = minetest.get_meta(first_shoot)
	node_below = minetest.get_node(first_shoot).name

	mcl_bamboo.mcl_log("Grow bamboo; checking height meta ")
	-- check the meta data for the first node, to see how high to make the stalk.
	if not meta then
		-- if no metadata, set the metadata!!!
		meta:set_int("height", init_height)
	end
	local height = meta:get_int("height", -1)
	mcl_bamboo.mcl_log("Grow bamboo; meta-height: " .. height)
	if height <= 10 then
		height = init_height
		meta:set_int("height", init_height)
	end

	mcl_bamboo.mcl_log("Grow bamboo; height: " .. height)

	-- Bonemeal: Grows the bamboo by 1-2 stems. (per the minecraft wiki.)
	if bonemeal_applied then
		-- handle applying bonemeal.
		for py = 1, BAM_MAX_HEIGHT_TOP do
			-- find the top node of bamboo.
			chk_pos = vector.offset(pos, 0, py, 0)
			node_name = minetest.get_node(chk_pos).name
			dist = vector.distance(soil_pos, chk_pos)
			if mcl_bamboo.is_bamboo(node_name) == false or node_name == BAMBOO_ENDCAP_NAME then
				break
			end
		end

		mcl_bamboo.mcl_log("Grow bamboo; dist: " .. dist)

		if node_name == BAMBOO_ENDCAP_NAME then
			-- prevent overgrowth
			return false
		end

		-- check to see if we have a full stalk of bamboo.
		if dist >= height - 1 then
			if dist == height - 1 then
				-- equals top of the stalk before the cap
				if node_name == "air" then
					mcl_bamboo.mcl_log("Grow bamboo; Placing endcap")
					minetest.set_node(vector.offset(chk_pos, 0, 1, 0), {name = BAMBOO_ENDCAP_NAME})
					return true -- returning true means use up the bonemeal.
				else
					return false
				end
			else
				-- okay, we're higher than the end cap, fail out.
				return false -- returning false means don't use up the bonemeal.
			end
		end

		-- and now, the meat of the section... add bamboo to the stalk.
		-- at this point, we should be lower than the generated maximum height. ~ about height -2 or lower.
		if dist <= height - 2 then
			if node_name == "air" then
				-- here we can check to see if we can do up to 2 bamboo shoots onto the stalk
				mcl_bamboo.mcl_log("Grow bamboo; Placing bamboo.")
				minetest.set_node(chk_pos, {name = node_below})
				-- handle growing a second node.
				if grow_amount == 2 then
					chk_pos = vector.offset(chk_pos, 0, 1, 0)
					if minetest.get_node(chk_pos).name == "air" then
						mcl_bamboo.mcl_log("Grow bamboo; OOOH! It's twofer day!")
						minetest.set_node(chk_pos, {name = node_below})
					end
				end
				return true -- exit out with a success. We've added 1-2 nodes, per the wiki.
			end
		end
	end

	-- Non-Bonemeal growth.
	for py = 1, BAM_MAX_HEIGHT_TOP do
		-- Find the topmost node above the stalk, and check it for "air"
		chk_pos = vector.offset(pos, 0, py, 0)
		node_below = minetest.get_node(pos).name
		node_name = minetest.get_node(chk_pos).name
		dist = vector.distance(soil_pos, chk_pos)

		if node_name ~= "air" and mcl_bamboo.is_bamboo(node_name) == false then
			break
		end

		-- stop growing check. ie, handle endcap placement.
		if dist >= height - 1 then
			local above_node_name = minetest.get_node(vector.offset(chk_pos, 0, 1, 0)).name
			if node_name == "air" and above_node_name == "air" then
				if height - 1 == dist then
					mcl_bamboo.mcl_log("Grow bamboo; Placing endcap")
					minetest.set_node(chk_pos, {name = BAMBOO_ENDCAP_NAME})
				end
			end
			break
		end

		-- handle regular node placement.
		-- find the air node above the top shoot. place a node. And then, if short enough,
		-- check for second node placement.
		if node_name == "air" then
			mcl_bamboo.mcl_log("Grow bamboo; dist: " .. dist)
			mcl_bamboo.mcl_log("Grow bamboo; Placing bamboo.")
			minetest.set_node(chk_pos, {name = node_below})
			-- handle growing a second node. (1 in 32 chance.)
			if grow_amount == 2 and dist <= height - 2 then
				chk_pos = vector.offset(chk_pos, 0, 1, 0)
				if minetest.get_node(chk_pos).name == "air" then
					mcl_bamboo.mcl_log("Grow bamboo; OOOH! It's twofer day!")
					minetest.set_node(chk_pos, {name = node_below})
				end
			end
			break
		end
	end
end

-- Add Groups function, courtesy of Warr1024.
function mcl_bamboo.add_groups(name, ...)
	local def = minetest.registered_items[name] or error(name .. " not found")
	local groups = {}
	for k, v in pairs(def.groups) do
		groups[k] = v
	end
	local function add_all(x, ...)
		if not x then
			return
		end
		groups[x] = 1
		return add_all(...)
	end
	addall(...)
	return minetest.override_item(name, {groups = groups})
end

function mcl_bamboo.mcl_log(m, l)
	if not m then
		minetest.log("error", "expected string, received: " .. m)
		return
	end
	if DEBUG then
		if not l then
			minetest.log("[mcl_bamboo]: " .. m)
		else
			minetest.log(l, "[mcl_bamboo]: " .. m)
		end
	end
end
