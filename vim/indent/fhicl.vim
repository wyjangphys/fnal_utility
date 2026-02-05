" ~/.vim/indent/fhicl.vim
" Basic indentation based on curly parenthesis

function! GetFhiclIndent()
  if v:lnum == 1
    return 0
  endif

  let lnum  = v:lnum - 1
  let open  = 0
  let close = 0

  " count curly braces up to previous line
  for i in range(1, lnum)
    let line = getline(i)
    if line =~ '^\s*#' || line =~ '^\s*//'
      continue
    endif
    let open  += len(split(line, '{')) - 1
    let close += len(split(line, '}')) - 1
  endfo

  let base_level = (open - close)
  if base_level < 0
    let base_level = 0
  endif

  " default indentation width
  let sw = &shiftwidth
  if sw == 0
    let sw = &tabstop
  endif

  let prev = getline(lnum)
  if prev =~ '{\s*$' || prev =~ '=\s*{\s*$' prev =~ ':\s*{\s*$'
    return base_level * sw + sw
  endif

  if prev =~ ',\s*$'
    return base_level * sw
  endif

  return base_level * sw
endfunction

" Set vim use indentexpr
setlocal indentexpr=GetFhiclIndent()
setlocal autoindent
