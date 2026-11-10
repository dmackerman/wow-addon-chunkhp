-- ChunkHP: lost health flashes as a chunk that fades out, then drains as a trail.
--
-- UnitHealth returns secret values in WoW Forever, so nothing here does math on
-- health. The overlay bars only ever receive health values through SetValue, and
-- they sit in a frame that clips to the empty part of the Blizzard bar (from the
-- fill texture's edge to the bar's end). Whatever an overlay shows past the real
-- fill is the lost chunk; heals end up hidden behind the fill on their own.

local ADDON, ns = ...
local L = ns.L

local DEFAULTS = {
	target = true,      -- decorate the target frame
	nameplates = true,  -- decorate nameplates
	flash = true,       -- the chunk flashes and fades out
	trail = true,       -- the chunk lingers, then drains away
	delay = 0.35,       -- seconds the trail holds before draining
	fadeTime = 0.45,    -- seconds the flash takes to fade
	flashColor = { 1, 1, 1, 0.9 },
	trailColor = { 1, 0.75, 0.15, 0.85 },
	preset = "classic", -- PRESETS key, or "custom" once something is changed by hand
}

-- Each preset sets these keys. Named by genre; the drain itself always uses
-- Blizzard's ease-out, so the feel comes from colors, hold time and flash.
local PRESET_ORDER = { "classic", "soulslike", "fighting", "jrpg", "arcade" }
local PRESETS = {
	classic = { flash = true, trail = true, delay = 0.35, fadeTime = 0.45,
		flashColor = { 1, 1, 1, 0.9 }, trailColor = { 1, 0.75, 0.15, 0.85 } },
	soulslike = { flash = false, trail = true, delay = 0.8, fadeTime = 0.45,
		flashColor = { 1, 1, 1, 0.9 }, trailColor = { 1, 0.7, 0.1, 0.9 } },
	fighting = { flash = true, trail = true, delay = 1.2, fadeTime = 0.15,
		flashColor = { 1, 1, 1, 1 }, trailColor = { 0.9, 0.1, 0.1, 0.9 } },
	jrpg = { flash = true, trail = true, delay = 0.5, fadeTime = 0.5,
		flashColor = { 1, 1, 1, 0.9 }, trailColor = { 1, 0.45, 0.55, 0.85 } },
	arcade = { flash = true, trail = false, delay = 0.35, fadeTime = 0.1,
		flashColor = { 1, 1, 1, 1 }, trailColor = { 1, 0.75, 0.15, 0.85 } },
}

local db
local category  -- our page in Options > AddOns, once registered
local previewOverlay  -- the overlay on the options preview bar, once built
local settingsByKey = {}  -- db key -> registered Settings object
local applyingPreset = false
local overlays = {}  -- health bar -> overlay
local byUnit = {}    -- unit token -> overlay
local EASE = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local FLAT = "Interface\\Buttons\\WHITE8X8"

local function IsForbidden(frame)
	return frame and frame.IsForbidden and frame:IsForbidden()
end

local function NewBar(parent, bar, color, level)
	local sb = CreateFrame("StatusBar", nil, parent)
	sb:SetAllPoints(bar)
	sb:SetFrameLevel(level)
	sb:SetStatusBarTexture(FLAT)
	sb:SetStatusBarColor(unpack(color))
	if bar.GetReverseFill then sb:SetReverseFill(bar:GetReverseFill()) end
	sb:SetMinMaxValues(0, 1)
	sb:SetValue(0)
	return sb
end

local function CreateOverlay(bar)
	local fill = bar:GetStatusBarTexture()
	local level = bar:GetFrameLevel() + 1

	local clip = CreateFrame("Frame", nil, bar)
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(level)
	if bar.GetReverseFill and bar:GetReverseFill() then
		clip:SetPoint("TOPRIGHT", fill, "TOPLEFT")
		clip:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
	else
		clip:SetPoint("TOPLEFT", fill, "TOPRIGHT")
		clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
	end

	local ov = { bar = bar, clip = clip }
	ov.trail = NewBar(clip, bar, db.trailColor, level + 1)
	ov.flash = NewBar(clip, bar, db.flashColor, level + 2)
	ov.flash:SetAlpha(0)

	ov.fade = ov.flash:CreateAnimationGroup()
	ov.fadeAlpha = ov.fade:CreateAnimation("Alpha")
	ov.fadeAlpha:SetFromAlpha(1)
	ov.fadeAlpha:SetToAlpha(0)
	ov.fadeAlpha:SetSmoothing("OUT")
	ov.fade:SetToFinalAlpha(true)

	overlays[bar] = ov
	return ov
end

-- An overlay follows either a unit or, for the options preview, a fake bar
-- whose plain numbers live in ov.fake.
local function HasSource(ov)
	if ov.fake then return true end
	return ov.unit ~= nil and UnitExists(ov.unit)
end

local function Health(ov)
	if ov.fake then return ov.fake.health, ov.fake.max end
	return UnitHealth(ov.unit), UnitHealthMax(ov.unit)
end

-- Snap everything to the current health with no animation (new target,
-- nameplate just shown, settings changed).
local function Reset(ov)
	ov.fade:Stop()
	ov.flash:SetAlpha(0)
	ov.pending = nil
	ov.hasLast = false
	if not HasSource(ov) then
		ov.clip:Hide()
		return
	end
	ov.clip:Show()
	ov.trail:SetStatusBarColor(unpack(db.trailColor))
	ov.flash:SetStatusBarColor(unpack(db.flashColor))
	ov.trail:SetShown(db.trail)
	local health, maxHealth = Health(ov)
	ov.trail:SetMinMaxValues(0, maxHealth)
	ov.flash:SetMinMaxValues(0, maxHealth)
	ov.trail:SetValue(health)
	ov.last = health
	ov.hasLast = true
end

local function OnHealth(ov)
	if not HasSource(ov) then return end
	local health = Health(ov)
	-- Health went from ov.last to health. If it dropped, the flash bar set to
	-- the old value shows exactly the lost slice past the real fill.
	if db.flash and ov.hasLast then
		ov.flash:SetValue(ov.last)
		ov.fade:Stop()
		ov.flash:SetAlpha(1)
		ov.fadeAlpha:SetDuration(db.fadeTime)
		ov.fade:Play()
	end
	if db.trail then
		ov.pending = GetTime() + db.delay
	end
	ov.last = health
	ov.hasLast = true
end

local function OnMaxHealth(ov)
	if not ov.unit then return end
	local maxHealth = UnitHealthMax(ov.unit)
	ov.trail:SetMinMaxValues(0, maxHealth)
	ov.flash:SetMinMaxValues(0, maxHealth)
end

local function Attach(unit, bar)
	if not bar or IsForbidden(bar) or not bar.GetStatusBarTexture then return end
	local ov = overlays[bar] or CreateOverlay(bar)
	if ov.unit and byUnit[ov.unit] == ov then byUnit[ov.unit] = nil end
	ov.unit = unit
	byUnit[unit] = ov
	Reset(ov)
end

local function Detach(unit)
	local ov = byUnit[unit]
	if not ov then return end
	byUnit[unit] = nil
	ov.unit = nil
	Reset(ov)
end

local function TargetHealthBar()
	local tf = TargetFrame
	if not tf then return end
	if tf.healthbar then return tf.healthbar end
	if TargetFrameHealthBar then return TargetFrameHealthBar end
	local main = tf.TargetFrameContent and tf.TargetFrameContent.TargetFrameContentMain
	return main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar
end

local function PlateHealthBar(plate)
	if not plate or IsForbidden(plate) then return end
	local uf = plate.UnitFrame
	if not uf or IsForbidden(uf) then return end
	if uf.healthBar then return uf.healthBar end
	local container = uf.HealthBarsContainer
	return container and (container.healthBar or container.HealthBar)
end

local function AttachPlate(unit)
	if not db.nameplates then return end
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	Attach(unit, PlateHealthBar(plate))
end

local function RefreshAll()
	for unit in pairs(byUnit) do Detach(unit) end
	if db.target and UnitExists("target") then Attach("target", TargetHealthBar()) end
	if db.nameplates and C_NamePlate.GetNamePlates then
		for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
			local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
			if unit then Attach(unit, PlateHealthBar(plate)) end
		end
	end
	if previewOverlay then Reset(previewOverlay) end
end

-- Copies a preset into db. Values with a menu control go through its setting so
-- the open options page updates too.
local function ApplyPreset(id)
	local preset = PRESETS[id]
	if not preset then return end
	applyingPreset = true
	for key, value in pairs(preset) do
		if type(value) == "table" then
			db[key] = CopyTable(value)
		elseif settingsByKey[key] then
			settingsByKey[key]:SetValue(value)
		else
			db[key] = value
		end
	end
	db.preset = id
	applyingPreset = false
	RefreshAll()
end

-- A hand-made change means the settings no longer match a preset.
local function MarkCustom()
	if applyingPreset or db.preset == "custom" then return end
	if settingsByKey.preset then
		settingsByKey.preset:SetValue("custom")
	else
		db.preset = "custom"
	end
end

-- Lets the trail hold for db.delay after the latest change, then drain.
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
	local now = GetTime()
	for _, ov in pairs(overlays) do
		if ov.pending and now >= ov.pending then
			ov.pending = nil
			if HasSource(ov) then
				ov.trail:SetValue((Health(ov)), EASE)
			end
		end
	end
end)

-- Options preview: a copy of a default enemy nameplate with plain numbers,
-- decorated by the same overlay code, so people can try the timing without a
-- target. Sizes come from the live nameplate options (NamePlateSetupOptions and
-- NamePlateDriverFrame), so it follows the player's Nameplate Style and Size
-- like the preview on Blizzard's own Nameplates page. The settings list builds
-- it from ChunkHPPreviewTemplate (ChunkHPPreview.xml) and calls Init.
local PREVIEW_MAX = 1000
local PREVIEW_HEALTH_COLOR = { 1, 0, 0 } -- hostile
local LEVEL_GAP = 5 -- between the health bar and the level box

-- The values Blizzard_NamePlates lays real plates out with (Forever 1.60.1).
-- The fallbacks are its Medium-size defaults, for when nameplates aren't loaded.
local function NamePlateLook()
	local constants = NamePlateConstants or {}
	local setup = NamePlateSetupOptions or {}
	local driver = NamePlateDriverFrame
	local style = tonumber(C_CVar.GetCVar(constants.STYLE_CVAR or "nameplateStyle"))
	local scale = driver and driver.GetNamePlateScale and driver:GetNamePlateScale(style)
	local anchors = constants.NAME_ANCHOR_STYLES or {}

	local look = {
		classic = setup.useClassicHealthBar,
		h = setup.horizontalScale or 1,
		v = setup.verticalScale or 1,
		height = setup.healthBarHeight or 13,
		inset = setup.insetWidth or 12,
		levelWidth = setup.playerLevelDiffWidth or 28,
		levelFontHeight = setup.levelFontHeight or 10,
		nameSpacing = setup.healthBarToNameAboveSpacing or 2,
		nameJustify = setup.nameJustificationWhenAboveHealthBar or "CENTER",
		nameRed = Enum.NamePlateStyle and style == Enum.NamePlateStyle.Legacy,
	}
	look.width = (driver and driver.GetNamePlateWidth and scale and driver:GetNamePlateWidth(style, scale))
		or (look.classic and 152 or 190) * look.h
	if setup.unitNameAnchorStyle == nil then
		look.nameAnchor = "above"
	elseif setup.unitNameAnchorStyle == anchors.InsideHealthBar then
		look.nameAnchor = "inside"
	elseif setup.unitNameAnchorStyle == anchors.CenteredAboveHealthBar then
		look.nameAnchor = "centered"
	else
		look.nameAnchor = "above"
	end
	return look
end

local function FontObject(name, fallback)
	return _G[name] and name or fallback
end

ChunkHPPreviewMixin = {}

function ChunkHPPreviewMixin:Init()
	if not self.bar then self:Build() end
	self:Layout()
	self:Refill()
end

function ChunkHPPreviewMixin:Build()
	-- The same framed box and label as the preview on the Nameplates page.
	local box = self:CreateTexture(nil, "BACKGROUND")
	box:SetAtlas("options_frame_child")
	box:SetPoint("TOPLEFT", 20, 0)
	box:SetPoint("BOTTOMRIGHT", -20, 34)
	local label = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -10)
	label:SetText(PREVIEW or L.PREVIEW)

	local plate = CreateFrame("Frame", nil, self)
	plate:SetPoint("CENTER", box, "CENTER", 0, -6)
	self.plate = plate

	local bar = CreateFrame("StatusBar", nil, plate)
	self.fill = bar:CreateTexture(nil, "ARTWORK")
	bar:SetStatusBarTexture(self.fill)
	bar:SetMinMaxValues(0, PREVIEW_MAX)
	self.bg = bar:CreateTexture(nil, "BACKGROUND")
	self.bar = bar

	self.fake = { health = PREVIEW_MAX, max = PREVIEW_MAX }
	self.ov = CreateOverlay(bar)
	self.ov.fake = self.fake
	previewOverlay = self.ov

	-- Border art, name and level sit above the overlays, as on a real plate.
	local front = CreateFrame("Frame", nil, plate)
	front:SetAllPoints(plate)
	front:SetFrameLevel(bar:GetFrameLevel() + 5)
	self.border = front:CreateTexture(nil, "ARTWORK")
	self.selected = front:CreateTexture(nil, "OVERLAY")
	self.name = front:CreateFontString(nil, "OVERLAY", FontObject("SystemFont_NamePlate_Outlined", "GameFontHighlightSmall"))
	self.name:SetText(L.PREVIEW_NAME)
	self.name:SetWordWrap(false)

	-- Level box (NameplateLevelFrame in Blizzard_NamePlates/Camelot).
	local level = CreateFrame("Frame", nil, front)
	level.bg = level:CreateTexture(nil, "BACKGROUND")
	level.bg:SetAtlas("ui-hud-nameplates-levelindicator")
	level.bg:SetAllPoints()
	level.text = level:CreateFontString(nil, "OVERLAY", FontObject("SystemFont_NamePlateLevel", "GameFontHighlightSmall"))
	level.text:SetPoint("CENTER")
	level.selected = level:CreateTexture(nil, "OVERLAY")
	level.selected:SetAtlas("ui-hud-nameplates-levelindicator-rectangle-selected")
	level.selected:SetPoint("TOPLEFT", -3, 3)
	level.selected:SetPoint("BOTTOMRIGHT", 3, -4)
	self.level = level

	local function Button(text, onClick, anchor)
		local b = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
		b:SetSize(96, 22)
		b:SetText(text)
		b:SetScript("OnClick", onClick)
		if anchor then
			b:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
		else
			b:SetPoint("BOTTOMLEFT", 37, 4)
		end
		return b
	end
	local hit = Button(L.PREVIEW_HIT, function() self:Hit(math.random(6, 12) / 100) end)
	local big = Button(L.PREVIEW_BIG_HIT, function() self:Hit(math.random(25, 35) / 100) end, hit)
	local heal = Button(L.PREVIEW_HEAL, function() self:SetHealth(self.fake.health + PREVIEW_MAX * 0.25) end, big)
	self.auto = Button(L.PREVIEW_AUTO_OFF, function() self:SetAuto(not self.ticker) end, heal)

	self:SetScript("OnHide", function() self:SetAuto(false) end)
end

-- Re-reads the nameplate options each time the page is shown, mirroring
-- NamePlateUnitFrameMixin's anchoring for the matching style.
function ChunkHPPreviewMixin:Layout()
	local look = NamePlateLook()
	local plate, bar, bg, border, name, level = self.plate, self.bar, self.bg, self.border, self.name, self.level
	plate:SetSize(look.width, look.height)
	for _, region in ipairs({ bar, bg, border, name, level, self.selected }) do
		region:ClearAllPoints()
	end
	if look.nameRed then
		name:SetVertexColor(1, 0, 0)
	else
		name:SetVertexColor(1, 1, 1)
	end

	local playerLevel = UnitLevel("player")
	level.text:SetText(playerLevel)
	level.text:SetTextHeight(look.levelFontHeight)
	local fair = FAIR_DIFFICULTY_COLOR
	if fair then level.text:SetTextColor(fair.r, fair.g, fair.b) end

	if look.classic then
		-- Classic: fixed border art with a slot for the level on the right.
		self.fill:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
		bar:SetPoint("TOPLEFT", plate, "TOPLEFT", 3.5 * look.h, 0.5 * look.v)
		bar:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", -20.75 * look.h, 0.5 * look.v)
		bg:Hide()
		border:SetTexture("Interface\\Tooltips\\Nameplate-Border")
		border:SetTexCoord(0, 1, 0.5, 1)
		border:SetSize(128 * look.h, 16 * look.v)
		border:SetPoint("CENTER", plate, "CENTER")
		border:Show()
		self.selected:Hide()
		level:SetSize(look.levelWidth, look.height)
		level:SetPoint("CENTER", border, "RIGHT", -11 * look.h, 0)
		level.bg:Hide()
		level.selected:Hide()
	else
		self.fill:SetAtlas("UI-HUD-CoolDownManager-Bar", true)
		bar:SetPoint("TOPLEFT", plate, "TOPLEFT", look.inset, 0)
		bar:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", -(look.inset + look.levelWidth + LEVEL_GAP), 0)
		bg:SetAtlas("UI-HUD-CoolDownManager-Bar-BG", true)
		bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 3)
		bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
		bg:Show()
		border:Hide()
		-- Drawn as your current target, the way you usually watch a mob's health.
		local selected = self.selected
		selected:SetAtlas((NamePlateConstants and NamePlateConstants.SELECTED_BORDER_ATLAS) or "UI-HUD-CoolDownManager-Selected-yellow")
		selected:SetPoint("TOPLEFT", bg, "TOPLEFT", -3, 2)
		selected:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, 2)
		selected:Show()
		level:SetWidth(look.levelWidth)
		level:SetPoint("TOPLEFT", bar, "TOPRIGHT", LEVEL_GAP, 3)
		level:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", LEVEL_GAP, -2)
		level.bg:Show()
		level.selected:Show()
	end

	if look.nameAnchor == "inside" then
		name:SetJustifyH("LEFT")
		name:SetPoint("LEFT", bar, "LEFT", 4, 0)
		name:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	elseif look.nameAnchor == "centered" then
		name:SetJustifyH("CENTER")
		name:SetPoint("BOTTOM", plate, "TOP", 0, look.nameSpacing)
	else
		name:SetJustifyH(look.nameJustify)
		name:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, look.nameSpacing)
		name:SetPoint("RIGHT", look.classic and plate or level, "RIGHT", 0, 0)
	end
	bar:SetStatusBarColor(unpack(PREVIEW_HEALTH_COLOR))
end

function ChunkHPPreviewMixin:SetHealth(value)
	value = math.max(0, math.min(PREVIEW_MAX, math.floor(value)))
	self.fake.health = value
	self.bar:SetValue(value)
	OnHealth(self.ov)
end

-- Back to full with no animation.
function ChunkHPPreviewMixin:Refill()
	self.fake.health = PREVIEW_MAX
	self.bar:SetValue(PREVIEW_MAX)
	Reset(self.ov)
end

function ChunkHPPreviewMixin:Hit(fraction)
	if self.fake.health <= 0 then
		self:Refill()
	else
		self:SetHealth(self.fake.health - PREVIEW_MAX * fraction)
	end
end

function ChunkHPPreviewMixin:SetAuto(on)
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
	if on then
		self.ticker = C_Timer.NewTicker(1.1, function()
			if self.fake.health < PREVIEW_MAX * 0.2 then
				self:Refill()
			else
				self:Hit(math.random(4, 15) / 100)
			end
		end)
	end
	self.auto:SetText(on and L.PREVIEW_AUTO_ON or L.PREVIEW_AUTO_OFF)
end

local TOGGLES = { target = true, nameplates = true, flash = true, trail = true }

-- Damage Numbers: shortcuts to the game's own floating combat text settings
-- (the same console variables as Blizzard's "Floating combat text on target"
-- menu), so they're game-wide and not saved by ChunkHP. The engine draws the
-- numbers; color, animation and crits can't be changed.
local DAMAGE_TEXT_TOGGLES = {
	{ cvar = "floatingCombatTextCombatDamage_v2", label = "DAMAGE_DAMAGE", tooltip = "DAMAGE_DAMAGE_TOOLTIP" },
	{ cvar = "floatingCombatTextCombatLogPeriodicSpells_v2", label = "DAMAGE_PERIODIC", tooltip = "DAMAGE_PERIODIC_TOOLTIP" },
	{ cvar = "floatingCombatTextCombatHealing_v2", label = "DAMAGE_HEALING", tooltip = "DAMAGE_HEALING_TOOLTIP" },
}
-- Not in Forever's options code, so only shown when the client has it.
local DAMAGE_TEXT_SCALE_CVARS = { "WorldTextScale_v2", "WorldTextScale" }

local function RegisterDamageNumberOptions()
	if not (Settings.RegisterProxySetting and CreateSettingsListSectionHeaderInitializer) then return end
	local function HasCVar(name) return C_CVar.GetCVar(name) ~= nil end

	Settings.RegisterInitializer(category, CreateSettingsListSectionHeaderInitializer(L.DAMAGE_HEADER, L.DAMAGE_HEADER_TOOLTIP))
	local settings = {}

	for _, toggle in ipairs(DAMAGE_TEXT_TOGGLES) do
		local cvar = toggle.cvar
		if HasCVar(cvar) then
			local setting = Settings.RegisterProxySetting(category, "CHUNKHP_" .. strupper(cvar),
				Settings.VarType.Boolean, L[toggle.label], C_CVar.GetCVarDefault(cvar) == "1",
				function() return C_CVar.GetCVarBool(cvar) == true end,
				function(value) C_CVar.SetCVar(cvar, value and "1" or "0") end)
			Settings.CreateCheckbox(category, setting, L[toggle.tooltip])
			settings[#settings + 1] = { setting = setting, default = C_CVar.GetCVarDefault(cvar) == "1" }
		end
	end

	for _, cvar in ipairs(DAMAGE_TEXT_SCALE_CVARS) do
		if HasCVar(cvar) then
			local default = tonumber(C_CVar.GetCVarDefault(cvar)) or 1
			local setting = Settings.RegisterProxySetting(category, "CHUNKHP_DAMAGE_TEXT_SCALE",
				Settings.VarType.Number, L.DAMAGE_SIZE, default,
				function() return tonumber(C_CVar.GetCVar(cvar)) or default end,
				function(value) C_CVar.SetCVar(cvar, ("%.2f"):format(value)) end)
			local options = Settings.CreateSliderOptions(0.5, 2.5, 0.1)
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
				return L.SCALE:format(value)
			end)
			Settings.CreateSlider(category, setting, options, L.DAMAGE_SIZE_TOOLTIP)
			settings[#settings + 1] = { setting = setting, default = default }
			break
		end
	end

	if CreateSettingsButtonInitializer and #settings > 0 then
		Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(L.DAMAGE_RESET, L.DAMAGE_RESET_BUTTON,
			function()
				for _, entry in ipairs(settings) do entry.setting:SetValue(entry.default) end
			end, L.DAMAGE_RESET_TOOLTIP, true))
	end
end

-- Adds ChunkHP to Options > AddOns. Every setting writes straight into db, so
-- the menu and /chunkhp always agree.
local function RegisterOptions()
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting
		and Settings.CreateCheckbox and Settings.CreateSlider and Settings.RegisterAddOnCategory) then
		print(L.OPTIONS_UNAVAILABLE)
		return
	end
	category = Settings.RegisterVerticalLayoutCategory("ChunkHP")
	if Settings.CreateElementInitializer and Settings.RegisterInitializer then
		Settings.RegisterInitializer(category, Settings.CreateElementInitializer("ChunkHPPreviewTemplate", { name = L.PREVIEW }))
	end

	local preset = Settings.RegisterAddOnSetting(category, "CHUNKHP_PRESET", "preset", db,
		Settings.VarType.String, L.OPTION_PRESET, DEFAULTS.preset)
	preset:SetValueChangedCallback(function(_, value) ApplyPreset(value) end)
	settingsByKey.preset = preset
	Settings.CreateDropdown(category, preset, function()
		local container = Settings.CreateControlTextContainer()
		for _, id in ipairs(PRESET_ORDER) do
			container:Add(id, L["PRESET_" .. strupper(id)], L["PRESET_" .. strupper(id) .. "_TOOLTIP"])
		end
		container:Add("custom", L.PRESET_CUSTOM, L.PRESET_CUSTOM_TOOLTIP)
		return container:GetData()
	end, L.OPTION_PRESET_TOOLTIP)

	local function Checkbox(key, label, tooltip)
		local setting = Settings.RegisterAddOnSetting(category, "CHUNKHP_" .. strupper(key), key, db,
			Settings.VarType.Boolean, label, DEFAULTS[key])
		setting:SetValueChangedCallback(function()
			MarkCustom()
			RefreshAll()
		end)
		settingsByKey[key] = setting
		Settings.CreateCheckbox(category, setting, tooltip)
	end
	Checkbox("target", L.OPTION_TARGET, L.OPTION_TARGET_TOOLTIP)
	Checkbox("nameplates", L.OPTION_NAMEPLATES, L.OPTION_NAMEPLATES_TOOLTIP)
	Checkbox("flash", L.OPTION_FLASH, L.OPTION_FLASH_TOOLTIP)
	Checkbox("trail", L.OPTION_TRAIL, L.OPTION_TRAIL_TOOLTIP)

	local function Slider(key, label, tooltip, minValue, maxValue)
		local setting = Settings.RegisterAddOnSetting(category, "CHUNKHP_" .. strupper(key), key, db,
			Settings.VarType.Number, label, DEFAULTS[key])
		local options = Settings.CreateSliderOptions(minValue, maxValue, 0.05)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
			return L.SECONDS:format(value)
		end)
		setting:SetValueChangedCallback(MarkCustom)
		settingsByKey[key] = setting
		Settings.CreateSlider(category, setting, options, tooltip)
	end
	Slider("delay", L.OPTION_DELAY, L.OPTION_DELAY_TOOLTIP, 0, 1.5)
	Slider("fadeTime", L.OPTION_FADE, L.OPTION_FADE_TOOLTIP, 0.1, 1.5)

	RegisterDamageNumberOptions()
	Settings.RegisterAddOnCategory(category)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		self:UnregisterEvent("ADDON_LOADED")
		local fresh = type(ChunkHPDB) ~= "table"
		if fresh then ChunkHPDB = {} end
		db = ChunkHPDB
		-- Older saves predate presets and may hold hand-tuned values.
		if not fresh and db.preset == nil then db.preset = "custom" end
		if db.preset ~= "custom" and not PRESETS[db.preset] then db.preset = nil end
		-- Fill in missing or wrong-typed values; a saved false is kept.
		for key, value in pairs(DEFAULTS) do
			if type(db[key]) ~= type(value) then
				db[key] = type(value) == "table" and CopyTable(value) or value
			end
		end
		RegisterOptions()
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
		self:RegisterEvent("UNIT_HEALTH")
		self:RegisterEvent("UNIT_MAXHEALTH")
	elseif event == "UNIT_HEALTH" then
		local ov = byUnit[arg1]
		if ov then OnHealth(ov) end
	elseif event == "UNIT_MAXHEALTH" then
		local ov = byUnit[arg1]
		if ov then OnMaxHealth(ov) end
	elseif event == "PLAYER_TARGET_CHANGED" then
		if not db.target then return end
		if UnitExists("target") then
			Attach("target", TargetHealthBar())
		else
			Detach("target")
		end
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		AttachPlate(arg1)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		Detach(arg1)
	elseif event == "PLAYER_ENTERING_WORLD" then
		RefreshAll()
	end
end)

SLASH_CHUNKHP1 = "/chunkhp"
SLASH_CHUNKHP2 = "/hittrail" -- the addon's old name
SlashCmdList.CHUNKHP = function(msg)
	local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
	local function OnOff(value) return value and L.ON or L.OFF end
	if TOGGLES[cmd] then
		db[cmd] = not db[cmd]
		MarkCustom()
		print(L.STATUS_TOGGLE:format(cmd, OnOff(db[cmd])))
		RefreshAll()
	elseif (cmd == "delay" or cmd == "fade") and tonumber(arg) then
		local value = math.max(0, tonumber(arg))
		db[cmd == "fade" and "fadeTime" or "delay"] = value
		MarkCustom()
		print(L.STATUS_TIME:format(cmd, value))
	elseif cmd == "preset" and PRESETS[arg] then
		if settingsByKey.preset then
			settingsByKey.preset:SetValue(arg)
		else
			ApplyPreset(arg)
		end
		print(L.STATUS_PRESET:format(L["PRESET_" .. strupper(arg)]))
	elseif cmd == "options" and category then
		Settings.OpenToCategory(category:GetID())
	else
		print(L.HELP_TOGGLES)
		print(L.HELP_TIMES)
		print(L.HELP_PRESETS:format(table.concat(PRESET_ORDER, " | ")))
		print(L.HELP_STATE:format(OnOff(db.target), OnOff(db.nameplates),
			OnOff(db.flash), OnOff(db.trail), db.delay, db.fadeTime))
	end
end
