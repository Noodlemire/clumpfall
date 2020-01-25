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

clumpfall.functions = {} --global functions variable

--[[
Description: 
	Searches for clump_fall_nodes within a given volume of radius clump_radius and all of the center points between the 3D points given by the parameters. 
Parameters: 
	Two 3D vectors; the first is the smaller, and the second is the larger. These are the two corners of the volume to be searched through. Note that clump_radius is added on to these min and max points, so keep that in mind in relation to the size of the volume that is actually effected by this function.
Returns:
	A table containing the positions of all clump_fall_nodes found
--]]
function clumpfall.functions.check_group_for_fall(min_pos, max_pos)
	--Local created to temporarily store clump_fall_nodes that should fall down
	local nodes_that_can_fall = {}

	--iterates through the entire cubic volume contained between the minimum and maximum positions
	for t = min_pos.z - clumpfall.clump_radius, max_pos.z + clumpfall.clump_radius do
		for n = min_pos.y - clumpfall.clump_radius, max_pos.y + clumpfall.clump_radius do
			for i = min_pos.x - clumpfall.clump_radius, max_pos.x + clumpfall.clump_radius do
				--Creates a 3D vector to store the position that is currently being inspected
				local check_this = {x=i, y=n, z=t}

				--If at least one clump_fall_node was found underneath, nothing else will happen. If none are found, the current position will be placed within the table nodes_that_can_fall. Also won't make a node fall if any walkable node is directly underneath, even if that node is not a clump_fall_node
				if clumpfall.functions.check_individual_for_fall(check_this, true) then
					table.insert(nodes_that_can_fall, check_this)
				end
			end
		end
	end
	
	--Once all this looping is complete, the list of nodes that can fall is complete and can be returned.
	return nodes_that_can_fall
end

--A helper function to help clumpfall.functions.check_individual_for_fall determine how supportable the node being checked is.
--Being in the cracky (stone) or choppy (wood) groups will help, as well as having a high level.
local function get_support_strength(nodename)
	local highest = 1

	if minetest.get_item_group(nodename, "cracky") > 0 then
		highest = 3
	elseif minetest.get_item_group(nodename, "choppy") > 0 then
		highest = 2
	end

	highest = highest + minetest.get_item_group(nodename, "level") + minetest.get_item_group(nodename, "clump_fall_support")

	return math.floor(highest * clumpfall.support_radius + 0.5)
end

--[[
Description:
	Checks a 3x3 area under the given pos for clump fall nodes that can be used as supports, and for a non-clump walkable node
Parameters:
	check_pos: The 3D Vector {x=?, y=?, z=?} as the location in which to check
	extended_search: If true, also check for supported side supports.
Returns:
	true if none of the described supports are found, false is supports are found, nil if this isn't a clump fall node being checked
--]]
function clumpfall.functions.check_individual_for_fall(check_pos, extended_search)
	local check_node = minetest.get_node(check_pos)

	--If the position currently being checked belongs to the clump_fall_node group, then
	if minetest.get_item_group(check_node.name, "clump_fall_node") ~= 0 then
		--First, check for a solid directly underneath. If there is one, this node can't fall.
		local underdef = minetest.registered_nodes[minetest.get_node({x=check_pos.x, y=check_pos.y-1, z=check_pos.z}).name]
		if not underdef or underdef.walkable then
			return false
		end

		--Next, look for clump fall nodes in a 3x3 area underneath. If one is found, this node can't fall.
		for b = check_pos.z - 1, check_pos.z + 1 do
			for a = check_pos.x - 1, check_pos.x + 1 do
				local bottom_pos = {x=a, y=check_pos.y-1, z=b}

				if minetest.get_item_group(minetest.get_node(bottom_pos).name, "clump_fall_node") ~= 0 then
					return false
				end
			end
		end

		--The extended search, where side supports are factored in.
		if extended_search then
			--Stores information about nodes at the same high which may be able to support the node being checked.
			local support_structure = {}
			--A node is easier to support if it's cracky, choppy, and/or has a high level.
			local max_support_radius = get_support_strength(check_node.name)

			--Supports are calculated one "circle" at a time
			for r = 1, max_support_radius - 1 do
				support_structure[r] = {}

				--In each circle, iterate over a square, with [b, a] being a position within that square.
				for b = check_pos.z - r, check_pos.z + r do
					support_structure[r][b] = {}

					for a = check_pos.x - r, check_pos.x + r do
						--This if statement makes sure that the area inside the current circle is not considered more than once.
						if b == check_pos.z - r or b == check_pos.z + r or a == check_pos.x - r or a == check_pos.x + r then
							--Only consider support when the side node is also a clump fall node.
							local side_pos = {x=a, y=check_pos.y, z=b}

							if minetest.get_item_group(minetest.get_node(side_pos).name, "clump_fall_node") ~= 0 then
								--If this is the first circle, no extra consideration is required.
								if r == 1 then
									support_structure[r][b][a] = true
								else
									--Otherwise, look in the inner circle for a support that connects to the node we're looking at right now.
									for bi = b - 1, b + 1 do
										for ai = a - 1, a + 1 do
											if support_structure[r - 1][bi] and support_structure[r - 1][bi][ai] then
												support_structure[r][b][a] = true
											end
										end
									end
								end
							end
						end
					end
				end

				--Once a circle is finished, check if any nodes within it have support underneath.
				--If they do, it's safe to exit the function early; regardless of what is found in outer circles, that support is enough.
				for b = check_pos.z - r, check_pos.z + r do
					for a = check_pos.x - r, check_pos.x + r do
						if support_structure[r][b][a] then
							local side_pos = {x=a, y=check_pos.y, z=b}

							--Recursively check each support for supports, but ONLY in the 3x3 area underneath.
							if not clumpfall.functions.check_individual_for_fall(side_pos, false) then
								return false
							end
						end
					end
				end
			end
		end
		
		--A node can fall only if all support checks have failed.
		return true
	end
end

--[[
Description: 
	Initiate a clump fall that starts within the given 3D points, and if needed, will cascade farther until there is nothing left in the area that can fall
Parameters: 
	Any number of 3D vectors of which to draw a cubic volume around. This volume will be the starting point for this clump fall
Returns: 
	Nothing
--]]
function clumpfall.functions.do_clump_fall(...)
	--Used to store an array version of the arguments
	local arg_array = ({...})[1]
	--Used to store an array version of the arguments once they are standardized
	local node_pos_to_check = {}
	
	--This check is needed to properly standardize the arguments. Without it, results of this function would be needlessly inconsistant.
	if type(arg_array[1]) ~= "table" then
		node_pos_to_check = {arg_array}
	else 
		node_pos_to_check = arg_array
	end

	--List of postions of nodes that check_group_for_fall() found to need falling
	local node_pos_to_fall = {}
	--Variable that assumes that no nodes needed to fall
	local found_no_fallable_nodes = true
	--Stores the largest x, y, and z values out of the 3D vertices given by the arguments
	local max_pos = {}
	--Stores the smallest x, y, and z values out of the 3D vertices given by the arguments
	local min_pos = {}
	--To be used later in this function, this stores the largest x, y, and z values of nodes that were actually found to need falling.
	local new_max_pos = {}
	--To be used later in this function, this stores the smallest x, y, and z values of nodes that were actually found to need falling.
	local new_min_pos = {}

	--Compares max_pos and min_pos to the list of arguments, and individually sets the x, y, and z values of each to, respectively, the largest/smallest x/y/z values
	for v, pos_find_minmax in pairs(node_pos_to_check) do
		if max_pos.x == nil or max_pos.x < pos_find_minmax.x then
			max_pos.x = pos_find_minmax.x
		end
		if max_pos.y == nil or max_pos.y < pos_find_minmax.y then
			max_pos.y = pos_find_minmax.y
		end
		if max_pos.z == nil or max_pos.z < pos_find_minmax.z then
			max_pos.z = pos_find_minmax.z
		end
		if min_pos.x == nil or min_pos.x > pos_find_minmax.x then
			min_pos.x = pos_find_minmax.x
		end
		if min_pos.y == nil or min_pos.y > pos_find_minmax.y then
			min_pos.y = pos_find_minmax.y
		end
		if min_pos.z == nil or min_pos.z > pos_find_minmax.z then
			min_pos.z = pos_find_minmax.z
		end
	end

	--Now that min_pos and max_pos have been calculated, they can be used to find fallable nodes
	node_pos_to_fall = clumpfall.functions.check_group_for_fall(min_pos, max_pos)

	--Next, iterate through each of the newfound clump_fall_node positions, if any...
	for v,pos_fall in pairs(node_pos_to_fall) do
		--Used to store the node at the current position
		local node_fall = minetest.get_node(pos_fall)

		--Make one more check in case the node at the current postion already fell or has otherwise been replaced
		if minetest.get_item_group(node_fall.name, "clump_fall_node") ~= 0 then 
			--Finally, turn the node into a falling node.
			minetest.spawn_falling_node(pos_fall)

			--Update nearby nodes to stop blocks in the falling_node and attached_node groups from floating
			clumpfall.functions.update_nearby_nonclump(pos_fall)
			--Since a node has truly been found that needed to fall, found_no_fallable_nodes can be set to false
			found_no_fallable_nodes = false

			--Compares new_max_pos and new_min_pos to the location of each falling node, and individually sets the x, y, and z values of each to, respectively, the largest/smallest x/y/z values
			if new_max_pos.x == nil or new_max_pos.x < pos_fall.x then
				new_max_pos.x = pos_fall.x
			end
			if new_max_pos.y == nil or new_max_pos.y < pos_fall.y then
				new_max_pos.y = pos_fall.y
			end
			if new_max_pos.z == nil or new_max_pos.z < pos_fall.z then
				new_max_pos.z = pos_fall.z
			end
			if new_min_pos.x == nil or new_min_pos.x > pos_fall.x then
				new_min_pos.x = pos_fall.x
			end
			if new_min_pos.y == nil or new_min_pos.y > pos_fall.y then
				new_min_pos.y = pos_fall.y
			end
			if new_min_pos.z == nil or new_min_pos.z > pos_fall.z then
				new_min_pos.z = pos_fall.z
			end
		end
	end

	--If nodes were found that need to fall in the next round of cascading, loop by calling this very method after a set delay (default: 1 second)
	if found_no_fallable_nodes == false then
		--This will be used with the new min and max position that have been found. 
		--These are used instead of the old ones so that the range of cascading can't expand indefinitely and cause crashes
		minetest.after(clumpfall.clump_interval, clumpfall.functions.do_clump_fall, {new_min_pos, new_max_pos})
	end
end

--[[
Description: 
	Checks the position for any falling nodes or attached nodes to call check_for_falling with, so that falling Clump Fall Nodes do not leave behind floating sand/gravel/plants/etc. The size of the volume checked is based on clump_radius.
Parameters: 
	pos as the 3D vector {x=?, y=?, z=?} of the position to check around
Returns: 
	Nothing
--]]
function clumpfall.functions.update_nearby_nonclump(pos)
	--Iterates through the entire cubic volume with radius clump_radius and pos as its center
	for t = pos.z - clumpfall.clump_radius, pos.z + clumpfall.clump_radius do
		for n = pos.y - clumpfall.clump_radius, pos.y + clumpfall.clump_radius do
			for i = pos.x - clumpfall.clump_radius, pos.x + clumpfall.clump_radius do
				--check_pos is used to store the point that is currently being checked.
				local check_pos = {x=i, y=n, z=t}
				--check_name is used to store the name of the node at check_pos
				local check_name = minetest.get_node(check_pos).name

				--If the node being checked doesn't belong to the falling_node or attached_node groups, then
				if minetest.get_item_group(check_name, "falling_node") ~= 0 or minetest.get_item_group(check_name, "attached_node") ~= 0 then
					--Call the method check_for_falling which will cause those nodes to begin falling if nothing is underneath.
					minetest.check_for_falling(check_pos)
				end
			end
		end
	end
end
