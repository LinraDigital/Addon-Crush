-- LD - Crush : pastille sur la minimap (déplaçable autour de la carte, badge de nouveaux matchs)
local _, ns = ...
local L = ns.L
local W = ns.W

local bouton, badge

local function Positionner()
    local angle = math.rad(ns.char.minimap.angle or 215)
    local rayon = (Minimap:GetWidth() / 2) + 10
    bouton:ClearAllPoints()
    bouton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * rayon, math.sin(angle) * rayon)
end

local function SuivreCurseur()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local echelle = Minimap:GetEffectiveScale()
    cx, cy = cx / echelle, cy / echelle
    ns.char.minimap.angle = math.deg((math.atan2 or math.atan)(cy - my, cx - mx))
    Positionner()
end

function ns.MajMinimap()
    if not badge then return end
    local n = ns.char.nouveauxMatchs or 0
    if n > 0 then
        badge.texte:SetText(n > 9 and "9+" or tostring(n))
        badge:Show()
    else
        badge:Hide()
    end
end

function ns.InitMinimap()
    bouton = CreateFrame("Button", "LibDBIcon10_LDCrush", Minimap)   -- nom LibDBIcon10_* : LD_UIModern range ces boutons dans sa colonne
    bouton:SetSize(31, 31)
    bouton:SetFrameStrata("MEDIUM")
    bouton:SetFrameLevel(8)
    bouton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bouton:RegisterForDrag("LeftButton")
    bouton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local fond = bouton:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    fond:SetSize(22, 22)
    fond:SetPoint("CENTER")

    local icone = bouton:CreateTexture(nil, "ARTWORK")
    icone:SetTexture(ns.MEDIA .. "LDCrush_Minimap")
    icone:SetSize(22, 22)
    icone:SetPoint("CENTER")

    local bordure = bouton:CreateTexture(nil, "OVERLAY")
    bordure:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    bordure:SetSize(53, 53)
    bordure:SetPoint("TOPLEFT")
    bouton.icon, bouton.background, bouton.border = icone, fond, bordure   -- convention LibDBIcon

    badge = CreateFrame("Frame", nil, bouton, "BackdropTemplate")
    badge:SetSize(16, 16)
    badge:SetPoint("TOPRIGHT", 4, 2)
    badge:SetFrameLevel(bouton:GetFrameLevel() + 2)
    W.Verre(badge, { 0.84, 0.27, 0.27, 1 }, { 0.1, 0.09, 0.07, 1 })
    badge.texte = W.Texte(badge, 9, { 1, 1, 1 }, nil, "OUTLINE")
    badge.texte:SetPoint("CENTER", 0, 0)
    badge:Hide()

    bouton:SetScript("OnClick", function(_, clic)
        if clic == "RightButton" then
            ns.Ouvrir("profil")
        else
            ns.Basculer()
        end
    end)
    bouton:SetScript("OnDragStart", function(self)
        if _G.LDUIM_MinimapFrame then return end   -- rangé dans la colonne de LD_UIModern
        self:SetScript("OnUpdate", SuivreCurseur)
    end)
    bouton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    bouton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("LD - Crush", 0.91, 0.71, 0.29)
        if ns.EstActif() then
            local n = ns.char.nouveauxMatchs or 0
            if n > 0 then
                GameTooltip:AddLine(n > 1 and L["%d nouveaux matchs"]:format(n) or L["1 nouveau match"], 0.44, 0.81, 0.5)
            end
            GameTooltip:AddLine((L["%d à découvrir · %d en ligne"]):format(#ns.ListeADecouvrir(), ns.NbEnLigne()), 0.84, 0.82, 0.79)
        end
        GameTooltip:AddLine(L["Clic gauche : ouvrir"], 1, 1, 1)
        GameTooltip:AddLine(L["Clic droit : profil"], 1, 1, 1)
        GameTooltip:AddLine(L["Glisser : déplacer"], 0.66, 0.65, 0.61)
        GameTooltip:Show()
    end)
    bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Positionner()
    ns.MajMinimap()
end
