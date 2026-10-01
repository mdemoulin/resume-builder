# resume-builder

Write your resume once, in XML, and build it in every format a job search
asks for: PDF for people, Word and OpenDocument for upload forms, HTML for a
web page, and plain text for the paste-it-in-a-box fields.

    make            # PDF, HTML, text, ODT, DOC and DOCX, all into out/
    make validate   # check src/xml/resume.xml against its DTD

One source means one place to fix a typo or update a job, and every copy
agrees with every other copy.

## How it works

`src/xml/resume.xml` is the resume, validated by `src/xml/resume.dtd`.
Three XSLT stylesheets in `lib/` turn it into everything else:

| Stylesheet | Produces | From there |
|---|---|---|
| `resume2latex.xsl` | LaTeX, styled by `src/tex/resume.sty` | `latex` → DVI, `dvipdfmx` → **PDF** |
| `resume2html.xsl` | **HTML** | `lynx --dump` → **text** |
| `resume2oo.xsl` | flat OpenDocument (`.fodt`) | LibreOffice → **ODT**, **DOC**, **DOCX** |

A `make` build ties it together, so only what changed is rebuilt.  Every
output is written twice, as `out/resume.*` and under a personal name,
`out/$USER-resume.*` by default; set your own with `make N=jdoe-resume`.

## Settings

The build has a handful of on/off settings, kept in `lib/params` (created
with the defaults on the first build).  Turn one on with `make <setting>`
and off with `make no<setting>`; `make settings` shows them all.

| Setting | Default | Effect |
|---|---|---|
| `extra` | off | include positions marked `extra="1"` and inline `<extra>` detail -- a long version from the same source |
| `federal` | off | include the details USAJOBS asks for: each job's address, hours, supervisor, reason for leaving and salary; drop sections marked `federal="0"`, add those marked `federal="1"` |
| `expandabbrevs` | off | follow each `<abbrev>` with its definition |
| `twophones` | off | list both phone numbers (the PDF labels the first Home and the second Cell) |
| `fancyheaders` | on | PDF running head with the name and page number |
| `fancyacronyms` | on | set acronyms a size smaller in the PDF |

`make federal-build` does a complete federal build into `federal/` and puts
the settings back afterward, so an ordinary build never comes out federal by
accident.

## Writing your resume

Start from the sample in `src/xml/resume.xml`.  It is a made-up person
whose resume uses every element and attribute the DTD defines, so each
setting above visibly changes the output.  Replace it with your own, run
`make validate`, then `make`.

Inline markup in descriptions:

- `<command>`, `<server>`: set in a typewriter face
- `<acronym>`: set a size smaller (with `fancyacronyms`)
- `<abbrev><word>REST</word><defn>Representational State Transfer</defn></abbrev>`
- `<emph>`: emphasis
- `<list><item>...</item></list>`: a compact bulleted list
- `<extra>...</extra>`: shown only with `extra`

`make spell` spell-checks the prose of the XML source itself (skipping the
markup), so a correction lands in the one file everything is built from.
Words you accept go in `lib/resume.dict`.

## Requirements

- GNU make
- `xsltproc` and `xmllint` (libxslt and libxml2)
- LaTeX with `latex` and `dvipdfmx`, and the `fancyhdr`, `xspace`, `calc`
  and `ifthen` packages (TeX Live has all of them)
- LibreOffice (`soffice`), for ODT, DOC and DOCX
- `lynx`, for the text version
- Perl 5.36 or later, for `lib/set-conf.pl`
- `aspell`, for `make spell`

## Other targets

`make help` lists everything.  The ones not covered above:

- `make pdf`, `make html`, `make txt`, `make docx`, ... -- just one format
- `make tex` -- the intermediate LaTeX, for debugging the PDF
- `make export` -- a tarball of the committed source, via `git archive`
- `make clean` -- empty `out/` and `tmp/`; `make mrclean` also removes
  `federal/` and `lib/params`

## License

Copyright (C) 2026 Michael A. Demoulin.  Licensed under the GNU General
Public License, version 3 or (at your option) any later version; see
[COPYING](COPYING).
