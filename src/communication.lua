local component = require("component")
local modem = component.modem
local event = require("event")
local serialization = require("serialization")
local queue = require("queue")

local communication = {}

local device_list = {}
local message_queue = queue.new(10)
local ack_queue = queue.new(3)
local PATH_CONFIG = "/etc/communication.cfg"
local ACK_TIMEOUT = 10

-- message types:
communication.ACK_MSG = "communication_ack_message"

-- event names:
communication.MSG_EVENT = "received_message_event"
communication.ACK_EVENT = "received_ack_event"

local function get_address_port(device)
    local dev = device_list[device]
    if dev == nil then
        print("warning communication: couldn't find device '"..device.."' in device_list")
        return nil
    end
    local dev_address = dev["address"]
    local dev_port = dev["port"]
    return dev_address, dev_port
end

-- port: number
-- returns device name on success, nil if device not found
local function get_device(address, port)
    for device, addr_port in pairs(device_list) do
        if addr_port["address"] == address and addr_port["port"] == port then
            return device
        end
    end
    print("warning communication: couldn't find device for address '"..address.."' and port "..port.." in device_list")
    return nil
end

local function send(rcv_address, rcv_port, request_ack, message_type, message)
    local msg = {
        message_type = message_type,
        message = message,
        request_ack = request_ack
    }
    local msg_string = serialization.serialize(msg)
    if not modem.send(rcv_address, rcv_port, msg_string) then
        print("error communication: failed to send message")
        return false
    end
    return true
end

local function message_listener(event_name, receiver_address, sender_address, port, distance, message_string)
    local msg = serialization.unserialize(message_string)

    local new_msg = {
        receiver_address = receiver_address,
        sender_address = sender_address,
        port = port,
        distance = distance,
        message_type = msg.message_type,
        message = msg.message
    }
    if msg.message_type == communication.ACK_MSG then
        if not queue.push(ack_queue, new_msg) then
            print("warning communication: lost an ack, ack_queue too small")
            return
        end
        event.push(communication.ACK_EVENT)
        return
    end

    if queue.is_full(message_queue) then
        print("warning communication: lost a message, message_queue too small")
        return
    end

    if msg.request_ack then
        if not send(sender_address, port, false, communication.ACK_MSG, "ack") then
            print("warning communication: failed to send ack. Received Message wasn't added to message queue")
            return
        end
    end

    assert(queue.push(message_queue, new_msg))
    event.push(communication.MSG_EVENT)
end


function communication.setup()
    local config = io.open(PATH_CONFIG, "r")
    if not config then
        print("error communication.setup(): no config at "..PATH_CONFIG)
        return false
    end

    for line in config:lines() do
        local match = string.gmatch(line, "[^=,]+")
        local dev_name = match()
        local dev_addr = match()
        local dev_port = match()
        if dev_name == nil or dev_addr == nil or dev_port == nil or tonumber(dev_port) == nil then
            print("warning communication.setup(): found bad formatted line: "..line)
        else
            print("name: ".. dev_name ..", address: "..dev_addr..", port: "..dev_port)
            dev_port = tonumber(dev_port)
            device_list[dev_name] = {
                address = dev_addr,
                port    = dev_port
            }
            modem.open(dev_port)
        end
    end
    config:close()

    if not event.listen("modem_message", message_listener) then
        print("error communication.setup(): couldn't register message_listener")
        return false
    end
    return true
end

function communication.list_devices()
    local list = {}
    for dev_name, _ in pairs(device_list) do
        table.insert(list, dev_name)
    end
    return list
end

-- receiver: string, device name
-- message_type: string
-- message: any except functions
-- returns true on success, false on failure
function communication.send(receiver, message_type, message)
    local rcv_address, rcv_port = get_address_port(receiver)
    if rcv_address == nil then
        return false
    end

    return send(rcv_address, rcv_port, false, message_type, message)
end

-- receiver: string, device name
-- message_type: string
-- message: any except functions
-- returns true on success, false on failure
function communication.send_with_ack(receiver, message_type, message)
    local rcv_address, rcv_port = get_address_port(receiver)
    if rcv_address == nil then
        return false
    end
    if not send(rcv_address, rcv_port, true, message_type, message) then
        return false
    end

    local event_type, _, _, _, _, ack_msg_string = event.pull(ACK_TIMEOUT, communication.ACK_EVENT)
    if event_type == nil then -- timed out waiting for ack message
        return false
    end
    local ack_msg = queue.pop(ack_queue)
    if ack_msg == nil then
        print("error communication.send_with_ack: expected ack in ack_queue")
        return false
    end
    if not (ack_msg.message_type == communication.ACK_MSG) then
        print("error communication.send_with_ack(): expected ack message, received: "..ack_msg["message_type"])
        return false
    end
    if not (ack_msg.sender_address == rcv_address and ack_msg.port == rcv_port) then
        print("warning communication.send_with_ack: received ack from unexpected device: "..ack_msg.sender_address)
        return false
    end
    return true
end

-- timeout: optional, adds timeout [s] waiting for message
-- returns on success: device: string, distance: number, message_type: string, message: any except functions
--         on fail: nil
function communication.receive_blocking(timeout)
    if queue.is_empty(message_queue) then
        if timeout then
            local event_type = event.pull(timeout, communication.MSG_EVENT)
            if event_type == nil then
                return nil
            end
        else
            local event_type = event.pull(communication.MSG_EVENT)
        end
    end

    return communication.receive()
end

-- returns immediately if no message is available
function communication.receive()
    local msg = queue.pop(message_queue)
    if(msg == nil) then
        -- queue doesn't contain a message
        return nil
    end

    local device = get_device(msg.sender_address, msg.port)
    if msg.message_type == nil or msg.message == nil or device == nil then
        return nil
    end

    return device, msg.distance, msg.message_type, msg.message
end

return communication