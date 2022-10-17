local BS = AceLibrary("Babble-Spell-2.2")
local elapsed = 0

local roman = {
	'I', 'II', 'III', 'IV', 'V',
	'VI', 'VII', 'VIII', 'IX', 'X',
	'XI', 'XII', 'XIII', 'XIV', 'XV',
	'XVI', 'XVII', 'XVIII', 'XIX', 'XX'
} -- 20 enough for vanilla ?

local toSeconds = function(x)
	return x - math.floor(x / 3600) * 3600
end

-- dIsInSeconds is passed by custom clients if they want to save on maths
-- dontRegister is passed by custom clients if they need to call Stop/Failed/Delayed manually
function oCB:SpellStart(s, d, dIsInSeconds, dontRegister)
	self:Debug(string.format("SpellStart - %s | %s (%s)%s", s, d, dIsInSeconds and "s" or "ms",
		dontRegister and " | Not Registering" or ""))
    
	if s == "" then
		s = (getglobal("GameTooltipTextLeft1"):GetText() or "")
	end
	
    if not dontRegister then
        self:RegisterEvent("SPELLCAST_STOP", "SpellStop")
        self:RegisterEvent("SPELLCAST_INTERRUPTED","SpellFailed")
        self:RegisterEvent("SPELLCAST_FAILED", "SpellFailed")
        self:RegisterEvent("SPELLCAST_DELAYED", "SpellDelayed")
    end
	
	local c = self.db.profile.Colors.Casting
		
	self.startTime = GetTime()
    
    if not dIsInSeconds then
        d = d/1000
    end
	self.maxValue = self.startTime + d
	
	self.frames.CastingBar.Bar:SetStatusBarColor(c.r, c.g, c.b)
	self.frames.CastingBar.Bar:SetMinMaxValues(toSeconds(self.startTime), toSeconds(self.maxValue) )
	self.frames.CastingBar.Bar:SetValue(0)
	
	self.SpellIcon = BS:GetSpellIcon(s)
	self.ItemIcon = self:FindItemIcon(s)
	
	if self.oCBRank and self.oCBRank ~= nil and self.db.profile.CastingBar.spellShowRank then
		if oCB:IsSpell(s, self.oCBRank) then
			self:Debug("Rank Found: "..s.." "..(self.oCBRank or ""))
			if self.db.profile.CastingBar.spellRomanRank then
				local num = tonumber(self.oCBRank)
				if num and num > 0 then
					self.oCBRank = roman[num]
				end
			end
			if not self.db.profile.CastingBar.spellShortRank then
				if (GetLocale() == "frFR") then
					self.frames.CastingBar.Spell:SetText(s.." "..string.format(string.gsub(RANK_COLON, ":", "%%s"), self.oCBRank))
				else
					self.frames.CastingBar.Spell:SetText(s.." "..string.format(string.gsub(RANK_COLON, ":", " %%s"), self.oCBRank))
				end
			else
				self.frames.CastingBar.Spell:SetText(s.." "..self.oCBRank)
			end
		else
			self.frames.CastingBar.Spell:SetText(s)
		end
	else
		self.frames.CastingBar.Spell:SetText(s)
	end
	self.frames.CastingBar:SetAlpha(1)
	self.frames.CastingBar.Time:SetText("")
	self.frames.CastingBar.Delay:SetText("")
	
	local mylatency = math.floor((GetTime() - (self.oCBCastSent or 0)) * 1000)
	if self.oCBCastSent ~= nil and mylatency < 1000 then
		local w = math.floor(self.frames.CastingBar.Bar:GetWidth())
		self.frames.CastingBar.Latency:SetText(mylatency.."ms")
		self.frames.CastingBar.LagBar:SetStatusBarColor(1, 0, 0, 0.5)
		self.frames.CastingBar.LagBar:SetMinMaxValues(0, 100)
		self.frames.CastingBar.LagBar:SetValue(100)
		local lagw = w - (w*(self.maxValue-self.startTime-(mylatency/1000))/(self.maxValue-self.startTime))
		if lagw >= w then lagw = w end
		self.frames.CastingBar.LagBar:SetWidth(lagw)
	else
		self.frames.CastingBar.Latency:SetText("")
		self.frames.CastingBar.LagBar:SetValue(0)
	end
	
	if not self.SpellIcon and not self.ItemIcon then
		if (TradeSkillFrame and TradeSkillFrame:IsVisible()) then
			self:Debug("entering loop !")
			for i=1,GetNumTradeSkills() do
				if GetTradeSkillInfo(i) == s then
					self:Debug("found! "..GetTradeSkillInfo(i))
					self.SpellIcon = GetTradeSkillIcon(i);
					break
				end
			end
			if not self.SpellIcon then self:Debug("Craft icon not found :(") end
		elseif self.oCBTooltip ~= nil then
			self.ItemIcon = self:FindItemIcon(self.oCBTooltip)
		end
	end

	if not self.db.profile.CastingBar.hideIcon then
		if self.oCBIcon ~= nil and self.oCBIcon == self.ItemIcon then
			self.frames.CastingBar.Texture:SetTexture(self.oCBIcon)
			self.frames.CastingBar.Icon:Show()
		elseif self.SpellIcon then
			self.frames.CastingBar.Texture:SetTexture(self.SpellIcon)
			self.frames.CastingBar.Icon:Show()
		elseif string.find(s, "^Recipe :") or string.find(s, "^Plans :") or string.find(s, "^Schematic :") or
			string.find(s, "^Formula :") then
			self.frames.CastingBar.Texture:SetTexture("Interface\\AddOns\\oCB\\Icons\\Spell_Arcane_MindMastery")
			self.frames.CastingBar.Icon:Show()
			self.frames.CastingBar.Latency:SetText("")
			self.frames.CastingBar.LagBar:SetWidth(0)
		elseif self.ItemIcon then
			self.frames.CastingBar.Texture:SetTexture(self.ItemIcon)
			self.frames.CastingBar.Icon:Show()
			self.frames.CastingBar.Latency:SetText("")
			self.frames.CastingBar.LagBar:SetValue(0)
		else
			self.frames.CastingBar.Texture:SetTexture("Interface\\AddOns\\oCB\\Icon")
			self.frames.CastingBar.Icon:Show()
		end
	end
	
	self.holdTime 	= 0
	self.delay 		= 0
	self.casting 	= 1
	self.fadeOut 	= nil  -- spellstart
	self.SpellIcon 	= nil
	self.ItemIcon 	= nil
	
	self.frames.CastingBar:Show()
	self.frames.CastingBar.Spark:Show()
end

-- Arg is for custom clients
function oCB:SpellStop(dontUnregister)
	self:Debug("SpellStop - Stopping cast")		
	local c = self.db.profile.Colors.Complete
	
	self.frames.CastingBar.Bar:SetValue(toSeconds(self.maxValue or 0))
	
	self.frames.CastingBar.Latency:SetText("")
	self.frames.CastingBar.LagBar:SetValue(0)
	
	if not self.channeling then
		self.frames.CastingBar.Bar:SetStatusBarColor(c.r, c.g, c.b)
		self.frames.CastingBar.Spark:Hide()
	end
	
	self.delay 		= 0
	self.casting 	= nil
	self.fadeOut 	= 1 -- spellstop
	
	self.oCBCastSent = nil
	
	if not self.db.profile.lock then self:ShowTest() end
	
    if not dontUnregister then
        self:UnregisterEvent("SPELLCAST_STOP")
        self:UnregisterEvent("SPELLCAST_FAILED")
        self:UnregisterEvent("SPELLCAST_INTERRUPTED")
        self:UnregisterEvent("SPELLCAST_DELAYED")
    end
end

function oCB:SpellFailed(dontUnregister)
	local c = self.db.profile.Colors.Failed

	self.frames.CastingBar.Bar:SetMinMaxValues(0, 1)
	self.frames.CastingBar.Bar:SetValue(1)
	self.frames.CastingBar.Bar:SetStatusBarColor(c.r, c.g, c.b)
	self.frames.CastingBar.Spark:Hide()
	
	self.frames.CastingBar.Latency:SetText("")
	self.frames.CastingBar.LagBar:SetValue(0)
	
	if (event == "SPELLCAST_FAILED") then
		self.frames.CastingBar.Spell:SetText(FAILED)
	else
		self.frames.CastingBar.Spell:SetText(INTERRUPTED)
	end
	
	self.casting 		= nil
	self.channeling 	= nil
	self.fadeOut	= 1 -- spellfailed
	self.holdTime = GetTime() + 2
	
	self.oCBCastSent = nil
    
    if not dontUnregister then
        self:UnregisterEvent("SPELLCAST_STOP")
        self:UnregisterEvent("SPELLCAST_FAILED")
        self:UnregisterEvent("SPELLCAST_INTERRUPTED")
        self:UnregisterEvent("SPELLCAST_DELAYED")
    end
end

function oCB:SpellDelayed(d)
	self:Debug(string.format("SpellDelayed - Spell delayed with %s", d/1000))
	d = d / 1000
	
	if(self.frames.CastingBar:IsShown()) then
		if self.delay == nil then self.delay = 0 end
		
		self.startTime = self.startTime + d
		self.maxValue = self.maxValue + d
		self.delay = self.delay + d
		
		self.frames.CastingBar.Bar:SetMinMaxValues(toSeconds(self.startTime), toSeconds(self.maxValue))
	end
end

local Patterns = {
	["SPELL_GAINED_SELF"] = string.gsub(string.gsub(AURAADDEDSELFHELPFUL, "%d%$", ""), "%%s", "(.+)"),
}

function oCB:PlayerCombatLog()
	
	self:Debug("PlayerCombatLog " .. arg1)
	if arg1 then
		-- "You gain %s."
		for spell in string.gfind(arg1, Patterns.SPELL_GAINED_SELF) do
			if BS:HasTranslation(spell) then
				self.oCBName = BS[spell]
				self.oCBIcon = BS:GetSpellIcon(spell)
				if self.channeling then
					self.frames.CastingBar.Spell:SetText(self.oCBName)
					if self.oCBIcon ~= nil and not self.db.profile.CastingBar.hideIcon then
						self.frames.CastingBar.Texture:SetTexture(self.oCBIcon)
						self.frames.CastingBar.Icon:Show()
					end
				end
			end
			return
		end
	end
end

function oCB:SpellChannelStart(d)
	self:Debug("SpellChannelStart - Starting channel")
	self:Debug("ChannelInfo - " .. (self.oCBName or arg2) .. " - " ..
		(self.oCBRank or "no rank") .. " - " .. (self.oCBIcon or ""))
	d = d / 1000
	local c = self.db.profile.Colors.Channel
	
	self.startTime = GetTime()
	self.endTime = self.startTime + d
	self.maxValue = self.endTime
	
	self.frames.CastingBar.Bar:SetStatusBarColor(c.r, c.g, c.b)
	self.frames.CastingBar.Bar:SetMinMaxValues(toSeconds(self.startTime), toSeconds(self.endTime))
	self.frames.CastingBar.Bar:SetValue(toSeconds(self.endTime))
	
	if self.oCBRank ~= nil and self.db.profile.CastingBar.spellShowRank then
		if oCB:IsSpell(self.oCBName, self.oCBRank) then
			self:Debug("Found: "..self.oCBName.." (Rank: "..self.oCBRank..")")
			if self.db.profile.CastingBar.spellRomanRank then
				local num = tonumber(self.oCBRank)
				if num and num > 0 then
					self.oCBRank = roman[num]
				end
			end
			if not self.db.profile.CastingBar.spellShortRank then
				self.frames.CastingBar.Spell:SetText(self.oCBName ..
					" " .. string.format(string.gsub(RANK_COLON, ":", "%%s"), self.oCBRank))
			else
				self.frames.CastingBar.Spell:SetText(self.oCBName.." "..self.oCBRank)
			end
		else
			self.frames.CastingBar.Spell:SetText(self.oCBName or arg2)
		end
	else
		self.frames.CastingBar.Spell:SetText(self.oCBName or arg2)
	end

	self.frames.CastingBar.Time:SetText("")
	self.frames.CastingBar.Delay:SetText("")
	self.frames.CastingBar:SetAlpha(1)
	
	self.frames.CastingBar.Icon:Hide()
	self.frames.CastingBar.Latency:SetText("")
	
	if self.oCBIcon ~= nil and not self.db.profile.CastingBar.hideIcon then
		self.frames.CastingBar.Texture:SetTexture(self.oCBIcon)
		self.frames.CastingBar.Icon:Show()
	end
	
	self.holdTime 	= 0
	self.casting		= nil
	self.channeling 	= 1
	self.fadeOut 	= nil  -- ChannelStart
	
	self.frames.CastingBar:Show()
	self.frames.CastingBar.Spark:Show()
end

function oCB:SpellChannelStop()
	self:Debug("SpellChannelStop - Stopping channel")
	if not self.channeling then return end
	local c = self.db.profile.Colors.Complete
	
	self.frames.CastingBar.Bar:SetValue(toSeconds(self.endTime))
	self.frames.CastingBar.Bar:SetStatusBarColor(c.r, c.g, c.b)
	self.frames.CastingBar.Spark:Hide()
	
	self.delay = 0
	self.casting = nil
	self.channeling = nil
	self.fadeOut = 1 -- channelstop
	
	self.oCBCastSent = nil
	
	if not self.db.profile.lock then self:ShowTest() end
end

function oCB:SpellChannelUpdate(d)
	self:Debug("SpellChannelUpdate - Updating channel")
	d = d / 1000
	
	if(self.frames.CastingBar:IsShown()) then
		local origDuration = self.endTime - self.startTime
		
		if self.delay == nil then self.delay = 0 end
		
		self.delay = self.delay + d
		self.endTime = GetTime() + d
		self.maxValue = self.endTime
		self.startTime = self.endTime - origDuration
		
		self.frames.CastingBar.Bar:SetMinMaxValues(toSeconds(self.startTime), toSeconds(self.endTime))
	end
end

function oCB:OnCasting()
	elapsed= elapsed + arg1
	if(oCB.casting) then
		local delay, n, sp = false, GetTime(), 0
		
		if (n >= oCB.maxValue) then n = oCB.maxValue end
		
		oCB.frames.CastingBar.Time:SetText(oCB:fmtTime(n-oCB.startTime).." / "..oCB:fmtTime(oCB.maxValue-oCB.startTime))
		
		if (oCB.delay ~= 0) then delay = 1 end
		if (delay) then
			oCB.frames.CastingBar.Delay:SetText("+"..string.format("%.1f", oCB.delay or "" ))
		else 
			oCB.frames.CastingBar.Delay:SetText("")
		end
		
		if UnitOnTaxi("player") then
			oCB.frames.CastingBar.Texture:SetTexture("Interface/Icons/Ability_Hunter_EagleEye")
			oCB.frames.CastingBar.Icon:Show()
			oCB.frames.CastingBar.Latency:SetText("")
			oCB.frames.CastingBar.LagBar:SetValue(0)
		end
		
		oCB.frames.CastingBar.Bar:SetValue(toSeconds(n))
		
		local w = oCB.frames.CastingBar.Bar:GetWidth()
		sp = ((n - oCB.startTime) / (oCB.maxValue - oCB.startTime)) * w
		if( sp < 0 ) then sp = 0 end
		
		oCB.frames.CastingBar.Spark:SetPoint("CENTER", oCB.frames.CastingBar.Bar, "LEFT", sp, 0)
	elseif (oCB.channeling) then
		local delay, n, sp = false, GetTime(), 0
		
		if (n > oCB.endTime) then n = oCB.endTime end
		if (n == oCB.endTime) then
			oCB.channeling = nil
			oCB.fadeOut = 1 --onupdate complete
			return
		end

		local b = oCB.startTime + (oCB.endTime - n)
		
		oCB.frames.CastingBar.Time:SetText(oCB:fmtTime(math.max(oCB.maxValue - n, 0.0)))
		
		if (oCB.delay and oCB.delay ~= 0) then delay = 1 end
		if (delay) then
			oCB.frames.CastingBar.Delay:SetText("-"..string.format("%.1f", oCB.delay ))
		else 
			oCB.frames.CastingBar.Delay:SetText("")
		end
		
		oCB.frames.CastingBar.Bar:SetValue(toSeconds(b))
		
		
		local w = oCB.frames.CastingBar.Bar:GetWidth()
		sp = ((b - oCB.startTime) / (oCB.endTime - oCB.startTime)) * w
		
		oCB.frames.CastingBar.Spark:SetPoint("CENTER", oCB.frames.CastingBar.Bar, "LEFT", sp, 0)
	elseif(GetTime() < oCB.holdTime) then
		return
	elseif(oCB.fadeOut) then
		local a = this:GetAlpha() - .05
		if (a > 0) then
			oCB.frames.CastingBar:SetAlpha(a)
		else
			oCB.fadeOut = nil  -- OnUpdate
			oCB.frames.CastingBar:Hide()
			oCB.frames.CastingBar.Time:SetText("")
			oCB.frames.CastingBar.Delay:SetText("")
			oCB.frames.CastingBar:SetAlpha(1)
		end
	end
end
