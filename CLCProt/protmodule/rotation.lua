-- don't load if class is wrong
local _, class = UnitClass("player")
if class ~= "PALADIN" then return end

		--shotrdp seraph shotr5 cs j hwsw asgc asgcfs ss2 hwfw as asfs es hpr how ss8 cons hw ss
local _, xmod = ...

xmod.protmodule = {}
xmod = xmod.protmodule

local GetTime = GetTime
local db

-- debug if clcInfo detected
local debug
if clcInfo then debug = clcInfo.debug end

local ef = CreateFrame("Frame") 	-- event frame
ef:Hide()
local qTaint = true								-- will force queue check

xmod.version = 6000001
xmod.defaults = {
	version = xmod.version,
	
	prio = "cs j",
	rangePerSkill = false,

	howclash = 0,  	-- priority time for hammer of wrath
	csclash = 0,		-- priority time for cs
	jclash = 0,     -- priority time for j
	hwswclash = 0, 	-- priority time for hwsw
	ssduration = 30, -- minimum duration on ss buff before suggesting refresh
}

-- @defines
--------------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:Hide()
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:RegisterEvent("GLYPH_UPDATED")
f:RegisterEvent("ADDON_LOADED")
--local gcdId, tvId, exoId, mexoId, howId, csId, hotrId, dsId, jId, esId, hprId,lhId,ssId,asId,hwId,conId,serId,sotId,sorId,soiId,shotrId,serId
local gcdId 				= 19740 	-- blessing of might for gcd
-- list of spellId
local tvId					= 85256		-- templar's verdict
local exoId					= 879		-- exorcism
local mexoId				= 122032	-- mass exorcism
local howId 				= 24275		-- hammer of wrath
local csId 					= 35395		-- crusader strike
local hotrId 				= 53595		-- hammer of the righteous
local dsId					= 53385		-- divine storm
local jId					= 20271		-- judgement
local esId					= 114157	-- execution sentence
local hprId					= 114165	-- holy prism
local lhId					= 114158	-- light's hammer
local ssId					= 20925		-- sacred shield
local asId                  = 31935		-- Avenger's Shield
local hwId                  = 119072 	-- Holy Wrath
local conId                 = 26573 	-- Consecration
local conId_consecrator 	= 159556	-- Glyph of the consecrator
local conId_placable 		= 116467	-- Glyph of Consecration
local serId                 = 152262 	-- Seraphim
local sotId                 = 31801 	-- Seal of Truth
local sorId                 = 20154 	-- Seal of Righteousness
local soiId                 = 20165 	-- Seal of Insight
local shotrId               = 53600 	-- shield of the righteous
local seraId                = 152262	-- seraphim

-- buffs
local buffDP 	= GetSpellInfo(90174)		-- divine purpose
local buffHA	= GetSpellInfo(105809)	-- holy avenger
local buffSeraph = GetSpellInfo(152262)
local buffAW    = GetSpellInfo(31884)		-- avenging wrath	
local buff4T15 	= GetSpellInfo(138169)  -- templar's verdict buff
local buff4T16  = GetSpellInfo(144595)	-- Item - Paladin T16 Retribution 4P Bonus

-- custom function to check ss since there are 2 buffs with same name
--local buffSS		= 65148
local buffSS = 20925
local s_conId = conId

local t_EF = 17583
local t_SS = 21811
local t_SW = 21795
local t_EmpS = 21201
local t_Sera = 21202
local t_HS = 21203
local t_FW = 54935
local t_FS = 54930
--[[ Bookkeeping 
Talents
EF = 17583
SS = 21811
Sanctified Wrath = 21795
EmpS = 21201
Seraph = 21202
HS = 21203
Glyphs
Final Wrath = 54935
Focused Shield = 54930
]]--

-- status vars
local s1, s2
local s_ctime, s_otime, s_gcd, s_hp, s_dp, s_ha, s_aw, s_ss, s_4t15, s_4t16, s_haste, s_targetType, t_gcd
local s_exoId = exoId

-- the queue
local qn = {} 		-- normal queue
local qm = {}		-- multi target queue
local q				-- working queue

local function GetCooldown(id)
	local start, duration = GetSpellCooldown(id)
	if start == nil then return 100 end
	local cd = start + duration - s_ctime - s_gcd
	if cd < 0 then return 0 end
	return cd
end

function CheckBuffDuration(unit, debuff)
for i=1,40 do
    local bufffff,_,ico,count,_,dur,ex,_,_,_,id = UnitBuff(unit, i)
    if bufffff == debuff then
        local dur = round(ex - GetTime(),3)
        return 0 + dur
    end
end
    return 0
end

function CheckGlyph(name)
for i=1, NUM_GLYPH_SLOTS do
	local enabled,_,_,glyphSpellID,_ = GetGlyphSocketInfo(i)
	if enabled then
		local link = GetGlyphLink(i)
		if link ~= "" then
			if GetSpellInfo(glyphSpellID) == name then
				return 1
			end
		end
	end
end
	return 0
end

function GetCurrentCooldown(ability)
    local startAbility, durationAbility, enableAbility = GetSpellCooldown(ability)
    if startAbility then
        if durationAbility ~= 0 then
            return durationAbility - (GetTime() - startAbility)
        else
            return 0
        end
    else
        return 0
    end
end

local HP_in_X_seconds = function (timeframe)
	local g_hp = UnitPower("player", SPELL_POWER_HOLY_POWER)
	local nglobals = math.ceil(timeframe / t_gcd)
	local g_cs = math.ceil(math.max(1,GetCurrentCooldown("Crusader Strike")/t_gcd))
	local g_j = math.ceil(math.max(1,GetCurrentCooldown("Judgment")/t_gcd))
	local g_asgc = 0
	local g_hwsw = 0
	local g_actions = {}
	local g_names = {}
	for i=1, nglobals do
		g_actions[i] = 0
		g_names[i] = 0
	end
	for i=g_cs,nglobals do
		if g_actions[i] == 0 then
			for j=0,10 do
				g_actions[i+3*j] = 1
				g_names[i+3*j] = "CS"
			end
			break
		end
	end
		for i=g_j,nglobals do
		if g_actions[i] == 0 then
			for j=0,10 do
				g_actions[i+4*j] = 1
				g_names[i+4*j] = "J"
			end
			break
		end
	end
	local _, name, _, selected, available = GetTalentInfoByID(t_SW, GetActiveSpecGroup())
		if name and selected and available then
		g_hwsw = math.ceil(math.max(1,GetCurrentCooldown("Holy Wrath")/t_gcd))
		for i=g_hwsw,nglobals do
			if g_actions[i] == 0 then
				for j=0,10 do
					g_actions[i+10*j] = 1
					g_names[i+10*j] = "HW"
				end
				break
			end
		end
	end
	if CheckBuffDuration("player","Grand Crusader") > 0 then
		g_asgc = math.ceil(math.max(1,CheckBuffDuration("player","Grand Crusader")/t_gcd))
		for i=g_asgc,nglobals do
			if g_actions[i] == 0 then
				g_actions[i] = 1
				g_names[i] = "ASGC"
				break
			end
		end
	end
	local HA_globals = math.ceil(math.max(1,CheckBuffDuration("player","Holy Avenger")/t_gcd))
	for i=1,nglobals do
		if i<HA_globals then
			g_hp = g_hp + g_actions[i]*3
		else
			g_hp = g_hp + g_actions[i]
		end
	end
	return g_hp
end

-- TODO	DP tests
-- actions ---------------------------------------------------------------------
local actions = {	
	as = {
		id = asId,
		GetCD = function()
			if s1 ~= asId 
			and CheckGlyph("Glyph of Focused Shield") == 0 
			and CheckBuffDuration("player","Grand Crusader") == 0 then
				return GetCooldown(asId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Avenger's Shield",
	},
	asgc = {
		id = asId,
		GetCD = function()
			if s1 ~= asId 
			and CheckBuffDuration("player","Grand Crusader") > 0
			and CheckGlyph("Glyph of Focused Shield") == 0 
			--and (s_hp + hpg <= 5 
			--	or CheckBuffDuration("player","Grand Crusader") < 2*t_gcd 
			--	or (s_hp < 5 and GetCurrentCooldown(seraId) <= t_gcd and s_ha > 0)) then
			then
				return GetCooldown(asId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
			s_hp = min(5, s_hp + hpg)
		end,
		info = "Avenger's Shield Grand Crusader",
	},
	asfs = {
		id = asId,
		GetCD = function()
			if s1 ~= asId 
			and CheckGlyph("Glyph of Focused Shield") == 1 
			and CheckBuffDuration("player","Grand Crusader") == 0 then
				return GetCooldown(asId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Avenger's Shield",
	},
	asgcfs = {
		id = asId,
		GetCD = function()
			if s1 ~= asId 
			and CheckBuffDuration("player","Grand Crusader") > 0
			and CheckGlyph("Glyph of Focused Shield") == 1 
			--and (s_hp + hpg <= 5 
				--or CheckBuffDuration("player","Grand Crusader") < 2*t_gcd 
				--or (s_hp < 5 and GetCurrentCooldown(seraId) <= t_gcd and s_ha > 0)) then
			then
				return GetCooldown(asId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
			
			s_hp = min(5, s_hp + hpg)
		end,
		info = "Avenger's Shield Grand Crusader",
	},	
	how = {
		id = howId,
		GetCD = function()
			if IsUsableSpell(howId) 
			and s1 ~= howId then
				return GetCooldown(howId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Hammer of Wrath",
	},
	cs = {
		id = csId,
		GetCD = function()
			--if s_hp + hpg <= 5 
			--or (s_hp < 5 and GetCurrentCooldown(seraId) <= t_gcd and s_ha > 0) then
				if s1 == csId then
					return max(0, (4.5 / s_haste - t_gcd - db.csclash))
				else
					return max(0, GetCooldown(csId) - db.csclash)
				end
			--end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
			s_hp = min(5, s_hp + hpg)
		end,
		info = "Crusader Strike",
	},
	hotr = {
		id = hotrId,
		GetCD = function()
			--if s_hp + hpg <= 5 
			--or (s_hp < 5 and GetCurrentCooldown(seraId) <= t_gcd and s_ha > 0) then
				if s1 == hotrId then
					return max(0, (4.5 / s_haste - t_gcd - db.csclash))
				else
					return max(0, GetCooldown(hotrId) - db.csclash)
				end
			--end
			return 100
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
			s_hp = min(5, s_hp + hpg)
		end,
		info = "Crusader Strike",
	},
	j = {
		id = jId,
		GetCD = function()
			if s1 ~= jId 
			--and (s_hp + hpg <= 5 
			--	or (s_hp < 5 and GetCurrentCooldown(seraId) <= t_gcd and s_ha > 0)) then
			then
				return max(0, GetCooldown(jId) - db.jclash)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
			s_hp = min(5, s_hp + hpg)
		end,
		info = "Judgement",
	},
	hw = {
		id = hwId,
		GetCD = function()
			if s1 ~= hwId then
				return GetCooldown(hwId) 
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Holy Wrath",
	},
	hwsw = {
		id = hwId,
		GetCD = function()
			if s1 ~= hwId 
			--and (s_hp + hpg <= 5 
			--	or (s_hp < 5 and GetCurrentCooldown(seraId) <= t_gcd and s_ha > 0)) then
			then
				return max(0, GetCooldown(hwId) - db.hwswclash) 
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
			s_hp = min(5, s_hp + hpg)
		end,
		info = "Holy Wrath Sanctified Wrath",
		reqTalent = t_SW,
	},
	hwfw = {
		id = hwId,
		GetCD = function()
			if s1 ~= hwId 
			and CheckGlyph("Glyph of Final Wrath") == 1 
			and UnitHealth("target") / UnitHealthMax("target") <= 0.20 then
				return GetCooldown(hwId) 
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Holy Wrath Final Wrath",
	},
	hwswfw = {
		id = hwId,
		GetCD = function()
			if s1 ~= hwId 
			--and (s_hp + hpg <= 5 
			--	or (s_hp < 5 and GetCurrentCooldown(seraId) <= t_gcd and s_ha > 0))
			and CheckGlyph("Glyph of Final Wrath") == 1 
			and UnitHealth("target") / UnitHealthMax("target") <= 0.20 then
				return max(0, GetCooldown(hwId) - db.hwswclash) 
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
			s_hp = min(5, s_hp + hpg)
		end,
		info = "Holy Wrath Sanctified Wrath Final Wrath",
		reqTalent = t_SW,
	},	
	cons = {
		id = conId,
		GetCD = function()
			if s1 ~= s_conId then
				return GetCooldown(s_conId) 
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Consecration",
	},	
	es = {
		id = esId,
		GetCD = function()
			if s1 ~= esId then
				return GetCooldown(esId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Execution Sentence",
		reqTalent = 17609,
	},
	hpr = {
		id = hprId,
		GetCD = function()
			if s1 ~= hprId then
				return GetCooldown(hprId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Holy Prism",
		reqTalent = 17605,
	},
	lh = {
		id = lhId,
		GetCD = function()
			if s1 ~= lhId then
				return GetCooldown(lhId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Light's Hammer",
		reqTalent = 17607,
	},
	ss = {
		id = ssId,
		GetCD = function()
			if s1 ~= ssId then
				return GetCooldown(ssId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd 
		end,
		info = "Sacred Shield",
		reqTalent = t_SS,
	},
	ss2 = {
		id = ssId,
		GetCD = function()
			if s1 ~= ssId and s_ss < 2 then
				return GetCooldown(ssId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Sacred Shield",
		reqTalent = t_SS,
	},
	ss8 = {
		id = ssId,
		GetCD = function()
			if s1 ~= ssId and s_ss < 8 then
				return GetCooldown(ssId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + s_gcd + t_gcd
		end,
		info = "Sacred Shield",
		reqTalent = t_SS,
	},
	shotr5 = {
		id = shotrId,
		GetCD = function()
			if s1 ~= shotrId 
			and (s_hp >= 5 or (s_hp >= 3 and s_ha > 0)) then
				local _, name, _, selected, available = GetTalentInfoByID(t_Sera, GetActiveSpecGroup())
				if name and selected and available then
					if HP_in_X_seconds(GetCurrentCooldown(seraId)+s_gcd+t_gcd) < 8 then 
						return 100 
					end
				end
				return GetCooldown(shotrId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + t_gcd
			s_hp = max(0, s_hp - 3)
		end,
		info = "Shield of the Righteous at 5 HP",
	},	
		shotrdp = {
		id = shotrId,
		GetCD = function()
			if s1 ~= shotrId 
			and s_dp > 0 then
				return GetCooldown(shotrId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime + t_gcd
		end,
		info = "Shield of the Righteous with Divine Purpose",
	},	
	seraph = {
		id = seraId,
		GetCD = function()
			if s1 ~= seraId 
			and s_hp >= 5 then
				return GetCooldown(seraId)
			end
			return 100 -- lazy stuff
		end,
		UpdateStatus = function()
			s_ctime = s_ctime 
			s_hp = max(0, s_hp - 5)
		end,
		info = "Seraphim",
		reqTalent = t_Sera,
	},	
}
--------------------------------------------------------------------------------

-- Change this db.prio to db.mtprio to switch to mt priority
local function UpdateQueue()
	-- normal queue
	qn = {}
	for v in string.gmatch(db.prio, "[^ ]+") do
		if actions[v] then	
			table.insert(qn, v)
		else
			print("clcprotmodule - invalid action:", v)
		end
	end
	db.prio = table.concat(qn, " ")
	-- force reconstruction for q
	qTaint = true
end

local function GetBuff(buff)
	local left = 0
	local _, expires
	_, _, _, _, _, _, expires = UnitBuff("player", buff, nil, "PLAYER")
	if expires then
		left = max(0, expires - s_ctime)
	end
	return left
end

-- special case for SS
local function GetBuffSS()
	-- parse all buffs and look for id
	local i = 1
	local name, _, _, _, _, _, expires, _, _, _, spellId = UnitAura("player", i, "player")
	while name do
		if spellId == buffSS then break end
		i = i + 1
		name, _, _, _, _, _, expires, _, _, _, spellId = UnitAura("player", i, "player")
	end
	
	local left = 0
	if name and expires then
		left = max(0, expires - s_ctime)
	end
	s_ss = left
end

-- reads all the interesting data
local function GetStatus()
	-- current time
	s_ctime = GetTime()
	
	-- gcd value
	local start, duration = GetSpellCooldown(gcdId)
	s_gcd = start + duration - s_ctime
	if s_gcd < 0 then s_gcd = 0 end

	-- the buffs
	s_dp	= GetBuff(buffDP)
	s_ha	= GetBuff(buffHA)
	s_aw	= GetBuff(buffAW)
	s_4t16 	= GetBuff(buff4T16)
	if s_ha > 0 then hpg = 3
	else hpg = 1 end

	-- special for ss
	GetBuffSS()
	
	-- client hp, haste, and gcd
	s_hp = UnitPower("player", SPELL_POWER_HOLY_POWER)
	s_haste = 1 + UnitSpellHaste("player") / 100
	t_gcd = max(1.,1.5 / (1+GetMeleeHaste()*0.01))
end

-- remove all talents not available and present in rotation
-- adjust for modified skills present in rotation
local function GetWorkingQueue()
	q = {}
	local name, selected, available
	for k, v in pairs(qn) do
		-- see if it has a talent requirement
		if actions[v].reqTalent then
			-- see if the talent is activated
			_, name, _, selected, available = GetTalentInfoByID(actions[v].reqTalent, GetActiveSpecGroup())
			if name and selected and available then
				table.insert(q, v)
			end
		else
			table.insert(q, v)
		end
	end
	-- adjust cons depending on glyph
	if CheckGlyph("Glyph of the Consecrator") == 1 then
		actions["cons"].id = conId_consecrator
		s_conId = conId_consecrator
	elseif CheckGlyph("Glyph of Consecration") == 1 then
		actions["cons"].id = conId_placable
		s_conId = conId_placable
	else
		actions["cons"].id = conId
		s_conId = conId
	end

--[[	-- adjust exo depending on glyph
	local glyphSpellId
	local mexo = false
	for i = 1, 3 do
		-- major glyphs are 2, 4, 6
		_, _, _, glyphSpellId = GetGlyphSocketInfo(i*2)
		if glyphSpellId == 122028 then
			mexo = true
			break
		end
	end

	if mexo then
		-- mass exorcism glyph detected
		-- switch spellid for actions
		actions["exo"].id = mexoId
		s_exoId = mexoId
	else
		actions["exo"].id = exoId
		s_exoId = exoId
	end]]--
end

local function GetNextAction()
	-- check if working queue needs updated due to glyph talent changes
	if qTaint then
		GetWorkingQueue()
		qTaint = false
	end

	local n = #q
	
	-- parse once, get cooldowns, return first 0
	for i = 1, n do
		local action = actions[q[i]]
		local cd = action.GetCD()
		if debug and debug.enabled then
			debug:AddBoth(q[i], cd)
		end
		if cd == 0 then
			return action.id, q[i]
		end
		action.cd = cd
	end
	
	-- parse again, return min cooldown
	local minQ = 1
	local minCd = actions[q[1]].cd
	for i = 2, n do
		local action = actions[q[i]]
		if minCd > action.cd then
			minCd = action.cd
			minQ = i
		end
	end
	return actions[q[minQ]].id, q[minQ]
end

-- exposed functions

-- this function should be called from addons
function xmod.Init()
	db = xmod.db
	UpdateQueue()
end

function xmod.GetActions()
	return actions
end

function xmod.Update()
	UpdateQueue()
end

function xmod.Rotation()
	s1 = nil
	GetStatus()
	if debug and debug.enabled then
		debug:Clear()
		debug:AddBoth("ctime", s_ctime)
		debug:AddBoth("gcd", s_gcd)
		debug:AddBoth("hp", s_hp)
		debug:AddBoth("ha", s_ha)
		debug:AddBoth("dp", s_dp)
		debug:AddBoth("haste", s_haste)
		debug:AddBoth("4t15", s_4t15)
	end
	local action
	s1, action = GetNextAction()
	if debug and debug.enabled then
		debug:AddBoth("s1", action)
	end
	-- 
	s_otime = s_ctime -- save it so we adjust buffs for next
	actions[action].UpdateStatus()
	
	-- adjust buffs
	s_otime = s_ctime - s_otime
	s_dp = max(0, s_dp - s_otime)
	s_ha = max(0, s_ha - s_otime)
	s_ss = max(0, s_ss - s_otime)
	s_aw = max(0, s_aw - s_otime)
	s_4t16 	= GetBuff(buff4T16)
	
	if debug and debug.enabled then
		debug:AddBoth("ctime", s_ctime)
		debug:AddBoth("otime", s_otime)
		debug:AddBoth("gcd", s_gcd)
		debug:AddBoth("hp", s_hp)
		debug:AddBoth("ha", s_ha)
		debug:AddBoth("dp", s_dp)
		debug:AddBoth("haste", s_haste)
		debug:AddBoth("4t15", s_4t15)
	end
	s2, action = GetNextAction()
	if debug and debug.enabled then
		debug:AddBoth("s2", action)
	end
	return s1, s2
end

-- event frame
ef = CreateFrame("Frame")
ef:Hide()
ef:SetScript("OnEvent", function() qTaint = true end)
ef:RegisterEvent("PLAYER_TALENT_UPDATE")




