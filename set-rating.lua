#!/usr/bin/env lua
-- SPDX-License-Identifier: MIT
--[[
  Set Rating – Nautilus right-click script
  Writes XMP:Rating (0-5, -1=reject) into selected image(s) via exiftool.

  If a darktable sidecar (<file>.<ext>.xmp) exists the rating goes there;
  otherwise it is written directly into the image file.
  Requires: lua5.3, exiftool, zenity
    sudo apt install lua5.3 libimage-exiftool-perl zenity

  Install:
    cp set-rating.lua ~/.local/share/nautilus/scripts/"Set Rating.lua"
    chmod +x ~/.local/share/nautilus/scripts/"Set Rating.lua"

  darktable:
    darktable keeps metadata in its database and ignores external XMP
    changes while running. To pick up the new rating:
      Preferences -> Storage -> enable "look for updated xmp files on
      startup", then restart darktable.  A dialog will offer to reload
      the modified sidecars into the database.
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

local exiftool_check = os.execute("which exiftool >/dev/null 2>/dev/null")
if exiftool_check ~= 0 then
  notify("exiftool not found. Install: sudo zypper install exiftool")
  os.exit(1)
end

local sidecar_count = 0
local targets = {}

for _, path in ipairs(files) do
  local sidecar = find_sidecar(path)
  table.insert(targets, shell_escape(sidecar or path))
  if sidecar then
    sidecar_count = sidecar_count + 1
  end
end

local cmd = "exiftool -overwrite_original -XMP:Rating=" .. rating .. " "
         .. table.concat(targets, " ")
local ok, _, code = os.execute(cmd)

if ok and code == 0 then
  local suffix = ""
  if sidecar_count > 0 then
    suffix = string.format(" (%d via .xmp sidecar)", sidecar_count)
  end
  notify(string.format("Set rating %d on %d file(s)%s.", rating, #files, suffix))
else
  notify(string.format("Rating failed on %d file(s).", #files))
end
