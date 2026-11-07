-- LD - Crush : composants d'interface (style verre sombre)
local _, ns = ...

local W = {}
ns.W = W

local BLANC = "Interface\\Buttons\\WHITE8X8"
W.POLICE_TITRE = "Fonts\\MORPHEUS.TTF"
W.POLICE = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

W.C = {
    fond    = { 0.07, 0.08, 0.10, 0.93 },
    carte   = { 1, 1, 1, 0.05 },
    bord    = { 1, 1, 1, 0.12 },
    bordFort= { 1, 1, 1, 0.28 },
    texte   = { 0.93, 0.92, 0.89 },
    gris    = { 0.66, 0.65, 0.61 },
    accent  = { 0.91, 0.71, 0.29 },
    sombre  = { 0.08, 0.07, 0.05 },
    vert    = { 0.44, 0.81, 0.50 },
    alerte  = { 0.88, 0.48, 0.37 },
}
local C = W.C

function W.Verre(f, fond, bord)
    f:SetBackdrop({ bgFile = BLANC, edgeFile = BLANC, edgeSize = 1 })
    fond, bord = fond or C.fond, bord or C.bord
    f:SetBackdropColor(fond[1], fond[2], fond[3], fond[4] or 1)
    f:SetBackdropBorderColor(bord[1], bord[2], bord[3], bord[4] or 1)
end

function W.Cadre(parent, l, h, fond, bord)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if l then f:SetSize(l, h) end
    W.Verre(f, fond or C.carte, bord)
    return f
end

function W.Texte(parent, taille, couleur, police, contour)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(police or W.POLICE, taille or 12, contour or "")
    local c = couleur or C.texte
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

function W.Titre(parent, taille, couleur)
    return W.Texte(parent, taille or 16, couleur or C.accent, W.POLICE_TITRE)
end

function W.Etiquette(parent, texte)
    local fs = W.Texte(parent, 10, C.gris)
    fs:SetText(string.upper(texte))
    return fs
end

-- Bouton texte : style "primaire" (fond accent) ou "secondaire" (verre)
function W.Bouton(parent, texte, l, h, style)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(l or 100, h or 26)
    local fs = W.Texte(b, 12)
    fs:SetPoint("CENTER")
    fs:SetJustifyH("CENTER")
    fs:SetWordWrap(false)
    b.label = fs
    b:SetFontString(fs)
    b:SetText(texte)

    function b:SetStyle(s)
        self.style = s
        if s == "primaire" then
            W.Verre(self, C.accent, C.accent)
            self.label:SetTextColor(C.sombre[1], C.sombre[2], C.sombre[3])
        else
            W.Verre(self, { 1, 1, 1, 0.06 }, C.bord)
            self.label:SetTextColor(C.texte[1], C.texte[2], C.texte[3])
        end
    end
    b:SetStyle(style or "secondaire")

    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then self:SetBackdropBorderColor(1, 1, 1, 0.45) end
    end)
    b:SetScript("OnLeave", function(self) self:SetStyle(self.style) end)
    b:SetScript("OnDisable", function(self) self:SetAlpha(0.45) end)
    b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    return b
end

-- Bouton image (cœur, croix)
function W.BoutonIcone(parent, texture, taille)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(taille, taille)
    b:SetNormalTexture(texture)
    b:SetHighlightTexture(texture, "ADD")
    b:GetHighlightTexture():SetAlpha(0.35)
    b:SetPushedTexture(texture)
    b:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8)
    return b
end

-- Groupe de boutons à sélectionner (simple ou multiple), disposés en grille
function W.GroupeChoix(parent, options, colonnes, largeur, multiple, auChangement)
    local g = CreateFrame("Frame", nil, parent)
    local ecart, hauteurBouton = 6, 26
    local lBouton = (largeur - (colonnes - 1) * ecart) / colonnes
    local lignes = math.ceil(#options / colonnes)
    g:SetSize(largeur, lignes * hauteurBouton + (lignes - 1) * ecart)
    g.boutons, g.valeur = {}, multiple and {} or nil

    local function Rafraichir()
        for _, b in ipairs(g.boutons) do
            local actif
            if multiple then actif = g.valeur[b.cle] else actif = (g.valeur == b.cle) end
            b:SetStyle(actif and "primaire" or "secondaire")
        end
    end

    for i, opt in ipairs(options) do
        local b = W.Bouton(g, opt.label, lBouton, hauteurBouton)
        local col, lig = (i - 1) % colonnes, math.floor((i - 1) / colonnes)
        b:SetPoint("TOPLEFT", col * (lBouton + ecart), -lig * (hauteurBouton + ecart))
        b.cle = opt.key
        b:SetScript("OnClick", function()
            if multiple then
                g.valeur[opt.key] = not g.valeur[opt.key] or nil
            else
                g.valeur = opt.key
            end
            Rafraichir()
            if auChangement then auChangement(g.valeur) end
        end)
        g.boutons[i] = b
    end

    function g:Get()
        if multiple then
            local copie = {}
            for k, v in pairs(self.valeur) do if v then copie[k] = true end end
            return copie
        end
        return self.valeur
    end
    function g:Set(v)
        if multiple then
            self.valeur = {}
            for k, val in pairs(v or {}) do if val then self.valeur[k] = true end end
        else
            self.valeur = v
        end
        Rafraichir()
    end
    return g
end

function W.Saisie(parent, l, h, multiligne)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(l, h or 26)
    W.Verre(e, { 1, 1, 1, 0.05 }, C.bordFort)
    e:SetFont(W.POLICE, 12, "")
    e:SetTextColor(1, 1, 1)
    e:SetAutoFocus(false)
    e:SetTextInsets(8, 8, multiligne and 6 or 0, multiligne and 6 or 0)
    if multiligne then
        e:SetMultiLine(true)
    else
        e:SetScript("OnEnterPressed", e.ClearFocus)
    end
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.8) end)
    e:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(C.bordFort[1], C.bordFort[2], C.bordFort[3], C.bordFort[4]) end)
    return e
end

-- Interrupteur on/off
function W.Interrupteur(parent, auChangement)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(36, 20)
    local pastille = b:CreateTexture(nil, "OVERLAY")
    pastille:SetTexture(BLANC)
    pastille:SetSize(14, 14)
    b.pastille = pastille
    function b:Set(v)
        self.valeur = v and true or false
        pastille:ClearAllPoints()
        if self.valeur then
            W.Verre(self, C.accent, C.accent)
            pastille:SetVertexColor(C.sombre[1], C.sombre[2], C.sombre[3])
            pastille:SetPoint("RIGHT", -3, 0)
        else
            W.Verre(self, { 1, 1, 1, 0.08 }, C.bordFort)
            pastille:SetVertexColor(0.7, 0.7, 0.7)
            pastille:SetPoint("LEFT", 3, 0)
        end
    end
    b:SetScript("OnClick", function(self)
        self:Set(not self.valeur)
        if auChangement then auChangement(self.valeur) end
    end)
    b:Set(false)
    return b
end

-- Icône de classe (atlas des icônes de création de personnage)
function W.IconeClasse(parent, taille)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(taille, taille)
    t:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    function t:SetClasse(classe)
        local c = classe and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classe]
        if c then
            self:SetTexCoord(c[1], c[2], c[3], c[4])
            self:Show()
        else
            self:Hide()
        end
    end
    return t
end

-- Fine ligne de séparation
function W.Separateur(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(BLANC)
    t:SetVertexColor(1, 1, 1, 0.08)
    t:SetHeight(1)
    return t
end
