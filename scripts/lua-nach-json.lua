-- lua-nach-json.lua - liest eine Gluon-site.conf (Lua-Ausdruck) und gibt sie
-- als JSON aus. Hilfsskript fuer scripts/multidomain-aus-stammdaten.py.
--
--   lua5.1 scripts/lua-nach-json.lua <datei>
--
-- Tabellen mit den Schluesseln 1..n (ohne Luecken) werden JSON-Arrays, alle
-- anderen Objekte mit sortierten Schluesseln. Eine leere Tabelle wird {}.
--
-- SPDX-License-Identifier: BSD-3-Clause

local f = assert(io.open(arg[1], 'rb'))
local text = f:read('*a')
f:close()
local chunk = assert(loadstring('return ' .. text, '=' .. arg[1]))
setfenv(chunk, {})
local wert = chunk()

local function ist_array(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	if n == 0 then return false end
	for i = 1, n do
		if t[i] == nil then return false end
	end
	return true
end

local function str(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		local e = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\t'] = '\\t', ['\r'] = '\\r' }
		return e[c] or string.format('\\u%04x', c:byte())
	end) .. '"'
end

local function json(v)
	local t = type(v)
	if t == 'string' then
		return str(v)
	elseif t == 'number' then
		if v ~= v or v == math.huge or v == -math.huge then error('Zahl nicht darstellbar') end
		if v == math.floor(v) then return string.format('%d', v) end
		for stellen = 14, 17 do -- kuerzeste Darstellung, die genau zurueckliest
			local s = string.format('%.' .. stellen .. 'g', v)
			if tonumber(s) == v then return s end
		end
	elseif t == 'boolean' then
		return tostring(v)
	elseif t == 'table' then
		local teile = {}
		if ist_array(v) then
			for i = 1, #v do teile[i] = json(v[i]) end
			return '[' .. table.concat(teile, ',') .. ']'
		end
		local schluessel = {}
		for k in pairs(v) do
			if type(k) ~= 'string' then error('Schluessel ist kein String: ' .. tostring(k)) end
			schluessel[#schluessel + 1] = k
		end
		table.sort(schluessel)
		for _, k in ipairs(schluessel) do teile[#teile + 1] = str(k) .. ':' .. json(v[k]) end
		return '{' .. table.concat(teile, ',') .. '}'
	end
	error('Typ nicht darstellbar: ' .. t)
end

io.write(json(wert), '\n')
