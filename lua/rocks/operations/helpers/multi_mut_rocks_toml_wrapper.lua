local config = require("rocks.config.internal")
local fs = require("rocks.fs")

---@class MutRocksTomlRefWithPath
---@field config MutRocksTomlRef Config metatable
---@field path? string The path to the configuration

---@class MultiMutRocksTomlWrapper
---@field cache table<string, MultiMutRocksTomlWrapper> Cache for nested metatables
---@field configs MutRocksTomlRefWithPath[] A list of rocks toml configs
local MultiMutRocksTomlWrapper = {}
MultiMutRocksTomlWrapper.__index = function(self, key)
    -- Give preference to class methods/fields
    if MultiMutRocksTomlWrapper[key] then
        return MultiMutRocksTomlWrapper[key]
    end
    -- Find the key within the config tables
    for _, tbl in ipairs(self.configs) do
        if tbl.config[key] ~= nil then
            if type(tbl.config[key]) == "table" then
                if not self.cache[key] then
                    self.cache[key] = MultiMutRocksTomlWrapper.new(vim.iter(self.configs)
                        :filter(function(v)
                            return type(v.config[key]) == "table"
                        end)
                        :fold({}, function(acc, v)
                            table.insert(acc, { config = v.config[key], path = v.path })
                            return acc
                        end))
                end
                return self.cache[key]
            else
                return tbl.config[key]
            end
        end
    end
    return nil
end
MultiMutRocksTomlWrapper.__newindex = function(self, key, value)
    local insert_index = 1
    for i, tbl in ipairs(self.configs) do
        -- Insert into base config by default
        if tbl.path == config.config_path then
            insert_index = i
        end
        if tbl.config[key] ~= nil then
            tbl.config[key] = value
            return
        end
    end
    -- If key not found in any table, add it to the first table
    self.configs[insert_index].config[key] = value
end

--- Write to all rocks toml config files in an async context
---@type async fun(self: MultiMutRocksTomlWrapper)
function MultiMutRocksTomlWrapper:write()
    for _, tbl in ipairs(self.configs) do
        if tbl.path ~= nil then
            fs.write_file_await(tbl.path, "w", tostring(tbl.config))
        end
    end
end

--- Function to create a new wrapper
---@param configs MutRocksTomlRefWithPath[] A list of rocks toml configs
---@return MultiMutRocksTomlWrapper
function MultiMutRocksTomlWrapper.new(configs)
    assert(#configs > 0, "Must provide at least one rocks toml config")
    local self = { cache = {}, configs = configs }
    setmetatable(self, MultiMutRocksTomlWrapper)
    return self
end

return MultiMutRocksTomlWrapper
