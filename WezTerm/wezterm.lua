-- WezTerm configuration - Windows today, macOS/Linux ready.
--
-- Deployed by SymbolicLinkMaker to ~/.config/wezterm/wezterm.lua (WezTerm checks
-- $XDG_CONFIG_HOME/wezterm/wezterm.lua, then ~/.wezterm.lua, on every platform).
--
-- This is an ADDITION next to Windows Terminal, not a replacement: Windows Terminal
-- keeps its settings_{MachineType}.json symlink and stays the default terminal.
-- WezTerm exists for its first-class CLI (`wezterm cli spawn/list/set-tab-title`),
-- which is the cross-platform equivalent of `wt new-tab --title` that the macOS
-- workspace port builds on.
--
-- Appearance is a deliberate port of Windows/WindowsTerminal/settings_{MachineType}.json,
-- the same way Unix/ghostty/config ports it: same font, same opacity, same 16-colour
-- Campbell palette, so ANSI-coloured output (ls, git diff, oh-my-posh) renders
-- identically in every terminal on every machine.

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- --- Shell -------------------------------------------------------------------
-- On Windows, land in PowerShell 7 so the full profile chain loads exactly as it
-- does in Windows Terminal: profile.ps1 (all-hosts additions, e.g. the WezTerm
-- fastfetch logo) first, then Microsoft.PowerShell_profile.ps1 (modules,
-- oh-my-posh, aliases, fastfetch). pwsh.exe resolves via PATH.
--
-- On macOS/Linux the default login shell is kept for now; the pwsh branch arrives
-- with the Unix workspace port.
if wezterm.target_triple:find('windows') then
	config.default_prog = { 'pwsh.exe', '-NoLogo' }
end

-- --- Start folder and scrollback ---------------------------------------------
-- A new window starts on the Desktop on macOS, as Windows Terminal's startingDirectory does
-- (profiles.defaults in settings_*.json); a new tab keeps the folder of the pane it came from.
if wezterm.target_triple:find('darwin') then
	config.default_cwd = wezterm.home_dir .. '/Desktop'
end
-- historySize 9999 of the Windows Terminal settings (WezTerm's own default is 3500).
config.scrollback_lines = 9999

-- --- Font --------------------------------------------------------------------
-- Matches profiles.defaults.font.face in the Windows Terminal settings. The
-- oh-my-posh theme is dense with Nerd Font glyphs - without a Nerd Font the
-- prompt renders as tofu. Size 12 is Windows Terminal's default.
config.font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Regular' })
config.font_size = 12.0
-- A font size change keeps the window size and changes the rows and columns instead, as in
-- Windows Terminal. The greeting's auto-fit shrinks the font until the panel fits (see the
-- user-var-changed handler below), which only works when the window does not grow back to
-- the old cell count; a tiled window would also fight AeroSpace.
config.adjust_window_size_when_changing_font_size = false

-- --- Colours: Windows Terminal "Campbell" ------------------------------------
-- The PowerShell profile in Windows Terminal sets no colorScheme, so it uses the
-- built-in default, Campbell. Reproduced explicitly (same values as
-- Unix/ghostty/config) rather than via a named scheme, so the config does not
-- depend on which schemes a given WezTerm build happens to bundle.
config.colors = {
	background = '#0C0C0C',
	foreground = '#CCCCCC',

	ansi = {
		'#0C0C0C', -- black
		'#C50F1F', -- red
		'#13A10E', -- green
		'#C19C00', -- yellow
		'#0037DA', -- blue
		'#881798', -- magenta
		'#3A96DD', -- cyan
		'#CCCCCC', -- white
	},
	brights = {
		'#767676', -- bright black
		'#E74856', -- bright red
		'#16C60C', -- bright green
		'#F9F1A5', -- bright yellow
		'#3B78FF', -- bright blue
		'#B4009E', -- bright magenta
		'#61D6D6', -- bright cyan
		'#F2F2F2', -- bright white
	},

	cursor_bg = '#FFFFFF',
	cursor_border = '#FFFFFF',

	-- Windows Terminal sets selectionBackground #FFFFFF and inverts the text on top.
	selection_bg = '#FFFFFF',
	selection_fg = '#0C0C0C',
}

-- Matches Windows Terminal's cursorShape "bar".
config.default_cursor_style = 'SteadyBar'

-- copyOnSelect false of the Windows Terminal settings: a mouse selection stays a selection and
-- only Cmd+C (Ctrl+Shift+C) copies it to the clipboard. WezTerm's default left-button release
-- (and the release after a double- or triple-click word or line selection) would copy every
-- selection to the clipboard as well.
config.mouse_bindings = {}
for streak = 1, 3 do
	table.insert(config.mouse_bindings, {
		event = { Up = { streak = streak, button = 'Left' } },
		mods = 'NONE',
		action = wezterm.action.CompleteSelection 'PrimarySelection',
	})
end
-- The Option-drag block selection too.
table.insert(config.mouse_bindings, {
	event = { Up = { streak = 1, button = 'Left' } },
	mods = 'ALT',
	action = wezterm.action.CompleteSelection 'PrimarySelection',
})

-- --- Keys ----------------------------------------------------------------------
-- The key actions of the Windows Terminal settings (actions / keybindings of settings_*.json):
--   Shift+Enter        sends ESC CR, the newline-without-submit of Claude Code and other TUIs
--   Cmd+W              closes the focused pane only (Windows' Ctrl+W closePane); the tab goes
--                      with its last pane
--   Cmd+Shift+W        closes the whole tab
--   Cmd+Shift+X        moves the focused pane into a new window (Windows' Alt+X moveTab; Option
--                      types characters on the Mac)
-- Always-on-top (Windows' toggleAlwaysOnTop) is not bound: stable WezTerm has no such action yet.
config.keys = {
	{ key = 'Enter', mods = 'SHIFT', action = wezterm.action.SendString '\x1b\r' },
}
if wezterm.target_triple:find('darwin') then
	table.insert(config.keys, { key = 'w', mods = 'SUPER', action = wezterm.action.CloseCurrentPane { confirm = false } })
	table.insert(config.keys, { key = 'w', mods = 'SUPER|SHIFT', action = wezterm.action.CloseCurrentTab { confirm = false } })
	table.insert(config.keys, {
		key = 'x',
		mods = 'SUPER|SHIFT',
		action = wezterm.action_callback(function(_, pane)
			pane:move_to_new_window()
		end),
	})
end

-- --- Launch menu: the Conda terminal ---------------------------------------------
-- The "Conda" profile of Windows Terminal: conda's shell hook, the base environment activated,
-- the Conda fastfetch panel (FastFetch/Unix/config_Conda.jsonc), then an interactive zsh in the
-- home folder. Opened from the launcher (right-click the + of the tab bar). The rc skips its own
-- greeting there, and gives the final shell conda's shell function back (it starts inside an
-- activated environment), so `conda activate` keeps working.
if wezterm.target_triple:find('darwin') then
	config.launch_menu = {
		{
			label = 'Conda',
			args = {
				'zsh',
				'-i',
				'-c',
				'eval "$(conda shell.zsh hook)" && conda activate base && fastfetch --config "$DOTFILES_ROOT/FastFetch/Unix/config_Conda.jsonc" --logo "$DOTFILES_ROOT/FastFetch/Unix/FastFetchLogo_Conda.txt"; exec zsh -i',
			},
			set_environment_variables = { FOUNDATION_STARTUP_SKIP = 'Greeting' },
			cwd = wezterm.home_dir,
		},
	}
end

-- --- Window ------------------------------------------------------------------
-- opacity 70 with useAcrylic false in Windows Terminal: plain transparency,
-- no blur behind it.
config.window_background_opacity = 0.7

-- Kitty graphics protocol, OFF by default in WezTerm. FastFetch/Unix/config_*.jsonc
-- renders the Apple logo through it ("kitty-direct", chosen for Ghostty). With
-- the protocol disabled WezTerm swallows the image but fastfetch still reserves
-- the 30-column logo area, so the panel appears shifted right with no logo (or,
-- when a frame gets through, with misaligned rows). Enabling it makes the same
-- config render identically in WezTerm and Ghostty.
config.enable_kitty_graphics = true

-- Box-drawing characters come from the font, not WezTerm's built-in block
-- renderer. The fastfetch panel is a frame of ╭─╮╰─╯ lines with • and Nerd Font
-- glyphs on the same rows; WezTerm's synthesized box glyphs sit a few pixels off
-- the font's glyphs, which reads as a jumbled frame. JetBrainsMono Nerd Font
-- ships every box-drawing character, so letting it draw them keeps the frame
-- and its neighbours on one baseline.
config.custom_block_glyphs = false

-- Never ask "really quit?" on Cmd+Q / closing the last window: Kill-All and
-- Close-Workspace tear terminals down programmatically and a confirmation dialog
-- would stall them, and the interactive Cmd+Q should be as immediate as it is in
-- Windows Terminal. Tabs are closed the same way (no per-tab confirmation).
config.window_close_confirmation = 'NeverPrompt'
config.skip_close_confirmation_for_processes_named = {
	'bash', 'sh', 'zsh', 'fish', 'tmux', 'nu', 'pwsh', 'powershell', 'cmd.exe', 'pwsh.exe', 'powershell.exe',
}

-- Windows Terminal's default padding.
config.window_padding = {
	left = 8,
	right = 8,
	top = 8,
	bottom = 8,
}

-- FancyZones note: nothing to configure here. WezTerm windows are ordinary
-- top-level windows (process wezterm-gui), so Shift+drag and Win+Arrow snapping
-- work out of the box. A workspace layout entry targeting WezTerm would use
-- ProcessName = "wezterm-gui".

-- --- Tab titles ----------------------------------------------------------------
-- The --suppressApplicationTitle analog. Workspace and project tabs get their name
-- (Dotfiles.ROOT) from `wezterm cli set-tab-title`; without this handler a program
-- that sets the terminal title (npm run dev, the shell prompt) would replace it on
-- screen. An explicitly set tab title always wins; other tabs show the pane title.
wezterm.on('format-tab-title', function(tab)
	local title = tab.tab_title
	if title and #title > 0 then
		return ' ' .. title .. ' '
	end
	return ' ' .. tab.active_pane.title .. ' '
end)

-- --- Greeting auto-fit -------------------------------------------------------
-- The Ctrl+0 / Ctrl+Minus keys Invoke-Fastfetch sends to Windows Terminal. The shell sends the
-- user variable FONT_STEP ("STEP PID", wt_font_step in Unix/lib/drivers/wezterm.sh): STEP 0
-- resets the font to the default, any other STEP shrinks it once more. The same actions as
-- Cmd+0 and Cmd+-, so the keyboard keeps working on top of it. Per window, as every WezTerm font
-- size is.
wezterm.on('user-var-changed', function(window, pane, name, value)
	if name ~= 'FONT_STEP' then
		return
	end
	local step = tonumber(value:match('^(%d+)'))
	if step == nil then
		return
	end
	if step == 0 then
		window:perform_action(wezterm.action.ResetFontSize, pane)
	else
		window:perform_action(wezterm.action.DecreaseFontSize, pane)
	end
end)

-- --- Local overrides ---------------------------------------------------------
-- A fork's own settings go in WezTerm/wezterm.local.lua, never in this shared file; chezmoi links
-- it next to this one (~/.config/wezterm/wezterm.local.lua) when the repository has it. It returns
-- a function that changes the config, run last so its values win:
--   return function(config, wezterm) config.font_size = 14.0 end
-- An error in it is logged (Ctrl+Shift+L shows the debug overlay) and the shared settings still
-- apply. Without the file nothing happens.
local local_file = wezterm.config_dir .. '/wezterm.local.lua'
local handle = io.open(local_file, 'r')
if handle then
	handle:close()
	wezterm.add_to_config_reload_watch_list(local_file)
	local loaded, extend = pcall(dofile, local_file)
	if loaded and type(extend) == 'function' then
		local applied, problem = pcall(extend, config, wezterm)
		if not applied then
			wezterm.log_error('wezterm.local.lua: ' .. tostring(problem))
		end
	elseif not loaded then
		wezterm.log_error('wezterm.local.lua: ' .. tostring(extend))
	else
		wezterm.log_error('wezterm.local.lua must return a function(config, wezterm)')
	end
end

return config
