<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet exclude-result-prefixes="java" version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output indent="no" method="xml" omit-xml-declaration="yes"/>
	<xsl:template match="/">
		<xsl:apply-templates mode="last" select="//Outcome/ResultData[position()=last()]"/>
	</xsl:template>
	<xsl:template match="ResultData" mode="last">
		<xsl:value-of select="PrizeOutcome[@name='Game.Total']/@totalPay"/>
	</xsl:template>
</xsl:stylesheet>