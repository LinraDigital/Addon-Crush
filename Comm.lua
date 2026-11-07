-- LD - Crush : protocole réseau (canal caché + chuchotements addon invisibles)
--
-- Messages (champs séparés par "^") :
--   H^proto^sexe^cherche^age^langues   présence, sur le canal ou en réponse à "?"
--   ?                                  « as-tu l'addon ? » (chuchotement)
--   Q                                  demande de profil (chuchotement)
--   P^surnom^classe^raceId^niveau^tags^dispo   profil (chuchotement)
--   B^bio                              bio (chuchotement)
--   L                                  like (chuchotement)
--   M                                  match confirmé (chuchotement)
local _, ns = ...

local SEP = "^"
local JETONS_MAX = 8          -- rafale autorisée
local fileHaute, fileBasse = {}, {}
local jetons, derniereRecharge = JETONS_MAX, 0
local TAILLE_MAX_FILE_BASSE = 40

---------------------------------------------------------------------------
-- Envoi avec limitation de débit (1 message/s, rafale de 8)
---------------------------------------------------------------------------
local envoyeur = CreateFrame("Frame")
envoyeur:Hide()
envoyeur:SetScript("OnUpdate", function(self)
    local maintenant = GetTime()
    jetons = math.min(JETONS_MAX, jetons + (maintenant - derniereRecharge))
    derniereRecharge = maintenant
    while jetons >= 1 do
        local m = table.remove(fileHaute, 1) or table.remove(fileBasse, 1)
        if not m then self:Hide() return end
        if m.dist == "CHANNEL" then
            if ns.channelId and ns.channelId > 0 then
                C_ChatInfo.SendAddonMessage(ns.PREFIX, m.msg, "CHANNEL", ns.channelId)
                jetons = jetons - 1
            end
        else
            C_ChatInfo.SendAddonMessage(ns.PREFIX, m.msg, "WHISPER", m.cible)
            jetons = jetons - 1
        end
    end
end)

function ns.Envoyer(msg, dist, cible, basse)
    if cible and ns.EstFaux(cible) then return end
    if basse then
        if #fileBasse >= TAILLE_MAX_FILE_BASSE then return end
        fileBasse[#fileBasse + 1] = { msg = msg, dist = dist, cible = cible }
    else
        fileHaute[#fileHaute + 1] = { msg = msg, dist = dist, cible = cible }
    end
    if not envoyeur:IsShown() then
        derniereRecharge = GetTime()
        envoyeur:Show()
    end
end

---------------------------------------------------------------------------
-- Construction des messages
---------------------------------------------------------------------------
function ns.MessageHello()
    local p = ns.compte.profil
    return table.concat({
        "H", ns.PROTO, p.sexe or "", ns.EnsembleVersTexte(p.cherche),
        tostring(ns.AgeActuel() or 0), ns.EnsembleVersTexte(p.langs),
        tostring(ns.char.versionProfil or 0),
    }, SEP)
end

local function MessageProfil()
    local _, classe = UnitClass("player")
    local _, _, raceId = UnitRace("player")
    return table.concat({
        "P", ns.Nettoyer(ns.char.surnom), classe or "", tostring(raceId or 0),
        tostring(UnitLevel("player")), ns.EnsembleVersTexte(ns.char.tags),
        ns.EnsembleVersTexte(ns.char.dispo),
    }, SEP)
end

local function MessageBio()
    return "B" .. SEP .. ns.CouperOctets(ns.Nettoyer(ns.char.bio), 230)
end

function ns.EnvoyerHello()
    if ns.EstActif() then ns.Envoyer(ns.MessageHello(), "CHANNEL") end
end

-- À appeler quand le profil change : renvoie la présence (les autres redemanderont le profil)
function ns.ProfilModifie()
    ns.char.versionProfil = time()
    ns.EnvoyerHello()
end

function ns.DemanderProfil(nom)
    local t = ns.profilDemande[nom]
    if t and GetTime() - t < 300 then return end
    ns.profilDemande[nom] = GetTime()
    ns.Envoyer("Q", "WHISPER", nom)
end

-- Envoie un like ou un match, ou le met en attente si le joueur est hors ligne
function ns.EnvoyerOuAttendre(nom, cmd)
    if ns.enLigne[nom] then
        ns.Envoyer(cmd, "WHISPER", nom)
    else
        ns.char.aEnvoyer[nom] = cmd
    end
end

---------------------------------------------------------------------------
-- Réception
---------------------------------------------------------------------------
local function MajProfil(nom)
    local p = ns.char.profils[nom]
    if not p then
        p = {}
        ns.char.profils[nom] = p
    end
    return p
end

local function Recevoir(texte, dist, expediteur)
    local nom = Ambiguate(expediteur, "none")
    if nom == ns.Me or not ns.EstActif() then return end
    if ns.char.bloques[nom] then return end

    local f = ns.Split(texte, SEP)
    local cmd = f[1]

    if cmd == "H" then
        if f[2] ~= ns.PROTO then return end
        local age = tonumber(f[5])
        if not age or age < 18 then return end
        if f[3] ~= "F" and f[3] ~= "H" then return end
        ns.enLigne[nom] = { t = GetTime() }
        local p = MajProfil(nom)
        p.sexe, p.age = f[3], age
        p.cherche = ns.TexteVersEnsemble(f[4])
        p.langs = ns.TexteVersEnsemble(f[6])
        -- Profil modifié depuis notre dernière lecture : on le redemande
        local version = f[7] or "0"
        if p.version ~= version then
            p.version = version
            if p.surnom and ns.char.croises[nom] then ns.DemanderProfil(nom) end
        end

        local attente = ns.croisementsEnAttente[nom]
        if attente then
            ns.croisementsEnAttente[nom] = nil
            ns.EnregistrerCroisement(nom, attente.zone)
        end
        local enAttente = ns.char.aEnvoyer[nom]
        if enAttente then
            ns.char.aEnvoyer[nom] = nil
            ns.Envoyer(enAttente, "WHISPER", nom)
        end

    elseif cmd == "?" and dist == "WHISPER" then
        ns.Envoyer(ns.MessageHello(), "WHISPER", nom)

    elseif cmd == "Q" and dist == "WHISPER" then
        ns.Envoyer(MessageProfil(), "WHISPER", nom)
        ns.Envoyer(MessageBio(), "WHISPER", nom)

    elseif cmd == "P" and dist == "WHISPER" then
        local surnom = ns.Nettoyer(f[2])
        if surnom == "" or ns.ContientLien(surnom) then return end
        local p = MajProfil(nom)
        p.surnom = surnom
        p.classe = f[3]
        p.race = tonumber(f[4])
        p.niveau = tonumber(f[5])
        p.tags = ns.TexteVersEnsemble(f[6])
        p.dispo = ns.TexteVersEnsemble(f[7])
        p.maj = time()

    elseif cmd == "B" and dist == "WHISPER" then
        local bio = ns.Nettoyer(f[2])
        local p = MajProfil(nom)
        p.bio = ns.ContientLien(bio) and "" or bio

    elseif cmd == "L" and dist == "WHISPER" then
        ns.RecevoirLike(nom)

    elseif cmd == "M" and dist == "WHISPER" then
        ns.RecevoirMatch(nom)
    end

    ns.RafraichirUI()
end

---------------------------------------------------------------------------
-- Canal caché
---------------------------------------------------------------------------
local function MasquerCanal()
    -- Pas de ChatFrame_RemoveChannel : appelé depuis un addon, il « salit » (taint) les
    -- fenêtres de chat et Blizzard bloque ensuite des actions protégées. On filtre à la place.
    if ns.filtreCanal then return end
    ns.filtreCanal = true
    local function Filtre(_, _, _, _, _, _, _, _, _, _, nomCanal)
        if nomCanal and string.lower(nomCanal) == string.lower(ns.CHANNEL) then return true end
    end
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", Filtre)
end

function ns.RejoindreCanal()
    if GetChannelName(ns.CHANNEL) == 0 then
        JoinTemporaryChannel(ns.CHANNEL)
    end
    C_Timer.After(3, function()
        local id = GetChannelName(ns.CHANNEL)
        if id and id > 0 then
            ns.channelId = id
            MasquerCanal()
            ns.EnvoyerHello()
        else
            C_Timer.After(20, ns.RejoindreCanal)
        end
    end)
end

local function PurgerEnLigne()
    local limite = GetTime() - 400
    for nom, info in pairs(ns.enLigne) do
        if info.t < limite then ns.enLigne[nom] = nil end
    end
end

function ns.NbEnLigne()
    local n = 0
    for _ in pairs(ns.enLigne) do n = n + 1 end
    return n
end

function ns.InitComm()
    C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)

    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:RegisterEvent("CHANNEL_UI_UPDATE")
    f:SetScript("OnEvent", function(_, event, prefixe, texte, dist, expediteur)
        if event == "CHAT_MSG_ADDON" then
            if prefixe == ns.PREFIX then Recevoir(texte, dist, expediteur) end
        else
            -- l'ordre des canaux peut changer : on met à jour l'identifiant
            local id = GetChannelName(ns.CHANNEL)
            if id and id > 0 then ns.channelId = id end
        end
    end)

    -- Masque les notifications « a rejoint / quitté le canal »
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", function(_, _, _, _, _, _, _, _, _, _, nomCanal)
        if nomCanal and string.lower(nomCanal) == string.lower(ns.CHANNEL) then return true end
    end)

    ns.RejoindreCanal()

    -- Présence toutes les ~2,5 min, nettoyage des joueurs partis
    ns.ticker = C_Timer.NewTicker(150 + math.random(0, 20), function()
        ns.EnvoyerHello()
        PurgerEnLigne()
        ns.RafraichirUI()
    end)
end
