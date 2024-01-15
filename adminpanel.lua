if SERVER then
    util.AddNetworkString("AdminModeNotification")
    util.AddNetworkString("AdminModeData")

    local allowedGroups = {
        ["superadmin"] = true,
        ["admin"] = true,
        ["Modérateur"] = true,
        ["Modérateur-Test"] = true,
        ["Responsable-Modération"] = true,
        ["Fondation"] = true
    }

    local function SetAdminMode(ply, enabled)
        ply:SetNWBool("AdminMode", enabled)
        ply:SetRenderMode(enabled and RENDERMODE_TRANSALPHA or RENDERMODE_NORMAL)
        ply:SetColor(enabled and Color(255, 255, 255, 0) or Color(255, 255, 255, 255))

        if enabled then
            ply:GodEnable()
            ply:SetMoveType(MOVETYPE_NOCLIP)
            ply:SetCollisionGroup(COLLISION_GROUP_WORLD)
            ply:DrawWorldModel(false)
        else
            ply:GodDisable()
            ply:SetMoveType(MOVETYPE_WALK)
            ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
            ply:DrawWorldModel(true)
        end

        net.Start("AdminModeNotification")
        net.WriteString(enabled and "Vous vous êtes mis en mode administrateur. Toutes les commandes de modération vous ont été attribuées." or "Vous avez désactivé le mode administrateur.")
        net.WriteFloat(enabled and 5 or 3)
        net.Send(ply)

        net.Start("AdminModeData")
        net.WriteBool(enabled)
        net.Send(ply)
    end

    hook.Add("PlayerSay", "ProcessAdminCommand", function(ply, text)
        local command = string.lower(text)

        if command == "!admin" then
            if not allowedGroups[ply:GetUserGroup()] then
                ply:ChatPrint("Vous n'avez pas la permission d'utiliser cette commande.")
                return ""
            end

            local is_admin_mode = ply:GetNWBool("AdminMode", false)
            SetAdminMode(ply, not is_admin_mode)

            return ""
        end
    end)

    hook.Add("PlayerShouldTakeDamage", "PreventDamageWithoutAdminMode", function(ply, attacker)
        if not ply:GetNWBool("AdminMode", false) and attacker:IsPlayer() and attacker:GetNWBool("AdminMode", false) then
            return false
        end
    end)

    hook.Add("PlayerInitialSpawn", "ActivateCloakAndGodModeForAdmin", function(ply)
        if ply:GetNWBool("AdminMode", false) then
            SetAdminMode(ply, true)
        end
    end)

    hook.Add("PlayerNoClip", "PreventNoclipWithoutAdminMode", function(ply)
        if not ply:GetNWBool("AdminMode", false) then
            net.Start("AdminModeNotification")
            net.WriteString("Vous devez activer le mode administrateur pour utiliser le noclip.")
            net.WriteFloat(5)
            net.Send(ply)
            return false
        end
    end)

    hook.Add("ShouldCollide", "PreventCollisionWithAdmins", function(ent1, ent2)
        if ent1:IsPlayer() and ent1:GetNWBool("AdminMode", false) then
            return false
        elseif ent2:IsPlayer() and ent2:GetNWBool("AdminMode", false) then
            return false
        end
    end)

    hook.Add("EntityTakeDamage", "AllowBulletDamageForAdmins", function(target, dmginfo)
        if target:IsPlayer() and target:GetNWBool("AdminMode", false) then
            local inflictor = dmginfo:GetInflictor()
            if IsValid(inflictor) and inflictor:IsWeapon() then
                dmginfo:SetDamageType(DMG_PHYSGUN)
            end
        end
    end)
end

if CLIENT then
    local isAdminMode = false

    net.Receive("AdminModeNotification", function()
        local text = net.ReadString()
        local duration = net.ReadFloat()
        notification.AddLegacy(text, NOTIFY_GENERIC, duration)
    end)

    net.Receive("AdminModeData", function()
        isAdminMode = net.ReadBool()
    end)

    local function DrawAdminHUD()
        local is_admin_mode = isAdminMode or false
        local hudSize = 200
        local hudPadding = 20
        local cornerRadius = 10
        local barHeight = (hudSize - (hudPadding * 5)) / 3

        if is_admin_mode then
            local x = hudPadding
            local y = hudPadding

            local noclipColor = LocalPlayer():GetMoveType() == MOVETYPE_NOCLIP and Color(0, 255, 0) or Color(255, 0, 0)
            draw.RoundedBox(cornerRadius, x, y, hudSize, barHeight, noclipColor)
            draw.SimpleText("Noclip", "DermaDefaultBold", x + hudPadding, y + (barHeight / 2), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            y = y + barHeight + hudPadding

            local godColor = LocalPlayer():GetNWBool("AdminMode", false) and Color(0, 255, 0) or Color(255, 0, 0)
            draw.RoundedBox(cornerRadius, x, y, hudSize, barHeight, godColor)
            draw.SimpleText("God", "DermaDefaultBold", x + hudPadding, y + (barHeight / 2), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            y = y + barHeight + hudPadding

            local cloakColor = LocalPlayer():GetNWBool("AdminMode", false) and Color(0, 255, 0) or Color(255, 0, 0)
            draw.RoundedBox(cornerRadius, x, y, hudSize, barHeight, cloakColor)
            draw.SimpleText("Cloak", "DermaDefaultBold", x + hudPadding, y + (barHeight / 2), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    hook.Add("HUDPaint", "DrawAdminHUD", DrawAdminHUD)

    hook.Add("HUDPaint", "PlayerInfoHUD", function()
        local localPlayer = LocalPlayer()

        if not localPlayer:GetNWBool("AdminMode", false) then
            return
        end

        local allowedRanks = {"Modérateur-Test", "Modérateur", "Responsable-Modération", "superadmin"}

        if not table.HasValue(allowedRanks, localPlayer:GetUserGroup()) then
            return
        end

        for _, ply in pairs(player.GetAll()) do
            if IsValid(ply) and ply ~= localPlayer then
                local pos = ply:EyePos():ToScreen()
                pos.y = pos.y - 50

                draw.SimpleText("Nom: " .. ply:Nick(), "DermaDefault", pos.x, pos.y, nameTextColor, TEXT_ALIGN_CENTER)
                draw.SimpleText("Vies: " .. ply:Health(), "DermaDefault", pos.x, pos.y + 20, healthTextColor, TEXT_ALIGN_CENTER)
                draw.SimpleText("Morts: " .. ply:Deaths(), "DermaDefault", pos.x, pos.y + 40, deathsTextColor, TEXT_ALIGN_CENTER)
                draw.SimpleText("SteamID: " .. ply:SteamID(), "DermaDefault", pos.x, pos.y + 60, steamIDTextColor, TEXT_ALIGN_CENTER)
            end
        end
    end)
end

---Fin du !admin

--Début des frames

surface.CreateFont("Default", {
    font = "Arial",
    size = ScrH() * 0.03,
    weight = 500,
    antialias = true,
    shadow = false
})

local function createPlayerActionButtons(selectedPlayerName, playerListFrame)
    local actionFrame = vgui.Create("DFrame")
    actionFrame:SetSize(200, 250)
    actionFrame:Center()
    actionFrame:SetTitle("Actions pour " .. selectedPlayerName)
    actionFrame:MakePopup()

    local actionList = vgui.Create("DPanelList", actionFrame)
    actionList:Dock(FILL)
    actionList:EnableVerticalScrollbar(true)

    local function runULXCommand(command)
        RunConsoleCommand("ulx", command, selectedPlayerName)
        actionFrame:Close()
    end

    local actions = {
        {text = "Kick", command = "kick"},
        {text = "Ban", command = "ban"},
        {text = "JailTP", command = "jailtp"},
        {text = "Freeze", command = "freeze"},
        {text = "Slay", command = "slay"},
        {text = "Stripweapons", command = "stripweapons"}
    }

    for _, action in ipairs(actions) do
        local button = vgui.Create("DButton")
        button:SetText(action.text)
        button:Dock(TOP)
        button:DockMargin(0, 5, 0, 0)
        button:SetColor(Color(255, 255, 255))
        button.Paint = function(self, w, h)
            draw.RoundedBox(20, 0, 0, w, h, Color(45, 117, 20))
        end
        button.DoClick = function()
            runULXCommand(action.command)
        end
        actionList:AddItem(button)
    end
end

local function openmenu(ply)
    local frame = vgui.Create("DFrame")
    frame:SetSize(1100, 600) --Défini la taille. vous pouvez faire plus petit ou plus grand, attention à ajuster les positions des boutons si vous modifier
    frame:Center()
    frame:SetTitle("Panneau Admin | Nom de votre serveur")--Définir le nom que vous voulez.
    frame:MakePopup()
    frame:SetDraggable(false) --Fait en sorte qu'on ne puissent pas bouger la frame (Sur true = on pourra la bouger)

    --Desine la popup(Frame)
    frame.Paint = function(self, w, h)
        draw.RoundedBox(25, 0, 0, w, h, Color(155, 155, 155))
        draw.RoundedBox(60, 10, 50, w - 20, h - 60, Color(95, 95, 95))
    end
--Dessine le texte
    local label = vgui.Create("DLabel", frame)
    label:SetText("Event")
    label:SetPos(50, 50)
    label:SetColor(Color(255, 0, 0))
    label:SetFont("Default")
    label:SizeToContents()
--Dessine la baregrise
    local barreGrise1 = vgui.Create("Panel", frame)
    barreGrise1:SetPos(180, 50)
    barreGrise1:SetSize(2, frame:GetTall() - 50)
    barreGrise1.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(150, 150, 150, 255))
    end

    local labelUtilitaires = vgui.Create("DLabel", frame)
    labelUtilitaires:SetText("Utilitaires")
    labelUtilitaires:SetPos(190, 50)
    labelUtilitaires:SetColor(Color(255, 0, 0))
    labelUtilitaires:SetFont("Default")
    labelUtilitaires:SizeToContents()

    local buttonJailTP = vgui.Create("DButton", frame)
    buttonJailTP:SetText("JailTP")
    buttonJailTP:SetSize(150, 30)
    buttonJailTP:SetPos(190, 50 + labelUtilitaires:GetTall() + 10)
    buttonJailTP:SetColor(Color(0, 0, 0 ))
    buttonJailTP:SetFont("Default")
    buttonJailTP:SetImage("icon16/lock_add.png") 
    buttonJailTP.Paint = function(self, w, h)
        
        draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
    end



    buttonJailTP.DoClick = function()
        local playerSelectFrame = vgui.Create("DFrame")
        playerSelectFrame:SetSize(300, 400)
        playerSelectFrame:Center()
        playerSelectFrame:SetTitle("Sélectionner un joueur")
        playerSelectFrame:MakePopup()

        local playerListPopup = vgui.Create("DListView", playerSelectFrame)
        playerListPopup:Dock(FILL)
        playerListPopup:AddColumn("Joueur")

        for _, ply in pairs(player.GetAll()) do
            playerListPopup:AddLine(ply:Nick())
        end

        local selectButton = vgui.Create("DButton", playerSelectFrame)
        selectButton:Dock(BOTTOM)
        selectButton:SetText("Sélectionner le joueur")
        selectButton.DoClick = function()
            local selectedLine = playerListPopup:GetSelectedLine()
            if selectedLine then
                local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
                playerSelectFrame:Close()
                Derma_StringRequest(
                    "Durée de Jail",
                    "Pendant combien de secondes voulez-vous jail " .. selectedPlayerName .. "? (1 à 100)",
                    "",
                    function(text)
                        local jailTime = tonumber(text)
                        if jailTime and jailTime >= 1 and jailTime <= 100 then
                            RunConsoleCommand("ulx", "jailtp", selectedPlayerName, tostring(jailTime))
                        else
                            Derma_Message("Veuillez entrer une valeur valide entre 1 et 100.", "Erreur", "OK")
                        end
                    end,
                    function() end
                )
            else
                Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
            end
        end
    end
    local buttonBan = vgui.Create("DButton", frame)
    buttonBan:SetText("Ban")
    buttonBan:SetSize(150, 30)
    buttonBan:SetPos(190, 50 + labelUtilitaires:GetTall() + 50)
    buttonBan:SetColor(Color(0, 0, 0 ))
    buttonBan:SetFont("Default")
    buttonBan:SetImage("icon16/flag_red.png") 
    buttonBan.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
    end
    buttonBan.DoClick = function()
        local playerSelectFrame = vgui.Create("DFrame")
        playerSelectFrame:SetSize(300, 400)
        playerSelectFrame:Center()
        playerSelectFrame:SetTitle("Sélectionner un joueur")
        playerSelectFrame:MakePopup()

        local playerListPopup = vgui.Create("DListView", playerSelectFrame)
        playerListPopup:Dock(FILL)
        playerListPopup:AddColumn("Joueur")

        for _, ply in pairs(player.GetAll()) do
            playerListPopup:AddLine(ply:Nick())
        end

        local selectButton = vgui.Create("DButton", playerSelectFrame)
        selectButton:Dock(BOTTOM)
        selectButton:SetText("Sélectionner le joueur")
        selectButton.DoClick = function()
            local selectedLine = playerListPopup:GetSelectedLine()
            if selectedLine then
                local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
                playerSelectFrame:Close()
                Derma_StringRequest(
                    "Durée de Bannissement",
                    "Pendant combien de secondes voulez-vous bannir " .. selectedPlayerName .. "? (De 0 (Permanents) à 99999999999999)",
                    "",
                    function(text)
                        local bantime = tonumber(text)
                        if bantime and bantime >= 0 and bantime <= 99999999999999 then
                            RunConsoleCommand("ulx", "ban", selectedPlayerName, tostring(bantime), "Ban par le modérateur suivant : ")
                        else
                            Derma_Message("Veuillez entrer une valeur valide entre 0 et 99999999999999.", "Erreur", "OK")
                        end
                    end,
                    function() end
                )
            else
                Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
            end
        end
    end

   
    local buttonKick = vgui.Create("DButton", frame)
    buttonKick:SetText("Kick")
    buttonKick:SetSize(150, 30)
    buttonKick:SetPos(190, 50 + labelUtilitaires:GetTall() + 90)
    buttonKick:SetColor(Color(0, 0, 0 ))
    buttonKick:SetFont("Default")
    buttonKick:SetImage("icon16/flag_orange.png") 
    buttonKick.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
    end
    buttonKick.DoClick = function()
        local playerSelectFrame = vgui.Create("DFrame")
        playerSelectFrame:SetSize(300, 400)
        playerSelectFrame:Center()
        playerSelectFrame:SetTitle("Sélectionner un joueur")
        playerSelectFrame:MakePopup()

        local playerListPopup = vgui.Create("DListView", playerSelectFrame)
        playerListPopup:Dock(FILL)
        playerListPopup:AddColumn("Joueur")

        for _, ply in pairs(player.GetAll()) do
            playerListPopup:AddLine(ply:Nick())
        end

        local selectButton = vgui.Create("DButton", playerSelectFrame)
        selectButton:Dock(BOTTOM)
        selectButton:SetText("Sélectionner le joueur")
        selectButton.DoClick = function()
            local selectedLine = playerListPopup:GetSelectedLine()
            if selectedLine then
                local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
                playerSelectFrame:Close()
                RunConsoleCommand("ulx", "kick", selectedPlayerName, "Kick par l'administrateur")
            else
                Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
            end
        end
    end

    local buttonFreeze = vgui.Create("DButton", frame)
    buttonFreeze:SetText("Freeze")
    buttonFreeze:SetSize(150, 30)
    buttonFreeze:SetPos(190, 50 + labelUtilitaires:GetTall() + 130)
    buttonFreeze:SetColor(Color(0, 0, 0))
    buttonFreeze:SetFont("Default")
    buttonFreeze:SetImage("icon16/door_out.png") 
    buttonFreeze.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
    end
    buttonFreeze.DoClick = function()
        local playerSelectFrame = vgui.Create("DFrame")
        playerSelectFrame:SetSize(300, 400)
        playerSelectFrame:Center()
        playerSelectFrame:SetTitle("Sélectionner un joueur")
        playerSelectFrame:MakePopup()

        local playerListPopup = vgui.Create("DListView", playerSelectFrame)
        playerListPopup:Dock(FILL)
        playerListPopup:AddColumn("Joueur")

        for _, ply in pairs(player.GetAll()) do
            playerListPopup:AddLine(ply:Nick())
        end

        local selectButton = vgui.Create("DButton", playerSelectFrame)
        selectButton:Dock(BOTTOM)
        selectButton:SetText("Sélectionner le joueur")
        selectButton.DoClick = function()
            local selectedLine = playerListPopup:GetSelectedLine()
            if selectedLine then
                local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
                playerSelectFrame:Close()
                RunConsoleCommand("ulx", "freeze", selectedPlayerName)
            else
                Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
            end
        end
    end

local buttonUnfreeze = vgui.Create("DButton", frame)
buttonUnfreeze:SetText("Unfreeze")
buttonUnfreeze:SetSize(150, 30)
buttonUnfreeze:SetPos(190, 50 + labelUtilitaires:GetTall() + 170)
buttonUnfreeze:SetColor(Color(0, 0, 0))
buttonUnfreeze:SetFont("Default")
buttonUnfreeze:SetImage("icon16/door_in.png") 
buttonUnfreeze.Paint = function(self, w, h)
    
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
end
buttonUnfreeze.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Sélectionner un joueur")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()
            RunConsoleCommand("ulx", "unfreeze", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end
-- RunConsoleCommand("ulx", selectedPlayerName)

    local barreGrise2 = vgui.Create("Panel", frame)
    barreGrise2:SetPos(360, 50)
    barreGrise2:SetSize(2, frame:GetTall() - 50)
    barreGrise2.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(150, 150, 150, 255))
    end

    ------------------------
    local buttonTP = vgui.Create("DButton", frame)
    buttonTP:SetText("TP ALL")
    buttonTP:SetSize(150, 30)
    buttonTP:SetPos(22, 50 + label:GetTall() + 10)
    buttonTP:SetColor(Color(0, 0, 0 ))
    buttonTP:SetFont("Default")
    buttonTP:SetImage("icon16/lightning_add.png") 
    buttonTP.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(45, 117, 20))
    end
    buttonTP.DoClick = function()
        RunConsoleCommand("ulx", "bring", LocalPlayer():Nick())
    end

    local buttonHeal = vgui.Create("DButton", frame)
    buttonHeal:SetText("Heal all")
    buttonHeal:SetSize(150, 30)
    buttonHeal:SetPos(22, 50 + label:GetTall() + 60)
    buttonHeal:SetColor(Color(0, 0, 0  ))
    buttonHeal:SetFont("Default")
    buttonHeal:SetImage("icon16/heart_add.png") 
    buttonHeal.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(45, 117, 20))
    end
    buttonHeal.DoClick = function()
        RunConsoleCommand("ulx", "hp", "*", "100")
    end


local buttonArmor = vgui.Create("DButton", frame)
buttonArmor:SetText("Amure")
buttonArmor:SetSize(150, 30)
buttonArmor:SetPos(22, 50 + label:GetTall() + 110)
buttonArmor:SetColor(Color(0, 0, 0))
buttonArmor:SetFont("Default")
buttonArmor:SetImage("icon16/shield_add.png") 
buttonArmor.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(45, 117, 20))
end
buttonArmor.DoClick = function()
    RunConsoleCommand("ulx", "armor", "*", "100")
end

-- Ajout du bouton "!uncloak"
local buttonUncloak = vgui.Create("DButton", frame)
buttonUncloak:SetText("Uncloak")
buttonUncloak:SetSize(150, 30)
buttonUncloak:SetPos(22, 50 + label:GetTall() + 160)
buttonUncloak:SetColor(Color(0, 0, 0))
buttonUncloak:SetFont("Default")
buttonUncloak:SetImage("icon16/eye.png") 
buttonUncloak.Paint = function(self, w, h)
    
    draw.RoundedBox(20, 0, 0, w, h, Color(0, 255, 0))
end
buttonUncloak.DoClick = function()
    RunConsoleCommand("ulx", "uncloak", LocalPlayer():Nick())
end

-- Ajout du bouton "ungod"
local buttonUngod = vgui.Create("DButton", frame)
buttonUngod:SetText("Ungod")
buttonUngod:SetSize(150, 30)
buttonUngod:SetPos(22, 50 + label:GetTall() + 210)
buttonUngod:SetColor(Color(0, 0, 0))
buttonUngod:SetFont("Default")
buttonUngod:SetImage("icon16/heart_delete.png") 
buttonUngod.Paint = function(self, w, h)

    draw.RoundedBox(20, 0, 0, w, h, Color(0, 255, 0))
end
buttonUngod.DoClick = function()
    RunConsoleCommand("ulx", "ungod", LocalPlayer():Nick())
end
local buttonRetirerGun = vgui.Create("DButton", frame)
buttonRetirerGun:SetText("Strip")
buttonRetirerGun:SetSize(150, 30)
buttonRetirerGun:SetPos(22, 50 + label:GetTall() + 250)
buttonRetirerGun:SetColor(Color(0, 0, 0))
buttonRetirerGun:SetFont("Default")
buttonRetirerGun:SetImage("icon16/cancel.png") 
buttonRetirerGun.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(0, 255, 0))
end
buttonRetirerGun.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Sélectionner un joueur")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()
            RunConsoleCommand("ulx", "strip", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end
local buttonGoto = vgui.Create("DButton", frame)
buttonGoto:SetText("Allez à")
buttonGoto:SetSize(150, 30)
buttonGoto:SetPos(190, 50 + labelUtilitaires:GetTall() + 210)
buttonGoto:SetColor(Color(0, 0, 0))
buttonGoto:SetFont("Default")
buttonGoto:SetImage("icon16/lightning_go.png") 
buttonGoto.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
end
buttonGoto.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Sélectionner un joueur")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()
            RunConsoleCommand("ulx", "goto", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

-- Bouton "Téléporter ici (bring)"
local buttonBring = vgui.Create("DButton", frame)
buttonBring:SetText("TP ICI")
buttonBring:SetSize(150, 30)
buttonBring:SetPos(190, 50 + labelUtilitaires:GetTall() + 250)
buttonBring:SetColor(Color(0, 0, 0))
buttonBring:SetFont("Default")
buttonBring:SetImage("icon16/lightning.png") 
buttonBring.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
end
buttonBring.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Sélectionner un joueur")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()
            RunConsoleCommand("ulx", "bring", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

local labelFun = vgui.Create("DLabel", frame)
    labelFun:SetText("Fun")
    labelFun:SetPos(370, 50)  -- Ajustez la position en fonction de vos besoins
    labelFun:SetColor(Color(255, 0, 0))
    labelFun:SetFont("Default")
    labelFun:SizeToContents()

    local barreGrise3 = vgui.Create("Panel", frame)
    barreGrise3:SetPos(575, 50)
    barreGrise3:SetSize(2, frame:GetTall() - 50)
    barreGrise3.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(150, 150, 150, 255))
    end

    local buttonIgnite = vgui.Create("DButton", frame)
buttonIgnite:SetText("Mettre En feu")
buttonIgnite:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonIgnite:SetPos(370, 50 + labelFun:GetTall() + 10)  -- Ajustez la position en fonction de vos besoins
buttonIgnite:SetColor(Color(0, 0, 0))
buttonIgnite:SetFont("Default")
buttonIgnite:SetImage("icon16/pill.png") 
buttonIgnite.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonIgnite.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sur de vouloir le mettre en feu ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            Derma_StringRequest(
                "Mettre en feu",
                "Pendant combien de secondes voulez-vous mettre en feu " .. selectedPlayerName .. "? (1 à 500)",
                "",
                function(text)
                    local igniteTime = tonumber(text)
                    if igniteTime and igniteTime >= 1 and igniteTime <= 500 then
                        RunConsoleCommand("ulx","ignite", selectedPlayerName, tostring(igniteTime))
                    else
                        Derma_Message("Veuillez entrer une valeur valide entre 1 et 100.", "Erreur", "OK")
                    end
                end,
                function() end
            )
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end
local buttonExtinguish = vgui.Create("DButton", frame)
buttonExtinguish:SetText("Retirer le feu ")
buttonExtinguish:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonExtinguish:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + 20)  -- Ajustez la position en fonction de vos besoins
buttonExtinguish:SetColor(Color(0, 0, 0))
buttonExtinguish:SetFont("Default")
buttonExtinguish:SetImage("icon16/cancel.png") 
buttonExtinguish.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonExtinguish.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir éteindre le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            -- Éteindre le joueur
            RunConsoleCommand("ulx", "unignite", selectedPlayerName )
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

local buttonWhip = vgui.Create("DButton", frame)
buttonWhip:SetText("Faire sauter")
buttonWhip:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonWhip:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + buttonExtinguish:GetTall() + 30)  -- Ajustez la position en fonction de vos besoins
buttonWhip:SetColor(Color(0, 0, 0))
buttonWhip:SetFont("Default")
buttonWhip:SetImage("icon16/arrow_up.png") 
buttonWhip.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonWhip.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir faire sauter le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            Derma_StringRequest(
                "Faire sauter",
                "Pendant combien de secondes voulez-vous faire sauter " .. selectedPlayerName .. "? (1 à 100)",
                "",
                function(text)
                    local whipTime = tonumber(text)
                    if whipTime and whipTime >= 1 and whipTime <= 100 then
                        -- Faire sauter le joueur
                        RunConsoleCommand("ulx", "whip", selectedPlayerName, tostring(whipTime))
                    else
                        Derma_Message("Veuillez entrer une valeur valide entre 1 et 100.", "Erreur", "OK")
                    end
                end,
                function() end
            )
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end
local buttonRagdoll = vgui.Create("DButton", frame)
buttonRagdoll:SetText("Ragdoll")
buttonRagdoll:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonRagdoll:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + buttonExtinguish:GetTall() + buttonWhip:GetTall() + 50)  -- Ajustez la position en fonction de vos besoins
buttonRagdoll:SetColor(Color(0, 0, 0))
buttonRagdoll:SetFont("Default")
buttonRagdoll:SetImage("icon16/pill_add.png") 
buttonRagdoll.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonRagdoll.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir ragdoll le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            -- Ragdoll le joueur
            RunConsoleCommand("ulx", "ragdoll", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

-- Ajout du bouton "Unragdoll"
local buttonUnragdoll = vgui.Create("DButton", frame)
buttonUnragdoll:SetText("Unragdoll")
buttonUnragdoll:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonUnragdoll:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + buttonExtinguish:GetTall() + buttonWhip:GetTall() + buttonRagdoll:GetTall() + 70)  -- Ajustez la position en fonction de vos besoins
buttonUnragdoll:SetColor(Color(0, 0, 0))
buttonUnragdoll:SetFont("Default")
buttonUnragdoll.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonUnragdoll.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir unragdoll le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            -- Unragdoll le joueur
            RunConsoleCommand("ulx", "unragdoll", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

local labelFun = vgui.Create("DLabel", frame)
    labelFun:SetText("Fun")
    labelFun:SetPos(370, 50)  -- Ajustez la position en fonction de vos besoins
    labelFun:SetColor(Color(255, 0, 0))
    labelFun:SetFont("Default")
    labelFun:SizeToContents()

    local barreGrise4 = vgui.Create("Panel", frame)
    barreGrise4:SetPos(770, 50)
    barreGrise4:SetSize(2, frame:GetTall() - 50)
    barreGrise4.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(150, 150, 150, 255))
    end

local buttonUnragdoll = vgui.Create("DButton", frame)
buttonUnragdoll:SetText("Unragdoll")
buttonUnragdoll:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonUnragdoll:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + buttonExtinguish:GetTall() + buttonWhip:GetTall() + buttonRagdoll:GetTall() + 70)  -- Ajustez la position en fonction de vos besoins
buttonUnragdoll:SetColor(Color(0, 0, 0))
buttonUnragdoll:SetFont("Default")
buttonUnragdoll:SetImage("icon16/pill_delete.png") 
buttonUnragdoll.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonUnragdoll.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir unragdoll le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            -- Unragdoll le joueur
            RunConsoleCommand("ulx", "unragdoll", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

local labelTp = vgui.Create("DLabel", frame)
labelTp:SetText("Téléportation")
labelTp:SetPos(590, 50)  -- Ajustez la position en fonction de vos besoins
labelTp:SetColor(Color(255, 0, 0))
labelTp:SetFont("Default")
labelTp:SizeToContents()


    local labelPlayers = vgui.Create("DLabel", frame)
    labelPlayers:SetText("Joueurs")
    labelPlayers:SetPos(frame:GetWide() - 320,50)
    labelPlayers:SetColor(Color(0, 0, 0 ))
    labelPlayers:SetFont("Default")
    labelPlayers:SizeToContents()

    local playerList = vgui.Create("DListView", frame)
    playerList:SetPos(frame:GetWide() - 320, 50 + labelPlayers:GetTall() + 2)
    playerList:SetSize(200, frame:GetTall() - 50 - labelPlayers:GetTall() - 20)
    playerList:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        local listItem = playerList:AddLine(ply:Nick())
        listItem.OnClick = function()
            createPlayerActionButtons(ply:Nick(), frame)
        end
    end
end

local allowedRoles = {
    ["Modérateur-Test"] = true,
    ["Modérateur"] = true,
    ["Responsable-Modération"] = true,
    ["superadmin"] = true
}

local function chatCommand(ply, text, teamChat, isDead)
    if string.lower(text) == "!panel" and ply == LocalPlayer() then
        if allowedRoles[ply:GetUserGroup()] then
            openmenu()
        else
            chat.AddText(Color(255, 0, 0), "Vous n'avez pas les permissions nécessaires pour exécuter cette commande.")
        end
        return true
    end
end

hook.Add("OnPlayerChat", "CheckPanelCommand", chatCommand)


---Fin du !admin

--Début des frames

surface.CreateFont("Default", {
    font = "Arial",
    size = ScrH() * 0.03,
    weight = 500,
    antialias = true,
    shadow = false
})

local function createPlayerActionButtons(selectedPlayerName, playerListFrame)
    local actionFrame = vgui.Create("DFrame")
    actionFrame:SetSize(200, 250)
    actionFrame:Center()
    actionFrame:SetTitle("Actions pour " .. selectedPlayerName)
    actionFrame:MakePopup()

    local actionList = vgui.Create("DPanelList", actionFrame)
    actionList:Dock(FILL)
    actionList:EnableVerticalScrollbar(true)

    local function runULXCommand(command)
        RunConsoleCommand("ulx", command, selectedPlayerName)
        actionFrame:Close()
    end

    local actions = {
        {text = "Kick", command = "kick"},
        {text = "Ban", command = "ban"},
        {text = "JailTP", command = "jailtp"},
        {text = "Freeze", command = "freeze"},
        {text = "Slay", command = "slay"},
        {text = "Stripweapons", command = "stripweapons"}
    }

    for _, action in ipairs(actions) do
        local button = vgui.Create("DButton")
        button:SetText(action.text)
        button:Dock(TOP)
        button:DockMargin(0, 5, 0, 0)
        button:SetColor(Color(255, 255, 255))
        button.Paint = function(self, w, h)
            draw.RoundedBox(20, 0, 0, w, h, Color(45, 117, 20))
        end
        button.DoClick = function()
            runULXCommand(action.command)
        end
        actionList:AddItem(button)
    end
end

local function openmenu(ply)
    local frame = vgui.Create("DFrame")
    frame:SetSize(1100, 600)
    frame:Center()
    frame:SetTitle("Panneau Admin | Ash")
    frame:MakePopup()
    frame:SetDraggable(false)

    frame.Paint = function(self, w, h)
        draw.RoundedBox(25, 0, 0, w, h, Color(155, 155, 155))
        draw.RoundedBox(60, 10, 50, w - 20, h - 60, Color(95, 95, 95))
    end

    local label = vgui.Create("DLabel", frame)
    label:SetText("Event")
    label:SetPos(50, 50)
    label:SetColor(Color(255, 0, 0))
    label:SetFont("Default")
    label:SizeToContents()

    local barreGrise1 = vgui.Create("Panel", frame)
    barreGrise1:SetPos(180, 50)
    barreGrise1:SetSize(2, frame:GetTall() - 50)
    barreGrise1.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(150, 150, 150, 255))
    end

    local labelUtilitaires = vgui.Create("DLabel", frame)
    labelUtilitaires:SetText("Utilitaires")
    labelUtilitaires:SetPos(190, 50)
    labelUtilitaires:SetColor(Color(255, 0, 0))
    labelUtilitaires:SetFont("Default")
    labelUtilitaires:SizeToContents()

    local buttonJailTP = vgui.Create("DButton", frame)
    buttonJailTP:SetText("JailTP")
    buttonJailTP:SetSize(150, 30)
    buttonJailTP:SetPos(190, 50 + labelUtilitaires:GetTall() + 10)
    buttonJailTP:SetColor(Color(0, 0, 0 ))
    buttonJailTP:SetFont("Default")
    buttonJailTP.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
    end



    buttonJailTP.DoClick = function()
        local playerSelectFrame = vgui.Create("DFrame")
        playerSelectFrame:SetSize(300, 400)
        playerSelectFrame:Center()
        playerSelectFrame:SetTitle("Sélectionner un joueur")
        playerSelectFrame:MakePopup()

        local playerListPopup = vgui.Create("DListView", playerSelectFrame)
        playerListPopup:Dock(FILL)
        playerListPopup:AddColumn("Joueur")

        for _, ply in pairs(player.GetAll()) do
            playerListPopup:AddLine(ply:Nick())
        end

        local selectButton = vgui.Create("DButton", playerSelectFrame)
        selectButton:Dock(BOTTOM)
        selectButton:SetText("Sélectionner le joueur")
        selectButton.DoClick = function()
            local selectedLine = playerListPopup:GetSelectedLine()
            if selectedLine then
                local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
                playerSelectFrame:Close()
                Derma_StringRequest(
                    "Durée de Jail",
                    "Pendant combien de secondes voulez-vous jail " .. selectedPlayerName .. "? (1 à 100)",
                    "",
                    function(text)
                        local jailTime = tonumber(text)
                        if jailTime and jailTime >= 1 and jailTime <= 100 then
                            RunConsoleCommand("ulx", "jailtp", selectedPlayerName, tostring(jailTime))
                        else
                            Derma_Message("Veuillez entrer une valeur valide entre 1 et 100.", "Erreur", "OK")
                        end
                    end,
                    function() end
                )
            else
                Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
            end
        end
    end
    local buttonBan = vgui.Create("DButton", frame)
    buttonBan:SetText("Ban")
    buttonBan:SetSize(150, 30)
    buttonBan:SetPos(190, 50 + labelUtilitaires:GetTall() + 50)
    buttonBan:SetColor(Color(0, 0, 0 ))
    buttonBan:SetFont("Default")
    buttonBan.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
    end
    buttonBan.DoClick = function()
        local playerSelectFrame = vgui.Create("DFrame")
        playerSelectFrame:SetSize(300, 400)
        playerSelectFrame:Center()
        playerSelectFrame:SetTitle("Sélectionner un joueur")
        playerSelectFrame:MakePopup()

        local playerListPopup = vgui.Create("DListView", playerSelectFrame)
        playerListPopup:Dock(FILL)
        playerListPopup:AddColumn("Joueur")

        for _, ply in pairs(player.GetAll()) do
            playerListPopup:AddLine(ply:Nick())
        end

        local selectButton = vgui.Create("DButton", playerSelectFrame)
        selectButton:Dock(BOTTOM)
        selectButton:SetText("Sélectionner le joueur")
        selectButton.DoClick = function()
            local selectedLine = playerListPopup:GetSelectedLine()
            if selectedLine then
                local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
                playerSelectFrame:Close()
                Derma_StringRequest(
                    "Durée de Bannissement",
                    "Pendant combien de secondes voulez-vous bannir " .. selectedPlayerName .. "? (De 0 (Permanents) à 99999999999999)",
                    "",
                    function(text)
                        local bantime = tonumber(text)
                        if bantime and bantime >= 0 and bantime <= 99999999999999 then
                            RunConsoleCommand("ulx", "ban", selectedPlayerName, tostring(bantime), "Ban par le modérateur suivant : ")
                        else
                            Derma_Message("Veuillez entrer une valeur valide entre 0 et 99999999999999.", "Erreur", "OK")
                        end
                    end,
                    function() end
                )
            else
                Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
            end
        end
    end

   
    local buttonKick = vgui.Create("DButton", frame)
    buttonKick:SetText("Kick")
    buttonKick:SetSize(150, 30)
    buttonKick:SetPos(190, 50 + labelUtilitaires:GetTall() + 90)
    buttonKick:SetColor(Color(0, 0, 0 ))
    buttonKick:SetFont("Default")
    buttonKick.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
    end
    buttonKick.DoClick = function()
        local playerSelectFrame = vgui.Create("DFrame")
        playerSelectFrame:SetSize(300, 400)
        playerSelectFrame:Center()
        playerSelectFrame:SetTitle("Sélectionner un joueur")
        playerSelectFrame:MakePopup()

        local playerListPopup = vgui.Create("DListView", playerSelectFrame)
        playerListPopup:Dock(FILL)
        playerListPopup:AddColumn("Joueur")

        for _, ply in pairs(player.GetAll()) do
            playerListPopup:AddLine(ply:Nick())
        end

        local selectButton = vgui.Create("DButton", playerSelectFrame)
        selectButton:Dock(BOTTOM)
        selectButton:SetText("Sélectionner le joueur")
        selectButton.DoClick = function()
            local selectedLine = playerListPopup:GetSelectedLine()
            if selectedLine then
                local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
                playerSelectFrame:Close()
                RunConsoleCommand("ulx", "kick", selectedPlayerName, "Kick par l'administrateur")
            else
                Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
            end
        end
    end

    local buttonFreeze = vgui.Create("DButton", frame)
    buttonFreeze:SetText("Freeze")
    buttonFreeze:SetSize(150, 30)
    buttonFreeze:SetPos(190, 50 + labelUtilitaires:GetTall() + 130)
    buttonFreeze:SetColor(Color(0, 0, 0))
    buttonFreeze:SetFont("Default")
    buttonFreeze.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
    end
    buttonFreeze.DoClick = function()
        local playerSelectFrame = vgui.Create("DFrame")
        playerSelectFrame:SetSize(300, 400)
        playerSelectFrame:Center()
        playerSelectFrame:SetTitle("Sélectionner un joueur")
        playerSelectFrame:MakePopup()

        local playerListPopup = vgui.Create("DListView", playerSelectFrame)
        playerListPopup:Dock(FILL)
        playerListPopup:AddColumn("Joueur")

        for _, ply in pairs(player.GetAll()) do
            playerListPopup:AddLine(ply:Nick())
        end

        local selectButton = vgui.Create("DButton", playerSelectFrame)
        selectButton:Dock(BOTTOM)
        selectButton:SetText("Sélectionner le joueur")
        selectButton.DoClick = function()
            local selectedLine = playerListPopup:GetSelectedLine()
            if selectedLine then
                local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
                playerSelectFrame:Close()
                RunConsoleCommand("ulx", "freeze", selectedPlayerName)
            else
                Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
            end
        end
    end

local buttonUnfreeze = vgui.Create("DButton", frame)
buttonUnfreeze:SetText("Unfreeze")
buttonUnfreeze:SetSize(150, 30)
buttonUnfreeze:SetPos(190, 50 + labelUtilitaires:GetTall() + 170)
buttonUnfreeze:SetColor(Color(0, 0, 0))
buttonUnfreeze:SetFont("Default")
buttonUnfreeze.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
end
buttonUnfreeze.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Sélectionner un joueur")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()
            RunConsoleCommand("ulx", "unfreeze", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end
-- RunConsoleCommand("ulx", selectedPlayerName)

    local barreGrise2 = vgui.Create("Panel", frame)
    barreGrise2:SetPos(360, 50)
    barreGrise2:SetSize(2, frame:GetTall() - 50)
    barreGrise2.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(150, 150, 150, 255))
    end

    ------------------------
    local buttonTP = vgui.Create("DButton", frame)
    buttonTP:SetText("TP ALL")
    buttonTP:SetSize(150, 30)
    buttonTP:SetPos(22, 50 + label:GetTall() + 10)
    buttonTP:SetColor(Color(0, 0, 0 ))
    buttonTP:SetFont("Default")
    buttonTP.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(45, 117, 20))
    end
    buttonTP.DoClick = function()
        RunConsoleCommand("ulx", "bring", LocalPlayer():Nick())
    end

    local buttonHeal = vgui.Create("DButton", frame)
    buttonHeal:SetText("Heal all")
    buttonHeal:SetSize(150, 30)
    buttonHeal:SetPos(22, 50 + label:GetTall() + 60)
    buttonHeal:SetColor(Color(0, 0, 0  ))
    buttonHeal:SetFont("Default")
    buttonHeal.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, Color(45, 117, 20))
    end
    buttonHeal.DoClick = function()
        RunConsoleCommand("ulx", "hp", "*", "100")
    end


local buttonArmor = vgui.Create("DButton", frame)
buttonArmor:SetText("Set Armure")
buttonArmor:SetSize(150, 30)
buttonArmor:SetPos(22, 50 + label:GetTall() + 110)
buttonArmor:SetColor(Color(0, 0, 0))
buttonArmor:SetFont("Default")
buttonArmor.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(45, 117, 20))
end
buttonArmor.DoClick = function()
    RunConsoleCommand("ulx", "armor", "*", "100")
end

-- Ajout du bouton "!uncloak"
local buttonUncloak = vgui.Create("DButton", frame)
buttonUncloak:SetText("Uncloak")
buttonUncloak:SetSize(150, 30)
buttonUncloak:SetPos(22, 50 + label:GetTall() + 160)
buttonUncloak:SetColor(Color(0, 0, 0))
buttonUncloak:SetFont("Default")
buttonUncloak.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(0, 255, 0))
end
buttonUncloak.DoClick = function()
    RunConsoleCommand("ulx", "uncloak", LocalPlayer():Nick())
end

-- Ajout du bouton "ungod"
local buttonUngod = vgui.Create("DButton", frame)
buttonUngod:SetText("Ungod")
buttonUngod:SetSize(150, 30)
buttonUngod:SetPos(22, 50 + label:GetTall() + 210)
buttonUngod:SetColor(Color(0, 0, 0))
buttonUngod:SetFont("Default")
buttonUngod.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(0, 255, 0))
end
buttonUngod.DoClick = function()
    RunConsoleCommand("ulx", "ungod", LocalPlayer():Nick())
end
local buttonRetirerGun = vgui.Create("DButton", frame)
buttonRetirerGun:SetText("RetirerGun")
buttonRetirerGun:SetSize(150, 30)
buttonRetirerGun:SetPos(22, 50 + label:GetTall() + 250)
buttonRetirerGun:SetColor(Color(0, 0, 0))
buttonRetirerGun:SetFont("Default")
buttonRetirerGun.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(0, 255, 0))
end
buttonRetirerGun.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Sélectionner un joueur")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()
            RunConsoleCommand("ulx", "strip", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end
local buttonGoto = vgui.Create("DButton", frame)
buttonGoto:SetText("Allez à")
buttonGoto:SetSize(150, 30)
buttonGoto:SetPos(190, 50 + labelUtilitaires:GetTall() + 210)
buttonGoto:SetColor(Color(0, 0, 0))
buttonGoto:SetFont("Default")
buttonGoto.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
end
buttonGoto.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Sélectionner un joueur")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()
            RunConsoleCommand("ulx", "goto", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

-- Bouton "Téléporter ici (bring)"
local buttonBring = vgui.Create("DButton", frame)
buttonBring:SetText("TP ICI")
buttonBring:SetSize(150, 30)
buttonBring:SetPos(190, 50 + labelUtilitaires:GetTall() + 250)
buttonBring:SetColor(Color(0, 0, 0))
buttonBring:SetFont("Default")
buttonBring.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 0, 0))
end
buttonBring.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Sélectionner un joueur")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()
            RunConsoleCommand("ulx", "bring", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

local labelFun = vgui.Create("DLabel", frame)
    labelFun:SetText("Fun")
    labelFun:SetPos(370, 50)  -- Ajustez la position en fonction de vos besoins
    labelFun:SetColor(Color(255, 0, 0))
    labelFun:SetFont("Default")
    labelFun:SizeToContents()

    local barreGrise3 = vgui.Create("Panel", frame)
    barreGrise3:SetPos(575, 50)
    barreGrise3:SetSize(2, frame:GetTall() - 50)
    barreGrise3.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(150, 150, 150, 255))
    end

    local buttonIgnite = vgui.Create("DButton", frame)
buttonIgnite:SetText("Mettre En feu")
buttonIgnite:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonIgnite:SetPos(370, 50 + labelFun:GetTall() + 10)  -- Ajustez la position en fonction de vos besoins
buttonIgnite:SetColor(Color(0, 0, 0))
buttonIgnite:SetFont("Default")
buttonIgnite.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonIgnite.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sur de vouloir le mettre en feu ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            Derma_StringRequest(
                "Mettre en feu",
                "Pendant combien de secondes voulez-vous mettre en feu " .. selectedPlayerName .. "? (1 à 500)",
                "",
                function(text)
                    local igniteTime = tonumber(text)
                    if igniteTime and igniteTime >= 1 and igniteTime <= 500 then
                        RunConsoleCommand("ulx","ignite", selectedPlayerName, tostring(igniteTime))
                    else
                        Derma_Message("Veuillez entrer une valeur valide entre 1 et 100.", "Erreur", "OK")
                    end
                end,
                function() end
            )
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end
local buttonExtinguish = vgui.Create("DButton", frame)
buttonExtinguish:SetText("Retirer le feu ")
buttonExtinguish:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonExtinguish:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + 20)  -- Ajustez la position en fonction de vos besoins
buttonExtinguish:SetColor(Color(0, 0, 0))
buttonExtinguish:SetFont("Default")
buttonExtinguish.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonExtinguish.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir éteindre le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            -- Éteindre le joueur
            RunConsoleCommand("ulx", "unignite", selectedPlayerName )
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

local buttonWhip = vgui.Create("DButton", frame)
buttonWhip:SetText("Faire sauter")
buttonWhip:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonWhip:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + buttonExtinguish:GetTall() + 30)  -- Ajustez la position en fonction de vos besoins
buttonWhip:SetColor(Color(0, 0, 0))
buttonWhip:SetFont("Default")
buttonWhip.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonWhip.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir faire sauter le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            Derma_StringRequest(
                "Faire sauter",
                "Pendant combien de secondes voulez-vous faire sauter " .. selectedPlayerName .. "? (1 à 100)",
                "",
                function(text)
                    local whipTime = tonumber(text)
                    if whipTime and whipTime >= 1 and whipTime <= 100 then
                        -- Faire sauter le joueur
                        RunConsoleCommand("ulx", "whip", selectedPlayerName, tostring(whipTime))
                    else
                        Derma_Message("Veuillez entrer une valeur valide entre 1 et 100.", "Erreur", "OK")
                    end
                end,
                function() end
            )
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end
local buttonRagdoll = vgui.Create("DButton", frame)
buttonRagdoll:SetText("Ragdoll")
buttonRagdoll:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonRagdoll:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + buttonExtinguish:GetTall() + buttonWhip:GetTall() + 50)  -- Ajustez la position en fonction de vos besoins
buttonRagdoll:SetColor(Color(0, 0, 0))
buttonRagdoll:SetFont("Default")
buttonRagdoll.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonRagdoll.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir ragdoll le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            -- Ragdoll le joueur
            RunConsoleCommand("ulx", "ragdoll", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

-- Ajout du bouton "Unragdoll"
local buttonUnragdoll = vgui.Create("DButton", frame)
buttonUnragdoll:SetText("Unragdoll")
buttonUnragdoll:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonUnragdoll:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + buttonExtinguish:GetTall() + buttonWhip:GetTall() + buttonRagdoll:GetTall() + 70)  -- Ajustez la position en fonction de vos besoins
buttonUnragdoll:SetColor(Color(0, 0, 0))
buttonUnragdoll:SetFont("Default")
buttonUnragdoll.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonUnragdoll.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir unragdoll le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            -- Unragdoll le joueur
            RunConsoleCommand("ulx", "unragdoll", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

local labelFun = vgui.Create("DLabel", frame)
    labelFun:SetText("Fun")
    labelFun:SetPos(370, 50)  -- Ajustez la position en fonction de vos besoins
    labelFun:SetColor(Color(255, 0, 0))
    labelFun:SetFont("Default")
    labelFun:SizeToContents()

    local barreGrise4 = vgui.Create("Panel", frame)
    barreGrise4:SetPos(770, 50)
    barreGrise4:SetSize(2, frame:GetTall() - 50)
    barreGrise4.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(150, 150, 150, 255))
    end

local buttonUnragdoll = vgui.Create("DButton", frame)
buttonUnragdoll:SetText("Unragdoll")
buttonUnragdoll:SetSize(200, 30)  -- Ajustez la largeur du bouton
buttonUnragdoll:SetPos(370, 50 + labelFun:GetTall() + buttonIgnite:GetTall() + buttonExtinguish:GetTall() + buttonWhip:GetTall() + buttonRagdoll:GetTall() + 70)  -- Ajustez la position en fonction de vos besoins
buttonUnragdoll:SetColor(Color(0, 0, 0))
buttonUnragdoll:SetFont("Default")
buttonUnragdoll.Paint = function(self, w, h)
    draw.RoundedBox(20, 0, 0, w, h, Color(255, 140, 0))  -- Couleur orange
end
buttonUnragdoll.DoClick = function()
    local playerSelectFrame = vgui.Create("DFrame")
    playerSelectFrame:SetSize(300, 400)
    playerSelectFrame:Center()
    playerSelectFrame:SetTitle("Vous êtes sûr de vouloir unragdoll le joueur ?")
    playerSelectFrame:MakePopup()

    local playerListPopup = vgui.Create("DListView", playerSelectFrame)
    playerListPopup:Dock(FILL)
    playerListPopup:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        playerListPopup:AddLine(ply:Nick())
    end

    local selectButton = vgui.Create("DButton", playerSelectFrame)
    selectButton:Dock(BOTTOM)
    selectButton:SetText("Sélectionner le joueur")
    selectButton.DoClick = function()
        local selectedLine = playerListPopup:GetSelectedLine()
        if selectedLine then
            local selectedPlayerName = playerListPopup:GetLine(selectedLine):GetColumnText(1)
            playerSelectFrame:Close()

            -- Unragdoll le joueur
            RunConsoleCommand("ulx", "unragdoll", selectedPlayerName)
        else
            Derma_Message("Veuillez sélectionner un joueur.", "Erreur", "OK")
        end
    end
end

local labelTp = vgui.Create("DLabel", frame)
labelTp:SetText("Téléportation")
labelTp:SetPos(590, 50)  -- Ajustez la position en fonction de vos besoins
labelTp:SetColor(Color(255, 0, 0))
labelTp:SetFont("Default")
labelTp:SizeToContents()


    local labelPlayers = vgui.Create("DLabel", frame)
    labelPlayers:SetText("Joueurs")
    labelPlayers:SetPos(frame:GetWide() - 320,50)
    labelPlayers:SetColor(Color(0, 0, 0 ))
    labelPlayers:SetFont("Default")
    labelPlayers:SizeToContents()

    local playerList = vgui.Create("DListView", frame)
    playerList:SetPos(frame:GetWide() - 320, 50 + labelPlayers:GetTall() + 2)
    playerList:SetSize(200, frame:GetTall() - 50 - labelPlayers:GetTall() - 20)
    playerList:AddColumn("Joueur")

    for _, ply in pairs(player.GetAll()) do
        local listItem = playerList:AddLine(ply:Nick())
        listItem.OnClick = function()
            createPlayerActionButtons(ply:Nick(), frame)
        end
    end
end

local allowedRoles = {
    ["Modérateur-Test"] = true,
    ["Modérateur"] = true,
    ["Responsable-Modération"] = true,
    ["superadmin"] = true
}

local function chatCommand(ply, text, teamChat, isDead)
    if string.lower(text) == "!panel" and ply == LocalPlayer() then
        if allowedRoles[ply:GetUserGroup()] then
            openmenu()
        else
            chat.AddText(Color(255, 0, 0), "Vous n'avez pas les permissions nécessaires pour exécuter cette commande.")
        end
        return true
    end
end

hook.Add("OnPlayerChat", "CheckPanelCommand", chatCommand)
