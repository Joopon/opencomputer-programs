local component = require("component")
local modem = component.modem
local event = require("event")
local serialization = require("serialization")

local communication = {}

local device_list = {}
local PATH_CONFIG = "/etc/communication.cfg"

-- message types:
communication.ACK_MSG = "communication_ack_message"

local function get_address_port(device)
    local dev = device_list[device]
    if dev == nil then
        print("warning communication: couldn't find device '"..device.."'in device_list")
        return nil
    end
    local dev_address = dev["address"]
    local dev_port = dev["port"]
    return dev_address, dev_port
end

local function send(rcv_address, rcv_port, message_type, message)
    local msg = {
        message_type = message_type,
        message = message
    }
    local msg_string = serialization.serialize(msg)
    if not modem.send(rcv_address, rcv_port, msg_string) then
        print("error communication: failed to send message")
        return false
    end
    return true
end

function communication.setup()
    local config = io.open(PATH_CONFIG, "r")
    if not config then
        print("error communication.setup(): no config at "..PATH_CONFIG)R
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

    return send(rcv_address, rcv_port, message_type, message)
end

-- receiver: string, device name
-- message_type: string
-- message: any except functions
-- timeout: optional, adds timeout [s] waiting for ack
-- returns true on success, false on failure
function communication.send_blocking_ack(receiver, message_type, message, timeout)
    local rcv_address, rcv_port = get_address_port(receiver)
    if rcv_address == nil then
        return false
    end
    if not send(rcv_address, rcv_port, message_type, message) then
        return false
    end

    local ack_msg_string, _
    if timeout then
        local ret
        ret, _, _, _, _, ack_msg_string = event.pull(timeout, "modem_message", modem.address, rcv_address, rcv_port)
        if ret == nil then -- timed out waiting for ack message
            return false
        end
    else
        _, _, _, _, _, ack_msg_string = event.pull("modem_message", modem.address, rcv_address, rcv_port)
    end
    local ack_msg = serialization.unserialize(ack_msg_string)
    if not (ack_msg["message_type"] == communication.ACK_MSG) then
        print("error communication.send(): expected ack message, received: "..ack_msg["message_type"])
        return false
    end
    return true
end

return communication