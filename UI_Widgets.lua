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

-- Bordure d'origine de WoW (infobulle) : pour les cartes et zones de saisie
function W.VerreNatif(f, fond, bord)
    f:SetBackdrop({
        bgFile = BLANC,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    fond = fond or C.carte
    bord = bord or { 0.8, 0.8, 0.8, 1 }
    f:SetBackdropColor(fond[1], fond[2], fond[3], fond[4] or 1)
    f:SetBackdropBorderColor(bord[1], bord[2], bord[3], bord[4] or 1)
end

function W.Cadre(parent, l, h, fond, bord)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if l then f:SetSize(l, h) end
    -- fond sombre opaque par défaut (comme les panneaux de LD - Poker)
    W.VerreNatif(f, fond or { 0.03, 0.04, 0.07, 0.9 }, bord)
    return f
end

-- Fenêtre : fond sombre et bordure des boîtes de dialogue de WoW, tracée à l'extérieur
-- du cadre pour ne pas décaler le contenu (même principe que LD - Poker)
function W.Fenetre(f)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.04, 0.07, 0.95)
    local ok, bf = pcall(CreateFrame, "Frame", nil, f, "BackdropTemplate")
    if not ok or not bf or not bf.SetBackdrop then return end
    bf:SetPoint("TOPLEFT", f, "TOPLEFT", -10, 10)
    bf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 10, -10)
    bf:SetFrameLevel(f:GetFrameLevel() + 30)
    bf:EnableMouse(false)
    bf:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })
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
-- Bouton rouge standard de WoW (UIPanelButtonTemplate).
-- "primaire" = bouton mis en avant / onglet actif (surbrillance fixe, texte blanc)
function W.Bouton(parent, texte, l, h, style)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(l or 100, h or 26)
    b:SetText(texte)
    local fs = b:GetFontString()
    fs:SetFont(W.POLICE, 12, "")
    fs:SetWordWrap(false)
    fs:SetWidth((l or 100) - 12)
    b.label = fs

    function b:SetStyle(s)
        self.style = s
        if s == "primaire" then
            self:LockHighlight()
            fs:SetTextColor(1, 1, 1)
        else
            self:UnlockHighlight()
            fs:SetTextColor(1, 0.82, 0)
        end
    end
    b:SetStyle(style or "secondaire")
    return b
end

-- Croix de fermeture standard de WoW
function W.Fermer(parent)
    return CreateFrame("Button", nil, parent, "UIPanelCloseButton")
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
    local e
    if multiligne then
        e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
        e:SetSize(l, h or 26)
        W.VerreNatif(e, { 0.03, 0.04, 0.07, 0.9 })
        e:SetTextInsets(8, 8, 6, 6)
        e:SetMultiLine(true)
    else
        -- Champ de saisie standard de WoW
        e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        e:SetSize(l - 10, 22)
        e:SetTextInsets(2, 2, 0, 0)
        e:SetScript("OnEnterPressed", e.ClearFocus)
    end
    e:SetFont(W.POLICE, 12, "")
    e:SetTextColor(1, 1, 1)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    return e
end

-- Interrupteur on/off
function W.Interrupteur(parent, auChangement)
    -- Case à cocher standard de WoW
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(28, 28)
    function b:Set(v)
        self.valeur = v and true or false
        self:SetChecked(self.valeur)
    end
    b:SetScript("OnClick", function(self)
        self:Set(self:GetChecked())
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
