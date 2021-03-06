function widget:GetInfo()
   return {
      name         = "ScytheCloakFireStateAutoToggle",
      desc         = "Makes Scythes automatically return fire when cloaked and fire at will when decloaked. Version 0,97",
      author       = "terve886",
      date         = "2020",
      license      = "PD", -- should be compatible with Spring
      layer        = 10,
      enabled      = true
   }
end

local GiveOrderToUnit = Spring.GiveOrderToUnit

local Scythe_ID = UnitDefNames.cloakheavyraid.id

local CMD_FIRE_STATE = CMD.FIRE_STATE

local GetSpecState = Spring.GetSpectatingState



function widget:UnitDecloaked(unitID, unitDefID, teamID)
	if (unitDefID==Scythe_ID) then
		GiveOrderToUnit(unitID,CMD_FIRE_STATE, 2, 0)
	end
end

function widget:UnitCloaked(unitID, unitDefID, teamID)
	if (unitDefID==Scythe_ID) then
		GiveOrderToUnit(unitID,CMD_FIRE_STATE, 1, 0)
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
end


function widget:PlayerChanged (playerID)
	DisableForSpec()
end
