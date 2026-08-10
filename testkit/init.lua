--[[
    TestKit — minimal Lua test framework for running Roblox Luau tests
    outside of Roblox Studio.

    Provides:
      - expect(value) → assertion builder (use :toBe(), :toEqual(), etc.)
      - testkit.loadModule(path) → loads a Lua module from filesystem
      - describe/it for test organization

    Usage:
      LUA_PATH="?.lua;testkit/?.lua;?/init.lua" lua5.1 tests/beatclock_test.lua
]]

local testkit = {}
local passed = 0
local failed = 0

-- ── Expect builder ──────────────────────────────────────

local function expect(actual)
    local mt = {}
    
    function mt:toBe(expected)
        if actual ~= expected then
            error(string.format("Expected %s, got %s", tostring(expected), tostring(actual)), 2)
        end
        return self
    end
    
    function mt:toEqual(expected)
        if type(actual) == "table" and type(expected) == "table" then
            local function deepEq(a, b)
                if type(a) ~= type(b) then return false end
                if type(a) ~= "table" then return a == b end
                for k, v in pairs(a) do if not deepEq(v, b[k]) then return false end end
                for k, v in pairs(b) do if not deepEq(v, a[k]) then return false end end
                return true
            end
            if not deepEq(actual, expected) then
                error("Expected tables to be equal", 2)
            end
        else
            if actual ~= expected then
                error(string.format("Expected %s, got %s", tostring(expected), tostring(actual)), 2)
            end
        end
        return self
    end
    
    function mt:toBeGreaterThan(expected)
        if not (actual > expected) then
            error(string.format("Expected %s > %s", tostring(actual), tostring(expected)), 2)
        end
        return self
    end
    
    function mt:toBeLessThan(expected)
        if not (actual < expected) then
            error(string.format("Expected %s < %s", tostring(actual), tostring(expected)), 2)
        end
        return self
    end
    
    function mt:toBeGreaterThanOrEqualTo(expected)
        if not (actual >= expected) then
            error(string.format("Expected %s >= %s", tostring(actual), tostring(expected)), 2)
        end
        return self
    end
    
    function mt:toBeLessThanOrEqualTo(expected)
        if not (actual <= expected) then
            error(string.format("Expected %s <= %s", tostring(actual), tostring(expected)), 2)
        end
        return self
    end
    
    function mt:toBeTrue()
        if actual ~= true then error(string.format("Expected true, got %s", tostring(actual)), 2) end
        return self
    end
    
    function mt:toBeFalse()
        if actual ~= false then error(string.format("Expected false, got %s", tostring(actual)), 2) end
        return self
    end
    
    function mt:toBeNil()
        if actual ~= nil then error(string.format("Expected nil, got %s", tostring(actual)), 2) end
        return self
    end
    
    function mt:toBeNear(expected, tolerance)
        if math.abs(actual - expected) > tolerance then
            error(string.format("Expected %s ± %s, got %s", tostring(expected), tostring(tolerance), tostring(actual)), 2)
        end
        return self
    end
    
    return mt
end

testkit.expect = expect

-- ── Module loading ──────────────────────────────────────

function testkit.loadModule(path)
    local file = io.open(path, "r")
    if not file then error("File not found: " .. path, 2) end
    local content = file:read("*a")
    file:close()
    
    -- Strip Luau type annotations for Lua 5.1 compatibility
    -- 1. Function params: (param: type) → (param)
    -- Match simple types (number, string, Vector3?, etc.)
    content = content:gsub("(%w+)%s*:%s*[%w%?]+%s*([,%)])", "%1%2")
    -- Match brace types: (param: { ... }) — use balanced brace matching
    content = content:gsub("(%w+)%s*:%s*%b{}%s*([,%)])", "%1%2")
    -- 2. Function return types: ): type\n → )\n
    content = content:gsub("%)%s*:%s*[^{%n]*%s*%c", ")\n")
    content = content:gsub("%)%s*:%s*%b{}", ")")
    -- Handle parenthesized multi-return types: ): (type1, type2)
    content = content:gsub("%)%s*:%s*%b()", ")")
    -- 3. Local var with brace types: local x: { ... } = → local x =
    local function stripBraceType(line)
        if line:match("^%s*local%s+%w+%s*:") then
            local s, e = line:find(":")
            if s then
                local before = line:sub(1, s-1)
                local rest = line:sub(e+1)
                local depth = 0
                local i = 1
                while i <= #rest do
                    local c = rest:sub(i,i)
                    if c == "{" then depth = depth + 1
                    elseif c == "}" then depth = depth - 1
                    elseif depth == 0 and c == "=" then
                        return before .. rest:sub(i)
                    elseif depth == 0 and c:match("[a-zA-Z]") then
                        while i <= #rest and rest:sub(i,i):match("[%w%?]") do i = i + 1 end
                        return before .. rest:sub(i)
                    end
                    i = i + 1
                end
            end
        end
        return line
    end
    local lines = {}
    for line in content:gmatch("([^\n]*)\n?") do
        line = stripBraceType(line)
        -- Also strip return type annotations: ): type at end of line
        line = line:gsub("(%))%s*:%s*[%w%?]+%s*$", "%1")
        line = line:gsub("^export type.*", "")
        line = line:gsub("^type%s+%w+%s*=.*", "")
        table.insert(lines, line)
    end
    content = table.concat(lines, "\n")
    
    local fn, err = loadstring(content, path)
    if not fn then error("Failed to load module: " .. tostring(err), 2) end
    
    local env = setmetatable({}, {__index = _G})
    setfenv(fn, env)
    local ok, result = pcall(fn)
    if not ok then error("Module execution failed: " .. tostring(result), 2) end
    
    if result and type(result) == "table" then return result end
    return env.BeatClock or env
end

-- ── Test registration ───────────────────────────────────

function testkit.describe(name, fn)
    print("\n=== " .. name .. " ===")
    fn()
end

function testkit.it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        print("  ✗ " .. name)
        print("    " .. tostring(err))
    end
end

testkit.test = testkit.it

-- ── Hooks (no-ops for compatibility) ───────────────────

function testkit.beforeAll(fn) pcall(fn) end
function testkit.afterAll(fn) pcall(fn) end
function testkit.beforeEach(fn) pcall(fn) end
function testkit.afterEach(fn) pcall(fn) end

-- ── Summary ─────────────────────────────────────────────

function testkit.summary()
    print(string.format("\n───────────────────────────────"))
    print(string.format("Passed: %d  Failed: %d  Total: %d", passed, failed, passed + failed))
    if failed > 0 then os.exit(1) end
end

-- ── Mock typeof for Luau compatibility ──────────────────

if not typeof then
    _G.typeof = function(v)
        local t = type(v)
        if t == "table" and v._robloxType then return v._robloxType end
        return t
    end
end

-- ── Mock Roblox `game` global ────────────────────────────

if not game then
    local function mockSignal()
        return { Connect = function(self, fn) return {Disconnect = function() end} end }
    end
    local mockPlayers = {
        PlayerAdded = mockSignal(),
        PlayerRemoving = mockSignal(),
        Players = {},
    }
    local mockReplicatedStorage = {
        WaitForChild = function(self, name) return self end,
    }
    local services = {
        Players = mockPlayers,
        ReplicatedStorage = mockReplicatedStorage,
        RunService = { Heartbeat = mockSignal(), RenderStepped = mockSignal() },
    }
    _G.game = setmetatable({}, {
        __index = function(t, k)
            if k == "GetService" then
                return function(self, name) return services[name] or {} end
            end
            return services[k] or {}
        end
    })
    _G.Players = mockPlayers
end

-- ── Expose globally ─────────────────────────────────────

_G.expect = expect
_G.describe = testkit.describe
_G.it = testkit.it
_G.test = testkit.test
_G.beforeAll = testkit.beforeAll
_G.afterAll = testkit.afterAll
_G.beforeEach = testkit.beforeEach
_G.afterEach = testkit.afterEach

return testkit
