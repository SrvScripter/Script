local screensize = vec2(ac.getSim().windowWidth, ac.getSim().windowHeight)
local hideImage = false -- Yeni değişken: Görselin saklanıp saklanmadığını kontrol eder.

-- Ekran oranını hesapla
local aspectRatio = screensize.x / screensize.y

-- Ana görsel için ölçeklendirme hesapla
local function calculateMainImageScale()
    local targetAspectRatio = 1920 / 1080 -- Orijinal görsel oranı
    local scale = 1

    if aspectRatio > targetAspectRatio then
        -- Ekran daha geniş, yüksekliğe göre ölçekle
        scale = screensize.y / 1080
    else
        -- Ekran daha dar, genişliğe göre ölçekle
        scale = screensize.x / 1920
    end

    return scale * 0.9 -- %90 boyut için
end

--image_0 is used as the rules splash screen
local image_0 = {
    ['src'] = 'https://cdn.numiezganggarage.com.tr/scripts/vipyatay.jpg',
    ['sizeX'] = 1920,
    ['sizeY'] = 1080,
    ['scale'] = calculateMainImageScale()
}

--image_1: sabit piksel boyut (tüm çözünürlüklerde aynı ebat; scale yok)
local image_1 = {
    ['src'] = 'https://cdn.numiezganggarage.com.tr/NGGLogoSunucu.png',
    ['sizeX'] = 128,
    ['sizeY'] = 128,
    ['paddingX'] = 20, -- ekran pikseli: sol kenardan
    ['paddingY'] = 10  -- ekran pikseli: üst kenardan
}

function script.update(dt)
    ac.debug('isInMainMenu', ac.getSim().isInMainMenu)
    ac.debug('Screen Size', string.format("%dx%d", screensize.x, screensize.y))
    ac.debug('Aspect Ratio', aspectRatio)

    -- "H" tuşuna basılırsa görseli sakla
    if ac.isKeyDown(ac.KeyIndex.Tab) or ac.isKeyDown(ac.KeyIndex.H) then
        hideImage = true
    end
end

function script.drawUI()
    if not hideImage and not ac.getSim().isInMainMenu then
        -- Ana görseli ortala
        local scaledWidth = image_0.sizeX * image_0.scale
        local scaledHeight = image_0.sizeY * image_0.scale
        local posX = (screensize.x - scaledWidth) / 2
        local posY = (screensize.y - scaledHeight) / 2

        ui.drawImage(
            image_0.src, 
            vec2(posX, posY), 
            vec2(posX + scaledWidth, posY + scaledHeight),
            true
        )
        ac.debug("Ana Görsel", string.format("Pozisyon: %d,%d Boyut: %dx%d", posX, posY, scaledWidth, scaledHeight))
    end

    if hideImage and not ac.getSim().isInMainMenu then
        -- Logo sabit piksel; sol üst köşede
        local posX = image_1.paddingX
        local posY = image_1.paddingY

        ui.drawImage(
            image_1.src,
            vec2(posX, posY),
            vec2(posX + image_1.sizeX, posY + image_1.sizeY),
            true
        )
    end
end
