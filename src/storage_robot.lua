local robot = require("robot")
local move = require("robot_movement")
local sides = require("sides")
local component = require("component")
local inventory = component.inventory_controller
local communication = require("communication")
local storage_messages = require("storage_messages")
local config_parser = require("config_parser")

local storage_robot = {}

-- how many chests are to the left/right of the middle
local num_chest_side = 2 --first left chest is -1, first right chest is 1, 0 is invalid
local num_chest_rows = 3
local curr_max_chest_height = 3 -- number of chests from ground

local item_slots_reserved = 12 -- slots from 1 to item_slots_reserved are reserved for item transportation
local CHECK_CHEST_INTERVAL=2
local PATH_CONFIG = "/etc/storage_robot.cfg"
local server_name
local origin_to_garage = {} -- has entries x (1 means 1 to the right, -2 means 2 to the left), y (number blocks from garage to origin)

local function is_valid_chest_location(chest_column, chest_row)
    return math.abs(chest_column) <= num_chest_side and not(chest_column == 0)
            and 1 <= chest_row and chest_row <= num_chest_rows
end

-- returns true if there is a chest in front
local function detect_chest()
    local size = inventory.getInventorySize(sides.front)
    return not (size == nil)
end

function storage_robot.setup()
    local config = config_parser.parse(PATH_CONFIG)
    if config==nil or config.server_name==nil or config.origin_to_garage==nil then
        return false
    end
    server_name = config.server_name[1]
    origin_to_garage.x = tonumber(config.origin_to_garage[1])
    origin_to_garage.y = tonumber(config.origin_to_garage[2])

    return origin_to_garage.x~=nil and origin_to_garage.y~=nil
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
        move.turnRight()
        move.forward(chest_column*2)
        move.turnLeft()
    else
        -- chest on left side
        move.turnLeft()
        move.forward(math.abs(chest_column)*2)
        move.turnRight()
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
        move.turnLeft()
        move.forward(chest_column*2)
        move.turnLeft()
    else
        -- robot on left side
        move.turnRight()
        move.forward(math.abs(chest_column)*2)
        move.turnRight()
    end

    move.forward(2*(chest_row-1))
    return true
end

-- stops one block before origin ((0,-1) from origin)
function storage_robot.from_garage_to_origin()
    move.forward(math.abs(origin_to_garage.x))
    if origin_to_garage.x > 0 then
        -- garage on right side
        move.turnRight()
    else
        -- garage on left side
        move.turnLeft()
    end
    move.forward(origin_to_garage.y-2)
end

-- starts one block before origin ((0,-1) from origin and one block above ground
function storage_robot.from_origin_to_garage()
    move.forward(origin_to_garage.y-2)
    if origin_to_garage.x > 0 then
        -- garage on right side
        move.turnLeft()
    else
        -- garage on left side
        move.turnRight()
    end
    move.forward(math.abs(origin_to_garage.x))
    move.turnAround()
    move.down(1)
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
            print("number of items taken: "..num)
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
            print("number of items put: "..num)
            if(ret) then
                move.up(curr_max_chest_height-height+1)
                break
            end
        end
        move.up(1)
    end
    return ret, put_items
end

-- puts all items from slot 1 to item_slots_reserved into chest in front of robot.
-- robots waits until it can put all items
function storage_robot.flush_items()
    local slot = 1
    while slot <= item_slots_reserved do
        robot.select(slot)
        robot.drop()
        while robot.count() ~= 0 do
            os.sleep(CHECK_CHEST_INTERVAL)
            robot.drop()
        end
        slot = slot + 1
    end
    robot.select(1)
end

function storage_robot.collect_items(chest_pos_x, chest_pos_y, num_items)
    storage_robot.from_garage_to_origin()
    move.forward(1)
    storage_robot.goto_chest(chest_pos_x, chest_pos_y)
    local items_taken = storage_robot.take_items_chesttower(num_items)
    storage_robot.returnto_origin(chest_pos_x, chest_pos_y)
    move.forward(1)
    move.turnLeft()
    move.forward(1)
    move.turnRight()
    move.down(curr_max_chest_height)
    storage_robot.flush_items()
    move.turnRight()
    move.forward(1)
    move.turnLeft()
    move.up(1)
    storage_robot.from_origin_to_garage()
    print("I brought you "..items_taken.." items.")
    return items_taken
end

function storage_robot.store_items(chest_pos_x, chest_pos_y)
    storage_robot.goto_chest(chest_pos_x, chest_pos_y)
    local ret, put_items = storage_robot.put_items_chesttower()
    storage_robot.returnto_origin(chest_pos_x, chest_pos_y)
    move.turnAround()
    move.down(curr_max_chest_height)
    print("I stored "..put_items.." items.")
    print("No items are left in my inventory: "..tostring(ret).."\n")
end

function storage_robot.main()
    if not storage_robot.setup() then
        print("error storage_robot.main(): failed to setup storage_robot")
        return
    end
    if not communication.setup() then
        print("error storage_robot.main(): failed to setup communication")
        return
    end

    while true do
        local _, _, message_type, message = communication.receive_blocking()
        if message_type == storage_messages.ITEM_COLLECT_REQUEST then
            if not storage_messages.check_item_collect_request(message) then
                print("warning storage_robot.main(): received invalid ITEM_COLLECT_REQUEST")
            else
                local chest_location = message.item_record.chest_location
                local items_taken = storage_robot.collect_items(chest_location.row, chest_location.column, message.number_of_items)
                local message = storage_messages.new_item_collect_response(message.item_record, message.number_of_items, items_taken)
                while not communication.send_with_ack(server_name, storage_messages.ITEM_COLLECT_RESPONSE, message) do
                end
            end
        else
            print("warning storage_robot.main(): received unexpected message of type "..message_type)
        end
    end
end

return storage_robot
