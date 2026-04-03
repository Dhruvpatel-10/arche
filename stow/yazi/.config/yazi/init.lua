-- init.lua — plugin initialization

-- Git status signs in file list
require("git"):setup({
	order = 1500,
})

-- Full border around UI
require("full-border"):setup({
	type = ui.Border.ROUNDED,
})
