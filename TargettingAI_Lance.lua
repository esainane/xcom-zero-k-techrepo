function widget:GetInfo()
	return {
		name         = "TargettingAI_Lance",
		desc         = "attempt to make Lance not fire Razors, metal extractors, solars and wind generators without order. Meant to be used with return fire state. Version 0,87",
		author       = "terve886",
		date         = "2019",
		license      = "PD", -- should be compatible with Spring
		layer        = 11,
		enabled      = true
	}
end

local abs = math.abs
local UPDATE_FRAME=4
local LanceStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitArmored = Spring.GetUnitArmored
local GetUnitStates = Spring.GetUnitStates
local IsUnitInLos = Spring.IsUnitInLos
local GetUnitVelocity  = Spring.GetUnitVelocity
local ENEMY_DETECT_BUFFER  = 40
local Echo = Spring.Echo
local Lance_ID = UnitDefNames.hoverarty.id
local Razor_ID = UnitDefNames.turretaalaser.id
local Halbert_ID = UnitDefNames.hoverassault.id
local Gauss_ID = UnitDefNames.turretgauss.id
local Faraday_ID = UnitDefNames.turretemp.id
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK



local LanceControllerMT
local LanceController = {
	unitID,
	pos,
	range,
	forceTarget,


	new = function(index, unitID)
		--Echo("LanceController added:" .. unitID)
		local self = {}
		setmetatable(self, LanceControllerMT)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		return self
	end,

	unset = function(self)
		--Echo("LanceController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	setForceTarget = function(self, param)
		self.forceTarget = param[1]
	end,

	isEnemyTooClose = function (self)
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], 500, Spring.ENEMY_UNITS)
		for i=1, #units do
			local unitDefID = GetUnitDefID(units[i])
			if not(unitDefID == nil)then
				local enemyPosition = {GetUnitPosition(units[i])}
				if (enemyPosition[2]>-30)then
					if (GetUnitIsDead(units[i]) == false) then
						local hasArmor = GetUnitArmored(units[i])
						if not((unitDefID == Razor_ID or unitDefID == Halbert_ID) and hasArmor) then
							GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
							return true
						end
					end
				end
			end
		end
		return false
	end,

	isEnemyInRange = function (self)
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range+ENEMY_DETECT_BUFFER, Spring.ENEMY_UNITS)
		local target = nil
		for i=1, #units do
			local enemyPosition = {GetUnitPosition(units[i])}
			if(enemyPosition[2]>-30)then
				if (units[i]==self.forceTarget and GetUnitIsDead(units[i]) == false)then
					GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
					return true
				end
				local unitDefID = GetUnitDefID(units[i])
				if not(unitDefID == nil)then
					if(IsUnitInLos(units[i]))then --Radar dots always return armor state as false
						if  (GetUnitIsDead(units[i]) == false)then
							local hasArmor = GetUnitArmored(units[i])
							if  (UnitDefs[unitDefID].metalCost >= 200 and
									not((unitDefID == Razor_ID
											or unitDefID == Gauss_ID
											or unitDefID == Faraday_ID
											or unitDefID == Halbert_ID) and hasArmor)) then
								if (target == nil) then
									target = units[i]
								end
								if (UnitDefs[GetUnitDefID(target)].metalCost < UnitDefs[unitDefID].metalCost)then
									target = units[i]
								end
							end
						end
					else
						if  (GetUnitIsDead(units[i]) == false)then
							if  (UnitDefs[unitDefID].metalCost >= 200 and
									not((unitDefID == Razor_ID
											or unitDefID == Gauss_ID
											or unitDefID == Faraday_ID
											or unitDefID == Halbert_ID))) then
								if (target == nil) then
									target = units[i]
								end
								if (UnitDefs[GetUnitDefID(target)].metalCost < UnitDefs[unitDefID].metalCost)then
									target = units[i]
								end
							end
						end
					end
				end
			end
		end
		if (target == nil) then
			GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
		else
			GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, target, 0)
		end
	end,

	handle=function(self)
		if(GetUnitStates(self.unitID).firestate==1)then
			local velocity = {GetUnitVelocity(self.unitID)}
			if(abs(velocity[1])+abs(velocity[3])>1.5)then --Do not fire while on move.
				return
			end
			self.pos = {GetUnitPosition(self.unitID)}
			if not(self:isEnemyTooClose())then
				self:isEnemyInRange()
			end
		end
	end
}
LanceControllerMT = {__index = LanceController}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (unitDefID == Lance_ID and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (LanceStack[unitID])then
			LanceStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (unitDefID == Lance_ID)
			and (unitTeam==GetMyTeamID()) then
		LanceStack[unitID] = LanceController:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (LanceStack[unitID]==nil) then
		LanceStack[unitID]=LanceStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for _,Lance in pairs(LanceStack) do
			Lance:handle()
		end
	end
end

-- The rest of the code is there to disable the widget for spectators
local function DisableForSpec()
	if GetSpecState() then
		widgetHandler:RemoveWidget(widget)
	end
end


function widget:Initialize()
	DisableForSpec()
	local units = GetTeamUnits(Spring.GetMyTeamID())
	for i=1, #units do
		local unitDefID = GetUnitDefID(units[i])
		if (unitDefID == Lance_ID)  then
			if  (LanceStack[units[i]]==nil) then
				LanceStack[units[i]]=LanceController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
