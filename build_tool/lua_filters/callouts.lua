--[==============================[
# callouts.lua

A Pandoc filter turning fenced divs into the coloured ISC callout boxes
defined in `isc_lab.tex`.

## Usage

    ::: checkout
    Une fois que vous avez terminé, appelez l'enseignant·e.
    :::

    ::: warning
    Ne téléchargez pas IntelliJ depuis le site de JetBrains.
    :::

    ::: info
    Le dossier `src` contient en général beaucoup de fichiers.
    :::

The default title of a box can be replaced with a `title` attribute:

    ::: {.warning title="Uniquement sur macOS"}
    ...
    :::

LaTeX and Typst output are rewritten; the Typst side calls the functions
of the same name declared in `typst/isc_lab.typ`. For every other output
format the div is left untouched, so the HTML writer keeps
`<div class="checkout">` and the box can be styled in CSS instead.

## Author

Pierre-André Mudry, ISC documents toolchain.
--]==============================]

-- Div class -> the LaTeX environment of isc_lab.tex, which is also the
-- name of the Typst function of typst/isc_lab.typ.
local environments = {
  checkout = 'isccheckout',
  warning  = 'iscwarning',
  info     = 'iscinfo',
}

-- The title attribute ends up verbatim in the LaTeX source, so the
-- characters that would otherwise be swallowed by TeX are escaped.
local specials = {
  ['\\'] = '\\textbackslash{}',
  ['{']  = '\\{',
  ['}']  = '\\}',
  ['$']  = '\\$',
  ['&']  = '\\&',
  ['#']  = '\\#',
  ['%']  = '\\%',
  ['_']  = '\\_',
  ['~']  = '\\textasciitilde{}',
  ['^']  = '\\textasciicircum{}',
}

local function escape_latex (str)
  return (str:gsub('[\\{}$&#%%_~^]', specials))
end

-- Typst content is delimited by square brackets, and `#` and `@` start a
-- code expression and a reference respectively.
local function escape_typst (str)
  return (str:gsub('[\\#%[%]@%$]', '\\%0'))
end

-- Returns the raw opening and closing markers for the requested format.
local function markers (format, environment, title)
  if format == 'latex' then
    local options = ''
    if title then
      options = '[title={' .. escape_latex(title) .. '}]'
    end
    return '\\begin{' .. environment .. '}' .. options,
           '\\end{' .. environment .. '}'
  end

  local options = ''
  if title then
    options = '(title: [' .. escape_typst(title) .. '])'
  end
  return '#' .. environment .. options .. '[', ']'
end

function Div (el)
  local format
  if FORMAT:match 'latex' then
    format = 'latex'
  elseif FORMAT:match 'typst' then
    format = 'typst'
  else
    return nil
  end

  for _, class in ipairs(el.classes) do
    local environment = environments[class]

    if environment then
      local opening, closing = markers(format, environment, el.attributes['title'])

      local blocks = { pandoc.RawBlock(format, opening) }
      for _, block in ipairs(el.content) do
        blocks[#blocks + 1] = block
      end
      blocks[#blocks + 1] = pandoc.RawBlock(format, closing)

      return blocks
    end
  end

  return nil
end
