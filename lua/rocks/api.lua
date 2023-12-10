---@mod rocks.api rocks.nvim Lua API
---
---@brief [[
---
---The Lua API for rocks.nvim.
---Intended for use by modules that extend this plugin.
---
---@brief ]]

-- Copyright (C) 2023 Neorocks Org.
--
-- Version:    0.1.0
-- License:    GPLv3
-- Created:    07 Dec 2023
-- Updated:    07 Dec 2023
-- Homepage:   https://github.com/nvim-neorocks/rocks.nvim
-- Maintainer: NTBBloodbath <bloodbathalchemist@protonmail.com>

---@class Rock
---@field name string
---@field version string

---@alias rock_name string

local api = {}

local nio = require("nio")
local cache = require("rocks.cache")
local luarocks = require("rocks.luarocks")
local fzy = require("rocks.fzy")
local state = require("rocks.state")
local commands = require("rocks.commands")
local config = require("rocks.config.internal")

---Tries to get the cached rocks.
---Returns an empty list if the cache has not been populated
---or no connection to luarocks.org can be established.
---Will spawn an async task to attempt to populate the cache
---if it is not ready.
---@return table<rock_name, Rock[]> rocks
function api.try_get_cached_rocks()
    return cache.try_get_rocks()
end

---Queries luarocks.org for rocks and passes the rocks
---to a callback. Invokes the callback with an empty table
---if no rocks are found or no connection to luarocks.org can be established.
---@param callback fun(rocks: table<rock_name, Rock[]>)
---@async
function api.query_luarocks_rocks(callback)
    nio.run(luarocks.search_all, function(success, rocks)
        if success then
            callback(rocks)
        end
    end)
end

---@class FuzzyFilterOpts
---@field sort? boolean Whether to sort the results (default: `true`).

---@generic T
---@param rock_tbl table<rock_name, T>
---@param query string
---@param opts? FuzzyFilterOpts
---@return table<rock_name, T>
function api.fuzzy_filter_rock_tbl(rock_tbl, query, opts)
    vim.validate({ query = { query, "string" } })
    if opts then
        vim.validate({ sort = { opts.sort, "boolean", true } })
    end
    local matching_names = fzy.fuzzy_filter(query, vim.tbl_keys(rock_tbl), opts)
    local result = vim.empty_dict()
    ---@cast result table<rock_name, Rock[]>
    for _, match in pairs(matching_names) do
        result[match] = rock_tbl[match]
    end
    return result
end

---Query for installed rocks.
---Passes the installed rocks (table indexed by name) to a callback when done.
---@param callback fun(rocks: table<rock_name, Rock>)
---@async
function api.query_installed_rocks(callback)
    nio.run(state.installed_rocks, function(success, rocks)
        if success then
            callback(rocks)
        end
    end)
end

---Gets the rocks.toml file path.
---Note that the file may not have been created yet.
---@return string rocks_toml_file
function api.get_rocks_toml()
    return config.config_path
end

---@class RocksCmd
---@field impl fun(args:string[]) The command implementation
---@field complete? fun(subcmd_arg_lead: string): string[] Command completions callback, taking the lead of the subcommand's arguments

---Register a `:Rocks` subcommand.
---@param name string The name of the subcommand to register
---@param cmd RocksCmd
function api.register_rocks_subcommand(name, cmd)
    commands.register_subcommand(name, cmd)
end

return api