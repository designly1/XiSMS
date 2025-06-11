_addon.name = 'XiSMS'
_addon.author = 'Jay Simons'
_addon.version = '1.0.0'
_addon.commands = { 'xsms' }

require('luau')
require('functions')
require('config')

local json = require 'lib/dkjson'
local https = require 'ssl/https'
local ltn12 = require 'ltn12'
local xml = require 'xml'
local url = 'https://xisms.app/api/v1'

local defaults = T {
    key = '',
    tells = 'on',
    notifications = {}
}

local settings = config.load(defaults)
local run = false;

-- Track sent notifications by index
local sent_notifications = {}

-- Flag to control whether SMS is sent on /tell
local send_tells_enabled = settings.tells == 'on'

local send_sms = function(message)
    if not run then
        notice("SMS sending is currently disabled.")
        return
    end
    local data = {
        message = message
    }

    local json_data = json.encode(data)

    -- Set up the request
    local response_body = {}
    local res, code, response_headers, status = https.request {
        url = url .. '/notify',
        method = "PUT",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#json_data),
            ["X-Api-Key"] = settings.key
        },
        source = ltn12.source.string(json_data),
        sink = ltn12.sink.table(response_body)
    }
    notice("SMS Send response: " .. table.concat(response_body))
end

local send_test_sms = function()
    send_sms('Test SMS from XiSMS')
end

windower.register_event('chat message', function(message, player, mode, is_gm)
    if mode == 3 and run and send_tells_enabled then
        local msg = 'Message from ' .. player .. ': ' .. message
        send_sms(msg)
    end
end)

-- Load and parse notifications from settings.xml
local function load_notifications()
    local xml_root, err = xml.read('data/settings.xml')
    if not xml_root then
        error('Failed to load settings.xml: ' .. tostring(err))
    end
    local notifications = {}
    local global = nil
    for _, child in ipairs(xml_root.children) do
        if child.name == 'global' then
            global = child
            break
        end
    end
    if not global then return notifications end
    for _, gchild in ipairs(global.children) do
        if gchild.name == 'notifications' then
            for _, when in ipairs(gchild.children) do
                if when.name == 'when' then
                    local cond, msg = nil, nil
                    for _, wchild in ipairs(when.children) do
                        if wchild.name == 'condition' then
                            cond = wchild.children[1] -- e.g., eq, gt, etc.
                        elseif wchild.name == 'message' then
                            msg = wchild.children[1] and wchild.children[1].value or nil
                        end
                    end
                    if cond and msg then
                        table.insert(notifications, { condition = cond, message = msg })
                    end
                end
            end
        end
    end
    return notifications
end

local notifications = load_notifications()

-- Helper to resolve variable value from player or other sources
local function get_var_value(var, player)
    if not var or not player then return nil end
    if type(var) ~= 'string' then return nil end
    -- Support nested fields: e.g., 'job_points.current'
    local parts = {}
    for part in string.gmatch(var, '[^%.]+') do
        table.insert(parts, part)
    end
    local value = player
    for _, part in ipairs(parts) do
        if type(value) == 'table' then
            value = value[part]
        else
            value = nil
            break
        end
    end
    return value
end

local function check_condition(cond, player)
    -- Only support eq, gt, lt, gte, lte, ne for now
    if not cond or not cond.name then return false end
    local op = cond.name
    local var, val
    for _, cchild in ipairs(cond.children) do
        if cchild.name == 'var' then
            local v = cchild.children[1]
            var = (type(v) == 'table' and v.value) or v
        elseif cchild.name == 'val' then
            local v = cchild.children[1]
            val = (type(v) == 'table' and v.value) or v
        end
    end
    if not var or val == nil then return false end
    local pval = get_var_value(var, player)
    -- Try to resolve val as a variable if it matches a player field, else treat as number
    local vval = tonumber(val)
    if vval == nil then
        vval = get_var_value(val, player)
        if vval ~= nil then vval = tonumber(vval) end
    end
    if pval == nil or vval == nil then return false end
    pval = tonumber(pval)
    -- Switch block for op
    if op == 'eq' then
        return pval == vval
    elseif op == 'gt' then
        return pval > vval
    elseif op == 'lt' then
        return pval < vval
    elseif op == 'gte' then
        return pval >= vval
    elseif op == 'lte' then
        return pval <= vval
    elseif op == 'ne' then
        return pval ~= vval
    end
    return false
end

windower.register_event('time change', function(old, new)
    if run then
        local player = windower.ffxi.get_player()
        if player then
            for idx, notif in ipairs(notifications) do
                if check_condition(notif.condition, player) then
                    if not sent_notifications[idx] then
                        send_sms(notif.message)
                        sent_notifications[idx] = true
                    end
                else
                    sent_notifications[idx] = false
                end
            end
        end
    end
end)

local function format_table(t, indent)
    indent = indent or 0
    local result = {}
    local indent_str = string.rep('  ', indent)

    for k, v in pairs(t) do
        if type(v) == 'table' then
            table.insert(result, indent_str .. k .. ':')
            table.insert(result, format_table(v, indent + 1))
        else
            table.insert(result, string.format('%s%s: %s', indent_str, k, tostring(v)))
        end
    end

    return table.concat(result, '\n')
end

windower.register_event('addon command', function(command)
    command = command and command:lower() or 'help'

    if command == 'start' then
        run = true
        notice('SMS listener started')
    elseif command == 'stop' then
        run = false
        notice('SMS listener stopped')
    elseif command == 'reload' then
        windower.send_command('lua r XiSMS')
        notice('Reloading XiSMS...')
    elseif command == 'dump' then
        local player = windower.ffxi.get_player()
        if player then
            notice('Player Object Dump:')
            notice(format_table(player))
        else
            notice('Player not found')
        end
    elseif command == 'test' then
        send_test_sms()
    elseif command == 'reset' then
        sent_notifications = {}
        notice('Notification sent flags reset')
    elseif command == 'tellson' then
        send_tells_enabled = true
        notice('SMS on /tell enabled')
    elseif command == 'tellsoff' then
        send_tells_enabled = false
        notice('SMS on /tell disabled')
    elseif command == 'help' then
        windower.add_to_chat(17, 'XiSMS  v' .. _addon.version .. ' commands:')
        windower.add_to_chat(17, '//xsms [options]')
        windower.add_to_chat(17, '    start      - Starts SMS listener')
        windower.add_to_chat(17, '    stop       - Stops SMS listener')
        windower.add_to_chat(17, '    reload     - Reloads the addon')
        windower.add_to_chat(17, '    dump       - Dumps player object as formatted table')
        windower.add_to_chat(17, '    reset      - Resets the notification sent flag')
        windower.add_to_chat(17, '    test       - Sends a test SMS')
        windower.add_to_chat(17, '    tellson    - Enables SMS on /tell')
        windower.add_to_chat(17, '    tellsoff   - Disables SMS on /tell')
        windower.add_to_chat(17, '    help       - Displays this help text')
    end
end)

--[[
 	Copyright (c) 2025, Jay Simons
 	All rights reserved.

 	Redistribution and use in source and binary forms, with or without
 	modification, are permitted provided that the following conditions are met :

 	* Redistributions of source code must retain the above copyright
 	  notice, this list of conditions and the following disclaimer.
 	* Redistributions in binary form must reproduce the above copyright
 	  notice, this list of conditions and the following disclaimer in the
 	  documentation and/or other materials provided with the distribution.
 	* Neither the name of XIPivot nor the
 	  names of its contributors may be used to endorse or promote products
 	  derived from this software without specific prior written permission.

 	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 	DISCLAIMED.IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
