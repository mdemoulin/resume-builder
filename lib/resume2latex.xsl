<?xml version="1.0" encoding="UTF-8"?>
<!--
    Copyright (C) 2026 Michael A. Demoulin
    SPDX-License-Identifier: GPL-3.0-or-later

    resume2latex.xsl - render resume.xml as a LaTeX document

    Replaces the old nsgmls | sgmlspl resume2latex.pl | cleanup_latex.pl
    pipeline.  The cleanup pass folds in here (see the "tex" template): the
    LaTeX / TeX / C++ rewrites, and the blank-line squashing that kept TeX
    from seeing a stray \par.

    Everything the document says is routed through "tex", which now also
    escapes TeX's special characters.  The old pipeline did not, so a single
    & or % anywhere in resume.xml produced a .tex that would not compile.

    Output structure is driven by src/tex/resume.sty:
        \Heading{name}{street}{city, state zip}{email}{phone}{phone}
        \begin{Section}{heading} ... \end{Section}
        \begin{Subsection}{heading} ... \end{Subsection}
        \begin{Jobsection}{title}{company}{from en-dash to} ... \end{Jobsection}
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="text" encoding="UTF-8"/>

<!-- element content is whitespace-insensitive; mixed content is not -->
<xsl:strip-space elements="*"/>
<xsl:preserve-space elements="description extra item"/>

<!-- 1 = resume.sty is compiled with @twophones, and so needs both numbers -->
<xsl:param name="twophones">0</xsl:param>

<!-- 1 = include blocks marked extra="1"; 0 = omit them.  Inline <extra> is
     gated in TeX instead, by \Extra and the @extra boolean. -->
<xsl:param name="extra">0</xsl:param>
<!-- 1 = emit the supervisor and hours a federal resume is rated against -->
<xsl:param name="federal">0</xsl:param>

<!-- characters TeX will not take literally.  MARKS must be the same length:
     translate() maps them positionally so we can find the first one. -->
<xsl:variable name="SPECIALS" select="'\{}$&amp;#^_~%'"/>
<xsl:variable name="MARK"  select="'&#xE000;'"/>
<xsl:variable name="MARKS" select="'&#xE000;&#xE000;&#xE000;&#xE000;&#xE000;&#xE000;&#xE000;&#xE000;&#xE000;&#xE000;'"/>
<!-- somewhere to park "LaTeX" so the "TeX" pass cannot bite the tail off it -->
<xsl:variable name="LMARK" select="'&#xE001;'"/>


<!-- ===== document ==================================================== -->

<!-- Build the whole document first, then filter it as one stream.  Doing it
     per text node is not the same thing: a node ending in "\n        " leaves
     its tail on a line of its own, which is blank by the time the next
     structural newline lands. -->
<xsl:template match="/">
  <xsl:variable name="raw">
    <xsl:apply-templates select="resume"/>
  </xsl:variable>
  <xsl:call-template name="drop-blank-lines">
    <xsl:with-param name="s" select="$raw"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="resume">
  <xsl:text>\documentclass{article}
\usepackage{xspace}
\usepackage{resume}
\nofiles
\begin{document}
</xsl:text>
  <xsl:apply-templates select="author"/>
  <xsl:apply-templates select="section[not(@federal) or @federal = $federal]"/>
  <xsl:text>\end{document}
</xsl:text>
</xsl:template>


<!-- \Heading always takes six arguments, so all six braces are emitted no
     matter what.  But resume.sty only expands #6 inside the @twophones
     branch, so a missing second phone is an empty brace pair and nothing
     more; it is only an error when twophones is on.  The old script emitted
     whatever it found and left LaTeX to complain about argument counts a
     hundred lines later. -->
<xsl:template match="author">
  <xsl:variable name="want" select="1 + ($twophones = '1')"/>
  <xsl:if test="count(email) != 1 or count(phone) &lt; $want">
    <xsl:message terminate="yes">
      <xsl:text>\Heading needs exactly 1 email and at least </xsl:text>
      <xsl:value-of select="$want"/>
      <xsl:text> phone(s); found </xsl:text>
      <xsl:value-of select="count(email)"/>
      <xsl:text> and </xsl:text>
      <xsl:value-of select="count(phone)"/>
    </xsl:message>
  </xsl:if>
  <xsl:text>\Heading{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="name"/></xsl:call-template>
  <xsl:text>}&#10;&#9;{</xsl:text>
  <!-- \Heading takes the address as two lines that sit left of the phone and
       the email.  With no street there is only one line to give it, so the
       city takes the first slot and the second is left empty; putting it in
       the second slot instead would print a blank line above it.
       The street is federal-only, same as the jobheader details: the
       public resume shows city and state only. -->
  <xsl:choose>
    <xsl:when test="not(address/street) or $federal != '1'">
      <xsl:call-template name="tex"><xsl:with-param name="s" select="address/city"/></xsl:call-template>
      <xsl:text>, </xsl:text>
      <xsl:call-template name="tex"><xsl:with-param name="s" select="address/state"/></xsl:call-template>
      <xsl:text>}&#10;&#9;{</xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="tex"><xsl:with-param name="s" select="address/street"/></xsl:call-template>
      <xsl:text>}&#10;&#9;{</xsl:text>
      <xsl:call-template name="tex"><xsl:with-param name="s" select="address/city"/></xsl:call-template>
      <xsl:text>, </xsl:text>
      <xsl:call-template name="tex"><xsl:with-param name="s" select="address/state"/></xsl:call-template>
      <xsl:if test="address/zip">
        <xsl:text> </xsl:text>
        <xsl:call-template name="tex"><xsl:with-param name="s" select="address/zip"/></xsl:call-template>
      </xsl:if>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:text>}&#10;&#9;{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="email"/></xsl:call-template>
  <xsl:text>}&#10;&#9;{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="phone[1]/number"/></xsl:call-template>
  <xsl:text>}&#10;&#9;{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="phone[2]/number"/></xsl:call-template>
  <xsl:text>}&#10;</xsl:text>
</xsl:template>


<!-- ===== sections ==================================================== -->

<xsl:template match="section">
  <xsl:text>\begin{Section}{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="heading"/></xsl:call-template>
  <xsl:text>}&#10;</xsl:text>
  <xsl:apply-templates select="(description | subsection | jobsubsection)[not(@extra = '1') or $extra = '1'][not(@federal) or @federal = $federal]"/>
  <xsl:text>\end{Section}&#10;</xsl:text>
</xsl:template>

<xsl:template match="subsection">
  <xsl:text>\begin{Subsection}{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="heading"/></xsl:call-template>
  <xsl:text>}&#10;</xsl:text>
  <xsl:apply-templates select="description"/>
  <xsl:text>\end{Subsection}&#10;</xsl:text>
</xsl:template>

<xsl:template match="jobsubsection">
  <xsl:text>\begin{Jobsection}&#10;&#9;{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/title"/></xsl:call-template>
  <xsl:text>}&#10;&#9;{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/company"/></xsl:call-template>
  <xsl:text>}&#10;&#9;{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/daterange/from"/></xsl:call-template>
  <xsl:text> -- </xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/daterange/to"/></xsl:call-template>
  <xsl:text>}&#10;</xsl:text>
  <xsl:if test="$federal = '1' and (jobheader/location | jobheader/hours | jobheader/salary | jobheader/supervisor | jobheader/reason)">
    <xsl:text>\JobFacts{</xsl:text>
    <xsl:if test="jobheader/location">
      <xsl:if test="jobheader/location/street">
        <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/location/street"/></xsl:call-template>
        <xsl:text>, </xsl:text>
      </xsl:if>
      <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/location/city"/></xsl:call-template>
      <xsl:text>, </xsl:text>
      <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/location/state"/></xsl:call-template>
      <xsl:text>.</xsl:text>
    </xsl:if>
    <xsl:if test="jobheader/hours">
      <xsl:if test="jobheader/location"><xsl:text>  </xsl:text></xsl:if>
      <xsl:text>Hours per week: </xsl:text>
      <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/hours"/></xsl:call-template>
      <xsl:text>.</xsl:text>
    </xsl:if>
    <xsl:if test="jobheader/salary">
      <xsl:if test="jobheader/location | jobheader/hours"><xsl:text>  </xsl:text></xsl:if>
      <xsl:text>Salary: </xsl:text>
      <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/salary"/></xsl:call-template>
      <xsl:text>.</xsl:text>
    </xsl:if>
    <xsl:if test="jobheader/supervisor">
      <xsl:if test="jobheader/location | jobheader/hours | jobheader/salary"><xsl:text>  </xsl:text></xsl:if>
      <xsl:text>Supervisor: </xsl:text>
      <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/supervisor/name"/></xsl:call-template>
      <xsl:if test="jobheader/supervisor/title">
        <xsl:text> (</xsl:text>
        <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/supervisor/title"/></xsl:call-template>
        <xsl:text>)</xsl:text>
      </xsl:if>
      <xsl:if test="jobheader/supervisor/number">
        <xsl:text>, </xsl:text>
        <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/supervisor/number"/></xsl:call-template>
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
      <xsl:call-template name="tex"><xsl:with-param name="s" select="jobheader/reason"/></xsl:call-template>
      <xsl:text>.</xsl:text>
    </xsl:if>
    <xsl:text>}&#10;</xsl:text>
  </xsl:if>
  <xsl:apply-templates select="description"/>
  <xsl:text>\end{Jobsection}&#10;</xsl:text>
</xsl:template>

<xsl:template match="description">
  <xsl:apply-templates/>
  <xsl:text>&#10;</xsl:text>
</xsl:template>


<!-- ===== inline content ============================================== -->

<xsl:template match="extra">
  <xsl:text>\Extra{</xsl:text><xsl:apply-templates/><xsl:text>}</xsl:text>
</xsl:template>

<xsl:template match="abbrev">
  <xsl:text>\abbrev{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="word"/></xsl:call-template>
  <xsl:text>}{</xsl:text>
  <xsl:call-template name="tex"><xsl:with-param name="s" select="defn"/></xsl:call-template>
  <xsl:text>}</xsl:text>
</xsl:template>

<xsl:template match="command">
  <xsl:text>\kbd{</xsl:text><xsl:apply-templates/><xsl:text>}</xsl:text>
</xsl:template>

<xsl:template match="server">
  <xsl:text>\server{</xsl:text><xsl:apply-templates/><xsl:text>}</xsl:text>
</xsl:template>

<xsl:template match="acronym">
  <xsl:text>\acronym{</xsl:text><xsl:apply-templates/><xsl:text>}</xsl:text>
</xsl:template>

<xsl:template match="emph">
  <xsl:text>\textbf{</xsl:text><xsl:apply-templates/><xsl:text>}</xsl:text>
</xsl:template>

<!-- a compact itemize: no extra space around or between items, so a list
     reads as part of the paragraph it sits in rather than breaking it up -->
<xsl:template match="list">
  <xsl:text>&#10;\begin{itemize}\setlength{\itemsep}{0pt}\setlength{\parskip}{0pt}\setlength{\topsep}{0pt}&#10;</xsl:text>
  <xsl:apply-templates select="item"/>
  <xsl:text>\end{itemize}&#10;</xsl:text>
</xsl:template>

<xsl:template match="item">
  <xsl:text>\item </xsl:text><xsl:apply-templates/><xsl:text>&#10;</xsl:text>
</xsl:template>

<xsl:template match="text()">
  <xsl:call-template name="tex"><xsl:with-param name="s" select="."/></xsl:call-template>
</xsl:template>

<!-- resume2latex.pl died on unrecognised elements; keep that -->
<xsl:template match="*">
  <xsl:message terminate="yes">
    <xsl:text>Unknown element: </xsl:text><xsl:value-of select="name()"/>
  </xsl:message>
</xsl:template>


<!-- ===== text plumbing =============================================== -->

<!-- everything the document says goes through here -->
<xsl:template name="tex">
  <xsl:param name="s"/>
  <xsl:variable name="esc">
    <xsl:call-template name="tex-escape">
      <xsl:with-param name="s" select="$s"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="parked">
    <xsl:call-template name="replace">
      <xsl:with-param name="s" select="$esc"/>
      <xsl:with-param name="from" select="'LaTeX'"/>
      <xsl:with-param name="to" select="$LMARK"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="tex">
    <xsl:call-template name="replace">
      <xsl:with-param name="s" select="$parked"/>
      <xsl:with-param name="from" select="'TeX'"/>
      <xsl:with-param name="to" select="'\TeX{}'"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="latex">
    <xsl:call-template name="replace">
      <xsl:with-param name="s" select="$tex"/>
      <xsl:with-param name="from" select="$LMARK"/>
      <xsl:with-param name="to" select="'\LaTeX{}'"/>
    </xsl:call-template>
  </xsl:variable>
  <!-- \cpp ends in \xspace, so it wants no trailing {} -->
  <xsl:call-template name="replace">
    <xsl:with-param name="s" select="$latex"/>
    <xsl:with-param name="from" select="'C++'"/>
    <xsl:with-param name="to" select="'\cpp'"/>
  </xsl:call-template>
</xsl:template>

<!-- Dropping a comment out of mixed content leaves the indentation on either
     side of it behind, which lands as a whitespace-only line, which TeX reads
     as \par.  This is cleanup_latex.pl's `next if /^\s*$/`, kept so the .tex
     still breaks on the same lines the source does: LaTeX reports errors by
     line number, and one giant line per section makes that useless. -->
<xsl:template name="drop-blank-lines">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="contains($s, '&#10;')">
      <xsl:variable name="line" select="substring-before($s, '&#10;')"/>
      <xsl:if test="normalize-space($line) != ''">
        <xsl:value-of select="$line"/>
        <xsl:text>&#10;</xsl:text>
      </xsl:if>
      <xsl:call-template name="drop-blank-lines">
        <xsl:with-param name="s" select="substring-after($s, '&#10;')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$s"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- recurse once per special character found, not once per character -->
<xsl:template name="tex-escape">
  <xsl:param name="s"/>
  <xsl:variable name="marked" select="translate($s, $SPECIALS, $MARKS)"/>
  <xsl:choose>
    <xsl:when test="contains($marked, $MARK)">
      <xsl:variable name="n" select="string-length(substring-before($marked, $MARK))"/>
      <xsl:variable name="c" select="substring($s, $n + 1, 1)"/>
      <xsl:value-of select="substring($s, 1, $n)"/>
      <xsl:choose>
        <xsl:when test="$c = '\'"><xsl:text>\textbackslash{}</xsl:text></xsl:when>
        <xsl:when test="$c = '~'"><xsl:text>\textasciitilde{}</xsl:text></xsl:when>
        <xsl:when test="$c = '^'"><xsl:text>\textasciicircum{}</xsl:text></xsl:when>
        <xsl:otherwise><xsl:text>\</xsl:text><xsl:value-of select="$c"/></xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="tex-escape">
        <xsl:with-param name="s" select="substring($s, $n + 2)"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$s"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template name="replace">
  <xsl:param name="s"/>
  <xsl:param name="from"/>
  <xsl:param name="to"/>
  <xsl:choose>
    <xsl:when test="contains($s, $from)">
      <xsl:value-of select="substring-before($s, $from)"/>
      <xsl:value-of select="$to"/>
      <xsl:call-template name="replace">
        <xsl:with-param name="s" select="substring-after($s, $from)"/>
        <xsl:with-param name="from" select="$from"/>
        <xsl:with-param name="to" select="$to"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$s"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
