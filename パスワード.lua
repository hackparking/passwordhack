-- UI検出で即死する安全フック
do
    local originalSearch = gg.searchNumber

    local function hookedSearch(...)
        gg.setVisible(false)
        local results = originalSearch(...)
        if gg.isVisible() then
            gg.alert("画面開いたな？終了するぞ")
            gg.clearResults()
            while true do os.exit() end
        end
        return results
    end

    gg.searchNumber = hookedSearch
end

-- 常時非表示化
gg.setVisible(false)

-- メイン処理
gg.clearResults()
gg.setRanges(gg.REGION_ANONYMOUS)

-- 検索して即時保存し、検索履歴をクリア
local tmpResults = gg.searchNumber("4294967316", gg.TYPE_QWORD)
local results = gg.getResults(9999)
gg.clearResults()  -- 検索値を削除（履歴からも消える）

if #results == 0 then
    gg.alert("値が見つかりませんでした。")
    os.exit()
end

-- +8のDWORD値取得
local addressList = {}
for _, v in ipairs(results) do
    table.insert(addressList, {address = v.address + 8, flags = gg.TYPE_DWORD})
end

local offsetValues = gg.getValues(addressList)

-- アドレスの重複除去
local filtered = {}
local seen_blocks = {}
for _, v in ipairs(offsetValues) do
    local block = math.floor(v.address / 0x100)
    if not seen_blocks[block] then
        seen_blocks[block] = true
        table.insert(filtered, v)
    end
end

-- 候補絞り込み（4桁、怪しい値除外）
local seen_values = {}
local likely_values = {}

local function isSuspicious(v)
    return (v % 10 == 0) or
           tostring(v):match("^(%d)%1+$") or
           tostring(v):match("^1234$") or
           tostring(v):match("^4321$")
end

for _, v in ipairs(filtered) do
    if v.value >= 1000 and v.value <= 9999 and not isSuspicious(v.value) then
        if not seen_values[v.value] then
            seen_values[v.value] = true
            table.insert(likely_values, {value = v.value, address = v.address})
        end
    end
end

-- ソートして表示
table.sort(likely_values, function(a, b) return a.value < b.value end)

if #likely_values == 0 then
    gg.alert("パスワード候補が見つかりませんでした。")
else
    local msg = "【ルームパスワード候補】\n"
    for _, v in ipairs(likely_values) do
        msg = msg .. string.format(" %d（アドレス: %X）\n", v.value, v.address)
    end
    gg.alert(msg)
end

-- 完全終了
os.exit()