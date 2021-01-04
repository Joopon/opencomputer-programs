local item_record = require("item_record")
local communication = require("communication")
local storage_messages = require("storage_messages")
local event = require("event")

local storage_management = {}

-- robot states
local ROBOT_AVAILABLE = "robot_state_available"
local ROBOT_BUSY = "robot_state_busy"

local item_record_list = {}
local storage_robot_list = {
    Dummy = { state = ROBOT_BUSY },
    Mute = { state = ROBOT_AVAILABLE }
}

local function get_item_record(item)
    local id = item_record.get_id(item)
    return item_record_list[id]
end

function storage_management.request_item(item_record, num_items)
    for name, robot in pairs(storage_robot_list) do
        if robot.state == ROBOT_AVAILABLE then
            local message = storage_messages.new_item_collect_request(item_record, num_items)
            if communication.send_with_ack(name, storage_messages.ITEM_COLLECT_REQUEST, message) then
                robot.state = ROBOT_BUSY
                return true
            end
        end
    end
    return false
end

function storage_management.test()
    local dummy_item = {
        damage=1,
        name="minecraft:banner",
        label="Red Banner"
    }
    local dummy_record = item_record.new_item_record(dummy_item, 3, -2, 64)
    if storage_management.request_item(dummy_record, 32) then
        print("successfully send collect request")
    else
        print("failed to send collect request")
    end
end

function storage_management.main()
    if not communication.setup() then
        print("error storage_management.main(): failed to setup communication")
        return
    end

    while true do
        local event_name = event.pullMultiple(communication.MSG_EVENT, "key_up")
        if event_name == communication.MSG_EVENT then
            local device, _, message_type, message = communication.receive()
            if message_type == storage_messages.ITEM_COLLECT_RESPONSE then
                if (not storage_messages.check_item_collect_response(message)) or storage_robot_list[device] == nil then
                    print("warning storage_management.main(): received invalid ITEM_COLLECT_RESPONSE")
                end
                print("robot "..device.." collected "..message.number_collected.." "..message.item_record.item.label)
                storage_robot_list[device].state = ROBOT_AVAILABLE
            else
                print("warning storage_management.main(): received unexpected message of type "..message_type)
            end
        elseif event_name == "key_up" then
            storage_management.test()
        end
    end
end
return storage_management