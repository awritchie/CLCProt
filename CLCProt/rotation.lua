-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end

local _, xmod = ...
xmod = xmod.protmodule

-- overwrite default variables
clcprot.db_defaults.profile.rotation = xmod.defaults

clcprot.RR_actions = xmod.GetActions()

function clcprot.RR_UpdateQueue()
	xmod.db = clcprot.db.profile.rotation
	xmod.Init()
end

function clcprot.RetRotation()
	return xmod.Rotation()
end

function clcprot.RR_BuildOptions()
	return xmod.BuildOptions()
end