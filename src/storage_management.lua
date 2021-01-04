local item_rec = require("item_record")
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
    local id = item_rec.get_id(item)
    return item_record_list[id]
end

local function add_item_record(item_record)
    local id = item_rec.get_id(item_record.item)
    if item_record_list[id] == nil then
        item_record_list[id] = item_record
        return true
    end
    return false
end

function storage_management.request_item(item_record, num_items)
    if num_items > item_record.amount or num_items < 0 then
        return false
    end
    for name, robot in pairs(storage_robot_list) do
        if robot.state == ROBOT_AVAILABLE then
            local message = storage_messages.new_item_collect_request(item_record, num_items)
            if communication.send_with_ack(name, storage_messages.ITEM_COLLECT_REQUEST, message) then
                robot.state = ROBOT_BUSY
                item_rec.set_amount(item_record, item_record.amount - num_items)
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
    local dummy_record = get_item_record(dummy_item)
    if dummy_record == nil then
        dummy_record = item_rec.new_item_record(dummy_item, 2, 1, 64)
        add_item_record(dummy_record)
    end

    if storage_management.request_item(dummy_record, 32) then
        print("successfully send collect request")
    else
        print("failed to send collect request")
    end
end

-- checks for an available messages and handles it if possible
-- returns false if no message was available, otherwise true
local function handle_message()
    local device, _, message_type, message = communication.receive()
    if device == nil then
        return false
    end
    if message_type == storage_messages.ITEM_COLLECT_RESPONSE then
        if (not storage_messages.check_item_collect_response(message)) or storage_robot_list[device] == nil then
            print("warning storage_management.main(): received invalid ITEM_COLLECT_RESPONSE")
            return true
        end
        print("robot "..device.." collected "..message.number_collected.." "..message.item_record.item.label.." ("..message.number_requested.." requested)")
        storage_robot_list[device].state = ROBOT_AVAILABLE
        if not(message.number_requested == message.number_collected) then
            local stored_item_record = get_item_record(message.item_record.item)
            if stored_item_record == nil then
                print("warning storage_management_handle_message(): couldn't find item_record from item_collect_response")
                return true
            end
            local num_missing = message.number_requested - message.number_collected
            item_rec.set_amount(stored_item_record, stored_item_record.amount + num_missing)
        end

        local ir = get_item_record(message.item_record.item)
        print("there are "..ir.amount.." left in storage")
    else
        print("warning storage_management.main(): received unexpected message of type "..message_type)
    end
    return true
end

function storage_management.main()
    if not communication.setup() then
        print("error storage_management.main(): failed to setup communication")
        return
    end

    while true do
        local event_name = event.pullMultiple(communication.MSG_EVENT, "key_up")
        if event_name == communication.MSG_EVENT then
            while handle_message() do -- handle all available messages
            end
        elseif event_name == "key_up" then
            storage_management.test()
        end
    end
end
return storage_management