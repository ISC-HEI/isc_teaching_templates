--[==============================[
# typst-compat.lua

Rewrites the raw LaTeX that ISC Markdown sources legitimately contain into
its Typst equivalent. Without this filter the Typst writer drops those
constructs silently, which is worse than failing: `\ref{fig}` simply
vanishes and the sentence around it loses its cross-reference.

Handled:

    \newpage / \clearpage / \pagebreak   ->  #pagebreak()
    \vspace{4mm} / \vspace*{4mm}         ->  #v(4mm)
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

-- ── Vertical space ───────────────────────────────────────────────────────
-- Typst understands pt, mm, cm, in and em, so a \vspace in one of those
-- units maps straight across. Anything else (ex, \baselineskip, a stretch
-- like `1fill`) has no direct equivalent and is left out rather than
-- guessed at.
local typst_units = { pt = true, mm = true, cm = true, ['in'] = true, em = true }

local function vspace (text)
  local amount, unit = text:match('^\\vspace%*?%s*{%s*(-?[%d%.]+)%s*(%a+)%s*}')
  if amount and typst_units[unit] then
    return '#v(' .. amount .. unit .. ')'
  end
  return nil
end

-- ── Page breaks ───────────────────────────────────────────────────────────
local function rawblock (el)
  if is_latex(el) and el.text:match('^\\%s*$') == nil then
    if el.text:match('^\\newpage') or el.text:match('^\\clearpage')
        or el.text:match('^\\pagebreak') then
      return pandoc.RawBlock('typst', '#pagebreak()')
    end

    local v = vspace(el.text)
    if v then
      return pandoc.RawBlock('typst', v)
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

  local v = vspace(el.text)
  if v then
    return pandoc.RawInline('typst', v)
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

-- ── Page break at the end of a paragraph ──────────────────────────────────
-- `\newpage` glued to the last word of a paragraph is representable: the
-- break just has to become a block of its own, after the paragraph. Only
-- the ones inside a list item are lost, Typst forbidding a page break
-- inside a container.
local function para (el)
  local inlines = el.content
  local last = inlines[#inlines]

  if last and last.t == 'RawInline' and is_latex(last)
      and (last.text:match('^\\newpage') or last.text:match('^\\clearpage')
           or last.text:match('^\\pagebreak')) then
    inlines:remove(#inlines)
    while #inlines > 0 and inlines[#inlines].t == 'Space' do
      inlines:remove(#inlines)
    end
    return { pandoc.Para(inlines), pandoc.RawBlock('typst', '#pagebreak()') }
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
  { Figure = figure, Para = para },
  { RawBlock = rawblock, RawInline = rawinline },
}
