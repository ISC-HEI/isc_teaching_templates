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

Only LaTeX output is rewritten. For every other output format the div is
left untouched, so the HTML writer keeps `<div class="checkout">` and the
box can be styled in CSS instead.

## Author

Pierre-André Mudry, ISC documents toolchain.
--]==============================]

-- Div class -> LaTeX environment defined in isc_lab.tex
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

function Div (el)
  if not FORMAT:match 'latex' then return nil end

  for _, class in ipairs(el.classes) do
    local environment = environments[class]

    if environment then
      local options = ''
      local title = el.attributes['title']

      if title then
        options = '[title={' .. escape_latex(title) .. '}]'
      end

      local blocks = { pandoc.RawBlock('latex', '\\begin{' .. environment .. '}' .. options) }
      for _, block in ipairs(el.content) do
        blocks[#blocks + 1] = block
      end
      blocks[#blocks + 1] = pandoc.RawBlock('latex', '\\end{' .. environment .. '}')

      return blocks
    end
  end

  return nil
end
