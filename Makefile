# resume-builder: one XML resume, every format
# Copyright (C) 2026 Michael A. Demoulin
# SPDX-License-Identifier: GPL-3.0-or-later

# never leave a half-written target behind for the next rule to consume.
.DELETE_ON_ERROR:
# "make" on its own builds everything, however the rules below are ordered
.DEFAULT_GOAL := all

R		       := resume
# the second, personal name every output is also copied to; make N=jdoe-resume
N		       ?= ${USER}-$R
TEXDIR		   := ${CURDIR}/src/tex
XMLDIR		   := ${CURDIR}/src/xml
TMPDIR		   := ${CURDIR}/tmp
OUTDIR		   := ${CURDIR}/out
LIBDIR		   := ${CURDIR}/lib
RESUME2OO	   := ${LIBDIR}/resume2oo.xsl
RESUME2LATEX   := ${LIBDIR}/resume2latex.xsl
RESUME2HTML	   := ${LIBDIR}/resume2html.xsl
GETCONFIG	   := ${LIBDIR}/set-conf.pl
PARAMS		   := ${LIBDIR}/params
DICT		   := ${LIBDIR}/$R.dict
REPL		   := ${LIBDIR}/$R.repl
# settings handed to the stylesheets; recursive (=) so $$ survives to the shell
XSLPARAMS	    = --stringparam twophones "$$(${GETCONFIG} -v twophones)" \
		          --stringparam extra "$$(${GETCONFIG} -v extra)" \
		          --stringparam federal "$$(${GETCONFIG} -v federal)" \
		          --stringparam expandabbrevs "$$(${GETCONFIG} -v expandabbrevs)"
OOPARAMS	    = ${XSLPARAMS}
# spell check reads the XML source, not an output: aspell's sgml mode skips
# markup so only prose is checked, and a correction lands in the one file every
# format is built from.  --home-dir keeps aspell out of $HOME, and naming
# both of its state files -- the word list and the replacement pairs -- keeps
# them beside the stylesheets instead of as dotfiles under it.
ASPELLOPTS	   := --lang=en_US --mode=sgml --home-dir=${LIBDIR} --personal=${DICT} --repl=${REPL}
# LibreOffice will not run headless against a profile another instance holds,
# so give the conversion one of its own rather than the user's.
SOFFICE		    = soffice --headless -env:UserInstallation=file://${TMPDIR}/lo
# output files
TMPHTMLFILE	   := ${TMPDIR}/$R.html
FODTFILE	   := ${OUTDIR}/$R.fodt
FODTFILE2	   := ${OUTDIR}/$N.fodt
ODTFILE		   := ${OUTDIR}/$R.odt
ODTFILE2	   := ${OUTDIR}/$N.odt
HTMLFILE	   := ${OUTDIR}/$R.html
HTMLFILE2	   := ${OUTDIR}/$N.html
PDFFILE		   := ${OUTDIR}/$R.pdf
PDFFILE2	   := ${OUTDIR}/$N.pdf
TXTFILE		   := ${OUTDIR}/$R.txt
TXTFILE2	   := ${OUTDIR}/$N.txt
DOCFILE		   := ${OUTDIR}/$R.doc
DOCFILE2	   := ${OUTDIR}/$N.doc
DOCXFILE	   := ${OUTDIR}/$R.docx
DOCXFILE2	   := ${OUTDIR}/$N.docx
DVIFILE		   := ${OUTDIR}/$R.dvi
DVIFILE2	   := ${OUTDIR}/$N.dvi
FEDERALDIR	   := ${CURDIR}/federal
FEDERALNAME	   := $N-long
SRCTAR		   := ${OUTDIR}/$R-src.tar
# input files
XMLFILE		   := ${XMLDIR}/$R.xml

# out/ and tmp/ hold nothing but build products, so they are not in version
# control; make them exist before any rule writes into them.
$(shell mkdir -p ${OUTDIR} ${TMPDIR})

# lib/params is per-checkout state, not source: the first build writes the
# defaults (the ordinary two-page industry resume), and the settings
# targets below change it from there.
${PARAMS}:
	${GETCONFIG} -s >/dev/null

##@ build
all:  dvi pdf html txt oo doc docx  ## every format below (the default goal)
over: clean all                    ## clean first, then build everything
dvi:  ${DVIFILE} ${DVIFILE2}       ## LaTeX -> dvi
pdf:  ${PDFFILE} ${PDFFILE2}       ## dvi -> pdf; what a human should be sent
html: ${HTMLFILE} ${HTMLFILE2}     ## xsltproc -> html
txt:  ${TXTFILE} ${TXTFILE2}       ## html -> lynx dump; for paste-in-a-box forms
tex:  ${TMPDIR}/$R.tex             ## the intermediate .tex, for debugging
doc:  ${DOCFILE} ${DOCFILE2}       ## Word 97 binary
docx: ${DOCXFILE} ${DOCXFILE2}     ## OOXML; what most ATS uploads want
fodt: ${FODTFILE} ${FODTFILE2}     ## flat ODF, the source of doc/docx/odt
odt:  ${ODTFILE} ${ODTFILE2}       ## zipped ODF
oo:   fodt odt                     ## both OpenDocument shapes
printout: ${DVIFILE}               ## dvips the dvi to the printer
	dvips ${DVIFILE}
# Help is generated from the "## text" trailing each documented target and the
# "##@ name" section headers, so a target that grows a comment shows up here
# with no second place to update.  Deliberately not the default goal: "make"
# on its own has always meant "all" here.
.PHONY: help
help:  ## this list
	@awk 'BEGIN {FS = ":.*##"} \
	     /^##@/                    { printf "\n%s:\n", substr($$0, 5); next } \
	     /^[a-zA-Z0-9_.%-]+:.*##/  { printf "  %-18s %s\n", $$1, $$2 }' \
	    ${MAKEFILE_LIST}
	@echo
	@echo 'turn a setting off with the no<setting> form, e.g. make noextra'
	@echo

# USAJOBS wants the opposite of a two-page industry resume: every position,
# abbreviations spelled out, and the supervisor/hours facts federal HR rates
# against.  Those settings live in lib/params and are global, so a forgotten
# one silently makes the next ordinary build a federal one -- hence the trap,
# which puts them back however this exits.  The copies go outside OUTDIR
# because clean empties that.
federal-build:  ## the long federal build, into federal/
	@set -e; \
	trap '${GETCONFIG} -s federal=f extra=f expandabbrevs=f >/dev/null' EXIT; \
	${GETCONFIG} -s federal=t extra=t expandabbrevs=f; \
	${MAKE} all; \
	mkdir -p ${FEDERALDIR}; \
	for e in pdf docx doc txt html odt; do \
	    cp -f ${OUTDIR}/$N.$$e ${FEDERALDIR}/${FEDERALNAME}.$$e; \
	    done
	@${MAKE} all
	@echo 'federal build in ${FEDERALDIR}; settings restored:'
	@${GETCONFIG} -p

##@ check
validate: ${XMLFILE} ${XMLDIR}/$R.dtd  ## check the XML against the DTD
	xmllint --noout --valid $<

spell: ${XMLFILE} ${DICT}  ## interactive spell check of the prose
	aspell ${ASPELLOPTS} check $<
spell-list: ${XMLFILE} ${DICT}  ## just list the unrecognised words
	@aspell ${ASPELLOPTS} list < $< | sort -u

##@ source
# git archive gives a tree with nothing unversioned in it -- no build output,
# no lib/params, no editor droppings -- straight from the committed HEAD, so
# what is in the tarball is exactly what anyone cloning would get.  It does
# not include uncommitted edits; commit first.
.PHONY: export
export: ${SRCTAR}  ## tarball of the committed source
${SRCTAR}: .git/HEAD .git/index
	@mkdir -p ${OUTDIR}
	git archive --format=tar --prefix=$R/ -o $@ HEAD

##@ housekeeping
clean:  ## empty out/ and tmp/, and delete *.bak
	rm -rf ${OUTDIR}/* ${TMPDIR}/*
	find ${CURDIR} -name \*.bak -delete
# the federal copies live outside OUTDIR precisely so that clean spares them;
# this is the one rule that does not.
mrclean: clean  ## clean, and also remove federal/ and lib/params
	rm -rf ${FEDERALDIR} ${PARAMS}
$N.%: $R.%
	cp -f $< $@

##@ settings (all boolean, stored in lib/params)
settings:  ## show what they are now
	${GETCONFIG} -p
expandabbrevs:  ## follow each abbreviation with its definition
	${GETCONFIG} -s $@=t
extra:  ## include the extra="1" jobs and inline <extra> detail
	${GETCONFIG} -s $@=t
federal:  ## include the supervisor and hours USAJOBS rates against
	${GETCONFIG} -s $@=t
fancyacronyms:  ## set acronyms a size smaller
	${GETCONFIG} -s $@=t
fancyheaders:  ## running head with name and page number
	${GETCONFIG} -s $@=t
fancyheadings:  ## disabled -- ugly
	@echo 'not doing... produces ugly output'
#	${GETCONFIG} -s $@=t
twophones:  ## list both phone numbers, labelled
	${GETCONFIG} -s $@=t
no%:
	${GETCONFIG} -s $(subst no, , $@)=f

# open document format.  The .fodt is flat ODF -- one XML file, so it is made
# the same way as the html and the .tex.  The .odt is derived from it, since
# repackaging a flat ODF as a zip is exactly what soffice is for.
${FODTFILE}: ${XMLFILE} ${XMLDIR}/$R.dtd ${RESUME2OO} ${PARAMS}
	xsltproc ${OOPARAMS} -o $@ ${RESUME2OO} $<
${ODTFILE}: ${FODTFILE}
	${SOFFICE} --convert-to odt --outdir ${OUTDIR} $<

# Word formats, off the same flat ODF.  "doc" is the Word 97 binary filter,
# "docx" the OOXML one -- .docx is what job sites and their applicant tracking
# systems expect, and some reject .doc outright, so both are built.
${DOCFILE}: ${FODTFILE}
	${SOFFICE} --convert-to doc --outdir ${OUTDIR} $<
${DOCXFILE}: ${FODTFILE}
	${SOFFICE} --convert-to docx --outdir ${OUTDIR} $<

# html format
${HTMLFILE}: ${XMLFILE} ${XMLDIR}/$R.dtd ${RESUME2HTML} ${PARAMS}
	xsltproc ${XSLPARAMS} -o $@ ${RESUME2HTML} $<

# text format
${TMPHTMLFILE}: ${XMLFILE} ${XMLDIR}/$R.dtd ${RESUME2HTML} ${PARAMS}
	xsltproc ${XSLPARAMS} --stringparam totxt 1 -o $@ ${RESUME2HTML} $<
${TXTFILE}: ${TMPHTMLFILE}
	lynx --dump $< >| $@

# LaTeX, dvi, pdf format
${TMPDIR}/$R.tex: ${XMLFILE} ${XMLDIR}/$R.dtd ${RESUME2LATEX} ${PARAMS}
	xsltproc ${XSLPARAMS} -o $@ ${RESUME2LATEX} $<
${TMPDIR}/$R.sty: ${TEXDIR}/$R.sty
	cp $< $@
${TMPDIR}/params.sty: ${PARAMS}
	${GETCONFIG} -t > $@
${TMPDIR}/$R.dvi: ${TMPDIR}/$R.tex ${TMPDIR}/$R.sty ${TMPDIR}/params.sty
	cd ${TMPDIR}/; latex -interaction=nonstopmode -halt-on-error $<
${OUTDIR}/$R.dvi: ${TMPDIR}/$R.dvi
	cp $< $@
# dvipdfmx, not ghostscript's dvipdf: Acrobat renders the dvipdf output as
# blank pages, though gs, poppler and every other viewer read it fine.  Both
# embed the same cm-super faces as CFF off the same dvi, so this is only a
# question of which writer Acrobat accepts -- and Acrobat is what the job
# sites hand a resume to.  The file comes out about 20% smaller as well.
${PDFFILE}: ${OUTDIR}/$R.dvi
	dvipdfmx -q -o $@ $<
