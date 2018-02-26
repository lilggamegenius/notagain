local env = requirex("goluwa").env

local autocomplete_font = env.fonts.CreateFont({
	font = "Roboto Black",
	size = 18,
	weight = 600,
	blur_size = 3,
	background_color = Color(25,50,100,255),
	blur_overdraw = 3,
})

local chatsounds_enabled = CreateClientConVar("chatsounds_enabled", "1", true, false, "Disable chatsounds")

do
	local found_autocomplete
	local random_mode = false

	local function query(str, scroll)
		found_autocomplete = env.autocomplete.Query("chatsounds", str, scroll)
		print(found_autocomplete, str, scroll)
	end

	hook.Add("ChatTextChanged", "chatsounds_autocomplete_init", function()
		if not chatsounds_enabled:GetBool() then return end

		hook.Remove("ChatTextChanged", "chatsounds_autocomplete_init")

		hook.Add("OnChatTab", "chatsounds_autocomplete", function(str)
			if str == "random" or random_mode then
				random_mode = true
				query("", 0)
				return found_autocomplete[1]
			end

			query(str, (input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) or input.IsKeyDown(KEY_LCONTROL)) and -1 or 1)

			if found_autocomplete[1] then
				return found_autocomplete[1]
			end
		end)

		hook.Add("ChatTextChanged", "chatsounds_autocomplete", function(str)
			if str == "" then
				random_mode = true
				return
			end

			random_mode = false
			query(str, 0)
		end)

		hook.Add("PostRenderVGUI", "chatsounds_autocomplete", function()
			if random_mode then return end
			if found_autocomplete and #found_autocomplete > 0 then
				local x, y = chat.GetChatBoxPos()
				local w, h = chat.GetChatBoxSize()
				env.gfx.SetFont(autocomplete_font)
				env.autocomplete.DrawFound("chatsounds", x, y + h, found_autocomplete)
			end
		end)
	end)

	hook.Add("FinishChat", "chatsounds_autocomplete", function()
		if not chatsounds_enabled:GetBool() then return end

		-- in some cases ChatTextChanged is called on FinishChat which adds the hook again
		timer.Simple(0, function()
			hook.Remove("PostRenderVGUI", "chatsounds_autocomplete")
			hook.Remove("ChatTextChanged", "chatsounds_autocomplete")
			hook.Remove("OnChatTab", "chatsounds_autocomplete")
		end)
	end)
end

local blacklist = {
	[220] = true, -- hl2
	[320] = true, -- hl2 death match
	[360] = true, -- hl1 death match
	[340] = true, -- hl2 lost coast
}

local init = false

local function player_say(ply, str)
	if not init then

		env.resource.AddProvider("https://github.com/PAC3-Server/chatsounds/raw/master/")

		env.chatsounds.Initialize()

		env.chatsounds.LoadListFromAppID(220) -- hl2

		for i, info in ipairs(engine.GetGames()) do
			if info.mounted and not blacklist[info.depot] then
				env.chatsounds.LoadListFromAppID(info.depot)
			end
		end

		env.chatsounds.BuildFromGithub("PAC3-Server/chatsounds")

		hook.Run("ChatsoundsInitialized")

		init = true
	end

	if str == "sh" or (str:find("sh%s") and not str:find("%Ssh")) or (str:find("%ssh") and not str:find("sh%S")) then
		env.audio.Panic()
	end

	if str:Trim():find("^%b<>$") then return end

	env.audio.player_object = ply
	env.chatsounds.Say(str, math.Round(CurTime()))
end

hook.Add("OnPlayerChat", "chatsounds", player_say)
concommand.Add("saysound",function(ply, _,_, str)
	player_say(ply, str)
end)

if not chatsounds_enabled:GetBool() then
	hook.Remove("OnPlayerChat", "chatsounds")
end
