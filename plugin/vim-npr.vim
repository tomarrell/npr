" Vim-NPR
" Max number of directory levels gf will traverse upwards
" to find a package.json file.
if !exists("g:vim_npr_max_levels")
  let g:vim_npr_max_levels = 5
endif

" Default file names to try if gf is run on a directory rather than a specific file.
" Checked in order of appearance. Empty string to check for exact file match first.
" The final two are specifically for matching libraries which define their UMD
" module resolution in their package.json, and these are the most common.
if !exists("g:vim_npr_file_names")
  let g:vim_npr_file_names = ["", ".js", ".jsx", "/index.js", "/index.jsx", "/src/index.js", "/lib/index.js"]
endif

" A list of file extensions that the plugin will actively work on.
if !exists("g:vim_npr_file_types")
  let g:vim_npr_file_types = ["js", "jsx", "css", "coffee"]
endif

" Default resolution directories if 'resolve' key is not found in package.json.
if !exists("g:vim_npr_default_dirs")
  let g:vim_npr_default_dirs = ["src", "lib", "test", "public", "node_modules"]
endif

function! VimNPRFindFile(cmd)
  return s:FindFile(a:cmd, 'same')
endfunction

function! VimNPRFindFile_NewWindow(cmd)
  return s:FindFile(a:cmd, 'window')
endfunction

function! VimNPRFindFile_NewTab(cmd)
  return s:FindFile(a:cmd, 'tab')
endfunction

function! s:FindFile(cmd, place) abort
  if index(g:vim_npr_file_types, expand("%:e")) == -1
    return s:print_error("(Error) VimNPR: incorrect file type for to perform resolution within. Please raise an issue at github.com/tomarrell/vim-npr.") " Don't run on filetypes that we don't support
  endif

  " Get file path pattern under cursor
  let l:cfile = expand("<cfile>")

  " Iterate over potential directories and search for the file
  for filename in g:vim_npr_file_names
    let l:possiblePath = expand("%:p:h") . '/' . l:cfile . filename

    if filereadable(l:possiblePath)
      return s:edit_file(l:possiblePath, a:cmd, a:place)
    endif
  endfor

  let l:foundPackage = 0
  let l:levels = 0

  " Traverse up directories and attempt to find package.json
  while l:foundPackage != 1 && l:levels < g:vim_npr_max_levels
    let l:levels = l:levels + 1
    let l:foundPackage = filereadable(expand('%:p'.repeat(':h', l:levels)) . '/package.json')
  endwhile

  if l:foundPackage == 0
    return s:print_error("(Error) VimNPR: Failed to find package.json, try increasing the levels by increasing g:vim_npr_max_levels variable.")
  endif

  " Handy paths to package.json and parent dir
  let l:packagePath = globpath(expand('%:p'.repeat(':h', l:levels)), 'package.json')
  let l:packageDir = fnamemodify(l:packagePath, ':h')

  try
    let l:resolveDirs = json_decode(join(readfile(l:packagePath))).resolve
  catch
    echo "Couldn't find 'resolve' key in package.json"
    let l:resolveDirs = g:vim_npr_default_dirs
  endtry

  " Iterate over potential directories and search for the file
  for dir in l:resolveDirs
    if l:cfile =~ '^\~'
      let l:possiblePath = substitute(l:cfile, '\~', l:packageDir . "/" . dir . "/", 'g')
    else
      let l:possiblePath = l:packageDir . "/" . dir . "/" . l:cfile
    endif

    for filename in g:vim_npr_file_names
      if filereadable(possiblePath . filename)
        return s:edit_file(possiblePath . filename, a:cmd, a:place)
      endif
    endfor
  endfor

  " Nothing found, print resolution error
  return s:print_error("(Error) VimNPR: Failed to sensibly resolve file in path. If you believe this to be an error, please log an error at github.com/tomarrell/vim-npr.")
endfunction


function! s:edit_file(path, cmd, place)
  "Open in the same window
  if a:place == "same"
    exe "edit" . a:cmd . " " . a:path
  endif
  "Open in a new (horizontal) window
  if a:place == "window"
    exe "sp" . a:cmd . " " . a:path
  endif
  "Open in a new tab
  if a:place == "tab"
    exe "tabnew" . a:cmd . " " . a:path
  endif
endfunction

function! s:print_error(error)
  echohl ErrorMsg
  echomsg a:error
  echohl NONE
  let v:errmsg = a:error
endfunction

" Unmap any user mapped gf functionalities. This is to restore gf
" when hijacked by another plugin e.g. vim-node
autocmd FileType javascript silent! unmap <buffer> gf
autocmd FileType javascript silent! unmap <buffer> <C-w>f
autocmd FileType javascript silent! unmap <buffer> <C-w><C-f>

" Automap gf when entering JS/css file types
autocmd BufEnter *.js,*.jsx,*.css,*.coffee nmap <buffer> gf :call VimNPRFindFile("")<CR>
autocmd BufEnter *.js,*.jsx,*.css,*.coffee nmap <buffer> <C-w>f :call VimNPRFindFile_NewWindow("")<CR>
autocmd BufEnter *.js,*.jsx,*.css,*.coffee nmap <buffer> <C-w>gf :call VimNPRFindFile_NewTab("")<CR>
