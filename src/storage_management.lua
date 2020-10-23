local robot = require("robot")
local movement = require("robot_movement")

local storage_management = {}

-- how many chests are to the left/right of the middle
local num_chest_side = 2 --first left chest is -1, first right chest is 1, 0 is invalid
local num_chest_rows = 2 --zero indexed

local function goto_right_chest(chest_column)
    robot.turnRight()
    movement.forward(chest_column*2)
    robot.turnLeft()
end
local function goto_left_chest(chest_column)
    robot.turnLeft()
    movement.forward(math.abs(chest_column)*2)
    robot.turnRight()
end


-- starting in the middle of the first chest row
function storage_management.goto_chest(chest_column, chest_row)
    if not (math.abs(chest_column) <= num_chest_side and not(chest_column == 0)
            and chest_row >= 0 and chest_row < num_chest_rows) then
        print("error: called goto with invalid chest location")
        return false
    end
    for row=0, chest_row-1, 1 do
        movement.forward(2)
    end

    if chest_column > 0 then
        goto_right_chest(chest_column)
    else
        goto_left_chest(chest_column)
    end
    return true
end

function storage_management.collect_item(chest_pos_x, chest_pos_y, num_items)

end



return storage_management
