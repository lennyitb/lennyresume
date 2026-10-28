% mosaicresume.cls -- a one-page resume with a degree credit mosaic
% Build with LuaLaTeX: latexmk resume.tex  (the .latexmkrc picks LuaLaTeX)
%
% Options:
%   palette=<name>  colors; walnut (default), harbor, forest, plum, graphite.
%                   See mosaicresume-palettes.tex, or \usepalette below.
%   a4              A4 paper instead of US letter
\NeedsTeXFormat{LaTeX2e}[2022-11-01]
\ProvidesClass{mosaicresume}[2026/10/28 v1.0 One-page resume with a degree credit mosaic]

\newcommand\mr@palette{walnut}
\newif\ifmr@afour
\DeclareKeys{
  palette.store = \mr@palette,
  a4.if = mr@afour,
}
\ProcessKeyOptions
\LoadClass[10pt]{article}

\RequirePackage{iftex}
\RequireLuaTeX

% ---------- Page ----------
% A 3/8 in bar down the left edge with a 7/16 in gutter. On letter paper the
% text is 7 1/16 in wide; the mosaic sizes itself to whatever width it gets.
\newlength{\coverbar}\setlength{\coverbar}{0.375in}
\RequirePackage[left=0.8125in, right=0.625in, top=0.65in, bottom=0.5in,
  marginparwidth=0pt, marginparsep=0pt, footskip=0pt, headheight=0pt,
  headsep=0pt]{geometry}
\ifmr@afour\geometry{a4paper}\else\geometry{letterpaper}\fi
\pagestyle{empty}
\AddToHook{shipout/background}{%
  \put(0,-\paperheight){\color{bar}\rule{\coverbar}{\paperheight}}}
\setlength{\parskip}{0pt}
\setlength{\parindent}{0pt}
\setlength{\columnsep}{0.2in}

% ---------- Fonts ----------
% Crimson Pro for text, Source Sans 3 for headings; both come with TeX Live
% and Overleaf. To use others, \setmainfont / \setsansfont in the preamble
% after \documentclass.
\RequirePackage{fontspec}
\setmainfont{CrimsonPro}[Extension=.ttf, UprightFont=*-Regular,
  ItalicFont=*-Italic, BoldFont=*-SemiBold, BoldItalicFont=*-SemiBoldItalic]
\setsansfont{SourceSans3}[Extension=.otf, UprightFont=*-Regular,
  ItalicFont=*-RegularIt, BoldFont=*-Bold, BoldItalicFont=*-BoldIt]
\RequirePackage{microtype}
% The \LaTeX logo, kerned for Crimson Pro (the default packs the A into the L)
\DeclareRobustCommand{\LaTeX}{L\kern-.2em{\sbox\z@ T\vbox to\ht\z@{\hbox{%
  \check@mathfonts\fontsize\sf@size\z@\math@fontsfalse\selectfont A}\vss}}%
  \kern-.08em\TeX}
% Ragged right, no hyphenation
\RequirePackage[document]{ragged2e}
\hyphenpenalty=10000
\exhyphenpenalty=10000
% \qty{-20}{\degree} and friends, set in the text font
\RequirePackage{siunitx}
\sisetup{mode=text, number-unit-product=\nobreakspace}

% ---------- Colors ----------
\RequirePackage{xcolor}
\RequirePackage{tikz}
% \usepalette{forest} or \usepalette{forest, highlight=1C5CAB}: each item is
% a palette name or a color=hex pair. \definepalette{name}{items} stores a
% list under a name.
\pgfkeys{/mosaicresume/color/.unknown/.code={%
  \ifx\pgfkeyscurrentvalue\pgfkeysnovalue@text
    \pgfkeysifdefined{/mosaicresume/palette/\pgfkeyscurrentname/.@cmd}
      {\pgfkeysalso{/mosaicresume/palette/\pgfkeyscurrentname}}
      {\ClassError{mosaicresume}{Unknown palette `\pgfkeyscurrentname'}
        {The palettes are defined in mosaicresume-palettes.tex.}}%
  \else
    \definecolor{\pgfkeyscurrentname}{HTML}{#1}%
  \fi}}
\newcommand\definepalette[2]{%
  \pgfkeys{/mosaicresume/palette/#1/.style={/mosaicresume/color/.cd,#2}}}
\newcommand\usepalette[1]{\pgfkeys{/mosaicresume/color/.cd,#1}}
\input{mosaicresume-palettes.tex}
\expandafter\usepalette\expandafter{\mr@palette}

% ---------- Type sizes ----------
\newcommand\bodysize{\fontsize{9}{10.8}\selectfont}
\newcommand\sectionsize{\sffamily\bfseries\fontsize{11}{13}\selectfont\color{bar}}
\newcommand\entrysize{\sffamily\bfseries\fontsize{9}{10.8}\selectfont}

% ---------- Header and footer ----------
% \nameblock{kicker}{Your Name}{one-line objective}
\newcommand{\nameblock}[3]{%
  {\itshape\color{muted}\fontsize{14}{17}\selectfont #1\par}
  \vspace{3pt}
  {\sffamily\bfseries\fontsize{38}{40}\selectfont #2\par}
  \vspace{5pt}
  {\itshape\color{muted}\fontsize{13}{16}\selectfont #3\par}
  \vspace{14pt}}
% \contactfooter{left lines}{right lines}, pushed to the bottom of the page.
% Separate lines with \par; \muted{...} grays a line out.
\newcommand{\contactfooter}[2]{%
  \par\vfill
  {\color{rule}\rule{\textwidth}{0.6pt}\par}
  \vspace{7pt}
  {\fontsize{10}{12}\selectfont
  \noindent\begin{minipage}[t]{0.62\textwidth}#1\par\end{minipage}\hfill
  \begin{minipage}[t]{0.3\textwidth}\raggedleft #2\par\end{minipage}\par}}
\newcommand{\muted}[1]{{\color{muted}#1}}

% ---------- Columns ----------
% \begin{threecolumns} first \nextcolumn second \nextcolumn third \end{threecolumns}
% The middle column is \middlecolumn wide; the outer two share the rest.
\newlength{\middlecolumn}\setlength{\middlecolumn}{2.3in}
\newcounter{mr@column}
\newlength{\mr@colwidth}
\newcommand{\mr@column}{%
  \ifnum\value{mr@column}=2 \setlength{\mr@colwidth}{\middlecolumn}%
  \else\setlength{\mr@colwidth}{\dimexpr(\textwidth - 2\columnsep - \middlecolumn)/2\relax}\fi
  \begin{minipage}[t]{\mr@colwidth}}
\newenvironment{threecolumns}{%
  \par\vspace{10pt}\bodysize\setcounter{mr@column}{1}%
  \noindent\mr@column}{%
  \end{minipage}\par}
\newcommand{\nextcolumn}{%
  \end{minipage}\hspace{\columnsep}\stepcounter{mr@column}\mr@column}

% ---------- Resume blocks ----------
% Section heading on the band; the band hangs \bandhang into the gutter so
% the heading text lines up with the column below.
\RequirePackage{enumitem}
\newlength{\bandhang}\setlength{\bandhang}{4pt}
\newcommand{\rsection}[1]{{\setlength{\fboxsep}{0pt}\leavevmode\hspace*{-\bandhang}%
  \colorbox{band}{\parbox[c][16pt][c]{\dimexpr\linewidth+\bandhang}{\hspace*{\bandhang}%
  \sectionsize\strut#1}}\par}\vspace{4pt}}
% \entry{Title}[subtitle, after a dot, in the muted text face]
\NewDocumentCommand{\entry}{m o}{%
  {\entrysize #1}\IfValueT{#2}{ {\normalfont\color{muted}·\,#2}}\par}
\newcommand{\meta}[1]{{\color{muted}#1\par}}
\newcommand{\skill}[2]{{\sffamily\bfseries #1}\enspace#2\par\vspace{2.5pt}}
\newlist{rbullets}{itemize}{1}
\setlist[rbullets]{label=\textcolor{accent}{--}, leftmargin=7pt, labelsep=3pt,
  topsep=1pt, itemsep=0.5pt, parsep=0pt, partopsep=0pt}
\newcommand{\gapafter}{\vspace{5.5pt}}
\newcommand{\sectiongap}{\vspace{9pt}}
% A detail still to fill in
\newcommand{\fillin}[1]{\textcolor{pending}{[#1]}}

% ---------- Credit mosaic ----------
% \creditmosaic[data file] draws the mosaic from courses.lua (or the file
% given) across the full line width; creditmosaic.lua does the drawing.
\newcommand\gpafont{\sffamily\bfseries\fontsize{7.5}{8}\selectfont}
\tikzset{
  plate/.style={fill=white, fill opacity=0.70, text opacity=1,
    rounded corners=1pt, inner xsep=1.2pt, inner ysep=1pt, align=center,
    font=\sffamily\bfseries\fontsize{5.3}{4.8}\selectfont},
  gpa/.style={inner sep=0pt, font=\gpafont},
  eralabel/.style={inner sep=0pt, font=\sffamily\bfseries\fontsize{6.2}{7}\selectfont},
  eranote/.style={inner sep=0pt, text=chartText,
    font=\sffamily\fontsize{6}{7}\selectfont},
  summary/.style={inner sep=0pt, text=chartText,
    font=\sffamily\fontsize{6}{7}\selectfont},
}
\newcommand\creditmosaic[1][courses.lua]{%
  \par\noindent
  \directlua{require("creditmosaic").draw("\luaescapestring{#1}", \number\linewidth)}%
  \par}
% Legend swatches: a small rounded square of a color, centered on the cap
% height; \swdot adds the dotted ring of a course in progress.
\newcommand{\sw}[1]{\tikz[baseline=-0.33em]\fill[fill=#1, rounded corners=0.9pt] (0,-0.28em) rectangle (0.56em,0.28em);}
\newcommand{\swdot}[1]{\tikz[baseline=-0.33em]{\fill[fill=#1, rounded corners=0.9pt] (0.08em,-0.2em) rectangle (0.48em,0.2em);
  \draw[draw=#1, line width=0.7pt, dash pattern=on 0.1pt off 1.1pt, line cap=round, rounded corners=1pt] (-0.06em,-0.34em) rectangle (0.62em,0.34em);}}
% \mosaiclegend{title}: the title, then a swatch for each grade band.
\newcommand{\mosaiclegend}[1]{%
  {\sffamily\fontsize{7}{9}\selectfont\color{chartText}%
   {\bfseries\color{black}#1}\quad
   \sw{gradeAp}\,A+\quad \sw{gradeA}\,A\,/\,A\textminus\quad \sw{gradeB}\,B\,/\,B\textminus\quad
   \sw{gradeC}\,C\,/\,C\textminus\quad \swdot{gradeA}\,in progress, expected grade\quad
   \sw{gradeRem}\,remaining\par}
  \vspace{6pt}}

\RequirePackage[hidelinks]{hyperref}
