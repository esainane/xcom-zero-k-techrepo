function widget:GetInfo()
   return {
      name         = "UltimatumSelfDefenceAI",
      desc         = "attempt to make Ultimatum kill nearby high value targets if decloaked. Version 0,97",
      author       = "terve886",
      date         = "2019",
      license      = "PD", -- should be compatible with Spring
      layer        = 10,
      enabled      = true
   }
end
local UPDATE_FRAME=5
local currentFrame = 0
local StriderStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit


local Ultimatum_ID = UnitDefNames.striderantiheavy.id

local GetUnitIsCloaked = Spring.GetUnitIsCloaked
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetTeamUnits = Spring.GetTeamUnits
local Echo = Spring.Echo
local CMD_STOP = CMD.STOP

local GetSpecState = Spring.GetSpectatingState


local UltimatumSelfDefenceAIMT
local UltimatumSelfDefenceAI = {
	unitID,
	pos,
	range,
	cooldownFrame,
	reloadTime,
	enemyNear = false,


	new = function(index, unitID)
		--Echo("UltimatumSelfDefenceAI added:" .. unitID)
		local self = {}
		setmetatable(self, UltimatumSelfDefenceAIMT)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		self.cooldownFrame = currentFrame+400
		local unitDefID = GetUnitDefID(self.unitID)
		self.reloadTime = WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].reload
		return self
	end,

	unset = function(self)
		--Echo("UltimatumSelfDefenceAI removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	isThreatInRange = function (self)
		if(GetUnitIsCloaked(self.unitID)==false)then
			self.pos = {GetUnitPosition(self.unitID)}
			local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+40, Spring.ENEMY_UNITS)
			for i=1, #units do
				if (GetUnitIsDead(units[i]) == false) then
					local unitDefID = GetUnitDefID(units[i])
					if not(unitDefID == nil)then
						if(UnitDefs[unitDefID].metalCost >= 1500 and UnitDefs[unitDefID].isAirUnit==false)then
							GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, units[i], 0)
							return true
						end
					end
				end
			end
		end
		return false
	end
}
UltimatumSelfDefenceAIMT = {__index = UltimatumSelfDefenceAI}

function widget:GameFrame(n)
	for _,Strider in pairs(StriderStack) do
		Strider:isThreatInRange()
	end
end



function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (unitDefID == Ultimatum_ID
	and unitTeam==GetMyTeamID()) then
		StriderStack[unitID] = UltimatumSelfDefenceAI:new(unitID);
	end
end

function widget:UnitDestroyed(unitID)
	if not (StriderStack[unitID]==nil) then
		StriderStack[unitID]=StriderStack[unitID]:unset();
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if (StriderStack[unitID] and damage~=0)then
		StriderStack[unitID].cooldownFrame=currentFrame+40
	end
end

function widget:GameFrame(n)
	currentFrame = n
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
		if (unitDefID == Ultimatum_ID) then
			if  (StriderStack[units[i]]==nil) then
				StriderStack[units[i]]=UltimatumSelfDefenceAI:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
