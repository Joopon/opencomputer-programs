local item_record = require("item_record")
local communication = require("communication")
local storage_messages = require("storage_messages")

local storage_management = {}

-- robot states
local ROBOT_AVAILABLE = "robot_state_available"
local ROBOT_BUSY = "robot_state_busy"

local item_record_list = {}
local storage_robot_list = {
    { name = "Dummy", state = ROBOT_BUSY},
    { name = "Mute", state = ROBOT_AVAILABLE }
}

local function get_item_record(item)
    local id = item_record.get_id(item)
    return item_record_list[id]
end

function storage_management.request_item(item_record, num_items)
    for _, robot in ipairs(storage_robot_list) do
        if robot.state == ROBOT_AVAILABLE then
            local message = storage_messages.new_item_collect_request(item_record, num_items)
            if communication.send_with_ack(robot.name, storage_messages.ITEM_COLLECT_REQUEST, message) then
                --robot.state = ROBOT_BUSY
                return true
            end
        end
    end
    return false
end

function storage_management.test()
    local dummy_item = {
        damage=1,
        name="minecraft:banner"
    }
    local dummy_record = item_record.new_item_record(dummy_item, 3, -2, 64)
    if storage_management.request_item(dummy_record, 32) then
        print("successfully send collect request")
    else
        print("failed to send collect request")
    end
end

return storage_management