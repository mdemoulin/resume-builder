<?xml version="1.0" encoding="UTF-8"?>
<!--
    Copyright (C) 2026 Michael A. Demoulin
    SPDX-License-Identifier: GPL-3.0-or-later

    resume2oo.xsl - render resume.xml as a flat ODF text document (.fodt)

    Replaces the old nsgmls | cleanup_oo.pl | sgmlspl resume2oo.pl pipeline,
    which appended to src/oo/oo-pre.txt and zipped the result with the rest of
    src/oo/ into a .sxw.  All of that is gone: a flat ODF document is a single
    XML file, so there is no content.xml, no META-INF/manifest.xml, no mimetype
    ordering rule, and no zip step.  src/oo/ is no longer used at all.

    What changed, beyond the packaging:

      * Format.  The old output was OpenOffice.org 1.x (.sxw,
        application/vnd.sun.xml.writer, xmlns .../openoffice.org/2000/...),
        superseded by OASIS ODF in 2005 and no longer writable by LibreOffice.
        This is ODF 1.3.  Note fo: is the ODF xsl-fo-compatible namespace, not
        the W3C XSL/Format one the old files used.

      * Lengths.  OOo 1.x wrote "6.5056inch"; ODF only accepts in/cm/mm/pt/pc.

      * Style names.  ODF encodes spaces in style names as _20_, with the
        readable form in style:display-name.

      * Properties.  The old single <style:properties> is split by kind into
        style:text-properties / style:paragraph-properties / etc.

      * Fonts.  Luxi Sans and Luxi Mono have not shipped on a Linux distro in
        roughly fifteen years; Liberation Sans and Liberation Mono replace them.

      * Two bugs in resume2oo.pl are fixed here.  It selected the table style
        "NameTabletwophones" while oo-pre.txt defined "NameTableTwoPhones", so
        the two-phone table was unstyled; and it always emitted three
        table-column elements even in the one-phone layout, which defines only
        two.  The one-phone path also closed the address cell before writing
        the email paragraph, leaving that paragraph outside any cell.

      * <list>/<item> now produce a real text:list.  The old script emitted
        nothing for either, running the items together as one paragraph.

    Parameters (set by the Makefile from lib/params, see set-conf.pl -v):
        twophones  1 = list both phone numbers, labelled; 0 = first only
        extra      1 = include <extra> content; 0 = omit it.  The old script
                   wrapped extras in an XML comment, which is the same thing
                   as omitting them but leaves the text in the file.
        expandabbrevs  1 = follow an abbreviation with its definition
                   in parentheses; 0 = give the abbreviation alone
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
    xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
    xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
    xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
    xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
    xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"
    xmlns:xlink="http://www.w3.org/1999/xlink">

<xsl:output method="xml" encoding="UTF-8" indent="yes"/>

<!-- element content is whitespace-insensitive; mixed content is not -->
<xsl:strip-space elements="*"/>
<xsl:preserve-space elements="description extra item"/>

<xsl:param name="twophones">0</xsl:param>
<xsl:param name="extra">0</xsl:param>
<xsl:param name="expandabbrevs">0</xsl:param>
<!-- 1 = emit the supervisor and hours a federal resume is rated against -->
<xsl:param name="federal">0</xsl:param>


<!-- ===== document ==================================================== -->

<xsl:template match="/">
  <office:document office:version="1.3"
      office:mimetype="application/vnd.oasis.opendocument.text">

    <office:meta>
      <meta:generator>resume2oo.xsl</meta:generator>
      <dc:title>The resume of <xsl:value-of select="/resume/author/name"/></dc:title>
      <dc:language>en-US</dc:language>
    </office:meta>

    <office:font-face-decls>
      <style:font-face style:name="Liberation Sans"
          svg:font-family="'Liberation Sans'"
          style:font-family-generic="swiss" style:font-pitch="variable"/>
      <style:font-face style:name="Liberation Mono"
          svg:font-family="'Liberation Mono'"
          style:font-family-generic="modern" style:font-pitch="fixed"/>
    </office:font-face-decls>

    <xsl:call-template name="styles"/>
    <xsl:call-template name="automatic-styles"/>

    <office:master-styles>
      <style:master-page style:name="Standard" style:page-layout-name="pm1"
          style:next-style-name="Continued">
        <style:footer>
          <text:p text:style-name="Resume_20_Continued">- continued -</text:p>
        </style:footer>
      </style:master-page>
      <style:master-page style:name="Continued" style:page-layout-name="pm2">
        <style:header>
          <xsl:for-each select="resume/author">
            <xsl:call-template name="contact-band">
              <xsl:with-param name="table">HeaderTable</xsl:with-param>
              <xsl:with-param name="cell">ContactCell</xsl:with-param>
              <xsl:with-param name="name">HeaderTable</xsl:with-param>
              <xsl:with-param name="pagenumber">1</xsl:with-param>
            </xsl:call-template>
          </xsl:for-each>
        </style:header>
      </style:master-page>
    </office:master-styles>

    <office:body>
      <office:text>
        <xsl:apply-templates select="resume/author"/>
        <xsl:apply-templates select="resume/section[not(@federal) or @federal = $federal]"/>
      </office:text>
    </office:body>
  </office:document>
</xsl:template>


<!-- ===== styles ====================================================== -->

<!-- Carried over from src/oo/styles.xml (recoverable at r5 if ever needed).

     The parent styles below MUST be declared here.  They look like
     LibreOffice built-ins, but a flat ODF document only has the styles it
     names: on import, a style:parent-style-name pointing at a style the file
     never defines is silently dropped, and the child falls back to the
     document default, which is serif and unsized.  That is what happened to
     Resume Section and Resume Subsection, and through them to Resume Name,
     Address, Email, Phone, Job Title, Company and Date Range. -->
<xsl:template name="styles">
  <office:styles>

    <!-- 10pt, not the 11pt LibreOffice defaults to: the resume is typeset by
         \documentclass{article} with no size option, so the body is 10pt, and
         the heading sizes below are that scale: 14pt for \Large (14.4), 12pt
         for \large.  The body itself is $bodysize, a half point under the
         pdf's, because Liberation Sans is the wider face; see there.  At 11pt
         the body wrapped wider and fit fewer lines per page, pushing the
         office formats to three pages while the pdf stayed at two. -->
    <style:default-style style:family="paragraph">
      <style:text-properties style:font-name="Liberation Sans" fo:font-size="{$bodysize}pt"/>
    </style:default-style>

    <style:style style:name="Standard" style:family="paragraph" style:class="text"/>

    <style:style style:name="Text_20_body" style:display-name="Text body"
        style:family="paragraph" style:parent-style-name="Standard" style:class="text">
      <style:paragraph-properties fo:margin-top="0in" fo:margin-bottom="0in"/>
    </style:style>

    <style:style style:name="Heading" style:family="paragraph"
        style:parent-style-name="Standard" style:next-style-name="Text_20_body"
        style:class="text">
      <style:text-properties style:font-name="Liberation Sans" fo:font-size="14pt"/>
      <style:paragraph-properties fo:margin-top="0.1665in" fo:margin-bottom="0in"
          fo:keep-with-next="always"/>
    </style:style>

    <!-- Resume Section overrides the italic below back to normal -->
    <style:style style:name="Heading_20_2" style:display-name="Heading 2"
        style:family="paragraph" style:parent-style-name="Heading"
        style:next-style-name="Text_20_body" style:class="text">
      <style:text-properties fo:font-size="14pt" fo:font-style="italic"
          fo:font-weight="bold"/>
    </style:style>

    <style:style style:name="Heading_20_3" style:display-name="Heading 3"
        style:family="paragraph" style:parent-style-name="Heading"
        style:next-style-name="Text_20_body" style:class="text">
      <style:text-properties fo:font-size="14pt" fo:font-weight="bold"/>
    </style:style>

    <style:style style:name="Strong_20_Emphasis" style:display-name="Strong Emphasis"
        style:family="text">
      <style:text-properties fo:font-weight="bold"/>
    </style:style>

    <style:style style:name="Teletype" style:family="text">
      <style:text-properties style:font-name="Liberation Mono"/>
    </style:style>

    <style:style style:name="Resume_20_Text_20_Body" style:display-name="Resume Text Body"
        style:family="paragraph" style:parent-style-name="Text_20_body" style:class="text">
      <style:text-properties style:font-name="Liberation Sans" fo:font-size="{$bodysize}pt"/>
      <style:paragraph-properties fo:text-align="justify" style:justify-single-word="false"/>
    </style:style>

    <!-- Orphan and widow control rather than keep-together: the LaTeX side
         lets a job's paragraph split across pages, and with keep-together a
         twelve-line federal description that missed the bottom of page one
         by a few lines went over whole, leaving 1.5in blank above the
         footer and a third page below.  JobTable's keep-with-next still
         holds the header to the first two lines. -->
    <style:style style:name="Resume_20_Job_20_Text_20_Body" style:display-name="Resume Job Text Body"
        style:family="paragraph" style:parent-style-name="Resume_20_Text_20_Body">
      <style:paragraph-properties fo:margin-top="0.0833in" fo:margin-bottom="0in"
          fo:orphans="2" fo:widows="2"/>
    </style:style>

    <style:style style:name="Resume_20_Section" style:display-name="Resume Section"
        style:family="paragraph" style:parent-style-name="Heading_20_2"
        style:next-style-name="Resume_20_Subsection" style:class="text">
      <style:text-properties fo:font-style="normal"/>
      <style:paragraph-properties fo:text-align="center" style:justify-single-word="false"/>
    </style:style>

    <style:style style:name="Resume_20_Subsection" style:display-name="Resume Subsection"
        style:family="paragraph" style:parent-style-name="Heading_20_3"
        style:next-style-name="Resume_20_Text_20_Body" style:class="text">
      <style:text-properties fo:font-size="12pt"/>
      <style:paragraph-properties fo:text-align="center" style:justify-single-word="false"/>
    </style:style>

    <style:style style:name="Resume_20_Name" style:display-name="Resume Name"
        style:family="paragraph" style:parent-style-name="Resume_20_Section" style:class="text">
      <style:paragraph-properties fo:margin-top="0in" fo:margin-bottom="0in"/>
    </style:style>

    <style:style style:name="Resume_20_Address" style:display-name="Resume Address"
        style:family="paragraph" style:parent-style-name="Resume_20_Subsection" style:class="text">
      <style:paragraph-properties fo:margin-top="0in" fo:margin-bottom="0in"
          fo:text-align="left" style:justify-single-word="false"/>
    </style:style>

    <style:style style:name="Resume_20_Email" style:display-name="Resume Email"
        style:family="paragraph" style:parent-style-name="Resume_20_Subsection" style:class="text"/>

    <!-- "page 2" under the name in the running header, and the page one
         footer.  Both are \footnotesize on the LaTeX side. -->
    <style:style style:name="Resume_20_Page_20_Number" style:display-name="Resume Page Number"
        style:family="paragraph" style:parent-style-name="Resume_20_Subsection" style:class="text">
      <style:text-properties fo:font-size="9pt" fo:font-weight="normal"/>
      <style:paragraph-properties fo:margin-top="0in" fo:margin-bottom="0in"
          fo:text-align="center" style:justify-single-word="false"/>
    </style:style>

    <style:style style:name="Resume_20_Continued" style:display-name="Resume Continued"
        style:family="paragraph" style:parent-style-name="Resume_20_Subsection" style:class="text">
      <style:text-properties fo:font-size="9pt" fo:font-weight="normal"/>
      <style:paragraph-properties fo:margin-top="0in" fo:margin-bottom="0in"
          fo:text-align="center" style:justify-single-word="false"/>
    </style:style>

    <style:style style:name="Resume_20_Phone" style:display-name="Resume Phone"
        style:family="paragraph" style:parent-style-name="Resume_20_Subsection" style:class="text">
      <style:paragraph-properties fo:margin-top="0in" fo:margin-bottom="0in"
          fo:text-align="right" style:justify-single-word="false"/>
    </style:style>

    <style:style style:name="Resume_20_Job_20_Title" style:display-name="Resume Job Title"
        style:family="paragraph" style:parent-style-name="Resume_20_Subsection"
        style:next-style-name="Resume_20_Company" style:class="text">
      <style:paragraph-properties fo:margin-top="0in" fo:margin-bottom="0in"/>
    </style:style>

    <!-- fo:text-align is "left"/"right" here, not the writing-mode-relative
         "start"/"end" ODF would otherwise prefer.  These parent onto Resume
         Subsection, which centres; with start/end the Word export dropped the
         override entirely (the styles came out with no w:jc at all) and the
         cells inherited that centring, so the company sat mid-column in .doc
         and .docx while the .odt and the pdf had it flush left.  With the
         absolute values the filter emits the w:jc and all four agree.  Resume
         Job Title deliberately has no alignment of its own and keeps
         inheriting the centring.  Resume Address and Resume Phone had the
         same defect and are fixed the same way. -->
    <style:style style:name="Resume_20_Company" style:display-name="Resume Company"
        style:family="paragraph" style:parent-style-name="Resume_20_Subsection"
        style:next-style-name="Resume_20_Date_20_Range" style:class="text">
      <style:paragraph-properties fo:margin-top="0in" fo:margin-bottom="0in"
          fo:text-align="left" style:justify-single-word="false"/>
    </style:style>

    <style:style style:name="Resume_20_Date_20_Range" style:display-name="Resume Date Range"
        style:family="paragraph" style:parent-style-name="Resume_20_Subsection"
        style:next-style-name="Resume_20_Text_20_Body" style:class="text">
      <style:paragraph-properties fo:margin-top="0in" fo:margin-bottom="0in"
          fo:text-align="right" style:justify-single-word="false"/>
    </style:style>

    <style:style style:name="Resume_20_Kbd" style:display-name="Resume Kbd"
        style:family="text" style:parent-style-name="Teletype">
      <style:text-properties style:font-name="Liberation Mono"/>
    </style:style>

    <style:style style:name="Resume_20_Server" style:display-name="Resume Server"
        style:family="text" style:parent-style-name="Teletype">
      <style:text-properties style:font-name="Liberation Mono"/>
    </style:style>

    <style:style style:name="Resume_20_Acronym" style:display-name="Resume Acronym"
        style:family="text">
      <style:text-properties style:font-name="Liberation Sans" fo:font-size="{$acronymsize}pt"/>
    </style:style>

    <style:style style:name="Resume_20_Emphasis" style:display-name="Resume Emphasis"
        style:family="text" style:parent-style-name="Strong_20_Emphasis">
      <style:text-properties style:font-name="Liberation Sans" fo:font-size="{$bodysize}pt"
          fo:font-weight="bold"/>
    </style:style>

    <!-- The two shifted letters of the TeX and LaTeX logos.  style:text-position
         is "vertical-offset font-size", both relative; the A rides high and
         small, the E drops at full size.  ODF has no way to express the tight
         negative kerning TeX itself uses, so the letters sit a little further
         apart than in the .pdf. -->
    <style:style style:name="Resume_20_Logo_20_A" style:display-name="Resume Logo A"
        style:family="text">
      <style:text-properties style:text-position="27% 70%"/>
    </style:style>
    <style:style style:name="Resume_20_Logo_20_E" style:display-name="Resume Logo E"
        style:family="text">
      <style:text-properties style:text-position="-22% 100%"/>
    </style:style>

    <!-- new: the old script emitted nothing for <list> and <item> -->
    <text:list-style style:name="Resume_20_List" style:display-name="Resume List">
      <text:list-level-style-bullet text:level="1" text:bullet-char="&#x2022;">
        <style:list-level-properties text:space-before="0.25in" text:min-label-width="0.25in"/>
      </text:list-level-style-bullet>
    </text:list-style>

  </office:styles>
</xsl:template>


<!-- Page geometry.  The industry copy keeps its 1in sides; the federal copy
     takes USAJOBS's own 0.5in advice on every side, the same as resume.sty's
     @federal branch, because at 1in it ran to a third page and USAJOBS caps
     resumes at two (2026).  Everything below that depends on the text width
     is derived from $textwidth so the two stay in step. -->
<xsl:variable name="side">
  <xsl:choose>
    <xsl:when test="$federal = '1'">0.5</xsl:when>
    <xsl:otherwise>1</xsl:otherwise>
  </xsl:choose>
</xsl:variable>
<xsl:variable name="textwidth" select="8.5 - 2 * $side"/>
<!-- Page one body top, and every page's body bottom edge.  The federal
     page one starts where resume.sty starts its header, 0.5in down. -->
<xsl:variable name="bodytop">
  <xsl:choose>
    <xsl:when test="$federal = '1'">0.5</xsl:when>
    <xsl:otherwise>1</xsl:otherwise>
  </xsl:choose>
</xsl:variable>
<!-- running-header top on pages after the first; the industry value puts
     that page's body top at the same 1in as page one, the federal one is
     where resume.sty puts its header -->
<xsl:variable name="headertop">
  <xsl:choose>
    <xsl:when test="$federal = '1'">0.5</xsl:when>
    <xsl:otherwise>0.35</xsl:otherwise>
  </xsl:choose>
</xsl:variable>
<!-- Body size.  Liberation Sans is wider than the pdf's Computer Modern, and
     at 10pt both builds ran eight to ten lines onto a third page: the federal
     one even after its margins came in, the industry one once the 2026
     wording edits lengthened a few sentences.  9.5pt puts both back at the
     pdf's two pages.  The acronym size follows it, one step down as \small
     is from \normalsize. -->
<xsl:variable name="bodysize" select="9.5"/>
<xsl:variable name="acronymsize" select="$bodysize - 1"/>
<xsl:variable name="bodyend">
  <xsl:choose>
    <xsl:when test="$federal = '1'">10.45</xsl:when>
    <xsl:otherwise>10.25</xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<!-- Table and column widths from src/oo/oo-pre.txt, with "inch" corrected to
     "in".  NameTableOnePhone deliberately has only two columns. -->
<xsl:template name="automatic-styles">
  <office:automatic-styles>

    <!-- The LaTeX side sets parskip to zero and buys its vertical rhythm with
         \vspace above headings only, so the body paragraphs here carry no
         space below them either; space is kept above a heading and nowhere
         else.  That plus the 0.75in bottom margin is what keeps the office
         formats at the same two pages as the pdf.  At LibreOffice's stock
         6pt-below-every-paragraph and a full 1in bottom margin the same
         content ran to three. -->
    <!-- Two page layouts, chained by style:next-style-name on the master
         pages: pm1 is page one, pm2 every page after it.  The body box is
         identical in both, 1in down from the top and ending 10.25in down, so
         which layout a page uses cannot shift the pagination.  pm1 spends the
         difference at the bottom on the footer, pm2 at the top on the running
         header.  The rule under the header is the fo:border-bottom, standing
         in for fancyhdr's headrule. -->
    <style:page-layout style:name="pm1">
      <style:page-layout-properties fo:page-width="8.5in" fo:page-height="11in"
          style:num-format="1" style:print-orientation="portrait"
          fo:margin-top="{$bodytop}in" fo:margin-bottom="{format-number(11 - $bodyend - 0.45, '0.##')}in"
          fo:margin-left="{$side}in" fo:margin-right="{$side}in"
          style:writing-mode="lr-tb"/>
      <style:footer-style>
        <style:header-footer-properties svg:height="0.3in" fo:margin-top="0.15in"/>
      </style:footer-style>
    </style:page-layout>

    <style:page-layout style:name="pm2">
      <style:page-layout-properties fo:page-width="8.5in" fo:page-height="11in"
          style:num-format="1" style:print-orientation="portrait"
          fo:margin-top="{$headertop}in" fo:margin-bottom="{format-number(11 - $bodyend, '0.##')}in"
          fo:margin-left="{$side}in" fo:margin-right="{$side}in"
          style:writing-mode="lr-tb"/>
      <!-- The gap between header and body is part of svg:height rather than
           fo:margin-bottom, which looks redundant and is not.  OOXML has one
           set of page margins per section, so the Word export has to collapse
           pm1 and pm2 into a single w:top, and it computes that as this
           layout's fo:margin-top plus svg:height, silently dropping the
           header's fo:margin-bottom.  With the gap in the margin the docx got
           w:top=1224 (0.85in) against the odt's 1in body top, which gave the
           docx five more lines on page one, enough to pull a whole job up and
           break the page somewhere else.  Folded into the height it exports as
           w:top=1440 and the two agree exactly.  The rule under the band comes
           from ContactCell's border, not from here, so that it sits under the
           header text instead of down at the body. -->
      <style:header-style>
        <style:header-footer-properties svg:height="0.65in" fo:margin-bottom="0in"/>
      </style:header-style>
    </style:page-layout>

    <!-- One three-column band, address | name | phones, used for both the
         page one body table and the running header; the twophones split is
         now in what goes into the cells, not in the table shape.  ContactCell
         carries the rule under the band on page one, where there is no header
         border to draw it. -->
    <style:style style:name="ContactTable" style:family="table">
      <style:table-properties style:width="{$textwidth}in" table:align="margins"
          fo:margin-bottom="0.25in" style:may-break-between-rows="false"/>
    </style:style>
    <style:style style:name="HeaderTable" style:family="table">
      <style:table-properties style:width="{$textwidth}in" table:align="margins"
          style:may-break-between-rows="false"/>
    </style:style>
    <style:style style:name="ContactTable.A" style:family="table-column">
      <style:table-column-properties style:column-width="{($textwidth - 2.3) div 2}in"/>
    </style:style>
    <style:style style:name="ContactTable.B" style:family="table-column">
      <style:table-column-properties style:column-width="2.3in"/>
    </style:style>
    <style:style style:name="ContactTable.C" style:family="table-column">
      <style:table-column-properties style:column-width="{($textwidth - 2.3) div 2}in"/>
    </style:style>
    <style:style style:name="ContactCell" style:family="table-cell">
      <style:table-cell-properties fo:padding="0in" fo:padding-bottom="0.04in"
          fo:border-bottom="0.4pt solid #000000" style:vertical-align="top"/>
    </style:style>

    <style:style style:name="JobTable" style:family="table">
      <style:table-properties style:width="{$textwidth}in" fo:margin-top="0.1701in"
          fo:margin-bottom="0.0799in" table:align="margins"
          style:may-break-between-rows="false" fo:keep-with-next="always"/>
    </style:style>
    <style:style style:name="JobTable.A" style:family="table-column">
      <style:table-column-properties style:column-width="{$textwidth div 2}in"/>
    </style:style>
    <style:style style:name="JobTable.B" style:family="table-column">
      <style:table-column-properties style:column-width="{$textwidth div 2}in"/>
    </style:style>

  </office:automatic-styles>
</xsl:template>


<!-- ===== author block ================================================ -->

<!-- The contact band, in the arrangement resume.sty's fancyhdr header uses:
     address left, name centred, phones right (its lhead/chead/rhead).  One
     template emits it twice, as the first thing in the body on page one and
     as the running header on every page after that.

     Page one deliberately keeps it in the BODY rather than in a header on
     every page as the LaTeX does.  A Word header is a separate part inside
     the .docx (word/header1.xml), not word/document.xml, and resume parsers
     that read only the document body would find no name, phone, email or
     address at all.  The pdf has no such problem, since its header is drawn
     text that pdftotext reads like any other; the structure is only a hazard
     on the office side, so only the office side diverges.

     With twophones on the email moves under the name and both numbers go
     right, labelled; off, the first number and the email share the right
     column.  Every number after the first is dropped, as in the html and
     LaTeX stylesheets. -->
<xsl:template name="contact-band">
  <xsl:param name="table">ContactTable</xsl:param>
  <xsl:param name="cell">ContactCell</xsl:param>
  <xsl:param name="name">ContactTable</xsl:param>
  <xsl:param name="pagenumber">0</xsl:param>

  <table:table table:name="{$name}" table:style-name="{$table}">
    <table:table-column table:style-name="ContactTable.A"/>
    <table:table-column table:style-name="ContactTable.B"/>
    <table:table-column table:style-name="ContactTable.C"/>

    <table:table-row>
      <table:table-cell table:style-name="{$cell}" table:value-type="string">
        <xsl:apply-templates select="address"/>
      </table:table-cell>

      <table:table-cell table:style-name="{$cell}" table:value-type="string">
        <text:p text:style-name="Resume_20_Name"><xsl:value-of select="name"/></text:p>
        <xsl:if test="$twophones = '1'">
          <xsl:apply-templates select="email"/>
        </xsl:if>
        <xsl:if test="$pagenumber = '1'">
          <text:p text:style-name="Resume_20_Page_20_Number">
            <xsl:text>page </xsl:text>
            <text:page-number text:select-page="current">2</text:page-number>
          </text:p>
        </xsl:if>
      </table:table-cell>

      <table:table-cell table:style-name="{$cell}" table:value-type="string">
        <xsl:choose>
          <xsl:when test="$twophones = '1'">
            <xsl:apply-templates select="phone"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="phone[1]"/>
            <xsl:apply-templates select="email"/>
          </xsl:otherwise>
        </xsl:choose>
      </table:table-cell>
    </table:table-row>
  </table:table>
</xsl:template>

<xsl:template match="author">
  <xsl:call-template name="contact-band"/>
</xsl:template>

<xsl:template match="address">
  <!-- street is federal-only; the public resume shows city and state -->
  <xsl:if test="street and $federal = '1'">
    <text:p text:style-name="Resume_20_Address"><xsl:value-of select="street"/></text:p>
  </xsl:if>
  <text:p text:style-name="Resume_20_Address">
    <xsl:value-of select="city"/>
    <xsl:text>, </xsl:text>
    <xsl:value-of select="state"/>
    <xsl:if test="zip">
      <xsl:text> </xsl:text>
      <xsl:value-of select="zip"/>
    </xsl:if>
  </text:p>
</xsl:template>

<xsl:template match="email">
  <text:p>
    <xsl:attribute name="text:style-name">
      <xsl:choose>
        <xsl:when test="$twophones = '1'">Resume_20_Email</xsl:when>
        <xsl:otherwise>Resume_20_Phone</xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
    <xsl:value-of select="."/>
  </text:p>
</xsl:template>

<xsl:template match="phone">
  <text:p text:style-name="Resume_20_Phone">
    <xsl:if test="$twophones = '1'">
      <xsl:choose>
        <xsl:when test="count(preceding-sibling::phone) = 0">Home: </xsl:when>
        <xsl:otherwise>Cell: </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
    <xsl:value-of select="number"/>
  </text:p>
</xsl:template>


<!-- ===== sections ==================================================== -->

<xsl:template match="section">
  <text:p text:style-name="Resume_20_Section"><xsl:value-of select="heading"/></text:p>
  <xsl:apply-templates select="(description | subsection | jobsubsection)[not(@extra = '1') or $extra = '1'][not(@federal) or @federal = $federal]"/>
</xsl:template>

<xsl:template match="subsection">
  <text:p text:style-name="Resume_20_Subsection"><xsl:value-of select="heading"/></text:p>
  <xsl:apply-templates select="description"/>
</xsl:template>

<xsl:template match="jobsubsection">
  <table:table table:name="JobTable{count(preceding::jobsubsection) + 1}"
      table:style-name="JobTable">
    <table:table-column table:style-name="JobTable.A"/>
    <table:table-column table:style-name="JobTable.B"/>
    <table:table-row>
      <table:table-cell table:number-columns-spanned="2" table:value-type="string">
        <text:p text:style-name="Resume_20_Job_20_Title">
          <xsl:value-of select="jobheader/title"/>
        </text:p>
      </table:table-cell>
      <table:covered-table-cell/>
    </table:table-row>
    <table:table-row>
      <table:table-cell table:value-type="string">
        <text:p text:style-name="Resume_20_Company">
          <xsl:value-of select="jobheader/company"/>
        </text:p>
      </table:table-cell>
      <table:table-cell table:value-type="string">
        <text:p text:style-name="Resume_20_Date_20_Range">
          <xsl:value-of select="jobheader/daterange/from"/>
          <xsl:text> - </xsl:text>
          <xsl:value-of select="jobheader/daterange/to"/>
        </text:p>
      </table:table-cell>
    </table:table-row>
  </table:table>
  <xsl:if test="$federal = '1' and (jobheader/location | jobheader/hours | jobheader/salary | jobheader/supervisor | jobheader/reason)">
    <text:p text:style-name="Resume_20_Job_20_Text_20_Body">
      <xsl:if test="jobheader/location">
        <xsl:if test="jobheader/location/street">
          <xsl:value-of select="jobheader/location/street"/>
          <xsl:text>, </xsl:text>
        </xsl:if>
        <xsl:value-of select="jobheader/location/city"/>
        <xsl:text>, </xsl:text>
        <xsl:value-of select="jobheader/location/state"/>
        <xsl:text>.</xsl:text>
      </xsl:if>
      <xsl:if test="jobheader/hours">
        <xsl:if test="jobheader/location"><xsl:text>  </xsl:text></xsl:if>
        <xsl:text>Hours per week: </xsl:text>
        <xsl:value-of select="jobheader/hours"/>
        <xsl:text>.</xsl:text>
      </xsl:if>
      <xsl:if test="jobheader/salary">
        <xsl:if test="jobheader/location | jobheader/hours"><xsl:text>  </xsl:text></xsl:if>
        <xsl:text>Salary: </xsl:text>
        <xsl:value-of select="jobheader/salary"/>
        <xsl:text>.</xsl:text>
      </xsl:if>
      <xsl:if test="jobheader/supervisor">
        <xsl:if test="jobheader/location | jobheader/hours | jobheader/salary"><xsl:text>  </xsl:text></xsl:if>
        <xsl:text>Supervisor: </xsl:text>
        <xsl:value-of select="jobheader/supervisor/name"/>
        <xsl:if test="jobheader/supervisor/title">
          <xsl:text> (</xsl:text>
          <xsl:value-of select="jobheader/supervisor/title"/>
          <xsl:text>)</xsl:text>
        </xsl:if>
        <xsl:if test="jobheader/supervisor/number">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="jobheader/supervisor/number"/>
        </xsl:if>
        <xsl:if test="jobheader/supervisor/@maycontact">
          <xsl:text>, may contact: </xsl:text>
          <xsl:value-of select="jobheader/supervisor/@maycontact"/>
        </xsl:if>
        <xsl:text>.</xsl:text>
      </xsl:if>
      <xsl:if test="jobheader/reason">
        <xsl:if test="jobheader/location | jobheader/hours | jobheader/salary | jobheader/supervisor"><xsl:text>  </xsl:text></xsl:if>
        <xsl:text>Reason for leaving: </xsl:text>
        <xsl:value-of select="jobheader/reason"/>
        <xsl:text>.</xsl:text>
      </xsl:if>
    </text:p>
  </xsl:if>
  <xsl:apply-templates select="description"/>
</xsl:template>

<!-- A text:list cannot sit inside a text:p, so a description holding one has
     to be split: loose content becomes a paragraph, then the lists follow.
     Lists in resume.xml are always the whole description, so nothing is
     reordered in practice; a list in the middle of a description would move
     the text after it up into the same paragraph as the text before it. -->
<xsl:template match="description">
  <xsl:variable name="style"><xsl:call-template name="body-style"/></xsl:variable>
  <xsl:variable name="loose">
    <xsl:apply-templates select="node()[not(self::list)]"/>
  </xsl:variable>
  <xsl:if test="normalize-space($loose) != ''">
    <text:p text:style-name="{$style}"><xsl:copy-of select="$loose"/></text:p>
  </xsl:if>
  <xsl:apply-templates select="list"/>
</xsl:template>

<!-- descriptions under a job get the tighter spacing -->
<xsl:template name="body-style">
  <xsl:choose>
    <xsl:when test="ancestor-or-self::jobsubsection">Resume_20_Job_20_Text_20_Body</xsl:when>
    <xsl:otherwise>Resume_20_Text_20_Body</xsl:otherwise>
  </xsl:choose>
</xsl:template>


<!-- ===== inline content ============================================== -->

<xsl:template match="list">
  <text:list text:style-name="Resume_20_List"><xsl:apply-templates/></text:list>
</xsl:template>

<xsl:template match="item">
  <xsl:variable name="style"><xsl:call-template name="body-style"/></xsl:variable>
  <text:list-item>
    <text:p text:style-name="{$style}"><xsl:apply-templates/></text:p>
  </text:list-item>
</xsl:template>

<xsl:template match="extra">
  <xsl:if test="$extra = '1'"><xsl:apply-templates/></xsl:if>
</xsl:template>

<xsl:template match="abbrev">
  <text:span text:style-name="Resume_20_Acronym"><xsl:value-of select="word"/></text:span>
  <xsl:if test="$expandabbrevs = '1'">
    <xsl:text> (</xsl:text>
    <xsl:value-of select="normalize-space(defn)"/>
    <xsl:text>)</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="command">
  <text:span text:style-name="Resume_20_Kbd"><xsl:apply-templates/></text:span>
</xsl:template>

<xsl:template match="server">
  <text:span text:style-name="Resume_20_Server"><xsl:apply-templates/></text:span>
</xsl:template>

<xsl:template match="acronym">
  <text:span text:style-name="Resume_20_Acronym"><xsl:apply-templates/></text:span>
</xsl:template>

<xsl:template match="emph">
  <text:span text:style-name="Resume_20_Emphasis"><xsl:apply-templates/></text:span>
</xsl:template>

<!-- resume2oo.pl was set up to gag on unrecognised elements; keep that -->
<xsl:template match="*">
  <xsl:message terminate="yes">
    <xsl:text>Unknown element: </xsl:text><xsl:value-of select="name()"/>
  </xsl:message>
</xsl:template>


<!-- ===== TeX and LaTeX logos ========================================= -->

<!-- Only text reached through apply-templates is scanned, which is the
     document body.  Headings and the author block are pulled with value-of
     and stay literal; none of them says TeX. -->
<xsl:template match="text()">
  <xsl:call-template name="logos"><xsl:with-param name="s" select="."/></xsl:call-template>
</xsl:template>

<!-- LaTeX has to be split off first, or the TeX pass would eat its tail and
     leave "La" stranded.  This is the same hazard resume2latex.xsl parks a
     marker character for; here the two passes just nest instead. -->
<xsl:template name="logos">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="contains($s, 'LaTeX')">
      <xsl:call-template name="logos-tex">
        <xsl:with-param name="s" select="substring-before($s, 'LaTeX')"/>
      </xsl:call-template>
      <xsl:text>L</xsl:text>
      <text:span text:style-name="Resume_20_Logo_20_A">A</text:span>
      <xsl:call-template name="tex-logo"/>
      <xsl:call-template name="logos">
        <xsl:with-param name="s" select="substring-after($s, 'LaTeX')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="logos-tex">
        <xsl:with-param name="s" select="$s"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="logos-tex">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="contains($s, 'TeX')">
      <xsl:value-of select="substring-before($s, 'TeX')"/>
      <xsl:call-template name="tex-logo"/>
      <xsl:call-template name="logos-tex">
        <xsl:with-param name="s" select="substring-after($s, 'TeX')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$s"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="tex-logo">
  <xsl:text>T</xsl:text>
  <text:span text:style-name="Resume_20_Logo_20_E">E</text:span>
  <xsl:text>X</xsl:text>
</xsl:template>

</xsl:stylesheet>
