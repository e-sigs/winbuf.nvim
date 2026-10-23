"""Run against the audited upstream checkout; each test demonstrates a defect."""
from pathlib import Path
import os
import pynvim
ROOT = os.environ.get("WINBUF_UNDER_TEST", str(Path(__file__).resolve().parents[1]))

def start():
 n=pynvim.attach('child',argv=['nvim','--embed','--headless','--clean','-n','-i','NONE'])
 n.ui_attach(120,40,rgb=True)
 n.exec_lua('vim.opt.rtp:prepend(...); vim.o.hidden=true; vim.o.mouse="a"; require("winbuf").setup({icons={enabled=false}})',ROOT)
 n.exec_lua('''
 T=require('winbuf.tracker'); A=require('winbuf.actions'); R=require('winbuf.render')
 function file(name)
  local b=vim.api.nvim_create_buf(true,false)
  vim.api.nvim_buf_set_name(b,'/tmp/winbuf-audit-'..name)
  vim.api.nvim_set_current_buf(b);return b
 end
 a=file('A'); b=file('B'); w=vim.api.nvim_get_current_win(); T.set_win_bufs(w,{a,b})
 ''')
 return n

def run(label,code):
 n=start()
 try:
  result=n.exec_lua(code)
  print(label+': '+('REPRODUCED' if result else 'NOT REPRODUCED'))
  assert result,label
 finally:
  try:n.command('qa!')
  except Exception:pass

run('native delete refusal', '''vim.api.nvim_buf_set_lines(b,0,-1,false,{'dirty'}); A.close_buf(b); return not vim.tbl_contains(T.get_win_bufs(w),b) and vim.bo[b].modified''')
run('callback cancellation', '''require('winbuf').config.buf_delete=function() return false end; vim.api.nvim_buf_set_lines(b,0,-1,false,{'dirty'}); A.close_buf(b);return not vim.tbl_contains(T.get_win_bufs(w),b)''')
run('last editor plus sidebar', '''T.set_win_bufs(w,{b});vim.cmd('vnew');vim.bo.buftype='nofile';vim.api.nvim_set_current_win(w);A.close_buf(b);return not vim.api.nvim_win_is_valid(w)''')
run('winfixbuf guard leak', '''vim.wo.winfixbuf=true;pcall(A.close_buf,b);return T._suppress_tracking''')
run('special winbar overwritten', '''vim.cmd('vnew');vim.bo.buftype='nofile';vim.wo.winbar='SIDEBAR';R.refresh_all();return vim.wo.winbar~='SIDEBAR' ''')
n=start()
try:
 n.exec_lua('''vim.cmd('rightbelow vsplit');right=vim.api.nvim_get_current_win();c=file('C');d=file('D');T.set_win_bufs(right,{c,d});vim.api.nvim_set_current_win(w);R.refresh_all();vim.cmd.redraw()''')
 pos=n.exec_lua('return vim.api.nvim_win_get_position(right)')
 n.api.input_mouse('left','press','',0,pos[0],pos[1]+3)
 n.api.input_mouse('left','release','',0,pos[0],pos[1]+3)
 n.command('sleep 30m')
 bad=n.exec_lua('return vim.api.nvim_win_get_buf(w)==c and vim.api.nvim_win_get_buf(right)==d')
 print('unfocused winbar mouse: '+('REPRODUCED' if bad else 'NOT REPRODUCED'));assert bad
finally:
 try:n.command('qa!')
 except Exception:pass
