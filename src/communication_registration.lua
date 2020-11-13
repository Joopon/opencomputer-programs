local component = require("component")
local modem = component.modem
local event = require("event")

local communication_registration = {}

local PATH_COMMUNICATION_CONFIG = "/etc/communication.cfg" -- make sure this matches with communication.lua


local function store_device(name, address, port)
    local config = io.open(PATH_COMMUNICATION_CONFIG, "a")
    config:write(name.."="..address..","..port.."\n")
    config:close()
end

function communication_registration.send_regist(port)
    if modem.isOpen(port) then
        print("error communication_registration.send_regist(): port "..port.." is already in use")
        return false
    end
    modem.open(port)
    local ret = modem.broadcast(port)
    modem.close(port)
    return ret
end

function communication_registration.receive_regist(port)
    if modem.isOpen(port) then
        print("error communication_registration.receive_regist: port "..port.." is already in use")
        return false
    end
    modem.open(port)
    local event_type, _, dev_addr, event_port = event.pullMultiple("modem_message", "interrupted")
    if event_type == "interrupted" then
        modem.close(port)
        return false
    end
    if not (event_port == port) then
        print("error communication_registration.receive_regist: received message on unexpected port "..event_port)
        modem.close(port)
        return false
    end
    print("Received message from address "..dev_addr.."\nDo you want to store this address? (Y/n)")
    local user_input = io.read()
    if user_input == "n" or user_input == "N" then
        modem.close(port)
        return false
    end
    print("Enter a name for the new device")
    local dev_name = io.read()
    print("Enter a port to communicate with the new device. (You need to enter the same port on the other device)")
    local dev_port = tonumber(io.read())
    if dev_port == nil then
        print("error communication_registration.receive_regist: port needs to be a number")
        modem.close(port)
        return false
    end
    print("\nAdding the follwing device:\nName: "..dev_name.."\nAddress: "..dev_addr.."\nPort: "..dev_port.."\n")
    print("Do you want to continue? (Y/n)")
    user_input = io.read()
    if user_input == "n" or user_input == "N" then
        modem.close(port)
        return false
    end

    store_device(dev_name, dev_addr, dev_port)
    modem.close(port)
    return true
end

return communication_registration
