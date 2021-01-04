local config_parser = {}

-- a config consists of multiple lines with one key and multiple values.
-- see the following example:
-- plant=tree
-- animal=dog,cat,fish

function config_parser.parse(path)
    local config_file = io.open(path, "r")
    if not config_file then
        print("error config_parser.parse(): no file at "..path)
        return nil
    end

    local config = {}
    for line in config_file:lines() do
        local match = string.gmatch(line, "[^=,]+")
        local key = match()
        if key ~=  nil then
            if config[key] ~= nil then
                print("warning config_parser.parse(): the key "..key.." appears multiple times in the config.")
            else
                local curr_value = match()
                if curr_value ~= nil then
                    local values = {}
                    repeat
                        table.insert(values, curr_value)
                        curr_value = match()
                    until curr_value == nil
                    config[key] = values
                end
            end
        end
    end

    config_file:close()
    return config
end

return config_parser