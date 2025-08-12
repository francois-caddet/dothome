local map_multistep = require('mini.keymap').map_multistep

local tab_steps = {
	'minisnippets_next','minisnippets_expand','pmenu_next',
	'jump_after_tsnode', 'jump_after_close',
}
  map_multistep('i', '<Tab>', tab_steps)

  local shifttab_steps = {
	'minisnippets_prev', 'pmenu_prev',
	'jump_before_tsnode', 'jump_before_open',
}
  map_multistep('i', '<S-Tab>', shifttab_steps)
map_multistep('i', '<CR>',    { 'pmenu_accept', 'minipairs_cr' })
map_multistep('i', '<BS>',    { 'minipairs_bs' })
