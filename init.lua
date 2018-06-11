--[[
   Copyright 2018 Noodlemire

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--]]

--the maximum radius of blocks to cause to fall at once. 
local clump_radius = 1

--[[
Description: 
    Searches for clump_fall_nodes within a given volume of radius clump_radius and all of the center points between the 3D points given by the parameters. 
Parameters: 
    Two 3D vectors; the first is the smaller, and the second is the larger. These are the two corners of the volume to be searched through. Note that clump_radius is added on to these min and max points, so keep that in mind in relation to the size of the volume that is actually effected by this function.
Returns:
    A table containing the positions of all clump_fall_nodes found
--]]
function check_group_for_fall(min_pos, max_pos)
    --Local created to temporarily store clump_fall_nodes that should fall down
    local nodes_that_can_fall = {}

    --iterates through the entire cubic volume contained between the minimum and maximum positions
    for t = min_pos.z - clump_radius, max_pos.z + clump_radius do
        for n = min_pos.y - clump_radius, max_pos.y + clump_radius do
            for i = min_pos.x - clump_radius, max_pos.x + clump_radius do
                --Creates a 3D vector to store the position that is currently being inspected
                local check_this = {x=i, y=n, z=t}

                --If the position currently being checked belongs to the clump_fall_node group, then
                if minetest.get_item_group(minetest.get_node(check_this).name, "clump_fall_node") ~= 0 then
                    --First create a variable that assumes that there are no clump_fall_nodes underneath the current position
                    local has_bottom_support = false

                    --This then checks each node under the current position within a 3x3 area for blocks within the clump_fall_node group
                    for b = t - 1, t + 1 do
                        for a = i - 1, i + 1 do
                            local bottom_pos = {x=a, y=n-1, z=b}
                            --As long as at least a single node belongs to the clump_fall_node group, has_bottom_support will be set to true.
                            if minetest.get_item_group(minetest.get_node(bottom_pos).name, "clump_fall_node") ~= 0 then
                                has_bottom_support = true
                            end
                        end
                    end
                    
                    --If at least one clump_fall_node was found underneath, nothing else will happen. If none are found, the current position will be placed within the table nodes_that_can_fall
                    if has_bottom_support == false then
                        table.insert(nodes_that_can_fall, {x=i, y=n, z=t})
                    end
                end
            end
        end
    end
    
    --Once all this looping is complete, the list of nodes that can fall is complete and can be returned.
    return nodes_that_can_fall
end

--[[
Description: 
    Initiate a clump fall that starts within the given 3D points, and if needed, will cascade farther until there is nothing left in the area that can fall
Parameters: 
    Any number of 3D vectors of which to draw a cubic volume around. This volume will be the starting point for this clump_fall
Returns: 
    Nothing
--]]
function clump_fall(...)
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
    local max_pos = {x, y, z}
    --Stores the smallest x, y, and z values out of the 3D vertices given by the arguments
    local min_pos = {x, y, z}
    --To be used later in this function, this stores the largest x, y, and z values of nodes that were actually found to need falling.
    local new_max_pos = {x, y, z}
    --To be used later in this function, this stores the smallest x, y, and z values of nodes that were actually found to need falling.
    local new_min_pos = {x, y, z}

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
    node_pos_to_fall = check_group_for_fall(min_pos, max_pos)

    --Next, iterate through each of the newfound clump_fall_node positions, if any...
    for v,pos_fall in pairs(node_pos_to_fall) do
        --Used to store the node at the current position
        local node_fall = minetest.get_node(pos_fall)
        --Gets the metadata of the node at the current position
        local meta = minetest.get_meta(pos_fall)
        --Will be used to store any metadata in a table
        local metatable = {}

        --If there is any metadata, then
        if meta ~= nil then
            --Convert that metadata to a table and store it in metatable
			metatable = meta:to_table()
		end

        --Make one more check in case the node at the current postion already fell or has otherwise been replaced
        if minetest.get_item_group(node_fall.name, "clump_fall_node") ~= 0 then 
            --Finally, a falling_node is placed at the current position just as the node that used to be here is removed
            minetest.remove_node(pos_fall)
            spawn_falling_node(pos_fall, node_fall, metatable)
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

    --If nodes were found that need to fall in the next round of cascading, loop by calling this very method after 1 second of in-game time passes
    if found_no_fallable_nodes == false then
        --This will be used with the new min and max position that have been found. 
        --These are used instead of the old ones so that the range of cascading can't expand indefinitely and cause crashes
        minetest.after(1, clump_fall, {new_min_pos, new_max_pos})
    end
end

--[[
Description:
    To be once immediately after initialization, this function iterates through every registered node, including those that were registered by other mods, and turns once that don't already fall by themselves into clump_fall_nodes
Parameters:
    None
Returns:
    Nothing
--]]
function make_nodes_fallable()
    --Inspect each registered node, one at a time
    for nodename, nodereal in pairs(minetest.registered_nodes) do
        --create a temporary list of the current node's groups
        local temp_node_group_list = nodereal.groups

        --Ensure that the nodes being modified aren't the placeholder block types that tecnically don't exist
        if nodename ~= "air" and nodename ~= "ignore" and 
                minetest.get_item_group(nodename, "falling_node") == 0 and --Don't need to affect nodes that already fall by themselves
                minetest.get_item_group(nodename, "attached_node") == 0 and --Same thing for nodes in this group, which fall when no longer attached to another node
                minetest.get_item_group(nodename, "liquid") == 0 and --Same thing for nodes in this group, which do technically fall and spread around
                minetest.get_item_group(nodename, "unbreakable") == 0 and --Lastly, if a block is invulnerable to begin with, it shouldn't fall down like a typical node
                minetest.get_item_group(nodename, "bed") == 0 then --Beds are able to create untouchable, solid nodes if they fall in a certain way (TODO: fix this)
            --Initialize a new group variable in the temp list known as "clump_fall_node" as 1
            temp_node_group_list.clump_fall_node = 1
            --Override the node's previous group list with the one that includes the new clump_fall_node group
            minetest.override_item(nodename, {groups = temp_node_group_list})
        else
            --For the rest, ensure that clump_fall_node is set to 0 and properly initialized
            temp_node_group_list.clump_fall_node = 0
            --Override the node's previous group list with the one that includes the new clump_fall_node group
            minetest.override_item(nodename, {groups = temp_node_group_list})
        end
    end
end

--[[
Description:
    
Parameters:
    pos: The postion to spawn the falling_node
    node: The node itself to imitate (NOT its name or location)
    meta: The metadata table to store information about the node to imitate, such as rotation and inventory
Returns:
    Nothing
--]]
function spawn_falling_node(pos, node, meta)
    --Create a __builtin:falling_node entity and add it to minetest
    local entity_fall = minetest.add_entity(pos, "__builtin:falling_node")
    --If successful, then
    if entity_fall then
        --Set its nodetype and metadata to the given arguments node and meta, respectively
        entity_fall:get_luaentity():set_node(node, meta)
    end
end

--After all nodes have been registered and 0 seconds have passed, run the make_nodes_fallable function
minetest.after(0, make_nodes_fallable)

--Set the clump_fall function to run at any postion where a node is dug, placed, or punched
minetest.register_on_dignode(clump_fall)
minetest.register_on_placenode(clump_fall)
minetest.register_on_punchnode(clump_fall)
