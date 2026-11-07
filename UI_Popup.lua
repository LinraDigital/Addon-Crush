-- LD - Crush : popup « C'est un Crush ! »
local _, ns = ...
local L = ns.L
local W = ns.W
local C = W.C

local popup

function ns.CreerPopupMatch()
    popup = CreateFrame("Frame", "LDCrushPopup", UIParent, "BackdropTemplate")
    popup:SetSize(320, 330)
    popup:SetPoint("CENTER", 0, 80)
    popup:SetFrameStrata("DIALOG")
    W.Fenetre(popup)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()
    tinsert(UISpecialFrames, "LDCrushPopup")

    local sur = W.Etiquette(popup, L["Nouveau match"])
    sur:SetPoint("TOP", 0, -20)
    local titre = W.Titre(popup, 26)
    titre:SetPoint("TOP", 0, -36)
    titre:SetText(L["C'est un Crush !"])

    local coeur = popup:CreateTexture(nil, "OVERLAY")
    coeur:SetTexture(ns.MEDIA .. "LDCrush_Like")
    coeur:SetSize(60, 60)
    coeur:SetPoint("TOP", 0, -88)

    local function Portrait(decalage)
        local cadre = W.Cadre(popup, 64, 64)
        cadre:SetPoint("TOP", decalage, -86)
        local ic = W.IconeClasse(cadre, 54)
        ic:SetPoint("CENTER")
        local nom = W.Texte(popup, 12)
        nom:SetPoint("TOP", cadre, "BOTTOM", 0, -6)
        nom:SetJustifyH("CENTER")
        return cadre, ic, nom
    end
    local cadreMoi, icMoi, nomMoi = Portrait(-82)
    local cadreAutre, icAutre, nomAutre = Portrait(82)
    coeur:SetDrawLayer("OVERLAY", 7)
    cadreMoi:SetFrameLevel(popup:GetFrameLevel() + 1)
    cadreAutre:SetFrameLevel(popup:GetFrameLevel() + 1)

    local texte = W.Texte(popup, 12, { 0.84, 0.82, 0.79 })
    texte:SetPoint("TOP", 0, -186)
    texte:SetWidth(272)
    texte:SetJustifyH("CENTER")

    local chuchoter = W.Bouton(popup, L["Chuchoter"], 272, 30, "primaire")
    chuchoter:SetPoint("BOTTOM", 0, 56)
    local inviter = W.Bouton(popup, L["Inviter en groupe"], 133, 28)
    inviter:SetPoint("BOTTOMLEFT", 24, 20)
    local plusTard = W.Bouton(popup, L["Plus tard"], 133, 28)
    plusTard:SetPoint("BOTTOMRIGHT", -24, 20)

    chuchoter:SetScript("OnClick", function() ns.Chuchoter(popup.nom) popup:Hide() end)
    inviter:SetScript("OnClick", function() ns.Inviter(popup.nom) end)
    plusTard:SetScript("OnClick", function() popup:Hide() end)

    function popup:Remplir(nom)
        self.nom = nom
        local pr = ns.char.profils[nom] or {}
        local c = ns.char.croises[nom] or { n = 0 }
        local _, maClasse = UnitClass("player")
        icMoi:SetClasse(maClasse)
        nomMoi:SetText(L["Toi"])
        nomMoi:SetTextColor(ns.CouleurClasse(maClasse))
        icAutre:SetClasse(pr.classe)
        nomAutre:SetText(Ambiguate(nom, "short"))
        nomAutre:SetTextColor(ns.CouleurClasse(pr.classe))
        local phrase = L["Vous vous êtes croisés |cffffffff%d fois|r"]:format(c.n)
        if c.zone and c.zone ~= "" then phrase = phrase .. L[", la dernière à %s"]:format(c.zone) end
        phrase = phrase .. ".\n"
        if pr.surnom then phrase = phrase .. L["Son surnom : %s."]:format(pr.surnom) .. " " end
        phrase = phrase .. L["Son vrai nom est maintenant visible."]
        texte:SetText(phrase)
    end
end

function ns.AfficherPopupMatch(nom)
    if not popup then return end
    popup:Remplir(nom)
    popup:Show()
end
