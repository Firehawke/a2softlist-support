<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:template match="/softwarelist">
    <xsl:for-each select="software">
        <xsl:sort select="position()" data-type="number" order="descending" />
        <xsl:copy-of select="."/>
        <xsl:text>&#xa;</xsl:text>
        <xsl:text>&#xa;</xsl:text>
    </xsl:for-each>
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>&#xa;</xsl:text>
</xsl:template>
</xsl:stylesheet>