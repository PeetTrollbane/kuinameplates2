--------------------------------------------------------------------------------
-- Kui Nameplates
-- By Kesava at curse.com
-- All rights reserved
--------------------------------------------------------------------------------
-- element create/update functions
-- layers ----------------------------------------------------------------------
--
-- ARTWORK
-- spell shield = 2
-- healthbar highlight = 1
-- spell icon = 1
-- spell icon background = 0

-- BACKGROUND
-- healthbar fill background = 2
-- healthbar background = 1
-- castbar background = 1
-- threat brackets = 0
-- frame/target glow = -5
--
--------------------------------------------------------------------------------
local folder,ns=...
local addon = KuiNameplates
local kui = LibStub('Kui-1.0')
local core = KuiNameplatesCore

local MEDIA = 'interface/addons/kui_nameplates/media/'
local CLASS_COLOURS = {
    DEATHKNIGHT = { .90, .22, .33 },
    DEMONHUNTER = { .74, .35, .95 },
    SHAMAN      = { .10, .54, .97 },
}

core.font = kui.m.f.francois
local FONT = core.font

-- TODO configuration
local sizes = {
    width = 132,
    height = 13,
    width_minus = 72,
    height_minus = 9,
    height_no_name = 9,
    glow = 8,
}
local target_glow_colour = { .3, .7, 1, 1 }
-- helper functions ############################################################
local CreateStatusBar
do
    local function FilledBar_SetStatusBarColor(self,...)
        self:orig_SetStatusBarColor(...)
        self.fill:SetVertexColor(...)
    end
    local function FilledBar_Show(self)
        self:orig_Show()
        self.fill:Show()
    end
    local function FilledBar_Hide(self)
        self:orig_Hide()
        self.fill:Hide()
    end
    function CreateStatusBar(parent)
        local bar = CreateFrame('StatusBar',nil,parent)
        bar:SetStatusBarTexture(kui.m.t.bar)
        bar:SetFrameLevel(0)

        local fill = parent:CreateTexture(nil,'BACKGROUND',nil,2)
        fill:SetTexture(kui.m.t.bar)
        fill:SetAllPoints(bar)
        fill:SetAlpha(.2)

        bar.fill = fill

        bar.orig_SetStatusBarColor = bar.SetStatusBarColor
        bar.SetStatusBarColor = FilledBar_SetStatusBarColor

        bar.orig_Show = bar.Show
        bar.Show = FilledBar_Show

        bar.orig_Hide = bar.Hide
        bar.Hide = FilledBar_Hide

        return bar
    end
end
local function CreateFontString(parent)
    local f = parent:CreateFontString(nil,'OVERLAY')
    f:SetFont(FONT,11,'THINOUTLINE')

    return f
end
local function GetClassColour(f)
    -- return adjusted class colour (used in nameonly)
    local class = select(2,UnitClass(f.unit))
    if CLASS_COLOURS[class] then
        return unpack(CLASS_COLOURS[class])
    else
        return kui.GetClassColour(class,2)
    end
end
-- create/update functions #####################################################
-- frame background ############################################################
local function UpdateFrameSize(f)
    -- set frame size and position
    if f.state.minus then
        f.bg:SetSize(sizes.width_minus,sizes.height_minus)
    else
        f.bg:SetSize(sizes.width,sizes.height)
    end

    if f.state.no_name and not f.state.player then
        f.bg:SetHeight(sizes.height_no_name)
    end

    -- calculate point to remain pixel-perfect
    f.x = floor((addon.width / 2) - (f.bg:GetWidth() / 2))
    f.y = floor((addon.height / 2) - (f.bg:GetHeight() / 2))

    f.bg:SetPoint('BOTTOMLEFT',f.x,f.y)

    f:UpdateMainBars()
    f:SpellIconSetWidth()
end
function core:CreateBackground(f)
    local bg = f:CreateTexture(nil,'BACKGROUND',nil,1)
    bg:SetTexture(kui.m.t.solid)
    bg:SetVertexColor(0,0,0,.8)

    f.bg = bg
    f.UpdateFrameSize = UpdateFrameSize
end
-- highlight ###################################################################
function core:CreateHighlight(f)
    local highlight = f.HealthBar:CreateTexture(nil,'ARTWORK',nil,1)
    highlight:SetTexture(kui.m.t.bar)
    highlight:SetAllPoints(f.HealthBar)
    highlight:SetVertexColor(1,1,1,.4)
    highlight:SetBlendMode('ADD')
    highlight:Hide()

    f.handler:RegisterElement('Highlight',highlight)
end
-- health bar ##################################################################
do
    local function UpdateMainBars(f)
        -- update health/power bar size
        local hb_height = f.bg:GetHeight()-2

        if f.PowerBar:IsShown() then
            hb_height = hb_height - 3
            f.PowerBar:SetHeight(2)
        end

        f.HealthBar:SetHeight(hb_height)
    end
    function core:CreateHealthBar(f)
        local healthbar = CreateStatusBar(f)

        healthbar:SetPoint('TOPLEFT',f.bg,1,-1)
        healthbar:SetPoint('RIGHT',f.bg,-1,0)

        f.handler:SetBarAnimation(healthbar,'cutaway')
        f.handler:RegisterElement('HealthBar',healthbar)

        f.UpdateMainBars = UpdateMainBars
    end
end
-- power bar ###################################################################
do
    local function UpdatePowerBar(f,on_show)
        if  f.state.player and
            f.state.power_type
            and UnitPowerMax(f.unit,f.state.power_type) > 0
        then
            if not f.elements.PowerBar then
                f.handler:EnableElement('PowerBar')

                f.PowerBar:SetMinMaxValues(0,UnitPowerMax(f.unit,f.state.power_type))
                f.PowerBar:SetValue(UnitPower(f.unit,f.state.power_type))
            end

            f.PowerBar:Show()
        else
            -- TODO need actual :Disable,:Enable functions and OnDisable/OnEnable
            -- for power bar colour stickiness to be fixed
            f.handler:DisableElement('PowerBar')
            f.PowerBar:Hide()
        end

        if not on_show then
            -- update health bar height
            f:UpdateMainBars()
        end
    end
    function core:CreatePowerBar(f)
        local powerbar = CreateStatusBar(f.HealthBar)
        powerbar:SetPoint('TOPLEFT',f.HealthBar,'BOTTOMLEFT',0,-1)
        powerbar:SetPoint('RIGHT',f.bg,-1,0)

        f.handler:SetBarAnimation(powerbar,'cutaway')
        f.handler:RegisterElement('PowerBar',powerbar)

        f.UpdatePowerBar = UpdatePowerBar
    end
end
-- name text ###################################################################
do
    local function UpdateNameText(f)
        if f.state.nameonly then
            if UnitIsPlayer(f.unit) then
                -- player class colour
                f.NameText:SetTextColor(GetClassColour(f))
            else
                if f.state.reaction >= 4 then
                    -- friendly colour
                    f.NameText:SetTextColor(.6,1,.6)
                    f.GuildText:SetTextColor(.8,.9,.8,.9)
                else
                    f.NameText:SetTextColor(1,.4,.3)
                    f.GuildText:SetTextColor(1,.8,.7,.9)
                end
            end

            -- set name text colour to health
            core:NameOnlyHealthUpdate(f)
        else
            if  not f.state.player and
                UnitIsPlayer(f.unit) and
                UnitIsFriend('player',f.unit)
            then
                -- friendly player class colour
                f.NameText:SetTextColor(GetClassColour(f))
            else
                -- white by default
                f.NameText:SetTextColor(1,1,1,1)
            end

            if f.state.no_name then
                f.NameText:Hide()
            else
                f.NameText:Show()
            end
        end
    end
    function core:CreateNameText(f)
        local nametext = CreateFontString(f)
        nametext:SetPoint('BOTTOM',f.HealthBar,'TOP',0,-3.5)

        f.handler:RegisterElement('NameText',nametext)

        f.UpdateNameText = UpdateNameText
    end
end
-- npc guild text ##############################################################
function core:CreateGuildText(f)
    local guildtext = f:CreateFontString(nil,'OVERLAY')
    guildtext:SetFont(FONT, 9, 'THINOUTLINE')
    guildtext:SetPoint('TOP',f.NameText,'BOTTOM', 0, -2)
    guildtext:SetShadowOffset(1,-1)
    guildtext:SetShadowColor(0,0,0,1)
    guildtext:Hide()

    f.GuildText = guildtext
end
-- frame glow ##################################################################
do
    -- frame glow texture coords
    local glow_coords = {
        { .05, .95,  0,  .24 }, -- top
        { .05, .95, .76,  1 },  -- bottom
        {  0,  .04,  0,   1 },  -- left
        { .96,  1,   0,   1 }   -- right
    }
    -- frame glow prototype
    local glow_prototype = {}
    glow_prototype.__index = glow_prototype
    function glow_prototype:SetVertexColor(...)
        for _,side in ipairs(self.sides) do
            side:SetVertexColor(...)
        end
    end
    function glow_prototype:Show(...)
        for _,side in ipairs(self.sides) do
            side:Show(...)
        end
    end
    function glow_prototype:Hide(...)
        for _,side in ipairs(self.sides) do
            side:Hide(...)
        end
    end
    function glow_prototype:SetSize(...)
        for i,side in ipairs(self.sides) do
            if i > 2 then
                side:SetWidth(...)
            else
                side:SetHeight(...)
            end
        end
    end
    -- update
    local function UpdateFrameGlow(f)
        if f.state.nameonly then
            f.ThreatGlow:Hide()
            f.TargetGlow:Hide()
            return
        end

        f.ThreatGlow:Show()

        if f.state.target then
            f.ThreatGlow:SetVertexColor(unpack(target_glow_colour))
            f.TargetGlow:Show()
        elseif not f.state.glowing then
            f.ThreatGlow:SetVertexColor(0,0,0,.6)
            f.TargetGlow:Hide()
        end
    end
    -- create
    function core:CreateFrameGlow(f)
        local glow = { sides = {} }
        setmetatable(glow,glow_prototype)

        for side,coords in ipairs(glow_coords) do
            side = f:CreateTexture(nil,'BACKGROUND',nil,-5)
            side:SetTexture(MEDIA..'frameglow')
            side:SetTexCoord(unpack(coords))

            tinsert(glow.sides,side)
        end

        glow:SetSize(sizes.glow)

        glow.sides[1]:SetPoint('BOTTOMLEFT', f.bg, 'TOPLEFT', 1, -1)
        glow.sides[1]:SetPoint('BOTTOMRIGHT', f.bg, 'TOPRIGHT', -1, -1)

        glow.sides[2]:SetPoint('TOPLEFT', f.bg, 'BOTTOMLEFT', 1, 1)
        glow.sides[2]:SetPoint('TOPRIGHT', f.bg, 'BOTTOMRIGHT', -1, 1)

        glow.sides[3]:SetPoint('TOPRIGHT', glow.sides[1], 'TOPLEFT')
        glow.sides[3]:SetPoint('BOTTOMRIGHT', glow.sides[2], 'BOTTOMLEFT')

        glow.sides[4]:SetPoint('TOPLEFT', glow.sides[1], 'TOPRIGHT')
        glow.sides[4]:SetPoint('BOTTOMLEFT', glow.sides[2], 'BOTTOMRIGHT')

        f.handler:RegisterElement('ThreatGlow',glow)

        f.UpdateFrameGlow = UpdateFrameGlow
    end
end
-- target glow #################################################################
-- updated by UpdateFrameGlow
function core:CreateTargetGlow(f)
    local targetglow = f:CreateTexture(nil,'BACKGROUND',nil,-5)
    targetglow:SetTexture('Interface\\AddOns\\Kui_Nameplates\\media\\target-glow')
    targetglow:SetTexCoord(0,.593,0,.875)
    targetglow:SetHeight(7)
    targetglow:SetPoint('TOPLEFT',f.bg,'BOTTOMLEFT',0,2)
    targetglow:SetPoint('TOPRIGHT',f.bg,'BOTTOMRIGHT')
    targetglow:SetVertexColor(unpack(target_glow_colour))
    targetglow:Hide()

    f.TargetGlow = targetglow
end
-- castbar #####################################################################
do
    local function SpellIconSetWidth(f)
        -- set spell icon width
        f.bg:GetHeight() -- calling this coaxes it into calculating the height
        f.SpellIcon.bg:SetWidth(floor(f.SpellIcon.bg:GetHeight()*1.5))
    end
    local function ShowCastBar(f)
        if f.state.nameonly then return end

        -- also show attached elements
        f.CastBar.bg:Show()
        f.SpellIcon.bg:Show()
        f.SpellName:Show()

        f:SpellIconSetWidth()
    end
    local function HideCastBar(f)
        -- also hide attached elements
        f.CastBar:Hide()
        f.CastBar.bg:Hide()
        f.SpellIcon.bg:Hide()
        f.SpellName:Hide()
        f.SpellShield:Hide()
    end
    function core:CreateCastBar(f)
        local bg = f:CreateTexture(nil,'BACKGROUND',nil,1)
        bg:SetTexture(kui.m.t.solid)
        bg:SetVertexColor(0,0,0,.8)
        bg:SetHeight(5)
        bg:SetPoint('TOPLEFT', f.bg, 'BOTTOMLEFT', 0, -1)
        bg:SetPoint('TOPRIGHT', f.bg, 'BOTTOMRIGHT')

        local castbar = CreateFrame('StatusBar', nil, f)
        castbar:SetFrameLevel(0)
        castbar:SetStatusBarTexture(kui.m.t.bar)
        castbar:SetStatusBarColor(.6, .6, .75)
        castbar:SetHeight(3)
        castbar:SetPoint('TOPLEFT', bg, 1, -1)
        castbar:SetPoint('BOTTOMRIGHT', bg, -1, 1)

        local spellname = f.HealthBar:CreateFontString(nil, 'OVERLAY')
        spellname:SetFont(FONT, 9, 'THINOUTLINE')
        spellname:SetPoint('TOP', castbar, 'BOTTOM', 0, -3.5)

        -- spell icon
        local spelliconbg = f:CreateTexture(nil, 'ARTWORK', nil, 0)
        spelliconbg:SetTexture(kui.m.t.solid)
        spelliconbg:SetVertexColor(0,0,0,.8)
        spelliconbg:SetPoint('BOTTOMRIGHT', bg, 'BOTTOMLEFT', -1, 0)
        spelliconbg:SetPoint('TOPRIGHT', f.bg, 'TOPLEFT', -1, 0)

        local spellicon = castbar:CreateTexture(nil, 'ARTWORK', nil, 1)
        spellicon:SetTexCoord(.1, .9, .25, .75)
        spellicon:SetPoint('TOPLEFT', spelliconbg, 1, -1)
        spellicon:SetPoint('BOTTOMRIGHT', spelliconbg, -1, 1)

        -- cast shield
        local spellshield = f.HealthBar:CreateTexture(nil, 'ARTWORK', nil, 2)
        spellshield:SetTexture('Interface\\AddOns\\Kui_Nameplates\\media\\Shield')
        spellshield:SetTexCoord(0, .84375, 0, 1)
        spellshield:SetSize(13.5, 16) -- 16 * .84375
        spellshield:SetPoint('LEFT', bg, -7, 0)
        spellshield:SetVertexColor(.5, .5, .7)

        -- spark
        local spark = castbar:CreateTexture(nil, 'ARTWORK')
        spark:SetDrawLayer('ARTWORK', 7)
        spark:SetVertexColor(1,1,.8)
        spark:SetTexture('Interface\\AddOns\\Kui_Media\\t\\spark')
        spark:SetPoint('CENTER', castbar:GetRegions(), 'RIGHT', 1, 0)
        spark:SetSize(6,9)

        -- hide elements by default
        bg:Hide()
        castbar:Hide()
        spelliconbg:Hide()
        spellshield:Hide()
        spellname:Hide()

        castbar.bg = bg
        spellicon.bg = spelliconbg

        f.handler:RegisterElement('CastBar', castbar)
        f.handler:RegisterElement('SpellName', spellname)
        f.handler:RegisterElement('SpellIcon', spellicon)
        f.handler:RegisterElement('SpellShield', spellshield)

        f.ShowCastBar = ShowCastBar
        f.HideCastBar = HideCastBar
        f.SpellIconSetWidth = SpellIconSetWidth
    end
end
-- state icons #################################################################
do
    local BOSS = {0,.5,0,.5}
    local RARE = {.5,1,.5,1}

    local function UpdateStateIcon(f)
        if f.state.nameonly then
            f.StateIcon:Hide()
            return
        end

        if f.state.classification == 'worldboss' then
            f.StateIcon:SetTexCoord(unpack(BOSS))
            f.StateIcon:SetVertexColor(1,1,1)
            f.StateIcon:Show()
        elseif f.state.classification == 'rare' or f.state.classification == 'rareelite' then
            f.StateIcon:SetTexCoord(unpack(RARE))
            f.StateIcon:SetVertexColor(1,.8,.2)
            f.StateIcon:Show()
        else
            f.StateIcon:Hide()
        end
    end
    function core:CreateStateIcon(f)
        local stateicon = f:CreateTexture(nil,'ARTWORK',nil,2)
        stateicon:SetTexture(MEDIA..'state-icons')
        stateicon:SetSize(20,20)
        stateicon:SetPoint('LEFT',f.HealthBar,'BOTTOMLEFT',0,1)

        f.StateIcon = stateicon
        f.UpdateStateIcon = UpdateStateIcon
    end
end
-- auras #######################################################################
function core.Auras_PostCreateAuraButton(button)
    -- move text slightly for our font
    button.cd:ClearAllPoints()
    button.cd:SetPoint('CENTER',1,-1)
    button.cd:SetShadowOffset(1,-1)
    button.cd:SetShadowColor(0,0,0,1)

    button.count:ClearAllPoints()
    button.count:SetPoint('BOTTOMRIGHT',3,-3)
    button.count:SetShadowOffset(1,-1)
    button.count:SetShadowColor(0,0,0,1)
end
function core:CreateAuras(f)
    local auras = f.handler:CreateAuraFrame({
        kui_whitelist = true,
        max = 10,
        point = {'BOTTOMLEFT','LEFT','RIGHT'},
        x_spacing = 1,
        y_spacing = 1,
        rows = 2
    })
    auras:SetWidth(124)
    auras:SetHeight(10)
    auras:SetPoint('BOTTOMLEFT',f.HealthBar,'TOPLEFT',4,15)
end
-- threat brackets #############################################################
do
    local TB_TEXTURE = 'interface/addons/kui_nameplates/media/threat-bracket'
    local TB_PIXEL_LEFTMOST = .28125
    local TB_RATIO = 2
    local TB_HEIGHT = 18
    local TB_WIDTH = TB_HEIGHT * TB_RATIO
    local TB_X_OFFSET = floor((TB_WIDTH * TB_PIXEL_LEFTMOST)-1)
    local TB_POINTS = {
        { 'BOTTOMLEFT', 'TOPLEFT',    -TB_X_OFFSET,  1.3 },
        { 'BOTTOMRIGHT','TOPRIGHT',    TB_X_OFFSET,  1.3 },
        { 'TOPLEFT',    'BOTTOMLEFT', -TB_X_OFFSET, -1.5 },
        { 'TOPRIGHT',   'BOTTOMRIGHT', TB_X_OFFSET, -1.5 }
    }
    -- threat bracket prototype
    local tb_prototype = {}
    tb_prototype.__index = tb_prototype
    function tb_prototype:SetVertexColor(...)
        for k,v in ipairs(self.textures) do
            v:SetVertexColor(...)
        end
    end
    function tb_prototype:Show(...)
        for k,v in ipairs(self.textures) do
            v:Show(...)
        end
    end
    function tb_prototype:Hide(...)
        for k,v in ipairs(self.textures) do
            v:Hide(...)
        end
    end
    -- update
    local function UpdateThreatBrackets(f)
        if f.state.nameonly then
            f.ThreatBrackets:Hide()
            return
        end

        if f.state.glowing then
            f.ThreatBrackets:SetVertexColor(unpack(f.state.glowColour))
            f.ThreatBrackets:Show()
        else
            f.ThreatBrackets:Hide()
        end
    end
    -- create
    function core:CreateThreatBrackets(f)
        local tb = { textures = {} }
        setmetatable(tb,tb_prototype)

        for i,p in ipairs(TB_POINTS) do
            local b = f:CreateTexture(nil,'BACKGROUND',nil,0)
            b:SetTexture(TB_TEXTURE)
            b:SetSize(TB_WIDTH, TB_HEIGHT)
            b:SetPoint(p[1], f.bg, p[2], p[3], p[4])
            b:Hide()

            if i == 2 then
                b:SetTexCoord(1,0,0,1)
            elseif i == 3 then
                b:SetTexCoord(0,1,1,0)
            elseif i == 4 then
                b:SetTexCoord(1,0,1,0)
            end

            tinsert(tb.textures,b)
        end

        f.ThreatBrackets = tb
        f.UpdateThreatBrackets = UpdateThreatBrackets
    end
end
-- name show/hide ##############################################################
function core:ShowNameUpdate(f)
    if f.state.nameonly then return end

    if  not core.profile.hide_names or
        f.state.target or
        f.state.threat or
        UnitShouldDisplayName(f.unit)
    then
        f.state.no_name = nil
    else
        f.state.no_name = true
    end
end
-- nameonly ####################################################################
do
    local function NameOnlyEnable(f)
        if f.state.nameonly then return end
        f.state.nameonly = true

        f.bg:Hide()
        f.HealthBar:Hide()
        f.HealthBar.fill:Hide()
        f.ThreatGlow:Hide()
        f.ThreatBrackets:Hide()

        f.NameText:SetShadowOffset(1,-1)
        f.NameText:SetShadowColor(0,0,0,1)

        f.NameText:ClearAllPoints()
        f.NameText:SetParent(f)

        if f.state.guild_text then
            f.GuildText:SetText(f.state.guild_text)
            f.GuildText:Show()
            f.NameText:SetPoint('CENTER',.5,6)
        else
            f.NameText:SetPoint('CENTER',.5,0)
        end

        f.NameText:Show()

        f:HideCastBar()

        f.handler:DisableElement('CastBar')
    end
    local function NameOnlyDisable(f)
        if not f.state.nameonly then return end
        f.state.nameonly = nil

        f.NameText:SetText(f.state.name)
        f.NameText:SetTextColor(1,1,1,1)
        f.NameText:SetShadowColor(0,0,0,0)

        f.NameText:ClearAllPoints()
        f.NameText:SetParent(f.HealthBar)
        f.NameText:SetPoint('BOTTOM', f.HealthBar, 'TOP', 0, -3.5)

        f.GuildText:Hide()

        f.bg:Show()
        f.HealthBar:Show()
        f.HealthBar.fill:Show()

        f.handler:EnableElement('CastBar')

        if f.state.casting then
            f.handler:CastBarShow()
        end
    end
    function core:NameOnlyHealthUpdate(f)
        -- set name text colour to approximate health
        if not f.state.nameonly then return end

        local cur,max = UnitHealth(f.unit),UnitHealthMax(f.unit)
        if cur and max then
            local health_len = strlen(f.state.name) * (cur / max)
            f.NameText:SetText(
                kui.utf8sub(f.state.name, 0, health_len)..
                '|cff666666'..kui.utf8sub(f.state.name, health_len+1)
            )
        end
    end
    function core:NameOnlyUpdate(f,hide)
        if  not hide and self.profile.nameonly and
            -- don't show on player frame
            not f.state.player and
            -- don't show on target
            not f.state.target and
            -- don't show on attackable units
            not UnitCanAttack('player',f.unit) and
            -- don't show on unattackable enemy players (ice block etc)
            not (UnitIsPlayer(f.unit) and UnitIsEnemy('player',f.unit))
        then
            NameOnlyEnable(f)
        else
            NameOnlyDisable(f)
        end
    end
end
