AddCSLuaFile()

local PLAYER = {}

PLAYER.DisplayName			= "Base Class"

PLAYER.WalkSpeed			= 400		-- How fast to move when not running
PLAYER.RunSpeed				= 600		-- How fast to move when running
PLAYER.CrouchedWalkSpeed	= 0.3		-- Multiply move speed by this when crouching
PLAYER.DuckSpeed			= 0.3		-- How fast to go from not ducking, to ducking
PLAYER.UnDuckSpeed			= 0.3		-- How fast to go from ducking, to not ducking
PLAYER.JumpPower			= 200		-- How powerful our jump should be
PLAYER.CanUseFlashlight		= false		-- Can we use the flashlight
PLAYER.MaxHealth			= 100		-- Max health we can have
PLAYER.StartHealth			= 100		-- How much health we start with
PLAYER.StartArmor			= 0			-- How much armour we start with
PLAYER.DropWeaponOnDie		= false		-- Do we drop our weapon when we die
PLAYER.TeammateNoCollide	= true		-- Do we collide with teammates or run straight through them
PLAYER.AvoidPlayers			= true		-- Automatically swerves around other players
PLAYER.UseVMHands			= true		-- Uses viewmodel hands

--WCG Variables
PLAYER.icon 				= "materials/icon16/arrow_in.png"
PLAYER.xp					= 0
PLAYER.xp_max				= 0
PLAYER.level				= 0
PLAYER.unspent_levels		= 0
PLAYER.abilities			= {}

--
-- Name: PLAYER:SetupDataTables
-- Desc: Set up the network table accessors
-- Arg1:
-- Ret1:
--
function PLAYER:SetupDataTables()
end

--
-- Name: PLAYER:Init
-- Desc: Called when the class object is created (shared)
-- Arg1:
-- Ret1:
--
function PLAYER:Init()
end

--
-- Name: PLAYER:Spawn
-- Desc: Called serverside only when the player spawns
-- Arg1:
-- Ret1:
--
function PLAYER:Spawn()

	self.xp = db_get_xp(self.Player)
	self.level = db_get_level(self.Player)
	self.xp_max = self.level * 1000 + 1000
	self.unspent_levels = self.level
	
	--Loading ability levels from DB
	for key,value in pairs(self.abilities) do
		value.Level = db_get_ability_level(self.Player, value)
		self.unspent_levels = self.unspent_levels - value.Level
	end
	
	--Activating Ability spawn handlers
	for key,value in pairs(self.abilities) do
		if(value.OnSpawn != nil and value.Level > 0) then
			value:OnSpawn(self)
		end
	end

end

--
-- Name: PLAYER:Loadout
-- Desc: Called on spawn to give the player their default loadout
-- Arg1:
-- Ret1:
--
function PLAYER:Loadout()

	self.Player:Give( "weapon_pistol" )
	self.Player:GiveAmmo( 255, "Pistol", true )
	
	self.Player:Give( "weapon_shotgun" )
	
	self.Player:Give( "weapon_crowbar" )
	
	self.Player:Give( "weapon_crossbow" )
	
	self.Player:Give( "weapon_ttt_m16" )

end

function PLAYER:SetModel()

	local cl_playermodel = self.Player:GetInfo( "cl_playermodel" )
	local modelname = player_manager.TranslatePlayerModel( cl_playermodel )
	util.PrecacheModel( modelname )
	self.Player:SetModel( modelname )

end

-- Clientside only
function PLAYER:CalcView( view ) end		-- Setup the player's view
function PLAYER:CreateMove( cmd ) end		-- Creates the user command on the client
function PLAYER:ShouldDrawLocal() end		-- Return true if we should draw the local player

-- Shared
function PLAYER:StartMove( cmd, mv ) end	-- Copies from the user command to the move
function PLAYER:Move( mv ) end				-- Runs the move (can run multiple times for the same client)
function PLAYER:FinishMove( mv ) end		-- Copy the results of the move back to the Player

--
-- Name: PLAYER:ViewModelChanged
-- Desc: Called when the player changes their weapon to another one causing their viewmodel model to change
-- Arg1: Entity|viewmodel|The viewmodel that is changing
-- Arg2: string|old|The old model
-- Arg3: string|new|The new model
-- Ret1:
--
function PLAYER:ViewModelChanged( vm, old, new )
end

--
-- Name: PLAYER:PreDrawViewmodel
-- Desc: Called before the viewmodel is being drawn (clientside)
-- Arg1: Entity|viewmodel|The viewmodel
-- Arg2: Entity|weapon|The weapon
-- Ret1:
--
function PLAYER:PreDrawViewModel( vm, weapon )
end

--
-- Name: PLAYER:PostDrawViewModel
-- Desc: Called after the viewmodel has been drawn (clientside)
-- Arg1: Entity|viewmodel|The viewmodel
-- Arg2: Entity|weapon|The weapon
-- Ret1:
--
function PLAYER:PostDrawViewModel( vm, weapon )
end

--
-- Name: PLAYER:GetHandsModel
-- Desc: Called on player spawn to determine which hand model to use
-- Arg1:
-- Ret1: table|info|A table containing model, skin and body
--
function PLAYER:GetHandsModel()

	-- return { model = "models/weapons/c_arms_cstrike.mdl", skin = 1, body = "0100000" }

	local playermodel = player_manager.TranslateToPlayerModelName( self.Player:GetModel() )
	return player_manager.TranslatePlayerHands( playermodel )

end

function PLAYER:GetIcon()
	return self.icon
end

function PLAYER:SetXP(xp)

	self.xp = xp
	db_set_xp(player, xp)
	
end

function PLAYER:GainXP(xp)

	self.xp = self.xp + xp
	while (self.xp >= self.xp_max) do
		self.xp = self.xp - self.xp_max
		self.xp_max = self.xp_max + 1000
		self:LevelUp()
	end
	
	db_set_xp(self.Player, self.xp)
	db_set_level(self.Player, self.level, player_manager.GetPlayerClass(self.Player))
	self:SendRaceInfo()
	print("GainXP: " .. xp)
	print("xp " .. self.xp .. "/" .. self.xp_max)
	print("level: " .. self.level)
	
end

function PLAYER:LevelUp()
	self.level = self.level + 1
	print("Level up to: " .. self.level)
end

function PLAYER:SendRaceInfo()
	net.Start("WCG_RaceState")
	net.WriteInt(self.xp, 32)
	net.WriteInt(self.xp_max, 32)
	net.WriteInt(self.level, 32)
	net.Send(self.Player)
end

function PLAYER:LevelAbility(ab)
	local ability = self.abilities[ab]
	
	if(ability == nil) then return end
	if(self.unspent_levels <= 0) then
		local msg  = "no level points available"
		self.Player:PrintMessage(HUD_PRINTCONSOLE, msg)
		return 
	end
	
	self.unspent_levels = self.unspent_levels - 1
	ability:LevelUp()
	db_set_ability_level(self.Player, ability)
	
	local msg  = ability.name .. " is now Level: " .. ability.Level .. "/" .. ability.MaxLevel
	self.Player:PrintMessage(HUD_PRINTCONSOLE, msg)
end

function PLAYER:ResetSkills()

	for k, v in pairs(self.abilities) do
		v.Level = 0
	end
	
	self.unspent_levels = self.level
	
end

function PLAYER:ActivateAbility(abilityIndex)

	--Activating Ability Manual activation handlers (OnActivation) cl_init.lua
	local ability = self.abilities[abilityIndex]
	if(ability == nil and value.Level > 0) then
		print("No ability found: " .. abilityIndex)
	else
		ability:Activate(self.Player)
	end
	
end

function PLAYER:OnDeath( inflictor, attacker )

	--Activating Ability OnDeath handlers (???) player.lua
	for key,value in pairs(self.abilities) do
		if(value.OnDeath != nil and value.Level > 0) then
			print(value.name)
			value:OnDeath()
		end
	end

end

function PLAYER:OnJump()

	--Activating Ability OnJump handlers (???) cl_init.lua
	for key,value in pairs(self.abilities) do
		if(value.OnJump != nil and value.Level > 0) then
			print(value.name)
			value:OnJump()
		end
	end

end

function PLAYER:OnLand( bInWater, bOnFloater, flFallSpeed )

	--Activating Ability OnLand handlers (???) player.lua
	for key,value in pairs(self.abilities) do
		if(value.OnLand != nil and value.Level > 0) then
			print(value.name)
			value:OnLand()
		end
	end

end

function PLAYER:DealDamage( target, hitgroup, dmginfo )

	--Activating Ability DealDamage handlers (OnDealDamage) player.lua
	for key,value in pairs(self.abilities) do
		if(value.OnDealDamage != nil and value.Level > 0) then
			print(value.name)
			value:OnDealDamage(target, hitgroup, dmginfo)
		end
	end

end

function PLAYER:ReciveDamage( attacker, hitgroup, dmginfo )

	--Activating Ability ReciveDamage handlers (OnReciveDamage) player.lua
	for key,value in pairs(self.abilities) do
		if(value.OnDealDamage != nil and value.Level > 0) then
			print(value.name)
			value:OnReciveDamage(attacker, hitgroup, dmginfo)
		end
	end

end

CreateRace( "base", PLAYER, nil )
