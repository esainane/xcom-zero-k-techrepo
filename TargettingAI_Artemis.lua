function widget:GetInfo()
   return {
      name         = "TargettingAI_Artemis",
      desc         = "attempt to make Artemis not fire cheap aircraft with metal cost less than 270. Meant to be used with hold/return fire state. Version 1,00",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 11,
	  handler		= true, --for adding customCommand into UI
      enabled      = true
   }
end


local UPDATE_FRAME=4
local ArtemisStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local Echo = Spring.Echo
local Artemis_ID = UnitDefNames.turretaaheavy.id
local GetSpecState = Spring.GetSpectatingState
local CMD_STOP = CMD.STOP
local CMD_ATTACK = CMD.ATTACK

local CMD_Change_MetalTarget = 19497
local ArtemisUnitDefID = UnitDefNames["turretaaheavy"].id
local selectedArtemis = nil

local cmdChangeMetalTarget = {
	id      = CMD_Change_MetalTarget,
	type    = CMDTYPE.ICON,
	tooltip = 'Change the metal threshold for selective firing.',
	action  = 'oneclickwep',
	params  = { }, 
	texture = 'LuaUI/Images/commands/Bold/dgun.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},  
}

local ArtemisControllerMT
local ArtemisController = {
	unitID,
	pos,
	range,
	forceTarget,
	metalTarget,
	metalTargetValue,


	new = function(index, unitID)
		--Echo("ArtemisController added:" .. unitID)
		local self = {}
		setmetatable(self, ArtemisControllerMT)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		self.metalTarget = {220, 300, 700}
		self.metalTargetValue = 1
		return self
	end,

	unset = function(self)
		--Echo("ArtemisController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,
	
	setForceTarget = function(self, param)
		self.forceTarget = param[1]
	end,
	
	changeMetalTarget = function(self)
		self.metalTargetValue = self.metalTargetValue+1
		if (self.metalTargetValue > #self.metalTarget)then
			self.metalTargetValue = 1
		end	
		Echo("Minimum metal filter changed to:" .. self.metalTarget[self.metalTargetValue])
	end,
	
	isEnemyInRange = function (self)
		local units = GetUnitsInCylinder(self.pos[1], self.pos[3], self.range, Spring.ENEMY_UNITS)
		local target = nil
		for i=1, #units do
			if (units[i]==self.forceTarget and GetUnitIsDead(units[i]) == false)then
				GiveOrderToUnit(self.unitID,CMD_ATTACK, units[i], 0)
				return true
			end
			local unitDefID = GetUnitDefID(units[i])
			if not(unitDefID == nil)then
				if  (GetUnitIsDead(units[i]) == false and  UnitDefs[unitDefID].isAirUnit == true and UnitDefs[unitDefID].metalCost >= self.metalTarget[self.metalTargetValue]) then
					if (target == nil) then
						target = units[i]
					end
					if (UnitDefs[GetUnitDefID(target)].metalCost < UnitDefs[unitDefID].metalCost)then
						target = units[i]
					end
				end
			end
		end
		if (target == nil) then
			GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		else
			GiveOrderToUnit(self.unitID,CMD_ATTACK, target, 0)
		end
	end,
	
	handle=function(self)
		if(GetUnitStates(self.unitID).firestate==1)then
			self:isEnemyInRange()
		end
	end
}
ArtemisControllerMT = {__index = ArtemisController}

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if (unitDefID == Artemis_ID and cmdID == CMD_ATTACK  and #cmdParams == 1) then
		if (ArtemisStack[unitID])then
			ArtemisStack[unitID]:setForceTarget(cmdParams)
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Artemis_ID)
		and (unitTeam==GetMyTeamID()) then
			ArtemisStack[unitID] = ArtemisController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID) 
	if not (ArtemisStack[unitID]==nil) then
		ArtemisStack[unitID]=ArtemisStack[unitID]:unset();
	end
end

function widget:GameFrame(n) 
	if (n%UPDATE_FRAME==0) then
		for _,Artemis in pairs(ArtemisStack) do 
			Artemis:handle()
		end
	end
end

--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedArtemis ~= nil then
		if (cmdID == CMD_Change_MetalTarget)then

			for i=1, #selectedArtemis do
				if(ArtemisStack[selectedArtemis[i]])then
					ArtemisStack[selectedArtemis[i]]:changeMetalTarget()
				end
			end
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedArtemis = filterArtemis(selectedUnits)
end

function filterArtemis(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (ArtemisUnitDefID == GetUnitDefID(unitID)) then
			n = n + 1
			filtered[n] = unitID
		end
	end
	if n == 0 then
		return nil
	else
		return filtered
	end
end

function widget:CommandsChanged()
	if selectedArtemis then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdChangeMetalTarget
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
		if (unitDefID == Artemis_ID)  then
			if  (ArtemisStack[units[i]]==nil) then
				ArtemisStack[units[i]]=ArtemisController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
