---@type number
MODULE_AUTOREBOOT_DELAY = 1500;
---@type table<string, {path: string, editedAtLow: number, editedAtHigh: number}>
MODULE_AUTOREBOOT_MODULES = {};

local ffi = require('ffi');
ffi.cdef [[
	typedef void* HANDLE;
	typedef void* LPSECURITY_ATTRIBUTES;
	typedef unsigned long DWORD;
	typedef int BOOL;
	typedef const char *LPCSTR;
	typedef struct _FILETIME {
        DWORD dwLowDateTime;
        DWORD dwHighDateTime;
	} FILETIME, *PFILETIME, *LPFILETIME;

	BOOL __stdcall GetFileTime(HANDLE hFile, LPFILETIME lpCreationTime, LPFILETIME lpLastAccessTime, LPFILETIME lpLastWriteTime);
	HANDLE __stdcall CreateFileA(LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
	BOOL __stdcall CloseHandle(HANDLE hObject);
]];

---@param path string Path to file
---@return {low: number, high: number}
local function getFileEditedAt(path)
	local handle = ffi.C.CreateFileA(path, 0x80000000, 0x00000001 + 0x00000002, nil, 3, 0x00000080, nil);
	local filetime = ffi.new('FILETIME[3]');
	if (handle ~= -1) then
		local result = ffi.C.GetFileTime(handle, filetime, filetime + 1, filetime + 2);
		ffi.C.CloseHandle(handle);
		if (result ~= 0) then
			return { low = tonumber(filetime[2].dwLowDateTime), high = tonumber(filetime[2].dwHighDateTime) };
		end
	end
	return { low = -1, high = -1 };
end

---@param str string String
---@param separator string Separator
---@return string[]
local function split(str, separator)
    local result = {}
    for match in (str .. separator):gmatch('(.-)' .. separator) do
        table.insert(result, match)
    end
    return result
end

---@param path string Path to file or directory
---@return boolean doesExists Does file or directory exists
local function doesExists(path)
    local ok, err, code = os.rename(path, path);
    return ok or code == 0;
end

---@param module string Module name
---@return string? Path
local function findModulePath(module)
    for _, path in ipairs(split(package.path .. package.cpath, ';')) do
        local path = path:gsub('?%.', module:gsub('%.', '\\') .. '.');
        if (doesExists(path)) then
            return path;
        end
    end
end

local function loadUsedModules()
    MODULE_AUTOREBOOT_MODULES = {};
    for module in pairs(package.loaded) do
        local path = findModulePath(module);
        if (path) then
            local editedAt = getFileEditedAt(path);
            MODULE_AUTOREBOOT_MODULES[module] = { path = path, editedAtLow = editedAt.low, editedAtHigh = editedAt.high };
        end
    end
end

local function checkModules()
    while (true) do
        wait(MODULE_AUTOREBOOT_DELAY);
        for module, moduleInfo in pairs(MODULE_AUTOREBOOT_MODULES) do
            local editedAt = getFileEditedAt(moduleInfo.path);
            if (editedAt.low ~= moduleInfo.editedAtLow or editedAt.high ~= moduleInfo.editedAtHigh) then
                print(('[MODULE-AUTOREBOOT]: Module "%s" was edited, rebooting script...'):format(module));
                thisScript():reload();
            end
        end
    end
end

loadUsedModules();
return lua_thread.create(checkModules);
