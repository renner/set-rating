#!/usr/bin/env lua
--[[
  Nautilus script: Set star rating (XMP:Rating) on selected image(s)

  Install:
    1. Save this file as ~/.local/share/nautilus/scripts/Set Rating.lua
    2. chmod +x "~/.local/share/nautilus/scripts/Set Rating.lua"
    3. Requires: lua5.3 (or similar), exiftool, zenity
       sudo apt install lua5.3 libimage-exiftool-perl zenity

  Usage:
    Right-click one or more images in Nautilus -> Scripts -> Set Rating.lua
    A dialog will ask for a rating 0-5 (or -1 to reject).
    darktable will pick up the change next time it reads/re-imports the file
    (Preferences -> Storage -> "look for updated xmp files", or
    right-click -> "read metadata from image" in lighttable).

  Sidecar handling:
    If darktable has already created an XMP sidecar for the selected image
    (e.g. "IMG_0001.CR3.xmp" next to "IMG_0001.CR3"), the rating is written
    to the sidecar instead of the original file. darktable reads ratings
    from the sidecar preferentially, so writing directly to the RAW/JPEG
    when a sidecar already exists would otherwise be ignored or overwritten
    the next time darktable saves its own sidecar.
--]]

local function get_selected_files()
  local files = {}
  local raw = os.getenv("NAUTILUS_SCRIPT_SELECTED_FILE_PATHS")
  if not raw or raw == "" then
    return files
  end
  for line in raw:gmatch("[^\n]+") do
    table.insert(files, line)
  end
  return files
end

local function shell_escape(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function ask_rating()
  local handle = io.popen(
    "zenity --scale --title='Set Rating' --text='Star rating (0-5, or -1 to reject):' " ..
    "--min-value=-1 --max-value=5 --value=0 --step=1 2>/dev/null"
  )
  local result = handle:read("*a")
  handle:close()
  result = result:gsub("%s+$", "") -- trim trailing newline
  return tonumber(result)
end

local function notify(msg)
  os.execute("notify-send " .. shell_escape("Set Rating") .. " " .. shell_escape(msg))
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- Given an image path, return the darktable-style sidecar path if one
-- exists, otherwise return nil. darktable sidecars are named
-- "<basename>.<ext>.xmp", e.g. "IMG_0001.CR3.xmp" (NOT "IMG_0001.xmp").
local function find_sidecar(path)
  local candidate = path .. ".xmp"
  if file_exists(candidate) then
    return candidate
  end
  return nil
end

local files = get_selected_files()
if #files == 0 then
  notify("No files selected.")
  os.exit(1)
end

local rating = ask_rating()
if rating == nil then
  -- user cancelled the dialog
  os.exit(0)
end

local ok_count = 0
local fail_count = 0
local sidecar_count = 0

for _, path in ipairs(files) do
  local sidecar = find_sidecar(path)
  local target = sidecar or path
  if sidecar then
    sidecar_count = sidecar_count + 1
  end

  -- -overwrite_original avoids exiftool leaving *_original backup copies
  local cmd = string.format(
    "exiftool -overwrite_original -XMP:Rating=%d %s",
    rating,
    shell_escape(target)
  )
  local ok, _, code = os.execute(cmd)
  if ok and code == 0 then
    ok_count = ok_count + 1
  else
    fail_count = fail_count + 1
  end
end

local suffix = ""
if sidecar_count > 0 then
  suffix = string.format(" (%d via .xmp sidecar)", sidecar_count)
end

if fail_count == 0 then
  notify(string.format("Set rating %d on %d file(s)%s.", rating, ok_count, suffix))
else
  notify(string.format("Rating set on %d file(s)%s, %d failed.", ok_count, suffix, fail_count))
end
