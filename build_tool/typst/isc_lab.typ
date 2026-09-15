$definitions.typst()$

// =========================================================================
//  ISC lab template -- Typst port of isc_lab.tex
//
//  The LaTeX template stays the reference: every value below is meant to
//  reproduce what pdflatex/xelatex produces, and the comments give the
//  LaTeX construct each block replaces. Use compareEngines.sh to check.
//
//  Pandoc template, so `$$` means a literal dollar and Typst math must be
//  avoided in this file (use sym.* instead).
// =========================================================================

// Same packages as ISC-HEI/isc-hei-typst-templates: gentle-clues for the
// callouts and codelst for the listings. codelst's negative numbers-width
// is what puts the line numbers outside the frame.
#import "@preview/gentle-clues:1.3.1": clue
#import "@preview/codelst:2.0.2": sourcecode

// --- ISC programme colours (used by the callout boxes) -------------------
#let isc-embedded = rgb(152, 199, 191) // Systemes informatiques embarques
#let isc-security = rgb(226, 171, 186) // Securite informatique
#let isc-networks = rgb(168, 144, 192) // Reseaux et systemes
#let isc-software = rgb(140, 198, 230) // Informatique logicielle
#let isc-data     = rgb(247, 241, 159) // Ingenierie des donnees

// --- Colours taken from isc_lab.tex --------------------------------------
#let heading-color    = rgb("#404040") // \color{darkgray} in \titleformat
#let rule-color       = rgb("#404040") // \titlerule inherits the heading colour
#let url-color        = rgb("#4077C0") // default-urlcolor
#let link-color       = rgb("#A50000") // default-linkcolor
#let listing-back     = rgb("#F2F2F2") // mdframed backgroundcolor=black!5
#let listing-numbers  = rgb("#B3B2B3") // listing-numbers
#let listing-frame    = rgb("#404040") // mdframed middlelinecolor=black!75
#let caption-color    = rgb("#777777") // caption textfont colour
#let table-rule       = rgb("#999999") // table-rule-color, \arrayrulecolor
#let table-row        = rgb("#F5F5F5") // table-row-color
// Title block offsets. LaTeX places the first baseline with \topskip and
// geometry's vcentering, neither of which Typst has, so the title block
// lands too high. Both values were measured on the reference PDF with
// `pdftotext -bbox` (title 13.8pt too high, first heading 20.5pt too high);
// they are tuning knobs, not derived quantities. Re-measure after changing
// the margins or the title font size.
#let title-top-offset    = 13.8pt
#let title-bottom-offset = 20.5pt

#let blockquote-bar   = rgb(221, 221, 221)
#let blockquote-text  = rgb(119, 119, 119)

// --- Callout boxes -------------------------------------------------------
// Counterpart of the tcolorbox environments in isc_lab.tex. Emitted by
// lua_filters/callouts.lua from `::: checkout` / `::: warning` / `::: info`.
//
// Built on gentle-clues rather than by hand: a hand-rolled block of two
// nested blocks leaves a blank line at the top of the body, because the
// inner block starts a new paragraph.
#let isccallout(accent, default-title, title: none, body) = clue(
  title: if title == none { default-title } else { title },
  accent-color: accent,
  icon: none,
  // par.spacing applies inside the clue too, and gentle-clues does not
  // collapse it, so the first paragraph of the body gets pushed down. This
  // block absorbs the leading and trailing space while paragraphs *inside*
  // the box keep their normal gap.
)[#block(above: 0pt, below: 0pt, body)]

#let isccheckout(title: none, body) = isccallout(isc-embedded, "Checkout", title: title, body)
#let iscwarning(title: none, body) = isccallout(isc-security, "Attention", title: title, body)
#let iscinfo(title: none, body) = isccallout(isc-software, "Info", title: title, body)

// =========================================================================
//  Document configuration
// =========================================================================
#let conf(
  title: none,
  authors: (),
  date: none,
  version: none,
  course: none,
  ue: none,
  logo: none,
  keywords: (),
  abstract: none,
  cols: 1,
  // geometry: a4paper, inner=2cm, outer=1.6cm, top=2.3cm, bottom=1cm,
  // includefoot=true. Typst puts the footer *outside* the body, so the
  // bottom margin absorbs LaTeX's \footskip (0.9cm) on top of bottom=1cm.
  margin: (top: 2.3cm, bottom: 1.9cm, left: 2cm, right: 1.6cm),
  paper: "a4",
  lang: "fr",
  region: "ch",
  font: ("Source Sans 3",),
  fontsize: 10pt,
  sectionnumbering: none,
  doc,
) = {
  let authorline = authors.map(a => a.name).join(", ")

  set document(title: title, author: authors.map(a => a.name), keywords: keywords)

  set page(
    paper: paper,
    margin: margin,

    // \fancypagestyle{eisvogel-header-footer}: title left, date + version
    // right, 0.4pt rule. \thispagestyle{firstpage} kills it on page 1.
    header: context {
      if counter(page).get().first() > 1 {
        set text(size: 8pt) // \footnotesize at 10pt
        grid(
          columns: (1fr, 1fr),
          align(left)[#title],
          align(right)[#date, v#version],
        )
        v(-4pt)
        line(length: 100%, stroke: 0.4pt + black)
      }
    },
    header-ascent: 40%,

    // Footer is identical on every page, including the first one.
    footer: context {
      line(length: 100%, stroke: 0.4pt + black)
      v(-4pt)
      set text(size: 8pt)
      grid(
        columns: (1fr, auto, 1fr),
        align(left)[#authorline #sym.bar.v #emph[#ue #course]],
        [],
        align(right)[
          #counter(page).display("1") #sym.bar.v #counter(page).final().first()
        ],
      )
    },
    footer-descent: 25%,
  )

  set text(lang: lang, region: region, font: font, size: fontsize)

  // \setlength{\parindent}{0pt} + \setlength{\parskip}{6pt plus 2pt minus 1pt}
  //
  // Careful: Typst's par.spacing *replaces* the inter-block gap, while
  // LaTeX's \parskip is *added* to \baselineskip. The equivalent of a 6pt
  // \parskip is therefore leading + 6pt, not 6pt. Setting 6pt here comes
  // out tighter than Typst's own default, let alone than LaTeX.
  set par(justify: true, leading: 0.65em, spacing: 12pt, first-line-indent: 0pt)

  // \setcounter{secnumdepth}{-\maxdimen}: no section numbering at all.
  set heading(numbering: sectionnumbering)

  // Pandoc emits tight lists, which Typst spaces with par.leading -- the
  // same thing pandoc's \tightlist does on the LaTeX side. Only the indent
  // needs setting.
  set list(indent: 0.6em)
  set enum(indent: 0.6em)

  show link: set text(fill: url-color)
  show ref: set text(fill: link-color)

  // \usepackage[nomap, lining, medium, scaled=1.1]{FiraMono}
  //
  // The size is absolute on purpose. codelst re-emits the listing as nested
  // raw elements, so a relative size like 0.92em would be applied twice and
  // the code would come out noticeably smaller than in the LaTeX output.
  show raw: set text(font: "Fira Mono", size: 9.5pt)

  // lstlisting wrapped in mdframed (black!5 background, black!75 frame,
  // roundcorner=4) with the line numbers in the margin.
  //
  // codelst does the numbering; numbers-width: -1em pulls the column out of
  // the frame instead of eating into the code, which is the arrangement of
  // ISC-HEI/isc-hei-typst-templates. lstlisting only numbers the listings
  // that declare a language, so plain blocks keep `numbering: none`.
  // No width on the frame: codelst sizes it, and forcing 100% pushes the
  // negative-offset number column back under the left border.
  let listing-frame-block = block.with(
    fill: listing-back,
    stroke: 0.5pt + listing-frame,
    radius: 4pt,
    inset: (x: 6pt, y: 5pt),
  )

  show raw.where(block: true): it => block(
    above: 9pt, // mdfsetup skipabove=9pt
    below: 6pt,
    sourcecode(
      frame: listing-frame-block,
      numbering: if it.lang == none { none } else { "1" },
      numbers-style: (lno) => text(fill: listing-numbers, size: 7pt, lno),
      numbers-width: -1em,
      gutter: 1.2em,
      it,
    ),
  )

  // \usepackage[textfont={color=caption-color}, skip=4mm, labelfont=bf,
  //   justification=centering]{caption}
  // Typst's French locale abbreviates the supplement to "Fig." and uses a
  // dash as separator, where babel-french spells out "Figure" and uses a
  // colon, so both have to be set explicitly.
  set figure(supplement: [Figure], gap: 4mm)
  set figure.caption(separator: [: ])
  show figure.caption: it => align(center)[
    #strong[#it.supplement~#context it.counter.display(it.numbering)#it.separator]#text(fill: caption-color, it.body)
  ]

  // Tables are booktabs in LaTeX: \toprule and \bottomrule at
  // \heavyrulewidth=0.3ex, a \midrule between header and body, no vertical
  // rules at all, \arraystretch=1.3 for the padding, all of it in
  // \arrayrulecolor{table-rule-color}.
  //
  // Pandoc already emits the \midrule as `table.hline()`, so only the two
  // heavy rules have to be added around the table. A show rule is not
  // re-entered for the same element, so referring to `it` here is safe.
  set table(inset: (x: 4pt, y: 4pt), stroke: none)
  set table.hline(stroke: 0.5pt + table-rule)
  show table: it => block(above: 12pt, below: 12pt, {
    set block(spacing: 0pt)
    // Pandoc centres the figure that wraps the table and passes
    // `align: (auto, auto)`, so without this the cells inherit the
    // centring instead of staying left-aligned like the LaTeX original.
    set align(left)
    line(length: 100%, stroke: 1.2pt + table-rule)
    it
    line(length: 100%, stroke: 1.2pt + table-rule)
  })

  // \renewenvironment{quote}: 3pt grey bar on the left, grey text.
  show quote.where(block: true): it => block(
    width: 100%,
    inset: (left: 10pt),
    above: 6pt,
    below: 6pt,
    stroke: (left: 3pt + blockquote-bar),
    text(fill: blockquote-text, it.body),
  )

  // \titleformat{\section}: \Large\bfseries\color{darkgray} with a
  // \titlerule above and one below. Drawing them as the block's own top and
  // bottom strokes keeps the gaps symmetric -- separate line() + v() calls
  // need a negative v() to look right, and that one overlaps the text.
  show heading.where(level: 1): it => block(
    width: 100%,
    above: 18pt,
    below: 12pt,
    inset: (y: 5pt),
    stroke: (top: 0.4pt + rule-color, bottom: 0.4pt + rule-color),
    text(size: 14.4pt, weight: "bold", fill: heading-color, it.body),
  )

  // \titleformat{\subsection}: \large\bfseries
  // \titlespacing* {0pt}{0.6\baselineskip}{0pt}
  show heading.where(level: 2): it => block(
    above: 14pt,
    below: 9pt,
    text(size: 12pt, weight: "bold", fill: heading-color, it.body),
  )

  // \titleformat{\subsubsection}: \normalsize\bfseries, {0pt}{0.4\baselineskip}{0pt}
  show heading.where(level: 3): it => block(
    above: 12pt,
    below: 8pt,
    text(size: fontsize, weight: "bold", fill: heading-color, it.body),
  )

  show heading.where(level: 4): it => block(
    above: 10pt,
    below: 6pt,
    text(size: fontsize, weight: "bold", style: "italic", it.body),
  )

  // --- Title block (tikz overlay logo + \Huge title + \large subtitle) ---
  // The logo hangs at 1.3cm from the right page edge and 0.8cm from the
  // top one, so it is offset from the body's top-right corner.
  if logo != none and logo != "" {
    place(
      top + right,
      dx: margin.right - 1.3cm,
      dy: 0.8cm - margin.top,
      image(logo, height: 1.5cm),
    )
  }

  v(4mm + title-top-offset)
  text(size: 24.88pt, weight: "bold")[#title] // \Huge\bfseries
  linebreak()
  text(size: 12pt)[#ue #course] // \large
  v(1mm + title-bottom-offset)

  doc
}

#show: doc => conf(
$if(title)$
  title: [$title$],
$endif$
$if(author)$
  authors: (
$for(author)$
$if(author.name)$
    ( name: "$author.name$" ),
$else$
    ( name: "$author$" ),
$endif$
$endfor$
  ),
$endif$
$if(date)$
  date: [$date$],
$endif$
$if(version)$
  version: [$version$],
$endif$
$if(course)$
  course: [$course$],
$endif$
$if(ue)$
  ue: [$ue$],
$endif$
$if(logo)$
  logo: "$logo$",
$endif$
$if(keywords)$
  keywords: ($for(keywords)$"$keyword$"$sep$,$endfor$),
$endif$
$if(margin)$
  margin: ($for(margin/pairs)$$margin.key$: $margin.value$,$endfor$),
$endif$
$if(papersize)$
  paper: "$papersize$",
$endif$
$if(mainfont)$
  font: ("$mainfont$",),
$endif$
$if(fontsize)$
  fontsize: $fontsize$,
$endif$
$if(section-numbering)$
  sectionnumbering: "$section-numbering$",
$endif$
  cols: $if(columns)$$columns$$else$1$endif$,
  doc,
)

$for(header-includes)$
$header-includes$

$endfor$
$for(include-before)$
$include-before$

$endfor$
$if(toc)$
#outline(title: auto, depth: $toc-depth$);
$endif$

$body$

$for(include-after)$
$include-after$
$endfor$
