local robot = require("robot")
local move = require("robot_movement")
local sides = require("sides")
local component = require("component")
local inventory = component.inventory_controller

local storage_robot = {}

-- how many chests are to the left/right of the middle
local num_chest_side = 2 --first left chest is -1, first right chest is 1, 0 is invalid
local num_chest_rows = 3
local curr_max_chest_height = 3 -- number of chests from ground

local item_slots_reserved = 12 -- slots from 1 to item_slots_reserved are reserved for item transportation

local function is_valid_chest_location(chest_column, chest_row)
    return math.abs(chest_column) <= num_chest_side and not(chest_column == 0)
            and 1 <= chest_row and chest_row <= num_chest_rows
end

-- returns true if there is a chest in front
local function detect_chest()
    local size = inventory.getInventorySize(sides.front)
    return not (size == nil)
end


-- starting in the middle of the first chest row
function storage_robot.goto_chest(chest_column, chest_row)
    if not is_valid_chest_location(chest_column, chest_row) then
        print("error: called goto_chest with invalid chest location")
        return false
    end
    move.forward(2*(chest_row-1))
    if chest_column > 0 then
        -- chest on right side
        robot.turnRight()
        move.forward(chest_column*2)
        robot.turnLeft()
    else
        -- chest on left side
        robot.turnLeft()
        move.forward(math.abs(chest_column)*2)
        robot.turnRight()
    end
    return true
end

function storage_robot.returnto_origin(chest_column, chest_row)
    if not is_valid_chest_location(chest_column, chest_row) then
        print("error: called returnto_origin with invalid chest_location")
        return false
    end
    if chest_column > 0 then
        -- robot on right side
        robot.turnLeft()
        move.forward(chest_column*2)
        robot.turnLeft()
    else
        -- robot on left side
        robot.turnRight()
        move.forward(math.abs(chest_column)*2)
        robot.turnRight()
    end

    move.forward(2*(chest_row-1))
    return true
end

-- fills from slot 1 to item_slots_reserved with number items from chest in front of robot
-- returns the number of items taken from the chest
function storage_robot.take_items(number)
    local slot = 1
    robot.select(slot)
    local taken = 0
    while taken < number do
        local got = robot.suck(math.min(number-taken, robot.space()))
        if got == false then
            if not (robot.space() == 0) then
                break
            end
            got = 0
        end
        taken = taken + got
        if robot.space()==0 then
            slot = slot + 1
            robot.select(slot)
            if slot > item_slots_reserved then
                break
            end
        end
    end

    robot.select(1)
    return taken
end

-- start in front of first chest (height 1), end at height curr_max_chest_height + 1
function storage_robot.take_items_chesttower(number)
    local taken = 0
    for height=1, curr_max_chest_height, 1 do
        if detect_chest() then
            local num = storage_robot.take_items(number-taken)
            taken = taken + num
            print("number of items taken:", num)
            if(taken >= number) then
                move.up(curr_max_chest_height-height+1)
                break
            end
        end
        move.up(1)
    end
    if taken > number then
        print("internal error: take_items_chesttower took too many items")
    end
    return taken
end

-- puts items from slot 1 to item_slots_reserved into chest in front of robot
-- returns boolean, number:
--   boolean: true if all items were put, false if there are still items left
--   number: the number of items put into the chest
function storage_robot.put_items()
    local slot = 0
    local put_items = 0
    local ret = true
    while slot < item_slots_reserved do
        slot = slot + 1
        robot.select(slot)
        local in_slot_before = robot.count()
        if not (in_slot_before==0) then
            if not robot.drop() then
                ret = false
                break -- there are still items but this chest is full
            end
            local in_slot_after = robot.count()
            put_items = put_items + (in_slot_before - in_slot_after)
            if not (in_slot_after==0) then
                slot = slot - 1 -- retry same slot again
            end
        end
    end

    robot.select(1)
    return ret, put_items
end

-- start in front of first chest (height 1), end at height curr_max_chest_height + 1
-- returns boolean, number:
--   boolean: true if all items were put, false if there are still items left
--   number: the number of items put into the chest
function storage_robot.put_items_chesttower()
    local put_items = 0
    local ret = false
    for height=1, curr_max_chest_height, 1 do
        if detect_chest() then
            local num
            ret, num = storage_robot.put_items()
            put_items = put_items + num
            print("number of items put:", num)
            if(ret) then
                move.up(curr_max_chest_height-height+1)
                break
            end
        end
        move.up(1)
    end
    return ret, put_items
end

function storage_robot.collect_items(chest_pos_x, chest_pos_y, num_items)
    storage_robot.goto_chest(chest_pos_x, chest_pos_y)
    local items_taken = storage_robot.take_items_chesttower(num_items)
    storage_robot.returnto_origin(chest_pos_x, chest_pos_y)
    robot.turnAround()
    move.down(curr_max_chest_height)
    print("I brought you", items_taken, "items.")
end

function storage_robot.store_items(chest_pos_x, chest_pos_y)
    storage_robot.goto_chest(chest_pos_x, chest_pos_y)
    local ret, put_items = storage_robot.put_items_chesttower()
    storage_robot.returnto_origin(chest_pos_x, chest_pos_y)
    robot.turnAround()
    move.down(curr_max_chest_height)
    print("I stored", put_items, "items.")
    print("No items are left in my inventory:", ret, "\n")
end


return storage_robot