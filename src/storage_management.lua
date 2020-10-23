local robot = require("robot")
local move = require("robot_movement")

local storage_management = {}

-- how many chests are to the left/right of the middle
local num_chest_side = 2 --first left chest is -1, first right chest is 1, 0 is invalid
local num_chest_rows = 3
local curr_max_chest_height = 1

local function is_valid_chest_location(chest_column, chest_row)
    return math.abs(chest_column) <= num_chest_side and not(chest_column == 0)
            and 1 <= chest_row and chest_row <= num_chest_rows
end


-- starting in the middle of the first chest row
function storage_management.goto_chest(chest_column, chest_row)
    if not is_valid_chest_location(chest_column, chest_row) then
        print("error: called goto_chest with invalid chest location")
        return false
    end
    for row=1, chest_row-1, 1 do
        move.forward(2)
    end

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

function storage_management.returnto_origin(chest_column, chest_row, height)
    if not (is_valid_chest_location(chest_column, chest_row) and 0<height and height<=curr_max_chest_height) then
        print("error: called returnto_origin with invalid chest_location or height")
        return false
    end
    move.up(1)
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

    for row=1, chest_row-1, 1 do
        move.forward(2)
    end
    move.down(height)
end

function storage_management.collect_item(chest_pos_x, chest_pos_y, num_items)
    storage_management.goto_chest(chest_pos_x, chest_pos_y)
    os.sleep(1)
    storage_management.returnto_origin(chest_pos_x, chest_pos_y, 1)
    robot.turnAround()
end



return storage_management
