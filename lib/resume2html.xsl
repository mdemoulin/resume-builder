<?xml version="1.0" encoding="UTF-8"?>
<!--
    Copyright (C) 2026 Michael A. Demoulin
    SPDX-License-Identifier: GPL-3.0-or-later

    resume2html.xsl - render resume.xml as HTML

    Replaces the old nsgmls | sgmlspl resume2html.pl | cleanup_html.pl
    pipeline.  The cleanup pass is gone: the <abbr>/mailto rewrites and the
    emit-a-comment-then-strip-it trick used for phone suppression are handled
    here directly.

    Parameters (set by the Makefile from lib/params, see set-conf.pl -v):
        twophones  1 = list both phone numbers, labelled; 0 = first only
        totxt      1 = plain-text run (no mailto: link), for the lynx dump
        extra      1 = include <extra> content; 0 = omit it
        expandabbrevs  1 = follow an abbreviation with its definition
                   in parentheses; 0 = give the abbreviation alone
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="html" indent="no"/>

<!-- element content is whitespace-insensitive; mixed content is not -->
<xsl:strip-space elements="*"/>
<xsl:preserve-space elements="description extra item"/>

<xsl:param name="twophones">0</xsl:param>
<xsl:param name="totxt">0</xsl:param>
<xsl:param name="extra">0</xsl:param>
<xsl:param name="expandabbrevs">0</xsl:param>
<!-- 1 = emit the supervisor and hours a federal resume is rated against -->
<xsl:param name="federal">0</xsl:param>


<xsl:template match="resume">
  <html>
    <head><title>The resume of <xsl:value-of select="/resume/author/name"/></title></head>
    <xsl:text>&#10;</xsl:text>
    <body>
      <xsl:text>&#10;</xsl:text>
      <xsl:apply-templates select="author | section[not(@federal) or @federal = $federal]"/>
    </body>
  </html>
  <xsl:text>&#10;</xsl:text>
</xsl:template>


<!-- ===== author block ================================================ -->

<xsl:template match="author">
  <xsl:apply-templates select="name"/>
  <ul>
    <xsl:apply-templates select="address"/>
    <xsl:apply-templates select="email"/>
    <xsl:apply-templates select="phone"/>
    <xsl:text>&#9;</xsl:text>
  </ul>
  <xsl:text>&#10;</xsl:text>
</xsl:template>

<xsl:template match="name">
  <h1><xsl:value-of select="."/></h1>
  <xsl:text>&#10;</xsl:text>
</xsl:template>

<xsl:template match="address">
  <li>
    <!-- street is federal-only: a resume behind a public link does not
         hand out a home address, but an application form wants one -->
    <xsl:if test="street and $federal = '1'">
      <xsl:value-of select="street"/>
      <xsl:text>, </xsl:text>
    </xsl:if>
    <xsl:value-of select="city"/>
    <xsl:text>, </xsl:text>
    <xsl:value-of select="state"/>
    <xsl:if test="zip">
      <xsl:text> </xsl:text>
      <xsl:value-of select="zip"/>
    </xsl:if>
  </li>
  <xsl:text>&#10;</xsl:text>
</xsl:template>

<xsl:template match="email">
  <xsl:text>&#9;</xsl:text>
  <li><kbd>
    <xsl:choose>
      <xsl:when test="$totxt = '1'">
        <xsl:value-of select="."/>
      </xsl:when>
      <xsl:otherwise>
        <a href="mailto:{normalize-space(.)}"><xsl:value-of select="."/></a>
      </xsl:otherwise>
    </xsl:choose>
  </kbd></li>
  <xsl:text>&#10;</xsl:text>
</xsl:template>

<!-- with twophones off, every number after the first is dropped -->
<xsl:template match="phone">
  <xsl:variable name="first" select="count(preceding-sibling::phone) = 0"/>
  <xsl:choose>
    <xsl:when test="$twophones = '1'">
      <xsl:text>&#9;</xsl:text>
      <li>
        <xsl:choose>
          <xsl:when test="$first"><xsl:text>Home: </xsl:text></xsl:when>
          <xsl:otherwise><xsl:text>Cell: </xsl:text></xsl:otherwise>
        </xsl:choose>
        <xsl:value-of select="number"/>
      </li>
      <xsl:text>&#10;</xsl:text>
    </xsl:when>
    <xsl:when test="$first">
      <xsl:text>&#9;</xsl:text>
      <li><xsl:value-of select="number"/></li>
      <xsl:text>&#10;</xsl:text>
    </xsl:when>
  </xsl:choose>
</xsl:template>


<!-- ===== sections ==================================================== -->

<xsl:template match="section">
  <h2><xsl:value-of select="heading"/></h2>
  <xsl:text>&#10;</xsl:text>
  <xsl:apply-templates select="*[not(self::heading)][not(@extra = '1') or $extra = '1'][not(@federal) or @federal = $federal]"/>
</xsl:template>

<xsl:template match="subsection">
  <h3><xsl:value-of select="heading"/></h3>
  <xsl:text>&#10;</xsl:text>
  <xsl:apply-templates select="description"/>
</xsl:template>

<xsl:template match="jobsubsection">
  <xsl:apply-templates select="jobheader"/>
  <xsl:apply-templates select="description"/>
</xsl:template>

<xsl:template match="jobheader">
  <h3>
    <xsl:value-of select="title"/><br/><xsl:text>&#10;</xsl:text>
    <xsl:value-of select="company"/><br/><xsl:text>&#10;</xsl:text>
    <xsl:value-of select="daterange/from"/>
    <xsl:text> - </xsl:text>
    <xsl:value-of select="daterange/to"/>
  </h3>
  <xsl:text>&#10;</xsl:text>
  <xsl:if test="$federal = '1' and (location | hours | salary | supervisor | reason)">
    <p class="jobfacts">
      <xsl:if test="location">
        <xsl:if test="location/street">
          <xsl:value-of select="location/street"/>
          <xsl:text>, </xsl:text>
        </xsl:if>
        <xsl:value-of select="location/city"/>
        <xsl:text>, </xsl:text>
        <xsl:value-of select="location/state"/>
        <xsl:text>.</xsl:text>
      </xsl:if>
      <xsl:if test="hours">
        <xsl:if test="location"><xsl:text>  </xsl:text></xsl:if>
        <xsl:text>Hours per week: </xsl:text>
        <xsl:value-of select="hours"/>
        <xsl:text>.</xsl:text>
      </xsl:if>
      <xsl:if test="salary">
        <xsl:if test="location | hours"><xsl:text>  </xsl:text></xsl:if>
        <xsl:text>Salary: </xsl:text>
        <xsl:value-of select="salary"/>
        <xsl:text>.</xsl:text>
      </xsl:if>
      <xsl:if test="supervisor">
        <xsl:if test="location | hours | salary"><xsl:text>  </xsl:text></xsl:if>
        <xsl:text>Supervisor: </xsl:text>
        <xsl:value-of select="supervisor/name"/>
        <xsl:if test="supervisor/title">
          <xsl:text> (</xsl:text>
          <xsl:value-of select="supervisor/title"/>
          <xsl:text>)</xsl:text>
        </xsl:if>
        <xsl:if test="supervisor/number">
          <xsl:text>, </xsl:text>
          <xsl:value-of select="supervisor/number"/>
        </xsl:if>
        <xsl:if test="supervisor/@maycontact">
          <xsl:text>, may contact: </xsl:text>
          <xsl:value-of select="supervisor/@maycontact"/>
        </xsl:if>
        <xsl:text>.</xsl:text>
      </xsl:if>
      <xsl:if test="reason">
        <xsl:if test="location | hours | salary | supervisor"><xsl:text>  </xsl:text></xsl:if>
        <xsl:text>Reason for leaving: </xsl:text>
        <xsl:value-of select="reason"/>
        <xsl:text>.</xsl:text>
      </xsl:if>
    </p>
    <xsl:text>&#10;</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="description">
  <p><xsl:apply-templates/></p>
  <xsl:text>&#10;</xsl:text>
</xsl:template>


<!-- ===== inline content ============================================== -->

<xsl:template match="extra">
  <xsl:if test="$extra = '1'"><xsl:apply-templates/></xsl:if>
</xsl:template>

<xsl:template match="list">
  <ul><xsl:apply-templates/></ul>
</xsl:template>

<xsl:template match="item">
  <li><xsl:apply-templates/></li>
</xsl:template>

<xsl:template match="abbrev">
  <abbr title="{normalize-space(defn)}"><xsl:value-of select="word"/></abbr>
  <xsl:if test="$expandabbrevs = '1'">
    <xsl:text> (</xsl:text>
    <xsl:value-of select="normalize-space(defn)"/>
    <xsl:text>)</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="command">
  <kbd><xsl:apply-templates/></kbd>
</xsl:template>

<!-- same element as a command, with a class so a stylesheet can tell the
     two apart; nothing styles it today -->
<xsl:template match="server">
  <kbd class="server"><xsl:apply-templates/></kbd>
</xsl:template>

<xsl:template match="emph">
  <strong><xsl:apply-templates/></strong>
</xsl:template>

<!-- acronyms are unmarked in HTML -->
<xsl:template match="acronym">
  <xsl:apply-templates/>
</xsl:template>

</xsl:stylesheet>
