
local dialogOpen = false
local dialog
local sprite = app.activeSprite

local zero = app.pixelColor.rgba(0, 0, 0)
local one = app.pixelColor.rgba(255, 255, 255)

local doAutoApply = false

local templates =
{
    0,     -- 0b0000000000000000,
    32768, -- 0b1000000000000000,
    32800, -- 0b1000000000100000,
    32928, -- 0b1000000010100000,
    41120, -- 0b1010000010100000,
    42144, -- 0b1010010010100000,
    42145, -- 0b1010010010100001,
    42149, -- 0b1010010010100101,
    42405, -- 0b1010010110100101,
    44453, -- 0b1010110110100101,
    44455, -- 0b1010110110100111,
    44463, -- 0b1010110110101111,
    44975, -- 0b1010111110101111,
    61359, -- 0b1110111110101111,
    61375, -- 0b1110111110111111,
    61439, -- 0b1110111111111111,
    65535, -- 0b1111111111111111,
}

local NextMultiple = function(value, interval)

    if value % interval == 0 then return value end

    return value + interval - (value % interval)

end

local ReadTemplateImage = function(size, template)

    if size < 4 then size = 4 end

    local image = Image(size, size)

    for y = 0, size do

        -- Cursor begins at the leftmost template bit, offset by 4 for each subsequent
        -- layer.
        local cursor = 15 - (4 * y)

        -- If the size is larger than the template, wrap the cursor vertically
        while cursor < 0 do
            cursor = cursor + 15
        end

        for x = 0, size do

            local mask = 1 << cursor

            if (template & mask) == mask then
                image:drawPixel(x, y, one)
            else
                image:drawPixel(x, y, zero)
            end

            -- Cursor moves towards the rightmost bit
            cursor = cursor - 1

            -- Wrap cursor to the beginning of the template
            if cursor < 0 then cursor = 15 end

        end

    end

    return image

end

local RecolorImage = function(image)
    
    local recolored = image:clone()

    for pixel in recolored:pixels() do

        if pixel() == zero then
            pixel(app.bgColor.rgbaPixel)
        else
            pixel(app.fgColor.rgbaPixel)
        end

    end

    return recolored

end

local previewImage = ReadTemplateImage(4, templates[9])
local brushImage = RecolorImage(previewImage)

local BuildBrushImage = function()

    local size = brushImage.width + dialog.data.increment

    local image = Image(size, size)

    local tx = math.ceil(size / (brushImage.width))
    local ty = math.ceil(size / (brushImage.height))

    for y = 0, ty do

        for x = 0, tx do
            
            image:drawImage(brushImage, Point(x * brushImage.width, y * brushImage.height))

        end

    end

    local scale = dialog.data.scale

    image:resize(size * scale, size * scale)

    return image

end


local Apply = function()
    app.activeBrush = Brush
    {
        image = BuildBrushImage(),
        pattern = BrushPattern.ORIGIN
    }
end

local AutoApply = function()

    if doAutoApply then Apply() end

end

local AdjustIncrement = function(delta)
    
    local inc = dialog.data.increment + delta

    if inc < 0 then inc = 0 end

    if dialog.data.force_tiling then inc = NextMultiple(inc, 4) end

    dialog:modify { id = "increment", text = ""..inc }

    AutoApply()

end

local AutoAdjustIncrement = function(direction)

    if dialog.data.force_tiling then
        AdjustIncrement(direction * 4)
    else
        AdjustIncrement(direction)
    end

end

local AdjustScale = function(delta)

    local scale = dialog.data.scale + delta

    if scale < 1 then scale = 1 end

    dialog:modify { id = "scale", text = ""..scale }

    AutoApply()

end

local DithererDialog = function()

    local dialog = Dialog
    {
        title = "Dithering Brushes",
        onclose = function() dialogOpen = false end
    }

    dialog:separator { text = "Density" }

    :slider
    {
        id = "density",
        -- label = "Density",
        min = 1,
        max = 17,
        value = 9,
        onchange = function()
            previewImage = ReadTemplateImage(4, templates[dialog.data.density])
            dialog:repaint()
            AutoApply()
        end
    }

    :separator { text = "Colors" }
    :shades
    {
        id = "colors",
        mode = "pick",
        colors = { app.fgColor, app.bgColor },
        onclick = function()
            AutoApply()
        end
    }

    :separator { text = "Pattern Preview" }
    :canvas
    {
        id = "previewCanvas",
        width = 110,
        height = 32,
        -- label = "Preview",
        onpaint = function(ev)
            -- Scaled image size
            local ss = 12

            local c = ev.context
            local w = dialog.bounds.width - 12
            c:drawThemeRect("sunken_normal", Rectangle(0, 0, w, 32))

            local thAbs = (w - 8) / ss
            local th = math.floor(thAbs)

            local tvAbs = 24 / ss
            local tv = math.floor(tvAbs)

            brushImage = RecolorImage(previewImage)

            for y = 0, tv - 1 do

                for x = 0, th - 1 do
                    c:drawImage(brushImage, 0, 0, 4, 4, 4 + x * ss, 4 + y * ss, ss, ss)
                end
                
            end

            local remainder = thAbs - th
            local rsw = math.floor(remainder * 4)
            local rdw = rsw * 3

            c:drawImage(brushImage, 0, 0, rsw, 4, 4 + th * ss, 4, rdw, ss)
            c:drawImage(brushImage, 0, 0, rsw, 4, 4 + th * ss, 4 + ss, rdw, ss)
        end
    }

    :separator { text = "Pattern Size Increment" }
    :number
    {
        id = "increment",
        decimals = 0,
        text = "0",
        onchange = function()

            AdjustIncrement(0)

        end
    }

    :slider
    {
        id = "inc_slider",
        min = -100,
        max = 100,
        value = 0,
        onchange = function()
            local value = dialog.data.inc_slider
            
            AutoAdjustIncrement(value)

            dialog:modify { id = "inc_slider", value = 0 }
        end
    }

    :button
    {
        text = "-",
        onclick = function()
            AutoAdjustIncrement(-1)
        end
    }

    :button
    {
        text = "+",
        onclick = function()
            AutoAdjustIncrement(1)
        end
    }

    :check
    {
        id = "force_tiling",
        text = "Force tiling",
        selected = false,
        onclick = function()
            AdjustIncrement(0)
        end
    }

    :check
    {
        id = "auto_apply",
        text = "Apply Automatically",
        selected = false,
        onclick = function()
            doAutoApply = not doAutoApply
        end
    }

    :separator { text = "Brush Scale" }
    :number
    {
        id = "scale",
        decimals = 0,
        text = "1",
        onchange = function()
            AdjustScale(0)
        end
    }

    :slider
    {
        id = "scale_slider",
        min = -100,
        max = 100,
        value = 0,
        onchange = function()
            local value = dialog.data.scale_slider
            
            AdjustScale(value)

            dialog:modify { id = "scale_slider", value = 0 }
        end
    }

    :button
    {
        id = "apply",
        text = "Apply",
        onclick = function()
            Apply()
        end
    }

    return dialog

end

local foregroundListener
local backgroundListener
local ColorChanged = function()

    if not dialogOpen then return end

    dialog:modify { id = "colors", colors = { app.fgColor, app.bgColor } }
    dialog:repaint()

end

function init(plugin)

    if not app.isUIAvailable then return end

    dialog = DithererDialog()

    foregroundListener = app.events:on('fgcolorchange', ColorChanged)
    backgroundListener = app.events:on('bgcolorchange', ColorChanged)

    plugin:newCommand
    {
        id = "dithering-brushes",
        title = "Dithering Brushes",
        group = "edit_transform",
        onenabled = function() return app.activeSprite ~= nil end,
        onclick = function()
            dialogOpen = true
            dialog:show { wait = false }
            dialog:repaint()
        end
    }

end

function exit(plugin)

    app.events:off(foregroundListener)
    app.events:off(backgroundListener)

end
