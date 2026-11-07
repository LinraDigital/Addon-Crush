-- LD - Crush : fenêtre principale, en-tête, onglets et navigation
local _, ns = ...
local L = ns.L
local W = ns.W
local C = W.C

local LARGEUR, HAUTEUR = 380, 620
ns.LARGEUR_CONTENU = LARGEUR - 28

ns.pages = {}         -- [nom] = frame, avec :Rafraichir()
local fenetre, onglets, boutonRetour, boutonsEntete, iconeEntete, titreEntete
local pageCourante = "decouvrir"
local ONGLETS = { "decouvrir", "croises", "matchs" }
local PAGES_SANS_ONGLETS = { accueil = true, mineur = true, profil = true, filtres = true }

local function LibelleOnglet(nom)
    if nom == "decouvrir" then return L["Découvrir"] end
    if nom == "croises" then return (L["Croisés · %d"]):format(#ns.ListeCroises()) end
    local n = #ns.ListeMatchs()
    return (L["Matchs · %d"]):format(n)
end

local function MajOnglets()
    for i, nom in ipairs(ONGLETS) do
        local b = onglets[i]
        b:SetText(LibelleOnglet(nom))
        b:SetStyle(pageCourante == nom and "primaire" or "secondaire")
    end
end

-- Choisit la bonne page selon l'état du profil
local function PageEffective(nom)
    local p = ns.compte.profil
    if p.mineur then return "mineur" end
    if not p.fait then return "accueil" end
    return nom
end

function ns.AfficherPage(nom)
    nom = PageEffective(nom)
    pageCourante = nom
    for n, page in pairs(ns.pages) do
        if n == nom then page:Show() else page:Hide() end
    end
    local sansOnglets = PAGES_SANS_ONGLETS[nom]
    for _, b in ipairs(onglets) do b:SetShown(not sansOnglets) end
    local retour = nom == "profil" or nom == "filtres"
    boutonRetour:SetShown(retour)
    titreEntete:SetText((nom == "profil" and L["Mon profil"]) or (nom == "filtres" and L["Filtres"]) or "Crush")
    iconeEntete:ClearAllPoints()
    iconeEntete:SetPoint("TOPLEFT", 12, -10)
    iconeEntete:SetShown(not retour)
    titreEntete:ClearAllPoints()
    if retour then
        titreEntete:SetPoint("LEFT", boutonRetour, "RIGHT", 8, 0)
    else
        titreEntete:SetPoint("LEFT", iconeEntete, "RIGHT", 6, 0)
    end
    fenetre:SetHeight(ns.pages[nom] and ns.pages[nom].hauteurFenetre or HAUTEUR)
    for _, b in ipairs(boutonsEntete) do b:SetShown(not sansOnglets) end

    if nom == "matchs" then
        ns.char.nouveauxMatchs = 0
        if ns.MajMinimap then ns.MajMinimap() end
    end
    ns.RafraichirUI()
end

function ns.RafraichirUI()
    if not fenetre or not fenetre:IsShown() then
        if ns.MajMinimap then ns.MajMinimap() end
        return
    end
    if not PAGES_SANS_ONGLETS[pageCourante] then MajOnglets() end
    local page = ns.pages[pageCourante]
    if page and page.Rafraichir then page:Rafraichir() end
    if ns.MajMinimap then ns.MajMinimap() end
end

function ns.Ouvrir(page)
    if not fenetre then return end
    fenetre:Show()
    ns.AfficherPage(page or "decouvrir")
end

function ns.Basculer()
    if not fenetre then return end
    if fenetre:IsShown() then
        fenetre:Hide()
    else
        ns.Ouvrir(pageCourante)
    end
end

-- Crée une page vide dans la zone de contenu
function ns.NouvellePage(nom, sansOnglets, hauteurFenetre)
    local p = CreateFrame("Frame", nil, fenetre)
    p:SetPoint("TOPLEFT", 14, sansOnglets and -58 or -82)
    p:SetPoint("BOTTOMRIGHT", -14, 12)
    p:Hide()
    p.hauteurFenetre = hauteurFenetre
    ns.pages[nom] = p
    return p
end

function ns.InitUI()
    fenetre = CreateFrame("Frame", "LDCrushFenetre", UIParent, "BackdropTemplate")
    fenetre:SetSize(LARGEUR, HAUTEUR)
    fenetre:SetPoint("CENTER", 0, 30)
    fenetre:SetFrameStrata("HIGH")
    fenetre:SetClampedToScreen(true)
    W.Fenetre(fenetre)
    fenetre:EnableMouse(true)
    fenetre:SetMovable(true)
    fenetre:RegisterForDrag("LeftButton")
    fenetre:SetScript("OnDragStart", fenetre.StartMoving)
    fenetre:SetScript("OnDragStop", fenetre.StopMovingOrSizing)
    fenetre:Hide()
    tinsert(UISpecialFrames, "LDCrushFenetre") -- Échap ferme la fenêtre
    ns.fenetre = fenetre

    -- En-tête
    boutonRetour = W.BoutonIcone(fenetre, ns.MEDIA .. "LDCrush_Retour", 20)
    boutonRetour:SetPoint("TOPLEFT", 12, -12)
    boutonRetour:SetScript("OnClick", function() ns.AfficherPage("decouvrir") end)

    local icone = fenetre:CreateTexture(nil, "ARTWORK")
    iconeEntete = icone
    icone:SetTexture(ns.MEDIA .. "LDCrush_Minimap")
    icone:SetSize(24, 24)
    icone:SetPoint("TOPLEFT", 12, -10)

    local titre = W.Titre(fenetre, 17)
    titreEntete = titre
    titre:SetPoint("LEFT", icone, "RIGHT", 6, 0)
    titre:SetText("Crush")

    local fermer = W.Fermer(fenetre)
    fermer:SetSize(26, 26)
    fermer:SetPoint("TOPRIGHT", -6, -6)
    fermer:SetFrameLevel(fenetre:GetFrameLevel() + 40)
    fermer:SetScript("OnClick", function() fenetre:Hide() end)

    local boutonFiltres = W.Bouton(fenetre, L["Filtres"], 56, 22)
    boutonFiltres:SetPoint("RIGHT", fermer, "LEFT", -2, 0)
    boutonFiltres:SetScript("OnClick", function() ns.AfficherPage("filtres") end)

    local boutonProfil = W.Bouton(fenetre, L["Profil"], 56, 22)
    boutonProfil:SetPoint("RIGHT", boutonFiltres, "LEFT", -6, 0)
    boutonProfil:SetScript("OnClick", function() ns.AfficherPage("profil") end)
    boutonsEntete = { boutonFiltres, boutonProfil }

    local sep = W.Separateur(fenetre)
    sep:SetPoint("TOPLEFT", 1, -42)
    sep:SetPoint("TOPRIGHT", -1, -42)

    -- Onglets
    onglets = {}
    local lOnglet = (LARGEUR - 28 - 8) / 3
    for i, nom in ipairs(ONGLETS) do
        local b = W.Bouton(fenetre, LibelleOnglet(nom), lOnglet, 26)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * (lOnglet + 4), -50)
        b:SetScript("OnClick", function() ns.AfficherPage(nom) end)
        onglets[i] = b
    end

    if ns.CreerPages then ns.CreerPages() end
    if ns.CreerPopupMatch then ns.CreerPopupMatch() end

    -- Rafraîchit l'affichage des durées (« il y a X min ») toutes les 30 s
    C_Timer.NewTicker(30, function() ns.RafraichirUI() end)
end
