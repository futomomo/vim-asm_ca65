" Vim indent file
" Language:         CA65 Assembler for 6502 Architectures
" Maintainer:       Max Bane <max.bane@gmail.com>

" Way derived from $VIMRUNTIME/indent/python.vim

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

" Some preliminary settings
setlocal nolisp     " Make sure lisp indenting doesn't supersede us
setlocal autoindent " indentexpr isn't much help otherwise

setlocal indentexpr=GetAsmCA65Indent(v:lnum)
"setlocal indentkeys+=<:>,=elif,=except
setlocal indentkeys+=<:>,=.else,=.elseif,=.endif,.endmacro,.endstruct,.endunion,.endenum,.endscope,.endproc

" Only define the function once.
if exists("*GetAsmCA65Indent")
    finish
endif
let s:keepcpo= &cpo
set cpo&vim

" Come here when loading the script the first time.

let s:maxoff = 50        " maximum number of lines to look backwards for ()

function GetAsmCA65Indent(lnum)

    " If the start of the line is in a string don't change the indent.
    if has('syntax_items')
        \ && synIDattr(synID(a:lnum, 1, 1), "name") =~ "String$"
        return -1
    endif

    " Search backwards for the previous non-empty line.
    let plnum = prevnonblank(v:lnum - 1)

    if plnum == 0
        " This is the first non-empty line, use zero indent.
        return 0
    endif

    " If the previous line is inside parenthesis, use the indent of the starting
    " line.
    " Trick: use the non-existing "dummy" variable to break out of the loop when
    " going too far back.
    call cursor(plnum, 1)
    let parlnum = searchpair('(\|{\|\[', '', ')\|}\|\]', 'nbW',
            \ "line('.') < " . (plnum - s:maxoff) . " ? dummy :"
            \ . " synIDattr(synID(line('.'), col('.'), 1), 'name')"
            \ . " =~ '\\(Comment\\|Todo\\|String\\)$'")
    if parlnum > 0
        let plindent = indent(parlnum)
        let plnumstart = parlnum
    else
        let plindent = indent(plnum)
        let plnumstart = plnum
    endif


    " When inside parenthesis (macro call): If at the first line below the
    " parenthesis add two 'shiftwidth', otherwise same as previous line.
    " i = m(a
    "       + b
    "       + c)
    call cursor(a:lnum, 1)
    let p = searchpair('(\|{\|\[', '', ')\|}\|\]', 'bW',
            \ "line('.') < " . (a:lnum - s:maxoff) . " ? dummy :"
            \ . " synIDattr(synID(line('.'), col('.'), 1), 'name')"
            \ . " =~ '\\(Comment\\|Todo\\|String\\)$'")
    if p > 0
        if p == plnum
            " When the start is inside parenthesis, only indent one 'shiftwidth'.
            let pp = searchpair('(\|{\|\[', '', ')\|}\|\]', 'bW',
            \ "line('.') < " . (a:lnum - s:maxoff) . " ? dummy :"
            \ . " synIDattr(synID(line('.'), col('.'), 1), 'name')"
            \ . " =~ '\\(Comment\\|Todo\\|String\\)$'")
            if pp > 0
        return indent(plnum) + (exists("g:asm_ca65_indent_nested_paren") ? eval(g:asm_ca65_indent_nested_paren) : shiftwidth())
            endif
            return indent(plnum) + (exists("g:asm_ca65_indent_open_paren") ? eval(g:asm_ca65_indent_open_paren) : (shiftwidth() * 2))
        endif
        if plnumstart == p
            return indent(plnum)
        endif
        return plindent
    endif


    " Get the line and remove a trailing comment.
    " Use syntax highlighting attributes when possible.
    let pline = getline(plnum)
    let pline_len = strlen(pline)
    if has('syntax_items')
        " If the last character in the line is a comment, do a binary search for
        " the start of the comment.    synID() is slow, a linear search would take
        " too long on a long line.
        if synIDattr(synID(plnum, pline_len, 1), "name") =~ "\\(Comment\\|Todo\\)$"
            let min = 1
            let max = pline_len
            while min < max
        let col = (min + max) / 2
        if synIDattr(synID(plnum, col, 1), "name") =~ "\\(Comment\\|Todo\\)$"
            let max = col
        else
            let min = col + 1
        endif
            endwhile
            let pline = strpart(pline, 0, min - 1)
        endif
    else
        let col = 0
        while col < pline_len
            if pline[col] == '#'
        let pline = strpart(pline, 0, col)
        break
            endif
            let col = col + 1
        endwhile
    endif

    " If the previous line ended with a colon, indent this line
    if pline =~ ':\s*$'
        return plindent + shiftwidth()
    endif

    " If the previous line began with a block/scope-opening command, indent
    " this line
    if pline =~ '^\s*\.\(if.*\|macro\|struct\|union\|scope\|proc\)\>'
        return plindent + shiftwidth()
    endif

    " If the previous line was a stop-execution statement...
    if getline(plnum) =~ '^\s*\(rts\|rti\|\.exitmacro\|.exitmac\)\>'
        " See if the user has already dedented
        if indent(a:lnum) > indent(plnum) - shiftwidth()
            " If not, recommend one dedent
            return indent(plnum) - shiftwidth()
        endif
        " Otherwise, trust the user
        return -1
    endif

    " If the current line begins with a block/scope-ending keyword, dedent
    if getline(a:lnum) =~ '^\s*\.\(else\|elseif\|end.\+\)\>'

        " Unless the previous line was a one-liner
        " if getline(plnumstart) =~ '^\s*\(for\|if\|try\)\>'
        "     return plindent
        " endif

        " Or the user has already dedented
        if indent(a:lnum) <= plindent - shiftwidth()
            return -1
        endif

        return plindent - shiftwidth()
    endif

    " When after a () construct we probably want to go back to the start line.
    " a = (b
    "             + c)
    " here
    if parlnum > 0
        return plindent
    endif

    return -1

endfunction

let &cpo = s:keepcpo
unlet s:keepcpo
