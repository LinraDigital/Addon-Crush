-- LD - Crush : écrans (accueil, découvrir, croisés, matchs, profil, filtres)
local _, ns = ...
local L = ns.L
local W = ns.W
local C = W.C

local LG -- largeur du contenu

local CHOIX_SEXE = { { key = "F", label = L["Une femme"] }, { key = "H", label = L["Un homme"] } }
local CHOIX_CHERCHE = { { key = "F", label = L["Femmes"] }, { key = "H", label = L["Hommes"] }, { key = "FH", label = L["Les deux"] } }

local function ChercheVersCle(ens)
    if ens.F and ens.H then return "FH" end
    if ens.F then return "F" end
    if ens.H then return "H" end
end
local function CleVersCherche(cle)
    if cle == "FH" then return { F = true, H = true } end
    if cle then return { [cle] = true } end
    return {}
end

-- Petit badge texte sur fond coloré
local function Badge(parent, fond, couleurTexte)
    local f = W.Cadre(parent, 10, 18, fond, fond)
    local fs = W.Texte(f, 10, couleurTexte)
    fs:SetPoint("CENTER")
    fs:SetWordWrap(false)
    f.texte = fs
    function f:Set(txt, nFond, nTexte)
        if nFond then W.Verre(self, nFond, nFond) end
        if nTexte then fs:SetTextColor(nTexte[1], nTexte[2], nTexte[3]) end
        fs:SetText(txt)
        self:SetWidth(fs:GetStringWidth() + 14)
    end
    return f
end

local function Erreur(parent)
    local fs = W.Texte(parent, 11, C.alerte)
    fs:SetWidth(LG)
    fs:SetJustifyH("CENTER")
    return fs
end

---------------------------------------------------------------------------
-- Accueil : création du profil
---------------------------------------------------------------------------
local function CreerAccueil()
    local p = ns.NouvellePage("accueil", true, 520)

    local titre = W.Titre(p, 20, { 1, 1, 1 })
    titre:SetPoint("TOPLEFT")
    titre:SetText(L["Crée ton profil"])

    local sous = W.Texte(p, 11, C.gris)
    sous:SetPoint("TOPLEFT", 0, -28)
    sous:SetWidth(LG)
    sous:SetText(L["Tu ne verras que les joueurs compatibles que tu croises en jeu."])

    W.Etiquette(p, L["Je suis"]):SetPoint("TOPLEFT", 0, -58)
    local sexe = W.GroupeChoix(p, CHOIX_SEXE, 2, LG, false)
    sexe:SetPoint("TOPLEFT", 0, -72)

    W.Etiquette(p, L["Mon âge"]):SetPoint("TOPLEFT", 0, -110)
    local age = W.Saisie(p, 70)
    age:SetPoint("TOPLEFT", 0, -124)
    age:SetNumeric(true)
    age:SetMaxLetters(2)

    W.Etiquette(p, L["Surnom affiché"]):SetPoint("TOPLEFT", 84, -110)
    local surnom = W.Saisie(p, LG - 84)
    surnom:SetPoint("TOPLEFT", 84, -124)
    surnom:SetMaxLetters(16)

    -- Avertissement moins de 18 ans
    local alerte = W.Cadre(p, LG, 62, { C.alerte[1], C.alerte[2], C.alerte[3], 0.14 }, { C.alerte[1], C.alerte[2], C.alerte[3], 0.45 })
    alerte:SetPoint("TOPLEFT", 0, -332)
    local alerteTxt = W.Texte(alerte, 11, { 0.95, 0.83, 0.79 })
    alerteTxt:SetPoint("TOPLEFT", 10, -8)
    alerteTxt:SetWidth(LG - 20)
    alerteTxt:SetText(L["LD - Crush est réservé aux joueurs de 18 ans et plus. Si tu valides, l'addon restera désactivé et tu n'apparaîtras chez personne. Ne partage jamais d'infos personnelles avec des inconnus en ligne."])
    alerte:Hide()

    local surnomInfo = W.Texte(p, 10, C.gris)
    surnomInfo:SetPoint("TOPLEFT", 0, -160)
    surnomInfo:SetWidth(LG)
    surnomInfo:SetText(L["Le nom de ton personnage reste caché. Il n'est révélé qu'en cas de match."])

    local note
    age:SetScript("OnTextChanged", function(self)
        local v = tonumber(self:GetText())
        local mineur = (v and v < 18) and true or false
        alerte:SetShown(mineur)
        surnomInfo:SetShown(not mineur)
        note:SetShown(not mineur)
    end)

    W.Etiquette(p, L["Je cherche"]):SetPoint("TOPLEFT", 0, -196)
    local cherche = W.GroupeChoix(p, CHOIX_CHERCHE, 3, LG, false)
    cherche:SetPoint("TOPLEFT", 0, -210)

    W.Etiquette(p, L["Langues parlées"]):SetPoint("TOPLEFT", 0, -248)
    local langs = W.GroupeChoix(p, ns.LANGS, 3, LG, true)
    langs:SetPoint("TOPLEFT", 0, -262)

    note = W.Texte(p, 10, C.gris)
    note:SetPoint("TOPLEFT", 0, -332)
    note:SetWidth(LG)
    note:SetText(L["Les liens externes (Discord, réseaux sociaux, sites) sont interdits dans les surnoms et les bios."])

    local erreur = Erreur(p)
    erreur:SetPoint("BOTTOM", 0, 42)

    local valider = W.Bouton(p, L["Commencer"], LG, 32, "primaire")
    valider:SetPoint("BOTTOM")
    valider:SetScript("OnClick", function()
        local a = tonumber(age:GetText())
        local s = ns.Nettoyer(surnom:GetText())
        local pr = ns.compte.profil
        if not sexe:Get() then erreur:SetText(L["Indique si tu es une femme ou un homme."]) return end
        if not a then erreur:SetText(L["Indique ton âge."]) return end
        if a < 18 then
            pr.mineur = true
            ns.AfficherPage("mineur")
            return
        end
        if s == "" then erreur:SetText(L["Choisis un surnom."]) return end
        if ns.ContientLien(s) then erreur:SetText(L["Pas de liens ni de réseaux sociaux dans le surnom."]) return end
        if not cherche:Get() then erreur:SetText(L["Indique qui tu cherches."]) return end
        local l = langs:Get()
        if ns.EnsembleVide(l) then erreur:SetText(L["Choisis au moins une langue."]) return end

        pr.sexe, pr.age, pr.ageDeclareLe = sexe:Get(), a, time()
        pr.cherche, pr.langs = CleVersCherche(cherche:Get()), l
        pr.fait = true
        ns.char.surnom = s
        ns.char.versionProfil = time()
        erreur:SetText("")
        ns.Demarrer()
        ns.AfficherPage("decouvrir")
    end)

    p:SetScript("OnShow", function() p:Charger() end)
    function p:Charger()
        langs:Set(ns.compte.profil.langs)
    end
end

local function CreerMineur()
    local p = ns.NouvellePage("mineur", true, 340)
    local titre = W.Titre(p, 20, { 1, 1, 1 })
    titre:SetPoint("TOP", 0, -70)
    titre:SetText(L["Réservé aux 18 ans et plus"])
    local txt = W.Texte(p, 12, C.gris)
    txt:SetPoint("TOP", titre, "BOTTOM", 0, -14)
    txt:SetWidth(LG - 30)
    txt:SetJustifyH("CENTER")
    txt:SetText(L["LD - Crush est désactivé sur ton compte. Tu n'apparais chez aucun joueur.\n\nProfite bien du jeu, et ne partage jamais d'informations personnelles avec des inconnus en ligne."])
end

---------------------------------------------------------------------------
-- Découvrir : carte à swiper
---------------------------------------------------------------------------
local function CreerDecouvrir()
    local p = ns.NouvellePage("decouvrir")

    local carte = W.Cadre(p, LG, 410)
    carte:SetPoint("TOP")

    local bandeau = W.Cadre(carte, LG - 2, 110, { 0.10, 0.11, 0.15, 1 }, { 0, 0, 0, 0 })
    bandeau:SetPoint("TOP", 0, -1)
    local icone = W.IconeClasse(bandeau, 72)
    icone:SetPoint("CENTER")

    local badgeCroise = Badge(bandeau, C.accent, C.sombre)
    badgeCroise:SetPoint("TOPRIGHT", -8, -8)

    local surnom = W.Titre(carte, 22, { 1, 1, 1 })
    surnom:SetPoint("TOPLEFT", 14, -124)
    surnom:SetWordWrap(false)

    local infos = W.Texte(carte, 11, C.gris)
    infos:SetPoint("TOPRIGHT", -14, -130)
    infos:SetJustifyH("RIGHT")

    local classe = W.Texte(carte, 12)
    classe:SetPoint("TOPLEFT", 14, -154)

    local lieu = W.Texte(carte, 11, C.gris)
    lieu:SetPoint("TOPLEFT", 14, -174)
    lieu:SetWidth(LG - 28)

    local bio = W.Texte(carte, 12, { 0.89, 0.87, 0.85 })
    bio:SetPoint("TOPLEFT", 14, -200)
    bio:SetWidth(LG - 28)
    bio:SetSpacing(2)

    local tags = W.Texte(carte, 11, C.accent)
    tags:SetPoint("TOPLEFT", bio, "BOTTOMLEFT", 0, -12)
    tags:SetWidth(LG - 28)

    local dispo = W.Texte(carte, 11, C.gris)
    dispo:SetPoint("TOPLEFT", tags, "BOTTOMLEFT", 0, -6)
    dispo:SetWidth(LG - 28)

    local cache = W.Texte(carte, 10, C.gris)
    cache:SetPoint("BOTTOMRIGHT", -12, 10)
    cache:SetText(L["Nom révélé au match"])

    local passer = W.BoutonIcone(p, ns.MEDIA .. "LDCrush_Passer", 52)
    passer:SetPoint("TOP", carte, "BOTTOM", -55, -18)
    local liker = W.BoutonIcone(p, ns.MEDIA .. "LDCrush_Like", 72)
    liker:SetPoint("TOP", carte, "BOTTOM", 50, -8)

    local vide = W.Texte(p, 12, C.gris)
    vide:SetPoint("TOP", 0, -170)
    vide:SetWidth(LG - 40)
    vide:SetJustifyH("CENTER")
    vide:SetText(L["Personne de nouveau pour l'instant.\n\nContinue d'explorer : les joueurs compatibles que tu croises et qui ont l'addon apparaîtront ici."])

    local pied = W.Texte(p, 10, C.gris)
    pied:SetPoint("BOTTOMLEFT", 12, 0)
    local point = p:CreateTexture(nil, "ARTWORK")
    point:SetTexture("Interface\\Buttons\\WHITE8X8")
    point:SetVertexColor(C.vert[1], C.vert[2], C.vert[3])
    point:SetSize(6, 6)
    point:SetPoint("LEFT", pied, "LEFT", -12, 0)

    local courant
    passer:SetScript("OnClick", function() if courant then ns.focus = nil ns.Passer(courant) end end)
    liker:SetScript("OnClick", function() if courant then ns.focus = nil ns.Liker(courant) end end)

    function p:Rafraichir()
        local file = ns.ListeADecouvrir()
        courant = nil
        local pf = ns.focus and ns.char.profils[ns.focus]
        if pf and pf.surnom and ns.char.croises[ns.focus] and ns.Statut(ns.focus) == "nouveau" and ns.PasseFiltres(ns.focus) then
            courant = ns.focus
        else
            courant = file[1]
        end

        local n = ns.NbEnLigne()
        pied:SetText(L["%d en ligne · %d à découvrir"]:format(n, #file))

        local aff = courant ~= nil
        carte:SetShown(aff); passer:SetShown(aff); liker:SetShown(aff); vide:SetShown(not aff)
        if not aff then return end

        local pr, c = ns.char.profils[courant], ns.char.croises[courant]
        icone:SetClasse(pr.classe)
        badgeCroise:Set((pr.sexe == "F" and L["Croisée %d fois"] or L["Croisé %d fois"]):format(c.n))
        surnom:SetText(pr.surnom)
        local langues = ns.LibellesLangues(pr.langs)
        infos:SetText((L["%s   Niv. %s · %d ans"]):format(langues, pr.niveau or "?", pr.age))
        local r, g, b = ns.CouleurClasse(pr.classe)
        classe:SetText(("|cff%02x%02x%02x%s|r · %s"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), ns.NomClasse(pr.classe, pr.sexe), ns.NomRace(pr.race)))
        lieu:SetText((L["Dernier croisement : %s, %s"]):format(c.zone ~= "" and c.zone or "?", ns.IlYA(c.dernier)))
        bio:SetText(pr.bio and pr.bio ~= "" and pr.bio or "|cff8a877f" .. L["Pas encore de bio."] .. "|r")
        tags:SetText(ns.LibellesTags(pr.tags, ns.TAGS))
        local d = ns.LibellesTags(pr.dispo, ns.DISPO)
        dispo:SetText(d ~= "" and L["Joue surtout : %s"]:format(d) or "")
    end
end

---------------------------------------------------------------------------
-- Listes défilantes (croisés, matchs)
---------------------------------------------------------------------------
local function ListeDefilante(page, hauteurLigne, nbLignes, creerLigne, remplirLigne, obtenirListe)
    local lignes, decalage = {}, 0
    for i = 1, nbLignes do
        local l = creerLigne(page)
        l:SetPoint("TOPLEFT", 0, -(i - 1) * (hauteurLigne + 6))
        lignes[i] = l
    end
    local function Maj()
        local liste = obtenirListe()
        decalage = math.max(0, math.min(decalage, #liste - nbLignes))
        for i, l in ipairs(lignes) do
            local nom = liste[i + decalage]
            if nom then remplirLigne(l, nom) l:Show() else l:Hide() end
        end
        return #liste
    end
    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function(_, delta)
        decalage = decalage - delta
        Maj()
    end)
    return Maj
end

local function CreerCroises()
    local p = ns.NouvellePage("croises")

    local function CreerLigne(parent)
        local l = CreateFrame("Button", nil, parent, "BackdropTemplate")
        l:SetSize(LG, 46)
        W.Verre(l, C.carte, { 1, 1, 1, 0.08 })
        l.icone = W.IconeClasse(l, 30)
        l.icone:SetPoint("LEFT", 8, 0)
        l.nom = W.Texte(l, 13)
        l.nom:SetPoint("TOPLEFT", 48, -8)
        l.nom:SetWordWrap(false)
        l.meta = W.Texte(l, 10, C.gris)
        l.meta:SetPoint("LEFT", l.nom, "RIGHT", 6, 0)
        l.lieu = W.Texte(l, 10, C.gris)
        l.lieu:SetPoint("TOPLEFT", 48, -27)
        l.lieu:SetWordWrap(false)
        l.compte = W.Texte(l, 12)
        l.compte:SetPoint("TOPRIGHT", -10, -7)
        l.statut = Badge(l, C.accent, C.sombre)
        l.statut:SetPoint("BOTTOMRIGHT", -8, 6)
        l:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.3) end)
        l:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.08) end)
        l:SetScript("OnClick", function(self)
            if self.cle and ns.Statut(self.cle) == "nouveau" then
                ns.focus = self.cle
                ns.AfficherPage("decouvrir")
            end
        end)
        return l
    end

    local STATUTS = {
        nouveau = { L["À découvrir"], C.accent, C.sombre },
        like    = { L["Liké"], { 1, 1, 1, 0.14 }, C.texte },
        passe   = { L["Passé"], { 1, 1, 1, 0.06 }, C.gris },
        match   = { L["Match"], C.vert, { 0.05, 0.10, 0.06 } },
    }

    local function Remplir(l, nom)
        local pr, c = ns.char.profils[nom], ns.char.croises[nom]
        local statut = ns.Statut(nom)
        l.cle = nom
        l.icone:SetClasse(pr.classe)
        local r, g, b = ns.CouleurClasse(pr.classe)
        -- Le vrai nom n'apparaît qu'après un match
        l.nom:SetText(statut == "match" and Ambiguate(nom, "short") or pr.surnom)
        l.nom:SetTextColor(r, g, b)
        l.meta:SetText((L["%s · %s · %d ans"]):format(ns.NomClasse(pr.classe, pr.sexe), pr.niveau or "?", pr.age))
        l.lieu:SetText(("%s · %s"):format(c.zone ~= "" and c.zone or "?", ns.IlYA(c.dernier)))
        l.compte:SetText("×" .. c.n)
        local s = STATUTS[statut]
        l.statut:Set(s[1], s[2], s[3])
    end

    local Maj = ListeDefilante(p, 46, 9, CreerLigne, Remplir, ns.ListeCroises)

    local vide = W.Texte(p, 12, C.gris)
    vide:SetPoint("TOP", 0, -170)
    vide:SetWidth(LG - 40)
    vide:SetJustifyH("CENTER")
    vide:SetText(L["Aucun joueur compatible croisé pour l'instant."])

    local pied = W.Texte(p, 10, C.gris)
    pied:SetPoint("BOTTOMLEFT")
    pied:SetText(L["Seuls les joueurs compatibles ayant l'addon apparaissent ici."])

    function p:Rafraichir()
        vide:SetShown(Maj() == 0)
    end
end

StaticPopupDialogs["LDCRUSH_BLOQUER"] = {
    text = L["Bloquer %s ? Ce joueur ne pourra plus te voir ni te chuchoter."],
    button1 = L["Bloquer"],
    button2 = CANCEL,
    OnAccept = function(_, nom) ns.Bloquer(nom) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ns.Chuchoter(nom)
    ChatFrame_OpenChat("/w " .. nom .. " ")
end

function ns.Inviter(nom)
    if ns.EstFaux(nom) then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(nom)
    else
        InviteUnit(nom)
    end
end

local function CreerMatchs()
    local p = ns.NouvellePage("matchs")

    local function CreerLigne(parent)
        local l = W.Cadre(parent, LG, 76)
        l.icone = W.IconeClasse(l, 30)
        l.icone:SetPoint("TOPLEFT", 8, -8)
        l.nom = W.Texte(l, 13)
        l.nom:SetPoint("TOPLEFT", 48, -8)
        l.nom:SetWordWrap(false)
        l.surnom = W.Texte(l, 10, C.gris)
        l.surnom:SetPoint("LEFT", l.nom, "RIGHT", 6, 0)
        l.info = W.Texte(l, 10, C.gris)
        l.info:SetPoint("TOPLEFT", 48, -28)
        l.chuchoter = W.Bouton(l, L["Chuchoter"], 80, 20, "primaire")
        l.chuchoter:SetPoint("BOTTOMLEFT", 48, 9)
        l.inviter = W.Bouton(l, L["Inviter"], 64, 20)
        l.inviter:SetPoint("LEFT", l.chuchoter, "RIGHT", 6, 0)
        l.bloquer = W.Bouton(l, L["Bloquer"], 64, 20)
        l.bloquer:SetPoint("LEFT", l.inviter, "RIGHT", 6, 0)
        l.chuchoter:SetScript("OnClick", function() ns.Chuchoter(l.cle) end)
        l.inviter:SetScript("OnClick", function() ns.Inviter(l.cle) end)
        l.bloquer:SetScript("OnClick", function()
            StaticPopup_Show("LDCRUSH_BLOQUER", Ambiguate(l.cle, "short"), nil, l.cle)
        end)
        return l
    end

    local function Remplir(l, nom)
        local pr = ns.char.profils[nom] or {}
        local c = ns.char.croises[nom] or { n = 0 }
        l.cle = nom
        l.icone:SetClasse(pr.classe)
        l.nom:SetText(Ambiguate(nom, "short"))
        l.nom:SetTextColor(ns.CouleurClasse(pr.classe))
        l.surnom:SetText(pr.surnom and ("(" .. pr.surnom .. ")") or "")
        l.info:SetText((L["Match %s · croisés %d fois"]):format(ns.IlYA(ns.char.matchs[nom].t), c.n))
    end

    local Maj = ListeDefilante(p, 76, 6, CreerLigne, Remplir, ns.ListeMatchs)

    local vide = W.Texte(p, 12, C.gris)
    vide:SetPoint("TOP", 0, -170)
    vide:SetWidth(LG - 40)
    vide:SetJustifyH("CENTER")
    vide:SetText(L["Pas encore de match.\n\nLike les joueurs croisés : si c'est réciproque, ils apparaîtront ici avec leur vrai nom."])

    function p:Rafraichir()
        vide:SetShown(Maj() == 0)
    end
end

---------------------------------------------------------------------------
-- Mon profil
---------------------------------------------------------------------------
local function CreerProfil()
    local p = ns.NouvellePage("profil", true)


    local icone = W.IconeClasse(p, 36)
    icone:SetPoint("TOPLEFT", 0, 0)
    local perso = W.Texte(p, 12, { 1, 1, 1 })
    perso:SetPoint("TOPLEFT", 46, -2)
    local persoInfo = W.Texte(p, 10, C.gris)
    persoInfo:SetPoint("TOPLEFT", 46, -20)
    persoInfo:SetText(L["Lus automatiquement depuis ton personnage"])

    W.Etiquette(p, L["Surnom affiché"]):SetPoint("TOPLEFT", 0, -50)
    local surnom = W.Saisie(p, LG)
    surnom:SetPoint("TOPLEFT", 0, -64)
    surnom:SetMaxLetters(16)
    local surnomInfo = W.Texte(p, 10, C.gris)
    surnomInfo:SetPoint("TOPLEFT", 0, -94)
    surnomInfo:SetText(L["Ton nom de personnage reste caché jusqu'au match."])

    W.Etiquette(p, L["Bio"]):SetPoint("TOPLEFT", 0, -118)
    local compteur = W.Texte(p, 10, C.gris)
    compteur:SetPoint("TOPRIGHT", 0, -118)
    -- Un EditBox multiligne ajuste sa hauteur au texte : on le met dans un cadre de hauteur fixe
    local bioCadre = W.Cadre(p, LG, 58, { 1, 1, 1, 0.05 }, C.bordFort)
    bioCadre:SetPoint("TOPLEFT", 0, -132)
    local bio = CreateFrame("EditBox", nil, bioCadre)
    bio:SetPoint("TOPLEFT", 8, -6)
    bio:SetPoint("TOPRIGHT", -8, -6)
    bio:SetHeight(46)
    bio:SetMultiLine(true)
    bio:SetFont(W.POLICE, 12, "")
    bio:SetTextColor(1, 1, 1)
    bio:SetAutoFocus(false)
    bio:SetMaxLetters(140)
    bio:SetMaxBytes(230)
    bio:SetScript("OnEscapePressed", bio.ClearFocus)
    bio:SetScript("OnEditFocusGained", function() bioCadre:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.8) end)
    bio:SetScript("OnEditFocusLost", function() bioCadre:SetBackdropBorderColor(C.bordFort[1], C.bordFort[2], C.bordFort[3], C.bordFort[4]) end)
    bio:SetScript("OnTextChanged", function(self)
        compteur:SetText(("%d / 140"):format(strlenutf8 and strlenutf8(self:GetText()) or #self:GetText()))
    end)
    -- Cliquer n'importe où dans le cadre donne le focus
    bioCadre:EnableMouse(true)
    bioCadre:SetScript("OnMouseDown", function() bio:SetFocus() end)

    W.Etiquette(p, L["Langues parlées"]):SetPoint("TOPLEFT", 0, -208)
    local langs = W.GroupeChoix(p, ns.LANGS, 3, LG, true)
    langs:SetPoint("TOPLEFT", 0, -222)

    W.Etiquette(p, L["J'aime en jeu"]):SetPoint("TOPLEFT", 0, -304)
    local tags = W.GroupeChoix(p, ns.TAGS, 3, LG, true)
    tags:SetPoint("TOPLEFT", 0, -318)

    W.Etiquette(p, L["Je joue surtout"]):SetPoint("TOPLEFT", 0, -400)
    local dispo = W.GroupeChoix(p, ns.DISPO, 3, LG, true)
    dispo:SetPoint("TOPLEFT", 0, -414)

    local option = W.Cadre(p, LG, 42)
    option:SetPoint("TOPLEFT", 0, -462)
    local optTitre = W.Texte(option, 12, { 1, 1, 1 })
    optTitre:SetPoint("TOPLEFT", 10, -7)
    optTitre:SetText(L["Masquer les chuchotements"])
    local optSous = W.Texte(option, 10, C.gris)
    optSous:SetPoint("TOPLEFT", 10, -24)
    optSous:SetText(L["des joueurs que tu as passés ou bloqués"])
    local interrupteur = W.Interrupteur(option)
    interrupteur:SetPoint("RIGHT", -10, 0)

    local erreur = Erreur(p)
    erreur:SetPoint("BOTTOM", 0, 40)

    local enregistrer = W.Bouton(p, L["Enregistrer"], LG, 30, "primaire")
    enregistrer:SetPoint("BOTTOM")
    enregistrer:SetScript("OnClick", function()
        local s = ns.Nettoyer(surnom:GetText())
        local b = ns.Nettoyer(bio:GetText())
        local l = langs:Get()
        if s == "" then erreur:SetText(L["Choisis un surnom."]) return end
        if ns.ContientLien(s) or ns.ContientLien(b) then
            erreur:SetText(L["Pas de liens ni de réseaux sociaux dans le surnom ou la bio."])
            return
        end
        if ns.EnsembleVide(l) then erreur:SetText(L["Choisis au moins une langue."]) return end
        erreur:SetText("")
        ns.char.surnom, ns.char.bio = s, b
        ns.char.tags, ns.char.dispo = tags:Get(), dispo:Get()
        ns.compte.profil.langs = l
        ns.char.options.masquerChuchotements = interrupteur.valeur
        surnom:ClearFocus(); bio:ClearFocus()
        ns.ProfilModifie()
        ns.Message(L["profil enregistré."])
        ns.AfficherPage("decouvrir")
    end)

    p:SetScript("OnShow", function() p:Charger() end)
    function p:Charger()
        local _, classe = UnitClass("player")
        icone:SetClasse(classe)
        perso:SetText((L["%s · %s · Niv. %d"]):format(ns.NomClasse(classe, ns.compte.profil.sexe), (UnitRace("player")), UnitLevel("player")))
        if not surnom:HasFocus() then surnom:SetText(ns.char.surnom or "") end
        if not bio:HasFocus() then bio:SetText(ns.char.bio or "") end
        langs:Set(ns.compte.profil.langs)
        tags:Set(ns.char.tags)
        dispo:Set(ns.char.dispo)
        interrupteur:Set(ns.char.options.masquerChuchotements)
        erreur:SetText("")
    end
end

---------------------------------------------------------------------------
-- Filtres
---------------------------------------------------------------------------
local function CreerFiltres()
    local p = ns.NouvellePage("filtres", true, 500)


    W.Etiquette(p, L["Je cherche"]):SetPoint("TOPLEFT", 0, -8)
    local cherche = W.GroupeChoix(p, CHOIX_CHERCHE, 3, LG, false)
    cherche:SetPoint("TOPLEFT", 0, -22)

    W.Etiquette(p, L["Âge"]):SetPoint("TOPLEFT", 0, -62)
    local lDe = W.Texte(p, 11, C.gris)
    lDe:SetPoint("TOPLEFT", 0, -82)
    lDe:SetText(L["De"])
    local ageMin = W.Saisie(p, 60)
    ageMin:SetPoint("TOPLEFT", 24, -76)
    ageMin:SetNumeric(true)
    ageMin:SetMaxLetters(2)
    local lA = W.Texte(p, 11, C.gris)
    lA:SetPoint("TOPLEFT", 100, -82)
    lA:SetText(L["à"])
    local ageMax = W.Saisie(p, 60)
    ageMax:SetPoint("TOPLEFT", 118, -76)
    ageMax:SetNumeric(true)
    ageMax:SetMaxLetters(2)
    local lAns = W.Texte(p, 11, C.gris)
    lAns:SetPoint("TOPLEFT", 186, -82)
    lAns:SetText(L["ans   (minimum 18)"])

    W.Etiquette(p, L["Langues que je comprends"]):SetPoint("TOPLEFT", 0, -116)
    local langs = W.GroupeChoix(p, ns.LANGS, 3, LG, true)
    langs:SetPoint("TOPLEFT", 0, -130)
    local langsInfo = W.Texte(p, 10, C.gris)
    langsInfo:SetPoint("TOPLEFT", 0, -194)
    langsInfo:SetWidth(LG)
    langsInfo:SetText(L["Un profil s'affiche s'il partage au moins une de ces langues."])

    W.Etiquette(p, L["Niveau du personnage"]):SetPoint("TOPLEFT", 0, -222)
    local niveau = W.GroupeChoix(p, {
        { key = 0, label = L["Tous"] }, { key = 10, label = "± 10" }, { key = 5, label = "± 5" },
    }, 3, LG, false)
    niveau:SetPoint("TOPLEFT", 0, -236)

    W.Etiquette(p, L["Croisés au moins"]):SetPoint("TOPLEFT", 0, -276)
    local croisMin = W.GroupeChoix(p, {
        { key = 1, label = L["1 fois"] }, { key = 2, label = L["2 fois"] }, { key = 3, label = L["3 fois et +"] },
    }, 3, LG, false)
    croisMin:SetPoint("TOPLEFT", 0, -290)

    local erreur = Erreur(p)
    erreur:SetPoint("BOTTOM", 0, 74)

    local reinit = W.Bouton(p, L["Réinitialiser"], LG, 26)
    reinit:SetPoint("BOTTOM", 0, 38)

    local appliquer = W.Bouton(p, L["Appliquer"], LG, 30, "primaire")
    appliquer:SetPoint("BOTTOM")

    p:SetScript("OnShow", function() p:Charger() end)
    function p:Charger()
        local f = ns.char.filtres
        cherche:Set(ChercheVersCle(ns.compte.profil.cherche))
        ageMin:SetText(tostring(f.ageMin))
        ageMax:SetText(tostring(f.ageMax))
        langs:Set(ns.EnsembleVide(f.langs) and ns.compte.profil.langs or f.langs)
        niveau:Set(f.niveau)
        croisMin:Set(f.croisMin)
        erreur:SetText("")
    end

    reinit:SetScript("OnClick", function()
        local f = ns.char.filtres
        f.ageMin, f.ageMax, f.langs, f.niveau, f.croisMin = 18, 99, {}, 0, 1
        p:Charger()
    end)

    appliquer:SetScript("OnClick", function()
        local mini = math.max(18, tonumber(ageMin:GetText()) or 18)
        local maxi = tonumber(ageMax:GetText()) or 99
        if maxi < mini then erreur:SetText(L["L'âge maximum doit être supérieur au minimum."]) return end
        local l = langs:Get()
        if ns.EnsembleVide(l) then erreur:SetText(L["Choisis au moins une langue."]) return end
        local f = ns.char.filtres
        f.ageMin, f.ageMax, f.langs = mini, maxi, l
        f.niveau, f.croisMin = niveau:Get() or 0, croisMin:Get() or 1

        local nouveau = CleVersCherche(cherche:Get())
        if ChercheVersCle(nouveau) ~= ChercheVersCle(ns.compte.profil.cherche) then
            ns.compte.profil.cherche = nouveau
            ns.ProfilModifie()
        end
        ns.AfficherPage("decouvrir")
    end)
end

function ns.CreerPages()
    LG = ns.LARGEUR_CONTENU
    CreerAccueil()
    CreerMineur()
    CreerDecouvrir()
    CreerCroises()
    CreerMatchs()
    CreerProfil()
    CreerFiltres()
end
