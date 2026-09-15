--[==============================[
# typst-compat.lua

Rewrites the raw LaTeX that ISC Markdown sources legitimately contain into
its Typst equivalent. Without this filter the Typst writer drops those
constructs silently, which is worse than failing: `\ref{fig}` simply
vanishes and the sentence around it loses its cross-reference.

Handled:

    \newpage / \clearpage / \pagebreak   ->  #pagebreak()
    \label{x} in a figure caption        ->  a Typst label placed after the figure
    \ref{x} / \autoref{x} / \pageref{x}  ->  @x

Active for Typst output only; every other writer sees the document
unchanged, so the LaTeX pipeline keeps working exactly as before.

## Author

Pierre-André Mudry, ISC documents toolchain.
--]==============================]

if not FORMAT:match 'typst' then
  return {}
end

local function is_latex (el)
  return el.format == 'latex' or el.format == 'tex'
end

-- ── Page breaks ───────────────────────────────────────────────────────────
local function rawblock (el)
  if is_latex(el) and el.text:match('^\\%s*$') == nil then
    if el.text:match('^\\newpage') or el.text:match('^\\clearpage')
        or el.text:match('^\\pagebreak') then
      return pandoc.RawBlock('typst', '#pagebreak()')
    end
  end
  return nil
end

-- ── Cross-references ──────────────────────────────────────────────────────
-- `\label{}` is not handled here: it has to be moved *after* the figure it
-- belongs to, which only the Figure handler below can do. Inline it is
-- dropped, so a stray label never leaks into the output.
local function rawinline (el)
  if not is_latex(el) then return nil end

  local target = el.text:match('^\\ref%s*{([^}]*)}')
      or el.text:match('^\\autoref%s*{([^}]*)}')
      or el.text:match('^\\pageref%*?%s*{([^}]*)}')
  if target then
    -- `@name` would print "Figure 1"; LaTeX's \ref prints just "1", and the
    -- sources already write "la figure \ref{...}" in full.
    return pandoc.RawInline('typst',
      '#ref(<' .. target .. '>, supplement: none)')
  end

  if el.text:match('^\\label%s*{') then
    return {}
  end

  -- A bare \newpage sometimes ends up inline, glued to the end of a
  -- paragraph or a list item. Typst forbids a page break inside a
  -- container, and there is no equivalent: dropping it is the only option.
  -- No loss in practice -- a manual page break is pagination tuning for one
  -- specific engine, and the two engines do not break pages in the same
  -- places anyway.
  if el.text:match('^\\newpage') or el.text:match('^\\clearpage')
      or el.text:match('^\\pagebreak') then
    return {}
  end

  return nil
end

-- ── Figures ───────────────────────────────────────────────────────────────
-- Pulls `\label{x}` out of the caption and re-emits it as a Typst label
-- right after the figure, which is where Typst expects to find one.
local function figure (el)
  local name = nil

  el = pandoc.walk_block(el, {
    RawInline = function (inline)
      if is_latex(inline) then
        local found = inline.text:match('^\\label%s*{([^}]*)}')
        if found then
          name = found
          return {}
        end
      end
      return nil
    end,
  })

  if name then
    return { el, pandoc.RawBlock('typst', '<' .. name .. '>') }
  end

  return el
end

-- Pandoc applies inline handlers before block handlers inside one filter
-- table, which would strip `\label{}` before `figure()` could move it.
-- Returning two tables forces a full first pass over the figures, then a
-- second one over everything else.
return {
  { Figure = figure },
  { RawBlock = rawblock, RawInline = rawinline },
}
