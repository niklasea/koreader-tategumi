--[[--
Chinese vertical text profile.

Checks the legacy CSS aliases used by Chinese EPUB producers and the
difference between Japanese JFM half-em punctuation and Chinese full-em
punctuation.
--]]

describe("Vertical text: Chinese profile #vertical_zh_profile", function()
    local DocumentRegistry, ReaderUI, Screen, UIManager
    local reader, path

    setup(function()
        require("commonrequire")
        disable_plugins()
        require("document/canvascontext"):init(require("device"))
        DocumentRegistry = require("document/documentregistry")
        ReaderUI = require("apps/reader/readerui")
        Screen = require("device").screen
        UIManager = require("ui/uimanager")
    end)

    after_each(function()
        if reader then
            reader:onClose()
            reader = nil
        end
        UIManager:quit()
        UIManager._exit_code = nil
        if path then
            os.remove(path)
            path = nil
        end
    end)

    local function open_html(html, lang)
        path = os.tmpname()
        os.remove(path)
        path = path .. ".xhtml"
        local f = assert(io.open(path, "wb"))
        f:write(html)
        f:close()
        reader = ReaderUI:new{
            dimen = Screen:getSize(),
            document = DocumentRegistry:openDocument(path),
        }
        UIManager:show(reader)
        local doc = reader.document
        doc:setFontFace("Noto Sans CJK SC")
        doc:setFontSize(32)
        doc:setTextMainLang(lang)
        reader.rolling:onUpdatePos()
        fastforward_ui_events()
        return doc
    end

    local function char_box(doc, target)
        local hits = doc:findAllText(target, false, 0, 10, false)
        assert.truthy(hits and hits[1], "missing text: " .. target)
        local boxes = doc:getScreenBoxesFromPositions(hits[1].start, hits[1]["end"], true)
        assert.truthy(boxes and boxes[1], "missing box: " .. target)
        return boxes[1]
    end

    it("accepts -ms-writing-mode and -epub-text-orientation aliases", function()
        local doc = open_html([[<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-TW"><head><style>
html, body { margin: 0; padding: 0; }
body { -ms-writing-mode: tb-rl; }
.sideways { -epub-text-orientation: sideways; }
</style></head><body><p>甲<span class="sideways">＝</span>乙</p></body></html>]], "zh-TW")
        assert.is_true(doc:hasVerticalContent())
        assert.equals("vertical-rl", doc:getPageWritingMode())
    end)

    it("keeps Chinese punctuation in a full-em slot", function()
        local doc = open_html([[<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-TW"><head><style>
html, body { margin: 0; padding: 0; }
html, body { writing-mode: vertical-rl; }
p { margin: 0; font-size: 32px; }
</style></head><body><p>甲。乙</p></body></html>]], "zh-TW")
        local zh_height = char_box(doc, "。").h

        reader:onClose()
        reader = nil
        os.remove(path)
        path = nil
        UIManager:quit()
        UIManager._exit_code = nil

        doc = open_html([[<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja"><head><style>
html, body { margin: 0; padding: 0; }
html, body { writing-mode: vertical-rl; }
p { margin: 0; font-size: 32px; }
</style></head><body><p>甲。乙</p></body></html>]], "ja")
        local ja_height = char_box(doc, "。").h
        print(string.format("[vertical_zh_profile] Chinese 。 slot=%d, Japanese 。 slot=%d",
            zh_height, ja_height))
        assert.is_true(zh_height > ja_height,
            "Chinese punctuation must not use the Japanese half-em slot")
    end)
end)
