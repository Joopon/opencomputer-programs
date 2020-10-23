local robot = require("robot")

local robot_movement = {}

local function move(distance, move_function)
    while distance > 0 do
        while not move_function() do
            os.sleep(1)
        end
        distance = distance -1
    end
end

function robot_movement.forward(distance)
    move(distance, robot.forward)
end

function robot_movement.back(distance)
    move(distance, robot.back)
end

function robot_movement.up(distance)
    move(distance, robot.up)
end

function robot_movement.down(distance)
    move(distance, robot.down)
end


return robot_movement
