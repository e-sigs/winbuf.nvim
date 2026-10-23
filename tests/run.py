"""Regression tests on the installed Neovim, with a real attached RPC UI."""
import os
import signal
signal.alarm(60)  # Fail a stalled test instead of leaving an embedded UI running.
from pathlib import Path
import pynvim
ROOT = str(Path(__file__).resolve().parents[1])

def start():
 n=pynvim.attach('child',argv=['nvim','--embed','--headless','--clean','-n','-i','NONE'])
 n.ui_attach(140,42,rgb=True)
 n.exec_lua('vim.opt.rtp:prepend(...); vim.o.hidden=true; vim.o.mouse="a"; require("winbuf").setup({icons={enabled=false}})',ROOT)
 n.exec_lua('''
 vim.notify=function(message) last_notice=message end; T=require('winbuf.tracker'); A=require('winbuf.actions'); R=require('winbuf.render')
 function file(name,dirty)
  local b=vim.api.nvim_create_buf(true,false)
  if name then vim.api.nvim_buf_set_name(b,vim.fn.tempname()..'-'..name) end
  vim.api.nvim_set_current_buf(b)
  if dirty then vim.api.nvim_buf_set_lines(b,0,-1,false,{'unsaved '..(name or 'unnamed')}) end
  return b
 end
 function eq(a,b) assert(vim.deep_equal(a,b),vim.inspect(a)..' != '..vim.inspect(b)) end
 function list(w) return T.get_win_bufs(w) end
 function settle() vim.wait(30); R.refresh_all() end
 a=file('A');b=file('B');left=vim.api.nvim_get_current_win()
 ''')
 return n

cases={
'independent groups and split inheritance': '''
vim.cmd('rightbelow vsplit');right=vim.api.nvim_get_current_win();eq(list(right),{b});
c=file('C');d=file('D');T.remove_buf_from_win(right,b);A.select(c,right)
A.select(a,left);A.cycle(1);eq(list(left),{a,b});eq(list(right),{c,d});eq(vim.api.nvim_win_get_buf(right),c)
''',
'shared modified membership': '''
vim.api.nvim_buf_set_lines(b,0,-1,false,{'shared edits'});vim.cmd('rightbelow vsplit');right=vim.api.nvim_get_current_win();
vim.fn.confirm=function() error('shared buffer prompted') end
assert(A.close_buf(b));eq(list(left),{a,b});eq(vim.api.nvim_win_get_buf(left),b);assert(vim.bo[b].modified)
''',
'cancel and failed save are atomic': '''
vim.api.nvim_buf_set_lines(b,0,-1,false,{'dirty'});local before=vim.fn.winlayout()
vim.fn.confirm=function()return 3 end;assert(not A.close_buf());eq(list(left),{a,b});eq(vim.fn.winlayout(),before);eq(vim.api.nvim_get_current_buf(),b)
vim.api.nvim_buf_set_name(b,'/nonexistent-winbuf-directory/file');vim.fn.confirm=function()return 1 end
assert(not A.close_buf());eq(list(left),{a,b});eq(vim.api.nvim_get_current_buf(),b);assert(vim.bo[b].modified)
''',
'unnamed save cancellation and save': '''
u=file(nil,true);local before=list(left);vim.fn.confirm=function() return 1 end;vim.fn.input=function() return '' end
assert(not A.close_buf());eq(list(left),before);eq(vim.api.nvim_get_current_buf(),u)
local path=vim.fn.tempname();vim.fn.input=function()return path end;assert(A.close_buf());eq(vim.fn.readfile(path),{'unsaved unnamed'});vim.fn.delete(path)
''',
'explicit discard': '''
vim.api.nvim_buf_set_lines(b,0,-1,false,{'dirty'});vim.fn.confirm=function()return 2 end;assert(A.close_buf());eq(list(left),{a});assert(not vim.api.nvim_buf_is_valid(b) or not vim.bo[b].buflisted)
''',
'last editor excludes sidebar float other tab': '''
T.set_win_bufs(left,{b});vim.cmd('vnew');sidebar=vim.api.nvim_get_current_win();vim.bo.buftype='nofile';vim.wo.winbar='SIDEBAR'
local f=vim.api.nvim_create_buf(false,true);local float=vim.api.nvim_open_win(f,false,{relative='editor',row=4,col=4,width=8,height=3})
vim.cmd('tabnew');local tab=vim.api.nvim_get_current_tabpage();vim.cmd('tabprevious');vim.api.nvim_set_current_win(left)
assert(A.close_buf());assert(vim.api.nvim_win_is_valid(left));eq(#T.windows(),1);assert(vim.api.nvim_win_is_valid(sidebar));eq(vim.wo[sidebar].winbar,'SIDEBAR');assert(vim.api.nvim_tabpage_is_valid(tab))
local empty=vim.api.nvim_get_current_buf();local n=#vim.api.nvim_list_bufs();for i=1,20 do assert(A.close_buf()) end;eq(vim.api.nvim_get_current_buf(),empty);eq(#vim.api.nvim_list_bufs(),n);assert(not vim.bo[empty].buflisted);eq(list(left),{})
''',
'whole group inactive dirty cancellation': '''
vim.api.nvim_buf_set_lines(a,0,-1,false,{'inactive dirty'});vim.cmd('vsplit');right=vim.api.nvim_get_current_win();c=file('C');T.set_win_bufs(right,{c});vim.api.nvim_set_current_win(left)
local before=vim.fn.winlayout();vim.fn.confirm=function()return 3 end;assert(not A.close_split());eq(list(left),{a,b});eq(vim.fn.winlayout(),before)
vim.fn.confirm=function()return 2 end;assert(A.close_split());assert(not vim.api.nvim_win_is_valid(left));eq(list(right),{c})
''',
'guard restored after winfixbuf failure': '''
vim.wo.winfixbuf=true;assert(not A.close_buf());assert(not T._suppress_tracking);eq(list(left),{a,b});eq(vim.api.nvim_get_current_buf(),b)
vim.wo.winfixbuf=false;c=file('C');eq(list(left),{a,b,c})
''',
'ownership and special windows': '''
vim.cmd('vnew');local special=vim.api.nvim_get_current_win();vim.bo.buftype='nofile';vim.wo.winbar='OWNED';settle();eq(vim.wo.winbar,'OWNED');eq(list(special),{})
vim.api.nvim_set_current_win(left);vim.wo.winbar='OTHER PLUGIN';R.refresh_all();eq(vim.wo.winbar,'OTHER PLUGIN')
vim.wo.diff=true;settle();eq(list(left),{});eq(vim.wo.winbar,'OTHER PLUGIN');assert(not A.move_buf('l'))
''',
'move existing shared modified absent destination': '''
vim.api.nvim_buf_set_lines(b,0,-1,false,{'dirty'});vim.cmd('rightbelow vsplit');right=vim.api.nvim_get_current_win();c=file('C');T.set_win_bufs(right,{b,c});vim.api.nvim_set_current_win(left)
assert(A.move_buf('l'));eq(list(left),{a});eq(list(right),{b,c});eq(vim.api.nvim_win_get_buf(right),b);assert(vim.bo[b].modified)
assert(A.move_buf('h'));eq(list(right),{c});eq(list(left),{a,b});assert(A.move_buf('h'));local new=vim.api.nvim_get_current_win();eq(list(new),{b});eq(list(left),{a});eq(list(right),{c})
''',
'ordinary window close and external deletion': '''
vim.cmd('vsplit');right=vim.api.nvim_get_current_win();c=file('C');vim.cmd('close');eq(list(left),{a,b});assert(not T.is_buf_in_any_win(c));vim.api.nvim_buf_delete(a,{});eq(list(left),{b})
''',
'new workspace edits become a tab': '''
T.set_win_bufs(left,{b});assert(A.close_buf());local empty=vim.api.nvim_get_current_buf();eq(list(left),{});vim.api.nvim_buf_set_lines(empty,0,-1,false,{'new'});vim.api.nvim_exec_autocmds('TextChanged',{buffer=empty});eq(list(left),{empty});assert(vim.bo[empty].buflisted)
''',
}
cases.update({
'named save and failed unnamed destination': """
vim.api.nvim_buf_set_lines(b,0,-1,false,{'save me'});local path=vim.api.nvim_buf_get_name(b)
vim.fn.confirm=function()return 1 end;assert(A.close_buf());eq(vim.fn.readfile(path),{'save me'});vim.fn.delete(path)
u=file(nil,true);local before=list(left);vim.fn.input=function()return '/nonexistent-winbuf-directory/unnamed' end
assert(not A.close_buf());eq(vim.api.nvim_buf_get_name(u),'');eq(list(left),before);assert(vim.bo[u].modified)
""",
'explicit resolver cancellation and old callback rejection': """
assert(not pcall(require('winbuf').setup,{buf_delete=function()return false end}))
require('winbuf').config.resolve_modified=function()return 'cancel' end
vim.api.nvim_buf_set_lines(b,0,-1,false,{'dirty'});assert(not A.close_buf());eq(list(left),{a,b})
""",
'actual untracked visible reference is preserved': """
vim.api.nvim_buf_set_lines(b,0,-1,false,{'visible elsewhere'})
local f=vim.api.nvim_open_win(b,false,{relative='editor',row=5,col=5,width=20,height=3})
vim.fn.confirm=function()error('visible reference prompted')end
assert(A.close_buf());eq(vim.api.nvim_win_get_buf(f),b);assert(vim.bo[b].modified)
""",
'failed move does not mutate either group': """
vim.cmd('rightbelow vsplit');right=vim.api.nvim_get_current_win();c=file('C');T.set_win_bufs(right,{c});vim.wo.winfixbuf=true
vim.api.nvim_set_current_win(left);local before=vim.fn.winlayout();assert(not A.move_buf('l'));eq(list(left),{a,b});eq(list(right),{c});eq(vim.fn.winlayout(),before);assert(not T._suppress_tracking)
d=file('D');eq(list(left),{a,b,d})
""",
'injected switch failure restores membership': """
local original=vim.api.nvim_win_set_buf;vim.api.nvim_win_set_buf=function()error('injected switch failure')end
assert(not A.close_buf());vim.api.nvim_win_set_buf=original;eq(list(left),{a,b});eq(vim.api.nvim_win_get_buf(left),b);assert(not T._suppress_tracking)
c=file('C');eq(list(left),{a,b,c})
""",
})
cases.update({
'moves skip nearby sidebar and floating windows': """
vim.cmd('rightbelow vnew');local side=vim.api.nvim_get_current_win();vim.bo.buftype='nofile';vim.wo.winbar='SIDEBAR';vim.api.nvim_set_current_win(left)
local float=vim.api.nvim_open_win(a,false,{relative='editor',row=3,col=20,width=10,height=3})
assert(A.move_buf('l'));local target=vim.api.nvim_get_current_win();assert(target~=side and target~=float);eq(list(left),{a});eq(list(target),{b});eq(vim.wo[side].winbar,'SIDEBAR')
assert(A.close_buf());assert(not vim.api.nvim_win_is_valid(target));eq(list(left),{a})
""",
'whole final group retains workspace and handles inactive discard': """
vim.api.nvim_buf_set_lines(a,0,-1,false,{'inactive dirty'});vim.cmd('vnew');local side=vim.api.nvim_get_current_win();vim.bo.buftype='nofile';vim.api.nvim_set_current_win(left)
vim.fn.confirm=function()return 3 end;assert(not A.close_split());eq(list(left),{a,b})
vim.fn.confirm=function()return 2 end;assert(A.close_split());assert(vim.api.nvim_win_is_valid(left));eq(list(left),{});assert(T.empty(vim.api.nvim_win_get_buf(left)));assert(vim.api.nvim_win_is_valid(side))
""",
})
cases.update({
'empty groups do not share new unnamed documents': """
T.set_win_bufs(left,{b});assert(A.close_buf());local first=vim.api.nvim_get_current_buf();vim.cmd('rightbelow vsplit');local right=vim.api.nvim_get_current_win();local c=file('C');assert(A.close_buf(c,false,right,true));local second=vim.api.nvim_win_get_buf(right)
assert(first~=second);vim.api.nvim_buf_set_lines(second,0,-1,false,{'new document'});eq(vim.api.nvim_buf_get_lines(first,0,-1,false),{''})
""",
'whole close protects current file before tracking event': """
local u=file(nil,true);T.set_win_bufs(left,{});vim.fn.confirm=function()return 3 end;assert(not A.close_split());eq(vim.api.nvim_get_current_buf(),u);assert(vim.bo[u].modified)
""",
})
cases['custom eligibility is shared by tracking rendering and actions'] = """
vim.cmd('vsplit');local excluded=vim.api.nvim_get_current_win();local c=file('C');vim.wo.winbar='THIRD PARTY'
require('winbuf').config.eligible=function(win) return win~=excluded end
settle();assert(not T.eligible(excluded));eq(list(excluded),{});eq(vim.wo.winbar,'THIRD PARTY');assert(not A.close_buf());assert(not A.move_buf('l'));assert(not A.cycle(1))
vim.api.nvim_set_current_win(left);assert(A.move_buf('l'));assert(vim.api.nvim_get_current_win()~=excluded);eq(vim.api.nvim_win_get_buf(excluded),c)
"""
for label,code in cases.items():
 n=start()
 try:n.exec_lua(code);print('PASS',label)
 finally:
  try:n.command('qa!')
  except Exception:pass

# Mouse events must hit the real winbar rendered by the attached UI.
n=start()
try:
 n.exec_lua('''vim.cmd('rightbelow vsplit');right=vim.api.nvim_get_current_win();c=file('C');d=file('D');T.set_win_bufs(right,{c,d});vim.api.nvim_set_current_win(left);R.refresh_all();vim.cmd.redraw()''')
 row,col=n.exec_lua('return vim.api.nvim_win_get_position(right)')
 def click(offset,button='left'):
  n.api.input_mouse(button,'press','',0,row,col+offset);n.api.input_mouse(button,'release','',0,row,col+offset);n.command('sleep 30m')
 click(3)
 n.exec_lua('eq(vim.api.nvim_win_get_buf(left),b);eq(vim.api.nvim_win_get_buf(right),c)')
 # Find the actual rendered close icon column rather than invoke the callback.
 n.exec_lua('vim.api.nvim_set_current_win(left);vim.cmd.redraw()')
 bar=n.exec_lua('return vim.api.nvim_eval_statusline(vim.wo[right].winbar,{winid=right,use_winbar=true,maxwidth=100}).str')
 offset=bar.index('󰅖')
 # Prefix uses only single-cell characters in this fixture (except ellipsis, width 1).
 click(offset)
 n.exec_lua('eq(list(right),{d});eq(list(left),{a,b});eq(vim.api.nvim_win_get_buf(left),b)')
 # Shared tab middle-click must not remove left membership or edits.
 n.exec_lua('vim.api.nvim_set_current_win(right);vim.api.nvim_win_set_buf(right,b);vim.api.nvim_buf_set_lines(b,0,-1,false,{"shared"});vim.api.nvim_set_current_win(left);R.refresh_all();vim.cmd.redraw()')
 bar=n.exec_lua('return vim.api.nvim_eval_statusline(vim.wo[right].winbar,{winid=right,use_winbar=true,maxwidth=100}).str')
 # second tab starts after the second separator
 offset=bar.index('▎',1)+3
 click(offset,'middle')
 n.exec_lua('eq(list(right),{d});eq(list(left),{a,b});assert(vim.bo[b].modified)')
 print('PASS real mouse switching/closing unfocused and shared tabs')
finally:
 try:n.command('qa!')
 except Exception:pass
print('All regression cases passed')
