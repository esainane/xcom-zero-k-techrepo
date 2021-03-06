function widget:GetInfo()
   return {
	name         = "PreFireRecluse",
    desc         = "attempt to make Recluse fire targets that are in max range + AoE range. Version 1.00",
    author       = "terve886",
    date         = "2019",
    license      = "PD", -- should be compatible with Spring
    layer        = 11,
	handler		= true, --for adding customCommand into UI
    enabled      = true
   }
end

local sin = math.sin
local cos = math.cos
local atan = math.atan
local sqrt = math.sqrt
local UPDATE_FRAME=10
local RecluseStack = {}
local GetUnitMaxRange = Spring.GetUnitMaxRange
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitIsDead = Spring.GetUnitIsDead
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitShieldState = Spring.GetUnitShieldState
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitStates = Spring.GetUnitStates
local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local ENEMY_DETECT_BUFFER  = 120
local Echo = Spring.Echo
local Recluse_ID = UnitDefNames.spiderskirm.id
local GetSpecState = Spring.GetSpectatingState
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_STOP = CMD.STOP

local selectedRecluses = nil
local CMD_TOGGLE_PREFIRE = 19345
local RecluseUnitDefID = UnitDefNames["spiderskirm"].id

local cmdToggle = {
	id      = CMD_TOGGLE_PREFIRE,
	type    = CMDTYPE.ICON,
	tooltip = 'Toggles Recluse PreFire behavior',
	action  = 'oneclickwep',
	params  = { },
	texture = 'LuaUI/Images/commands/Bold/dgun.png',
	pos     = {CMD_ONOFF,CMD_REPEAT,CMD_MOVE_STATE,CMD_FIRE_STATE, CMD_RETREAT},
}

local RecluseControllerMT
local RecluseController = {
	unitID,
	pos,
	range,
	toggle = false,
	enemyNear = false,
	damage,


	new = function(index, unitID)
		--Echo("RecluseController added:" .. unitID)
		local self = {}
		setmetatable(self,RecluseControllerMT)
		self.unitID = unitID
		self.range = GetUnitMaxRange(self.unitID)
		self.pos = {GetUnitPosition(self.unitID)}
		local unitDefID = GetUnitDefID(self.unitID)
		local weaponDefID = UnitDefs[unitDefID].weapons[1].weaponDef
		local wd = WeaponDefs[weaponDefID]
		self.damage = wd.damages[4]
		return self
	end,

	unset = function(self)
		--Echo("RecluseController removed:" .. self.unitID)
		GiveOrderToUnit(self.unitID,CMD_STOP, {}, {""},1)
		return nil
	end,

	getToggleState = function(self)
		return self.toggle
	end,

	toggleOn = function (self)
		self.toggle = true
		Echo("ReclusePreFire toggled On")
	end,

	toggleOff = function (self)
		self.toggle = false
		Echo("ReclusePreFire toggled Off")
	end,

	isEnemyInRange = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+22, false)
		if  (enemyUnitID and GetUnitIsDead(enemyUnitID) == false) then
			if (self.enemyNear == false)then
				GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
				self.enemyNear = true
			end
			return true
		end
		self.enemyNear = false
		return false
	end,

	isEnemyInEffectiveRange = function (self)
		local enemyUnitID = GetUnitNearestEnemy(self.unitID, self.range+ENEMY_DETECT_BUFFER, false)
		if(enemyUnitID)then
			local unitDefID = GetUnitDefID(enemyUnitID)
			if not(unitDefID == nil)then
				if (GetUnitIsDead(enemyUnitID) == false and UnitDefs[unitDefID].isAirUnit==false) then
					local enemyPosition = {GetUnitPosition(enemyUnitID)}
					local rotation = atan((self.pos[1]-enemyPosition[1])/(self.pos[3]-enemyPosition[3]))
					local targetPosRelative={
						sin(rotation) * (self.range-8),
						nil,
						cos(rotation) * (self.range-8),
					}

					local targetPosAbsolute
					if (self.pos[3]<=enemyPosition[3]) then
						targetPosAbsolute = {
							self.pos[1]+targetPosRelative[1],
							nil,
							self.pos[3]+targetPosRelative[3],
						}
						else
						targetPosAbsolute = {
							self.pos[1]-targetPosRelative[1],
							nil,
							self.pos[3]-targetPosRelative[3],
						}
					end
					targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
					GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
					return true
				end
			end
		end
		GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
		return false
	end,


	isShieldInEffectiveRange = function (self)
		local closestShieldID = nil
		local closestShieldDistance = nil
		local rotation, closestShieldRadius
		local units = GetUnitsInSphere(self.pos[1], self.pos[2], self.pos[3], self.range+320, Spring.ENEMY_UNITS)
		for i=1, #units do
			local unitDefID = GetUnitDefID(units[i])
			if not(unitDefID == nil)then
				if (GetUnitIsDead(units[i]) == false and UnitDefs[unitDefID].hasShield == true) then
					local shieldHealth = {GetUnitShieldState(units[i])}
					if (shieldHealth[2] and self.damage <= shieldHealth[2])then
						local enemyPositionX, enemyPositionY, enemyPositionZ = GetUnitPosition(units[i])

						local targetShieldRadius
						if (UnitDefs[unitDefID].weapons[2] == nil)then
							targetShieldRadius = WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].shieldRadius
						else
							targetShieldRadius = WeaponDefs[UnitDefs[unitDefID].weapons[2].weaponDef].shieldRadius
						end

						local enemyShieldDistance = distance(self.pos[1], enemyPositionX, self.pos[3], enemyPositionZ)-targetShieldRadius
						if not(closestShieldDistance)then
							closestShieldDistance = enemyShieldDistance
							closestShieldID = units[i]
							closestShieldRadius = targetShieldRadius
							rotation = atan((self.pos[1]-enemyPositionX)/(self.pos[3]-enemyPositionZ))
						end

						if (enemyShieldDistance < closestShieldDistance and enemyShieldDistance > 20) then
							closestShieldDistance = enemyShieldDistance
							closestShieldID = units[i]
							closestShieldRadius = targetShieldRadius
							rotation = atan((self.pos[1]-enemyPositionX)/(self.pos[3]-enemyPositionZ))
						end
					end
				end
			end
		end
		if(closestShieldID ~= nil)then
			local enemyPositionX, enemyPositionY, enemyPositionZ = GetUnitPosition(closestShieldID)
			local targetPosRelative={
				sin(rotation) * (closestShieldRadius-14),
				nil,
				cos(rotation) * (closestShieldRadius-14),
			}

			local targetPosAbsolute
			if (self.pos[3]<=enemyPositionZ) then
				targetPosAbsolute = {
					enemyPositionX-targetPosRelative[1],
					nil,
					enemyPositionZ-targetPosRelative[3],
				}
				else
					targetPosAbsolute = {
					enemyPositionX+targetPosRelative[1],
					nil,
					enemyPositionZ+targetPosRelative[3],
				}
			end
			targetPosAbsolute[2]= GetGroundHeight(targetPosAbsolute[1],targetPosAbsolute[3])
			GiveOrderToUnit(self.unitID,CMD_UNIT_SET_TARGET, {targetPosAbsolute[1], targetPosAbsolute[2], targetPosAbsolute[3]}, 0)
		else
			GiveOrderToUnit(self.unitID,CMD_UNIT_CANCEL_TARGET, 0, 0)
		end
	end,


	handle=function(self)
		if(GetUnitStates(self.unitID).firestate~=0)then
			self.pos = {GetUnitPosition(self.unitID)}
			if(self:isEnemyInRange()) then
				return
			end
			if(self.toggle)then
				if(self:isEnemyInEffectiveRange())then
					return
				end
			end
			self:isShieldInEffectiveRange()
		end
	end
}
RecluseControllerMT = {__index=RecluseController}

function distance ( x1, y1, x2, y2 )
  local dx = (x1 - x2)
  local dy = (y1 - y2)
  return sqrt ( dx * dx + dy * dy )
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
		if (unitDefID == Recluse_ID)
		and (unitTeam==GetMyTeamID()) then
			RecluseStack[unitID] = RecluseController:new(unitID);
		end
end

function widget:UnitDestroyed(unitID)
	if not (RecluseStack[unitID]==nil) then
		RecluseStack[unitID]=RecluseStack[unitID]:unset();
	end
end

function widget:GameFrame(n)
	if (n%UPDATE_FRAME==0) then
		for _,Recluse in pairs(RecluseStack) do
			Recluse:handle()
		end
	end
end

--- COMMAND HANDLING

function widget:CommandNotify(cmdID, params, options)
	if selectedRecluses ~= nil then
		if (cmdID == CMD_TOGGLE_PREFIRE)then
			local toggleStateGot = false
			local toggleState
			for i=1, #selectedRecluses do
				for _,Recluse in pairs(RecluseStack) do
					if (selectedRecluses[i] == Recluse.unitID)then
						if (toggleStateGot == false)then
							toggleState = Recluse:getToggleState()
							toggleStateGot = true
						end
						if (toggleState) then
							Recluse:toggleOff()
						else
							Recluse:toggleOn()
						end
					end
				end
			end
		end
	end
end

function widget:SelectionChanged(selectedUnits)
	selectedRecluses = filterRecluses(selectedUnits)
end

function filterRecluses(units)
	local filtered = {}
	local n = 0
	for i = 1, #units do
		local unitID = units[i]
		if (RecluseUnitDefID == GetUnitDefID(unitID)) then
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
	if selectedRecluses then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands+1] = cmdToggle
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
	local units = GetTeamUnits(GetMyTeamID())
	for i=1, #units do
		local unitDefID = GetUnitDefID(units[i])
		if (unitDefID == Recluse_ID)  then
			if  (RecluseStack[units[i]]==nil) then
				RecluseStack[units[i]]=RecluseController:new(units[i])
			end
		end
	end
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
