local component = require("component")

local communication = {}

local receiver_list = {}
local PATH_CONFIG = "/etc/communication.cfg"

function communication.setup()
    local config = io.open(PATH_CONFIG, "r")
    if not config then
        print("error communication.setup(): no config at "..PATH_CONFIG)
        return false
    end

    for line in config:lines() do
        local match = string.gmatch(line, "[^=]+")
        local rcv_name = match()
        local rcv_addr = match()
        print("receiver: "..rcv_name.." address: "..rcv_addr)
        receiver_list[rcv_name] = rcv_addr
    end
    config:close()
    return true
end



return communication