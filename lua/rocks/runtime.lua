---@mod rocks rocks.runtime
---
---@brief [[
---
---Functions for adding rocks to the runtimepath and sourcing them
---
---@brief ]]

-- Copyright (C) 2024 Neorocks Org.
--
-- License:    GPLv3
-- Created:    25 Dec 2023
-- Updated:    25 Apr 2024
-- Homepage:   https://github.com/nvim-neorocks/rocks.nvim
-- Maintainers: NTBBloodbath <bloodbathalchemist@protonmail.com>, Vhyrro <vhyrro@gmail.com>, mrcjkb <marc@jakobi.dev>

local runtime = {}

local constants = require("rocks.constants")
local log = require("rocks.log")

---@alias rock_pattern "*" | rock_name

---@class rocks.PackaddOpts
---@field bang? boolean

---@param err_msg? string
---@return nil | boolean
local function is_not_found(err_msg)
    return err_msg and err_msg:find("Directory not found in 'packpath'") ~= nil
end

---@param rock Rock
---@param opts rocks.PackaddOpts
---@param err string The previous error message
---@return boolean success
---@return string | nil error_message
local function init_site_symlink_and_retry_packadd(rock, opts, err)
    local symlink_created = require("rocks.adapter").init_site_symlink_sync(rock)
    if symlink_created then
        return pcall(vim.cmd.packadd, { rock.name, bang = opts.bang })
    end
    return false, err
end

---@param rock_spec RockSpec
---@param opts? rocks.PackaddOpts
---@return boolean found
function runtime.packadd(rock_spec, opts)
    opts = vim.tbl_deep_extend("force", {
        bang = false,
    }, opts or {})
    local ok, err = pcall(vim.cmd.packadd, { rock_spec.name, bang = opts.bang })
    if is_not_found(err) and rock_spec.version then
        ok, err = init_site_symlink_and_retry_packadd({
            name = rock_spec.name,
            version = rock_spec.version, --[[ @as string ]]
        }, opts, err)
    end
    if not ok and err and not is_not_found(err) then
        vim.schedule(function()
            vim.notify(err, vim.log.levels.ERROR)
        end)
    elseif not ok then
        return false
    end
    return true
end

---@param rock_spec RockSpec
---@return boolean?
local function is_start_plugin(rock_spec)
    return not rock_spec.opt and rock_spec.version and rock_spec.name ~= constants.ROCKS_NVIM
end

---Source all plugins with `opt ~= true`
---NOTE: We don't want this to be async,
---to ensure Neovim sources `after/plugin` scripts
---after we source start plugins.
---@param user_rocks RockSpec[]
function runtime.source_start_plugins(user_rocks)
    log.trace("Sourcing start plugins")
    ---@type RockSpec[]
    local not_found = {}
    for _, rock_spec in pairs(user_rocks) do
        if is_start_plugin(rock_spec) and not runtime.packadd(rock_spec) then
            table.insert(not_found, rock_spec)
        end
    end
    if #not_found > 0 then
        local rock_names = vim
            .iter(not_found)
            ---@param rock_spec RockSpec
            :map(function(rock_spec)
                return rock_spec.name
            end)
            :totable()
        vim.schedule(function()
            vim.notify(
                ("rocks.nvim: You may need to run 'Rocks sync'.\nThe following plugins were not found:\n%s."):format(
                    vim.inspect(rock_names)
                ),
                vim.log.levels.WARN
            )
        end)
    end
end

return runtime
