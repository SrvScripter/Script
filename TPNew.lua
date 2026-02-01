Settings = ac.storage({
	KeyValue = 999, --key value for ac
	KeyName = "", --key name for user
	TPtoCam = false,
	ShowKeyTP = true,
	tpDistance = 8,
	SpectatePlayer = false,
	MousetoTrackRays = false,
	MousetoTrackRays_updates = "500",
	MousetoTrackRays_Chord_keyValue = 999,
	MousetoTrackRays_Chord_KeyName = "",
	MousetoTrackRays_pos_keyValue = 999,
	MousetoTrackRays_pos_KeyName = "",
	MousetoTrackRays_dir_keyValue = 999,
	MousetoTrackRays_dir_KeyName = "",
	MousetoTrackRays_TP_keyValue = 999,
	MousetoTrackRays_TP_KeyName = "",
	-- Teleport İzin Sistemi
	AllowOthersToMe = true, -- Başkalarının bana ışınlanmasına izin ver
	ShowTeleportMessage = false, -- Chat'e "ışınlandın" mesajı göster
	-- Arkadaşlar ve Karaliste (virgülle ayrılmış string olarak saklanır)
	ArkadaşlarStr = "", -- İznim kapalı olsa bile ışınlanabilenler "Player1,Player2,Player3"
	KaralisteStr = "", -- İznim açık olsa bile ışınlanamAyanlar "Troll1,Troll2"
})

-- String'den tablo'ya çevirme fonksiyonları
local function parseList(str)
	local list = {}
	if str and str ~= "" then
		for name in string.gmatch(str, "[^,]+") do
			table.insert(list, name)
		end
	end
	return list
end

local function listToString(list)
	return table.concat(list, ",")
end

-- Runtime tablolar
local Arkadaşlar = parseList(Settings.ArkadaşlarStr)
local Karaliste = parseList(Settings.KaralisteStr)

-- Listeyi kaydet
local function saveArkadaşlar()
	Settings.ArkadaşlarStr = listToString(Arkadaşlar)
end

local function saveKaraliste()
	Settings.KaralisteStr = listToString(Karaliste)
end

-- Network İzin Sistemi (Chat-Based)
local playerPermissions = {} -- [driverName] = true/false
local lastPermissionUpdate = {} -- [driverName] = timestamp
local myLastBroadcast = 0
local myLastBroadcastedStatus = nil -- Son broadcast edilen durum
local BROADCAST_INTERVAL = 30 -- Saniye (log spam'ini azaltmak için artırıldı)
local PERMISSION_TIMEOUT = 45 -- Saniye

-- SteamID Network Paylaşımı
local playerSteamIDs = {} -- [driverName] = steamID
local mySteamID = nil
local lastSteamBroadcast = 0
local STEAM_BROADCAST_INTERVAL = 60 -- 60 saniyede bir

-- Ses olmadan chat mesajı gönder (gizli protokol)
local function sendHiddenMessage(msg)
	-- Chat'e gönder (daha az sıklıkta)
	ac.sendChatMessage(msg)
end

-- Kendi izin durumunu broadcast et (sadece değişiklik varsa)
local function broadcastMyPermission(force)
	local status = Settings.AllowOthersToMe and "1" or "0"
	local currentTime = os.clock()
	
	-- Sadece durum değişmişse gönder (spam önlemek için)
	if force or myLastBroadcastedStatus ~= status then
		local myName = ac.getDriverName(0)
		local message = "TP:" .. myName .. ":" .. status
		
		-- Arkadaşlar varsa ekle
		if #Arkadaşlar > 0 then
			message = message .. ":WL:" .. table.concat(Arkadaşlar, ",")
		end
		
		-- Karaliste varsa ekle
		if #Karaliste > 0 then
			message = message .. ":BL:" .. table.concat(Karaliste, ",")
		end
		
		sendHiddenMessage(message)
		myLastBroadcast = currentTime
		myLastBroadcastedStatus = status
    end
end

-- SteamID broadcast et
local function broadcastMySteamID(force)
	local currentTime = os.clock()
	
	-- İlk kez al
	if not mySteamID and ac.getUserSteamID then
		mySteamID = ac.getUserSteamID()
	end
	
	-- Eğer SteamID varsa ve broadcast zamanı geldiyse
	if mySteamID and mySteamID ~= "" and mySteamID ~= "0" then
		if force or (currentTime - lastSteamBroadcast) >= STEAM_BROADCAST_INTERVAL then
			local myName = ac.getDriverName(0)
			sendHiddenMessage("STEAM:" .. myName .. ":" .. mySteamID)
			lastSteamBroadcast = currentTime
		end
	end
end

-- Arkadaşlar/Karaliste kontrol fonksiyonları
local function isInArkadaşlar(playerName)
	for _, name in ipairs(Arkadaşlar) do
		if name == playerName then
			return true
		end
	end
	return false
end

local function isInKaraliste(playerName)
	for _, name in ipairs(Karaliste) do
		if name == playerName then
			return true
		end
	end
	return false
end

local function addToArkadaşlar(playerName)
	-- Karaliste'ten çıkar
	for i, name in ipairs(Karaliste) do
		if name == playerName then
			table.remove(Karaliste, i)
			break
		end
	end
	saveKaraliste()
	
	-- Arkadaşlar'a ekle (eğer yoksa)
	if not isInArkadaşlar(playerName) then
		table.insert(Arkadaşlar, playerName)
		saveArkadaşlar()
		-- Hemen broadcast et
		broadcastMyPermission(true)
	end
end

local function addToKaraliste(playerName)
	-- Arkadaşlar'dan çıkar
	for i, name in ipairs(Arkadaşlar) do
		if name == playerName then
			table.remove(Arkadaşlar, i)
			break
		end
	end
	saveArkadaşlar()
	
	-- Karaliste'ye ekle (eğer yoksa)
	if not isInKaraliste(playerName) then
		table.insert(Karaliste, playerName)
		saveKaraliste()
		-- Hemen broadcast et
		broadcastMyPermission(true)
	end
end

local function removeFromArkadaşlar(playerName)
	for i, name in ipairs(Arkadaşlar) do
		if name == playerName then
			table.remove(Arkadaşlar, i)
			saveArkadaşlar()
			-- Hemen broadcast et
			broadcastMyPermission(true)
			return true
		end
	end
	return false
end

local function removeFromKaraliste(playerName)
	for i, name in ipairs(Karaliste) do
		if name == playerName then
			table.remove(Karaliste, i)
			saveKaraliste()
			-- Hemen broadcast et
			broadcastMyPermission(true)
			return true
		end
	end
	return false
end

-- Oyuncunun bana ışınlanıp ışınlanamayacağını kontrol et
local function canPlayerTeleportToMe(playerName)
	-- Karaliste kontrolü (öncelikli)
	if isInKaraliste(playerName) then
		return false -- Karaliste'de ise ASLA ışınlanamaz
	end
	
	-- Arkadaşlar kontrolü
	if isInArkadaşlar(playerName) then
		return true -- Arkadaşlar'da ise HER ZAMAN ışınlanabilir
	end
	
	-- Normal izin kontrolü
	return Settings.AllowOthersToMe
end

-- Remote oyuncu izinlerini sakla (arkadaşlar/karaliste dahil)
local remotePlayerLists = {} -- [playerName] = {arkadaşlar={}, karaliste={}, allow=true/false}

-- Chat mesajlarını işle (izin mesajlarını parse et)
local function processChatMessage(message, senderCarIndex)
	-- Format: STEAM:playerName:steamID
	if string.sub(message, 1, 6) == "STEAM:" then
		local parts = {}
		for part in string.gmatch(message, "[^:]+") do
			table.insert(parts, part)
		end
		
		if #parts == 3 and parts[1] == "STEAM" then
			local playerName = parts[2]
			local steamID = parts[3]
			
			if playerName and steamID then
				playerSteamIDs[playerName] = steamID
			end
		end
		return true -- Mesajı gizle
	end
	
	-- Format: TP:playerName:status[:WL:name1,name2][:BL:name3,name4]
	if string.sub(message, 1, 3) == "TP:" then
		-- Mesajı parse et
		local parts = {}
		for part in string.gmatch(message, "[^:]+") do
			table.insert(parts, part)
		end
		
		if #parts >= 3 and parts[1] == "TP" then
			local playerName = parts[2]
			local status = parts[3]
			
			-- Remote oyuncu bilgilerini sakla
			if not remotePlayerLists[playerName] then
				remotePlayerLists[playerName] = {arkadaşlar = {}, karaliste = {}, allow = true}
			end
			
			-- Genel izin durumu
			remotePlayerLists[playerName].allow = (status == "1")
			remotePlayerLists[playerName].arkadaşlar = {}
			remotePlayerLists[playerName].karaliste = {}
			
			-- Arkadaşlar (WL) ve Karaliste (BL) parse et
			local i = 4
			while i <= #parts do
				if parts[i] == "WL" and parts[i+1] then
					-- Arkadaşlar (WL)
					for name in string.gmatch(parts[i+1], "[^,]+") do
						table.insert(remotePlayerLists[playerName].arkadaşlar, name)
					end
					i = i + 2
				elseif parts[i] == "BL" and parts[i+1] then
					-- Karaliste (BL)
					for name in string.gmatch(parts[i+1], "[^,]+") do
						table.insert(remotePlayerLists[playerName].karaliste, name)
					end
					i = i + 2
				else
					i = i + 1
				end
			end
			
			-- Genel izin durumunu güncelle (eski sistem uyumluluğu için)
			-- Ben ona ışınlanabilir miyim kontrolü
			local myName = ac.getDriverName(0)
			local canITeleport = false
			
			-- Karaliste'de miyim?
			local inKaraliste = false
			for _, name in ipairs(remotePlayerLists[playerName].karaliste) do
				if name == myName then
					inKaraliste = true
					break
				end
			end
			
			if inKaraliste then
				canITeleport = false
			else
				-- Arkadaşlar'da mıyım?
				local inArkadaşlar = false
				for _, name in ipairs(remotePlayerLists[playerName].arkadaşlar) do
					if name == myName then
						inArkadaşlar = true
						break
					end
				end
				
				if inArkadaşlar then
					canITeleport = true
				else
					canITeleport = remotePlayerLists[playerName].allow
				end
			end
			
			playerPermissions[playerName] = canITeleport
			lastPermissionUpdate[playerName] = os.clock()
			
			return true -- Mesajı gizle (eğer API destekliyorsa)
		end
	end
	return false -- Normal mesajları göster
end

-- Chat filtreleme - birden fazla yöntem dene
local chatFilterInstalled = false

-- Yöntem 1: ac.onChatMessage (CSP 0.1.77+)
pcall(function()
	if ac.onChatMessage then
		ac.onChatMessage(function(message, senderCarIndex)
			local shouldHide = processChatMessage(message, senderCarIndex)
			return shouldHide -- true = mesajı gizle
		end)
		chatFilterInstalled = true
	end
end)

-- Yöntem 2: ac.setChatMessageFilter (eski CSP)
pcall(function()
	if not chatFilterInstalled and ac.setChatMessageFilter then
		ac.setChatMessageFilter(function(message)
			local shouldHide = processChatMessage(message, 0)
			return not shouldHide -- false = mesajı gizle
		end)
		chatFilterInstalled = true
	end
end)

-- Yöntem 3: ac.addChatMessageListener
pcall(function()
	if not chatFilterInstalled and ac.addChatMessageListener then
		ac.addChatMessageListener(function(message, sender)
			processChatMessage(message, sender)
		end)
		chatFilterInstalled = true
	end
end)

-- İlk başlangıçta kendi izni ve SteamID'yi broadcast et (sadece bir kere)
setTimeout(function()
	broadcastMyPermission(true)
	broadcastMySteamID(true)
end, 3)

local timer = {
	running = 5,	--we move length/blength into here
	length = 5,		--the normal length after teleporting
	blength = 0.5,	--length after setting a button
}

local OverlayTimerKey = false -- Overlay gösterimi için
local selectedCarIndex = nil -- Seçili oyuncu index'i

--#region [Menu]
local function Teleportation()
	--showing timer seems logical to me here
	ui.text("Bekleme Süresi: " .. math.round(timer.running, 1))

	ui.tabBar("Atabbar", function()
		ui.tabItem("Işınlanma Menüsü", CartoCar_UI)
		ui.tabItem("İzin Ayarları", PermissionSettings_UI)
		ui.tabItem("Arkadaşlar/Karaliste", ArkadaşlarKaraliste_UI)
		ui.tabItem("Oyuncular Bilgisi", WHOIS_UI)
	end)
end

-- İzin Ayarları Menüsü
function PermissionSettings_UI()
	ui.header("Teleport İzin Sistemi")
	ui.separator()
	
	-- Başkalarının bana ışınlanması (NETWORK KORUMASLI)
	ui.text("Başkalarının Sana Işınlanması:")
	local oldSetting = Settings.AllowOthersToMe
	if ui.checkbox("Başkalarının bana ışınlanmasına izin ver##allowothers", Settings.AllowOthersToMe) then
		Settings.AllowOthersToMe = not Settings.AllowOthersToMe
		-- Değişikliği hemen broadcast et (force = true)
		broadcastMyPermission(true)
	end
	
	if not Settings.AllowOthersToMe then
		ui.textColored("🚫 Başkaları SANA ışınlanamaz.", rgbm(1, 0.3, 0.3, 1))
		if #Arkadaşlar > 0 then
			ui.textWrapped("⚠ Ancak Arkadaşlar listesindeki " .. #Arkadaşlar .. " oyuncu ışınlanabilir.")
		else
			ui.textWrapped("Diğer oyuncular seni listede '🚫 Kapalı' olarak görecek.")
		end
	else
		ui.textColored("✅ Başkaları sana ışınlanabilir.", rgbm(0.3, 1, 0.3, 1))
		if #Karaliste > 0 then
			ui.textWrapped("⚠ Ancak Karaliste'deki " .. #Karaliste .. " oyuncu ışınlanamaz.")
		else
			ui.textWrapped("Diğer oyuncular seni listede '✅ Açık' olarak görecek.")
		end
	end
	
	ui.separator()
	
	-- Teleport Bildirimi Ayarı
	ui.text("Diğer Ayarlar:")
	if ui.checkbox("Chat'e 'Işınlandın' mesajı göster##showtpmsg", Settings.ShowTeleportMessage) then
		Settings.ShowTeleportMessage = not Settings.ShowTeleportMessage
	end
	ui.textWrapped("Işınlandığınızda chat'e bildirim mesajı gönderir.")
	
	ui.separator()
	
	-- İstatistikler
	ui.separator()
	ui.text("📊 Network İstatistikleri:")
	
	local activePermissions = 0
	for name, perm in pairs(playerPermissions) do
		if perm ~= nil then activePermissions = activePermissions + 1 end
	end
	ui.textWrapped("🌐 Alınan izin bilgileri: " .. activePermissions .. " oyuncu")
	
	if not chatFilterInstalled then
		ui.newLine()
		ui.textColored("⚠ Chat Filtresi Yüklenemedi", rgbm(1, 1, 0, 1))
		ui.textWrapped("Chat'te 'TP:' ile başlayan mesajlar görülebilir. Bunlar izin protokolüdür, görmezden gelebilirsiniz.")
	else
		ui.textColored("✅ Chat Filtresi: Aktif", rgbm(0.3, 1, 0.3, 1))
	end
	
	ui.newLine()
	ui.textWrapped("💡 Bu script'i kullanmayan oyuncular '❓ Bilinmiyor' olarak görünür.")
end

-- Arkadaşlar/Karaliste Yönetim Menüsü
function ArkadaşlarKaraliste_UI()
	ui.header("Arkadaşlar ve Karaliste Yönetimi")
	ui.separator()
	
	ui.textWrapped("🔒 Arkadaşlar: İzniniz kapalı olsa bile bu oyuncular size ışınlanabilir.")
	ui.textWrapped("⛔ Karaliste: İzniniz açık olsa bile bu oyuncular size ışınlanamaz.")
	ui.separator()
	
	-- Aktif oyuncuları listele
	ui.text("Sunucudaki Oyuncular:")
	ui.childWindow("##playerslist", vec2(ui.availableSpaceX(), 300), function()
		for i = 1, sim.carsCount - 1 do
			local car = ac.getCar(i)
			local driverName = ac.getDriverName(i)
			
			if car.isConnected and not car.isAIControlled and not string.find(driverName, "NGG Trafik") then
				local isArkadaş = isInArkadaşlar(driverName)
				local isKaraliste = isInKaraliste(driverName)
				
				-- Oyuncu durumu ikonu
				local statusIcon = ""
				local statusColor = rgbm(1, 1, 1, 1)
				
				if isArkadaş then
					statusIcon = "✅ "
					statusColor = rgbm(0.3, 1, 0.3, 1)
				elseif isKaraliste then
					statusIcon = "⛔ "
					statusColor = rgbm(1, 0.3, 0.3, 1)
				else
					statusIcon = "⚪ "
					statusColor = rgbm(0.8, 0.8, 0.8, 1)
				end
				
				ui.pushStyleColor(ui.StyleColor.Text, statusColor)
				ui.text(statusIcon .. driverName)
				ui.popStyleColor()
				
				-- Butonlar
				ui.sameLine()
				
				if isArkadaş then
					if ui.button("Arkadaşlar'dan Çıkar##wl" .. i) then
						removeFromArkadaşlar(driverName)
					end
				else
					if ui.button("Arkadaşlar'a Ekle##wl" .. i) then
						addToArkadaşlar(driverName)
        end
    end
				
				ui.sameLine()
				
				if isKaraliste then
					if ui.button("Karaliste'den Çıkar##bl" .. i) then
						removeFromKaraliste(driverName)
					end
				else
					if ui.button("Karaliste'ye Ekle##bl" .. i) then
						addToKaraliste(driverName)
            end
        end
    end
end
	end)
	
	ui.separator()
	
	-- İstatistikler
	ui.text("📊 İstatistikler:")
	ui.textWrapped("✅ Arkadaşlar'da " .. #Arkadaşlar .. " oyuncu")
	ui.textWrapped("⛔ Karaliste'de " .. #Karaliste .. " oyuncu")
	
	ui.separator()
	
	-- Temizleme butonları
	if #Arkadaşlar > 0 then
		if ui.button("Tüm Arkadaşlar'ı Temizle") then
			Arkadaşlar = {}
			saveArkadaşlar()
			broadcastMyPermission(true)
		end
	end
	
	if #Karaliste > 0 then
		ui.sameLine()
		if ui.button("Tüm Karaliste'yi Temizle") then
			Karaliste = {}
			saveKaraliste()
			broadcastMyPermission(true)
		end
	end
	
	ui.newLine()
	ui.textWrapped("💡 İpucu: Karaliste en yüksek önceliğe sahiptir. Arkadaşlar listesi izin kapalıyken etkilidir.")
end

-- WHOIS Bilgisi Menüsü
function WHOIS_UI()
	ui.header("WHOIS - Oyuncu Bilgileri")
	ui.separator()
	
	ui.textWrapped("🔍 Sunucudaki tüm oyuncuların detaylı bilgilerini görebilirsiniz.")
	ui.separator()
	
	-- Oyuncu sayısı
	local onlineCount = 0
	for i = 0, sim.carsCount - 1 do
		local car = ac.getCar(i)
		if car and car.isConnected and not car.isAIControlled then
			local driverName = ac.getDriverName(i)
			if driverName then
				local isTraffic = string.find(driverName, "NGG Trafik") ~= nil
				if not isTraffic then
					onlineCount = onlineCount + 1
				end
			end
		end
	end
	
	ui.text("🌐 Toplam Oyuncu: " .. onlineCount)
	ui.separator()
	
	-- Oyuncu listesi  
	ui.childWindow("##whoislist", vec2(ui.availableSpaceX(), 450), function()
		for i = 0, sim.carsCount - 1 do
			local car = ac.getCar(i)
			if car and car.isConnected and not car.isAIControlled then
				local driverName = ac.getDriverName(i)
				local isTraffic = driverName and string.find(driverName, "NGG Trafik") ~= nil
				if driverName and driverName ~= "" and not isTraffic then
					-- Oyuncu bilgi kartı
					ui.pushFont(ui.Font.Title)
					if i == 0 then
						ui.textColored("👤 " .. driverName .. " (Sen)", rgbm(0.3, 1, 0.3, 1))
					else
						ui.text("👤 " .. driverName)
					end
    ui.popFont()
	
					
					-- SteamID64 / GUID (güvenli çağrı)
					local steamID = nil
					local idType = "Bilinmiyor"
					
					-- Yöntem 1: ac.getUserSteamID() - lokal oyuncu için
					if i == 0 and ac.getUserSteamID then
						steamID = ac.getUserSteamID()
						idType = "SteamID64"
					end
					
					-- Yöntem 2: Network'ten paylaşılan SteamID (öncelikli)
					if (not steamID or steamID == "" or steamID == "0") and playerSteamIDs[driverName] then
						steamID = playerSteamIDs[driverName]
						idType = "SteamID64"
					end
					
					-- Yöntem 3: Multiplayer session bilgisi (CSP)
					if (not steamID or steamID == "" or steamID == "0") and ac.getSession then
						local session = ac.getSession(i)
						if session and session.steamID then
							steamID = session.steamID
							idType = "SteamID64"
						end
					end
					
					-- Yöntem 4: ac.getDriverGUID() - tüm oyuncular için
					if not steamID or steamID == "" or steamID == "0" then
						if ac.getDriverGUID then
							steamID = ac.getDriverGUID(i)
							if steamID and steamID ~= "" and steamID ~= "0" then
								idType = "GUID"
							end
						end
					end
					
					if steamID and steamID ~= "" and steamID ~= "0" then
						ui.text("  🔑 " .. idType .. ": " .. steamID)
						
						-- Kopyalama butonu
						ui.sameLine()
						if ui.button("Kopyala##steam" .. i) then
							ui.setClipboardText(steamID)
						end
						
						-- Steam profil linki (sadece SteamID64 için)
						if idType == "SteamID64" then
							ui.sameLine()
							if ui.button("Steam Profil##profile" .. i) then
								os.openURL("https://steamcommunity.com/profiles/" .. steamID)
							end
						end
					else
						ui.textColored("  🔑 ID: Mevcut değil (API desteği yok)", rgbm(1, 0.7, 0, 1))
					end
					
					-- Araç bilgisi
					local carName = ac.getCarName(i) or "Bilinmiyor"
					ui.text("  🚗 Araç: " .. carName)
					
					-- Bağlantı bilgisi
					ui.textColored("  🟢 Durum: Online", rgbm(0.3, 1, 0.3, 1))
					
					-- Ülke kodu
					local nationCode = ac.getDriverNationCode(i)
					if nationCode and nationCode ~= "" then
						ui.text("  🌍 Ülke: " .. nationCode)
					end
					
					-- İzin durumu
					local permission = playerPermissions[driverName]
					if i ~= 0 then
						if permission == true then
							ui.textColored("  ✅ Teleport İzni: Açık", rgbm(0.3, 1, 0.3, 1))
						elseif permission == false then
							ui.textColored("  🚫 Teleport İzni: Kapalı", rgbm(1, 0.3, 0.3, 1))
						else
							ui.textColored("  ❓ Teleport İzni: Bilinmiyor", rgbm(0.7, 0.7, 0.7, 1))
						end
					end
					
					-- Arkadaşlar/Karaliste durumu
					if i ~= 0 then
						local isArkadaş = isInArkadaşlar(driverName)
						local isKaraliste = isInKaraliste(driverName)
						
						if isArkadaş then
							ui.textColored("  💚 Listede: Arkadaşlar", rgbm(0.3, 1, 0.3, 1))
						elseif isKaraliste then
							ui.textColored("  ⛔ Listede: Karaliste", rgbm(1, 0.3, 0.3, 1))
						else
							ui.text("  ⚪ Listede: Normal")
						end
					end
					
					-- Hız ve mesafe bilgisi (kendin dışındaki oyuncular için)
					if i ~= 0 then
						local speed = math.sqrt(car.velocity.x^2 + car.velocity.z^2) * 3.6
						ui.text(string.format("  💨 Hız: %.0f km/h", speed))
						
						local myCar = ac.getCar(0)
						if myCar then
							local distance = math.sqrt(
								(car.position.x - myCar.position.x)^2 + 
								(car.position.y - myCar.position.y)^2 + 
								(car.position.z - myCar.position.z)^2
							)
							ui.text(string.format("  📍 Mesafe: %.0f m", distance))
						end
					end
					
					ui.separator()
				end
			end
		end
	end)
	
	ui.separator()
	ui.textWrapped("💡 İpucu: SteamID64'ü kopyalayıp Steam'de arama yapabilir veya direkt profil linkine gidebilirsiniz.")
end
--#endregion

--#region [Car to Car] --physics stuff works in ui shit too so lol
function CartoCar_UI()
	ui.text("Işınlanacağın Arkadaşını Seç ve 'IŞINLAN' tuşuna bas.")
	
	-- Seçili oyuncunun izin durumunu göster
	if selectedCar and selectedCarIndex then
		local targetName = ac.getDriverName(selectedCarIndex)
		local hasPermission = playerPermissions[targetName]
		
		if hasPermission == false then
			ui.textColored("🚫 Bu oyuncu teleportları kapatmış! Işınlanamazsın.", rgbm(1, 0.3, 0.3, 1))
		elseif hasPermission == true then
			ui.textColored("✅ Bu oyuncu teleportları kabul ediyor.", rgbm(0.3, 1, 0.3, 1))
		else
			ui.textColored("❓ Bu oyuncunun izin durumu bilinmiyor (script yok olabilir).", rgbm(0.7, 0.7, 0.7, 1))
		end
	end
	
	-- Cooldown kontrolü
	if timer.running > 0 then
		ui.textColored("⏱ Bekleme süresi: " .. math.round(timer.running, 1) .. " saniye", rgbm(1, 1, 0.3, 1))
	end
	
	-- Işınlan butonu - izin kontrolü eklendi
	local canTeleport = selectedCar and timer.running <= 0
	local targetName = selectedCarIndex and ac.getDriverName(selectedCarIndex)
	local targetPermission = targetName and playerPermissions[targetName]
	
	-- Eğer hedef oyuncu DENY etmişse, buton devre dışı
	if targetPermission == false then
		ui.pushStyleColor(ui.StyleColor.Button, rgbm(0.3, 0.3, 0.3, 1))
		ui.pushStyleColor(ui.StyleColor.ButtonHovered, rgbm(0.4, 0.4, 0.4, 1))
		ui.pushStyleColor(ui.StyleColor.ButtonActive, rgbm(0.3, 0.3, 0.3, 1))
		ui.button("Işınlan (İzin Yok! 🚫)")
		ui.popStyleColor(3)
	elseif ui.button("Işınlan") and canTeleport then
		timer.running = timer.length
		local dir = selectedCar.look

		local playerVelocity = ac.getCarState(1).velocity
		local playerGear = ac.getCarState(1).gear
		local playerRPM = ac.getCarState(1).rpm

		physics.setCarPosition(0, selectedCar.position + vec3(0, 0.1, 0) - dir * 10, -dir)
		physics.setCarVelocity(0, playerVelocity)

		physics.engageGear(0, playerGear)
		physics.setEngineRPM(0, playerRPM)
		
		-- Bildirim (ayarlarda açıksa göster)
		if Settings.ShowTeleportMessage then
			if selectedCarIndex then
				ac.sendChatMessage("✈ " .. targetName .. " oyuncusuna ışınlandın!")
			else
				ac.sendChatMessage("✈ Işınlandın!")
			end
		end
	end
	
	ui.separator()
	ui.text("Işınlanacağın Arkadaşını Seç:")
	ui.childWindow("##drivers", vec2(ui.availableSpaceX(), 480), function()
		for i = 1, sim.carsCount - 1 do
			local car = ac.getCar(i)
			local driverName = ac.getDriverName(i)
			
			if car.isConnected and not car.isAIControlled and not string.find(driverName, "NGG Trafik") then
				-- İzin durumuna göre ikon ekle
				local permissionIcon = ""
				local permissionColor = rgbm(1, 1, 1, 1)
				local extraInfo = ""
				
				local permission = playerPermissions[driverName]
				
				-- Remote player'ın arkadaşlar/karaliste durumunu kontrol et
				local myName = ac.getDriverName(0)
				if remotePlayerLists[driverName] then
					local lists = remotePlayerLists[driverName]
					-- Ben onun karaliste'sinde miyim?
					for _, name in ipairs(lists.karaliste) do
						if name == myName then
							extraInfo = " [⛔Karaliste]"
							break
						end
					end
					-- Ben onun arkadaşları'nda mıyım?
					if extraInfo == "" then
						for _, name in ipairs(lists.arkadaşlar) do
							if name == myName then
								extraInfo = " [✅Arkadaş]"
								break
							end
						end
					end
				end
				
				if permission == true then
					permissionIcon = "✅ "
					permissionColor = rgbm(0.3, 1, 0.3, 1)
				elseif permission == false then
					permissionIcon = "🚫 "
					permissionColor = rgbm(1, 0.3, 0.3, 1)
				else
					permissionIcon = "❓ "
					permissionColor = rgbm(0.7, 0.7, 0.7, 1)
				end
				
				ui.pushStyleColor(ui.StyleColor.Text, permissionColor)
				if ui.selectable(permissionIcon .. driverName .. extraInfo, selectedCar == car) then
					selectedCar = car
					selectedCarIndex = i
					if Settings.SpectatePlayer == true then
						ac.focusCar(i)
					end
				end
				ui.popStyleColor()
			end
		end
	end)
	
	ui.separator()
	ui.textWrapped("💡 İkonlar:")
	ui.text("  ✅ = İzin Var | 🚫 = İzin Yok | ❓ = Bilinmiyor")
	ui.text("  [✅Arkadaş] = Arkadaşları'nda | [⛔Karaliste] = Karaliste'sinde")
end




function script.update(dt)
	--#region [Timer]
	if timer.running >= 0 then -- timer for anything to go
		timer.running = timer.running - dt
	end
	--#endregion
	
	--#region [Network - Permission Broadcast]
	local currentTime = os.clock()
	
	-- SteamID broadcast (periyodik, sessizce)
	broadcastMySteamID(false)
	
	-- Periyodik broadcast kaldırıldı (log spam'i önlemek için)
	-- Sadece durum değiştiğinde broadcast yapılacak
	
	-- Eski izinleri temizle (timeout olmuşlar)
	for playerName, lastUpdate in pairs(lastPermissionUpdate) do
		if currentTime - lastUpdate > PERMISSION_TIMEOUT then
			playerPermissions[playerName] = nil
			lastPermissionUpdate[playerName] = nil
		end
	end
	
	-- Çıkmış oyuncuların izinlerini temizle
	for playerName, _ in pairs(playerPermissions) do
		local found = false
		for i = 0, sim.carsCount - 1 do
			if ac.getDriverName(i) == playerName then
				local car = ac.getCar(i)
				if car and car.isConnected then
					found = true
					break
				end
			end
		end
		if not found then
			playerPermissions[playerName] = nil
			lastPermissionUpdate[playerName] = nil
		end
	end
	--#endregion
end

function script.drawUI()
	if OverlayTimerKey == true then
		ui.transparentWindow("Keyandabindandacooldown", vec2(-15, -5), vec2(150, 150), false, function()
			ui.text("Key: " .. Settings.KeyName .. "\nBekleme Süresi: " .. math.round(timer.running, 1))
		end)
end
end

ui.registerOnlineExtra(ui.Icons.Compass, "Arkadaşına Işınlan!", nil, Teleportation,nil, ui.OnlineExtraFlags.Tool, ui.WindowFlags.NoScrollWithMouse)
