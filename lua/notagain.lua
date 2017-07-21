AddCSLuaFile()

local root_dir = "notagain"
notagain = notagain or {}
notagain.loaded_libraries = notagain.loaded_libraries or {}
notagain.directories = notagain.directories or {}
notagain.hasloaded = false

do
	notagain.addon_dir = "addons/notagain/"

	local _, dirs = file.Find("addons/*", "MOD")

	for _, dir in ipairs(dirs) do
		if file.Exists("addons/" .. dir .. "/lua/notagain.lua", "MOD") then
			notagain.addon_dir = "addons/" .. dir .. "/"
			break
		end
	end
end

do
	local function load_path(path)
		if not file.Exists(path, "LUA") then
			return nil, "unable to find " .. path
		end

		local var = CompileFile(path)

		if type(var) ~= "string" then
			return var
		end

		return nil, var
	end

	local function find_library(tries, name, dir)
		local errors = ""

		for _, try in ipairs(tries) do
			local func, err = load_path(dir .. try:format(name))

			if func then
				return func
			end

			errors = errors .. err .. "\n"
		end

		return nil, errors
	end

	function notagain.GetLibrary(name, ...)
		--print("REQUIRE: ", name)

		if notagain.loaded_libraries[name] then
			return notagain.loaded_libraries[name]
		end

		local func
		local errors = ""

		if not func then
			local addon_tries = {
				"libraries/%s.lua",
				"libraries/client/%s.lua",
				"libraries/server/%s.lua",
				"%s.lua",
			}

			for addon_name, addon_dir in pairs(notagain.directories) do
				local found, err = find_library(addon_tries, name, addon_dir .. "/")

				if found then
					func = found
				else
					errors = errors .. err
				end
			end
		end

		-- foo/init.lua
		if not func then
			local res, msg = load_path(root_dir .. "/" .. name .. "/init.lua")
			if res then
				func = res
			else
				errors = errors .. msg
			end
		end

		if func == nil then
			return nil, errors
		end

		local ok, lib = pcall(func, ...)

		if ok == false then
			return nil, lib
		end

		if lib == nil then
			return nil, "library " .. name .. " returns nil"
		end

		notagain.loaded_libraries[name] = lib

		return lib
	end
end

function notagain.UnloadLibrary(name)
	notagain.loaded_libraries[name] = nil
end

local function run_dir(dir)
	for _, name in pairs((file.Find(dir .. "*.lua", "LUA"))) do
		local path = dir .. name

		include(path)

		if SERVER then
			AddCSLuaFile(path)
		end
	end

	for _, name in pairs((file.Find(dir .. "client/*.lua", "LUA"))) do
		local path = dir .. "client/" .. name

		if CLIENT then
			include(path)
		end

		if SERVER then
			AddCSLuaFile(path)
		end
	end

	if SERVER then
		for _, name in pairs((file.Find(dir .. "server/*.lua", "LUA"))) do
			include(dir .. "server/" .. name)
		end
	end
end

function notagain.AutorunDirectory(addon_name)
	run_dir(notagain.directories[addon_name] .. "/prerun/")
	run_dir(notagain.directories[addon_name] .. "/autorun/")
end

function notagain.Autorun()
	--If external stuff needs to be called before notagain
	hook.Run("NotagainPreLoad")

	--local include = function(path) print("INCLUDE: ", path) return _G.include(path) end
	--local AddCSLuaFile = function(path) print("AddCSLuaFile: ", path) return AddCSLuaFile(path) end

	-- pre autorun
	for addon_name, addon_dir in pairs(notagain.directories) do
		run_dir(addon_dir .. "/prerun/")
	end

	-- autorun
	for addon_name, addon_dir in pairs(notagain.directories) do
		if SERVER then -- libraries
			local dir = addon_dir .. "/libraries/"

			for _, name in pairs((file.Find(dir .. "*.lua", "LUA"))) do
				AddCSLuaFile(dir .. name)
			end

			local path = dir .. "client/"
			for _, name in pairs((file.Find(path .. "*.lua", "LUA"))) do
				AddCSLuaFile(path .. name)
			end
		end

		if not notagain.loaded_libraries[addon_name] then
			local path = addon_dir .. "/" .. addon_name .. ".lua"
			if file.Exists(path, "LUA") then
				notagain.loaded_libraries[addon_name] = include(path)
			end
		end

		run_dir(addon_dir .. "/autorun/")
	end

	notagain.hasloaded = true

	--If external stuff need that notagain has fully loaded
	hook.Run("NotagainPostLoad")
end

function notagain.PreInit()
	for addon_name, addon_dir in pairs(notagain.directories) do
		run_dir(addon_dir .. "/preinit/")
	end
end

function notagain.PostInit()
	for addon_name, addon_dir in pairs(notagain.directories) do
		run_dir(addon_dir .. "/postinit/")
	end
end

function _G.requirex(name, ...)
	local res, err = notagain.GetLibrary(name, ...)
	if res == nil then error(err, 2) end
	return res
end

do
	local dirs = {}

	for i, addon_dir in ipairs(select(2, file.Find(root_dir .. "/*", "LUA"))) do
		dirs[addon_dir] = root_dir .. "/" .. addon_dir
	end

	notagain.directories = dirs
end