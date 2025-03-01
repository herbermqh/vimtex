" VimTeX - LaTeX plugin for Vim
"
" Maintainer: Karl Yngve Lervåg
" Email:      karl.yngve@gmail.com
"

function! vimtex#view#zathura#new() abort " {{{1
  return s:viewer.init()
endfunction

" }}}1


let s:viewer = vimtex#view#_template#new({
      \ 'name': 'Zathura',
      \ 'xwin_id': 0,
      \ 'has_synctex': 1,
      \})

function! s:viewer._check() dict abort " {{{1
  " Check if Zathura is executable
  if !executable('zathura')
    call vimtex#log#error('Zathura is not executable!')
    return v:false
  endif

  " Check if Zathura has libsynctex
  if g:vimtex_view_zathura_check_libsynctex && executable('ldd')
    let l:shared = vimtex#jobs#capture('ldd $(which zathura)')
    if v:shell_error == 0
          \ && empty(filter(l:shared, 'v:val =~# ''libsynctex'''))
      call vimtex#log#warning('Zathura is not linked to libsynctex!')
      let s:viewer.has_synctex = 0
    endif
  endif

  return v:true
endfunction

" }}}1
function! s:viewer._exists() dict abort " {{{1
  return self.xdo_exists()
endfunction

" }}}1
function! s:viewer._start(outfile) dict abort " {{{1
  let l:cmd  = 'zathura'
  if self.has_synctex
    let l:cmd .= ' -x "' . s:inverse_search_cmd
          \ . ' -c \"VimtexInverseSearch %{line} ''%{input}''\""'
    if g:vimtex_view_forward_search_on_start
      let l:cmd .= ' --synctex-forward '
            \ .  line('.')
            \ .  ':' . col('.')
            \ .  ':' . vimtex#util#shellescape(expand('%:p'))
    endif
  endif
  let l:cmd .= ' ' . g:vimtex_view_zathura_options
  let l:cmd .= ' ' . vimtex#util#shellescape(a:outfile)
  let l:cmd .= '&'
  let self.cmd_start = l:cmd

  call vimtex#jobs#run(self.cmd_start)

  call self.xdo_get_id()
endfunction

" }}}1
function! s:viewer._forward_search(outfile) dict abort " {{{1
  if !self.has_synctex | return | endif

  let l:synctex_file = fnamemodify(a:outfile, ':r') . '.synctex.gz'
  if !filereadable(l:synctex_file) | return | endif

  let self.texfile = vimtex#paths#relative(expand('%:p'), b:vimtex.root)
  let self.outfile = vimtex#paths#relative(a:outfile, getcwd())

  let self.cmd_forward_search = printf(
        \ 'zathura --synctex-forward %d:%d:%s %s &',
        \ line('.'), col('.'),
        \ vimtex#util#shellescape(self.texfile),
        \ vimtex#util#shellescape(self.outfile))

  call vimtex#jobs#run(self.cmd_forward_search)
endfunction

" }}}1

function! s:viewer.get_pid() dict abort " {{{1
  " First try to match full output file name
  let l:outfile = fnamemodify(get(self, 'outfile', self.out()), ':t')
  let l:output = vimtex#jobs#capture(
        \ 'pgrep -nf "^zathura.*' . escape(l:outfile, '~\%.') . '"')
  let l:pid = str2nr(join(l:output, ''))
  if !empty(l:pid) | return l:pid | endif

  " Now try to match correct servername as fallback
  let l:output = vimtex#jobs#capture(
        \ 'pgrep -nf "^zathura.+--servername ' . v:servername . '"')
  return str2nr(join(l:output, ''))
endfunction

" }}}1


let s:inverse_search_cmd = get(g:, 'vimtex_callback_progpath',
      \                        get(v:, 'progpath', get(v:, 'progname', '')))
      \ . (has('nvim')
      \   ? ' --headless'
      \   : ' -T dumb --not-a-term -n')
