--[[
clumpfall
Copyright (C) 2018-2020 Noodlemire

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
--]]

clumpfall = {} --global variable

--the maximum radius of blocks to cause to fall at once. 
clumpfall.clump_interval = math.max(0.1, tonumber(minetest.settings:get("clumpfall_clump_interval")) or 1)
clumpfall.clump_radius = math.max(1, tonumber(minetest.settings:get("clumpfall_clump_radius")) or 1)
clumpfall.support_radius = math.max(0, tonumber(minetest.settings:get("clumpfall_support_radius")) or 1)

--Short for modpath, this stores this really long but automatic modpath get
local mp = minetest.get_modpath(minetest.get_current_modname()).."/"

--Load other lua components
dofile(mp.."functions.lua")
dofile(mp.."override.lua")

--Add callbacks to nodes in general so that when they are dug, punched, or placed, a clump fall may begin
minetest.register_on_dignode(function(pos, oldnode, digger)
	clumpfall.functions.do_clump_fall(pos)
end)
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
	clumpfall.functions.do_clump_fall(pos)
end)
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	clumpfall.functions.do_clump_fall(pos)
end)

--run the make_nodes_fallable function to make most nodes into Clump Fall Nodes,
minetest.after(0, clumpfall.override.make_nodes_fallable)

--and run the place_node() fix 
minetest.after(0, clumpfall.override.fix_falling_nodes)
