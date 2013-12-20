-- Configuration
serverColour = Color(255, 200, 200, 200)	--ABGR?
joinColour = Color(255, 10, 255, 10)
deathColour = Color(255, 10, 10, 255)
announceColour = Color(255, 0, 255, 255)
adminColour = Color(255, 10, 10, 255)

-- Globals
homes = {}	-- Home locations
kills = {}	-- Player kill counts
settings = {}	-- Admin settings
admins = {} -- Store admin GUIDs 

--------------------------------------- Event Functions ---------------------------------------

-- When the module is loaded
onModuleLoad = function(args)
	print("---------------------------------------")
	print("Setting up...")

	-- Load file settings
	loadAdminSettings("settings.cfg")
	print("Settings loaded.")

	-- Setup kills table for all current players
	for player in Server:GetPlayers() do
		kills[player:GetName()] = 0
	end
	print("Scoreboard created.")

	-- Notify
	Chat:Broadcast("CL Module Reloaded. Reset your homes!", announceColour)
	print("CL setup complete.")
	print("---------------------------------------")
end

-- When a player joins the game
onPlayerJoin = function(args)
	local player = args.player
	local name = args.player:GetName()
	
	-- Notify others
	Chat:Broadcast(name .. " joined the game.", joinColour)
	
	local motd = settings["motd"]

	-- Issue message of the day to new player
	if motd != nil then
		Chat:Send(player, motd, serverColour)
	else
		print("'motd' not set!")
	end

	-- Reset kill count in case player exited out of a tight spot!
	kills[name] = 0
end

-- Player leaves
onPlayerQuit = function(args)
	Chat:Broadcast(args.player:GetName() .. " left the game.", joinColour)
end

-- When a player chats a message
onPlayerChat = function(args)
	local player = args.player
	local playerName = args.player:GetName()
	local position = args.player:GetPosition()
	local message = args.text

	-- Reset RNG
	math.randomseed(os.time())

	--------------------------------------- Player Commands ---------------------------------------

	-- Issue help
	if message == "/help" then
		respond(player, "Available commands:", serverColour) 
		Chat:Send(player, "/help /players /kill /findme", serverColour)
		Chat:Send(player, "/getvehicle [car, plane, random] or <wikivalue 0 - 91>", serverColour)
		Chat:Send(player, "/getweapon [handgun, revolver, sawnoff, smg, assault, sniper, shotgun, rocket, grenade, sam, bubble, minigun, rocket2]", serverColour)
		Chat:Send(player, "/sethome /gohome ", serverColour)
		Chat:Send(player, "/gotoplayer <name>", serverColour)
		Chat:Send(player, "/scores /about /server !adminhelp", serverColour)
		
		return false -- Do not show the chat message
	end	

	-- Kill the player
	if message == "/kill" then
		player:SetHealth(0)
		
		return false
	end

	-- Get the player's location
	if message == "/findme" then
		respond(player, "XYZ: " .. tostring(player:GetPosition()), serverColour)
		
		return false
	end

	-- Spawn vehicles
	if string.find(message, "/getvehicle") then
		-- If vehicle setting has been set
		if settings["allowvehicles"] != nil then
			-- If vehicle spawning is allowed
			if settings["allowvehicles"] == true then
				-- Function for use in pcall()
				createVehicle = function(id, position)
					Vehicle.Create(id, position, player:GetAngle())
				end

				-- Get type
				local type = string.sub(message, 13)

				--Offset away from player
				position.x = position.x + 10

				-- Shortcut types
				if type == "car" then
					Vehicle.Create(91, position, player:GetAngle())
				elseif type == "plane" then
					Vehicle.Create(81, position, player:GetAngle())
				elseif type == "random" then
					local id = math.random(0, 91)
					respond(player, "Rolled vehicleId " .. id, serverColour)
					if pcall(createVehicle, id, position) then
						-- Success! Vehicle has been created in pcall argument function
					else	
						respond(player, "Invalid vehicleId! Try again.", serverColour)
					end
				
				-- Numerical value
				else
					-- Get id from type
					local id = tonumber(type)
					
					-- If it's a valid number
					if id != nil then
						-- It's a valid vehicleId
						if id >= 0 and id <= 91 then
							Vehicle.Create(id, position, player:GetAngle())
						else
							respond(player, "Valid range is 0 - 91", serverColour)
						end
					end
				end
			else
				respond(player, "Vehicle spawns are not allowed!", serverColour)
			end
		else
			respond(player, "Vehicles permission not specified by admin.", serverColour)
			print("ERROR: 'allowvehicles' setting not set!")
		end

		return false
	end
	
	-- Spawn a weapon
	if string.find(message, "/getweapon") then
		-- If weapon setting has been set
		if settings["allowweapons"] != nil then
			-- If weapon spawning is allowed
			if settings["allowweapons"] == true then
				-- Slots 0, 1 or 2 -> Left, Right or Primary (Two-handed)
				giveWeapon = function(id, slot, number)
					-- If not two handed weapon
					if slot != 2 then
						--If just one hand
						if number == 1 then
							player:GiveWeapon(0, Weapon(id))

						-- Duel wield!
						elseif number == 2 then	
							player:GiveWeapon(0, Weapon(id))
							player:GiveWeapon(1, Weapon(id))
						end
					else
						player:GiveWeapon(2, Weapon(id))
					end
				end

				-- Get type, then id
				local type = string.sub(message, 12)
				local id = 0
				
				-- Default settings (arbitrary)
				local slot = 0	-- Primary
				local number = 2 -- Both hands

				-- Turn name into id
				if type == "handgun" then
					id = 2
				elseif type == "revolver" then
					id = 4
				elseif type == "smg" then
					id = 5
				elseif type == "sawnoff" then
					id = 6
				elseif type == "assault" then
					id = 11
					slot = 2
					number = 1
				elseif type == "shotgun" then
					id = 13
					slot = 2
					number = 1
				elseif type == "sniper" then
					id = 14
					slot = 2
					number = 1
				elseif type == "rocket" then
					id = 16
					slot = 2
					number = 1
				elseif type == "grenade" then
					id = 17
				elseif type == "sam" then
					id = 31
					slot = 2
					number = 1
				elseif type == "minigun" then
					id = 26
					slot = 2
					number = 1
				elseif type == "bubble" then
					id = 43
					slot = 2
					number = 1
				elseif type == "rocket2" then
					id = 66
					slot = 2
					number = 2
				end

				-- Give the weapon
				if id > 0 then
					if pcall(giveWeapon, id, slot, number) then
						respond(player, "Gave weapon: " .. type, serverColour)
					else
						respond(player, "Invalid weaponId", serverColour)
					end
				else
					respond(player, "Invalid weapon type. See /help for list.", serverColour)
				end
			else
				respond(player, "Weapons are not allowed!", serverColour)
			end
		else
			respond(player, "Weapons permission not specified by admin.", serverColour)
			print("ERROR: 'allowweapons' setting not set!")
		end
		
		return false
	end

	-- Teleport to a player
	if string.find(message, "/gotoplayer") then
		-- If teleport setting has been set
		if settings["allowteleports"] != nil then
			-- If teleports are allowed
			if settings["allowteleports"] == true then
				-- Get name
				local target = string.sub(message, 13)

				-- Get Player
				local targetPlayer = getPlayerFromName(target)

				-- Beam me up, Scotty!
				if targetPlayer != nil then
					player:SetPosition(targetPlayer:GetPosition())
					Chat:Broadcast("Teleported " .. playerName .. " to " .. targetPlayer:GetName(), serverColour)

					return false
				
				-- No match
				else
					respond(player, "No match found for player " .. target, deathColour)	
				end
			else
				respond(player, "Teleporting not allowed!", serverColour)
			end
		else
			respond(player, "Teleport permission not specified by admin.", serverColour)
			print("ERROR: 'allowteleports' setting not set!")
		end

		return false
	end

	-- Set player home
	if message == "/sethome" then
		-- If teleport setting has been set
		if settings["allowteleports"] != nil then
			-- If teleports are allowed
			if settings["allowteleports"] == true then
				homes[playerName] = player:GetPosition()
				respond(player, "Home set!", serverColour)
			else
				respond(player, "Teleporting not allowed!", serverColour)
			end
		else
			respond(player, "Teleport permission not specified by admin.", serverColour)
			print("ERROR: 'allowteleports' setting not set!")
		end

		return false
	end

	--Go home
	if message == "/gohome" then
		-- If teleport setting has been set
		if settings["allowteleports"] != nil then
			-- If teleports are allowed
			if settings["allowteleports"] == true then
				if homes[playerName] != nil then
					local pos = homes[playerName]

					-- Stop falling through terrain
					pos.y = pos.y + 5	
					
					-- Go there
					player:SetPosition(pos)
				else
					
					respond(player, "You have no home set. Use /sethome to set one.", serverColour)
				end
			else
				respond(player, "Teleporting not allowed!", serverColour)
			end
		else
			respond(player, "Teleport permission not specified by admin.", serverColour)
			print("ERROR: 'allowteleports' setting not set!")
		end
		
		return false
	end

	-- About this module
	if message == "/about" then
		respond(player, "JC2-MP Module 'CL' by Chris Lewis and Adam Taylor.", serverColour)
		Chat:Send(player, "Source available at http://github.com/C-D-Lewis/jc2-mp-cl", serverColour)

		return false
	end

	-- Server info
	if message == "/server" then
		local info = settings["serverinfo"]

		if info != nil then
			respond(player, info, serverColour)
		else
			respond(player, "No server information available.", serverColour)
			print("'serverinfo' not set!")
		end

		return false
	end

	-- List players
	if message == "/players" then
		respond(player, "Current players online:", serverColour)
		
		-- Show all players
		for p in Server:GetPlayers() do
			Chat:Send(player, p:GetName(), serverColour)
		end

		return false
	end

	-- Scoreboard
	if message == "/scores" then
		respond(player, "Current scores:", serverColour)

		-- Show all players' scores
		for key, value in pairs(kills) do
			Chat:Send(player, key .. " - " .. value .. " kills", serverColour)
		end

		return false
	end

	--------------------------------------- Admin Commands ---------------------------------------

	-- Get a SteamID for a Player
	if string.find(message, "!steamid") then
		-- If Player is admin
		if checkAdmin(player) then
			-- Get name
			local name = string.sub(message, 10)
			
			-- Return the SteamID
			if getPlayerFromName(name) != nil then
				respond(player, "SteamId for " .. name .. ": " .. tostring(getPlayerFromName(name):GetSteamId()), adminColour)
				print("SteamId for " .. name .. ": " .. tostring(getPlayerFromName(name):GetSteamId()))
			else
				respond(player, "No match found for player " .. name, adminColour)
			end	
		else
			respond(player, "You do not have permission to run this command!", serverColour)
		end
		
		return false
	end
	
	-- Kick a player
	if string.find(message, "!kick")then
		-- If Player is admin
		if checkAdmin(player) then
			-- Get name
			local name = string.sub(message, 7)
			
			-- Kick the Player
			if getPlayerFromName(name) != nil then
				respond(player, "KICKING " .. name, adminColour)
				print("KICKING " .. name)
				getPlayerFromName(name):Kick()
			else
				respond(player, "No match found for player " .. name, adminColour)
			end
		else
			respond(player, "You do not have permission to run this command!", serverColour)
		end
		
		return false
	end
	
	-- Ban a Player
	if string.find(message, "!ban")then
		-- If Player is admin
		if checkAdmin(player) then
			-- Get name
			local name = string.sub(message, 6)
			
			-- Ban the Player
			if getPlayerFromName(name) != nil then
				respond(player, "BANNING " .. name, adminColour)
				print("BANNING " .. name)
				getPlayerFromName(name):Ban()
			else
				respond(player, "No match found for player " .. name, adminColour)
			end
		else
			respond(player, "You do not have permission to run this command!", serverColour)
		end
		
		return false
	end
	
	-- Give admin help
	if message == "!adminhelp" then
		-- If Player is admin
		if checkAdmin(player) then
			respond(player, "Available commands:", adminColour) 
			Chat:Send(player, "!steamid !kick !ban", adminColour)
		else
			respond(player, "You do not have permission to run this command!", serverColour)
		end
		
		return false
	end
	
	return true -- Do show the message, for it is chit chat
end

-- When a player dies
onPlayerDeath = function(args)
	local playerName = args.player:GetName()
	local reason = args.reason

	-- In case Player died mysteriously
	local msg = playerName .. " is no more."

	-- If it was murder
	if args.killer then
		-- Get name
		local killerName = args.killer:GetName()

		-- Can't get a point from suicide!
		if killerName != playerName then
			-- Reason specific messages
			if reason == 1 then
				msg = killerName .. " smashed " .. playerName .. "."
			elseif reason == 2 then
				msg = killerName .. " filled " .. playerName .. " full o' lead."
			elseif reason == 3 then
				msg = killerName .. " detonated " .. playerName .. "."
			elseif reason == 4 then
				msg = playerName .. " was caught in " .. killerName .. "'s headlights."
			end

			-- Award points to killer
			if kills[killerName] != nil then 
				kills[killerName] = kills[killerName] + 1
			else
				kills[killerName] = 1
			end
		else
			-- Player killed themselves!
			msg = playerName .. " hurt itself in its confusion!"
		end

	-- No killer
	else
		if reason == 1 then
			msg = playerName .. " doesn't even lift."
		elseif reason == 2 then
			msg = playerName .. " ran too fast into a bullet."
		elseif reason == 3 then
			msg = playerName .. " failed at fireworks."
		elseif reason == 4 then
			msg = playerName .. " didn't look both ways."
		end
	end

	-- If deaths are to be shown
	if settings["showdeaths"] == true then
		Chat:Broadcast(msg, deathColour)
	end
end

--------------------------------------- General Functions ---------------------------------------

-- Load admin settings from path
loadAdminSettings = function(path)
	-- Open file
	local file = io.open(path, "r")

	-- For whole file
	while true do
		-- Get next line
		local line = file:read("*line")

		-- While file has lines
		if line != nil then
			-- Line is not a comment
			if string.find(line, "//") == nil then
				-- Get divider
				local s, e = string.find(line, "=")

				-- If found
				if s != nil and e != nil then
					local prefix = string.sub(line, 0, s - 1)
					local suffix = string.sub(line, e + 1)

					-- Any boolean setting!
					if suffix == "true" then
						settings[prefix] = true
					elseif suffix == "false" then
						settings[prefix] = false
					
					-- Adding a new admin
					elseif prefix == "admin" then
						table.insert(admins,suffix)
						settings[prefix] = suffix
					
					-- Plain text, such as MOTD
					else
						settings[prefix] = suffix	
					end

					-- Show in console
					print(prefix, settings[prefix])
				end		
			end	
		else
			break
		end
	end

	--Finally
	file:close()
end

-- Issue a response seperated by a newline (\n causes graphical overlap of chat messages)
respond = function(player, message, colour)
	Chat:Send(player, " ", colour)
	Chat:Send(player, message, colour)
end

-- Check a player is admin
checkAdmin = function(player)
	for key,value in pairs(admins) do
		if tostring(player:GetSteamId()) == value then
			-- Admin found!
			return true
		end	
	end

	-- No admin found
	return false
end

-- Match a name to a user entered query
getPlayerFromName = function(query)
	-- Get all players matching target description
	local results = Player.Match(query)

	-- For all matching players, find exact name match
	for index, player in ipairs(results) do -- 'pairs' not 'ipairs'?
		if player:GetName() == query then
			return player
		end
	end

	return nil	-- Java-like return null (here 'nil') if no result
end

--------------------------------------- Main Execution ---------------------------------------

-- Subscribe to game events
Events:Subscribe("ModuleLoad", onModuleLoad)
Events:Subscribe("PlayerJoin", onPlayerJoin)
Events:Subscribe("PlayerQuit", onPlayerQuit)
Events:Subscribe("PlayerChat", onPlayerChat)
Events:Subscribe("PlayerDeath", onPlayerDeath)