<?xml version='1.0' ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="/">
		<PaytableResponse>
			<PaytableStatistics>
				<xsl:attribute name="name">
					<xsl:value-of select="//PaytableVariation/Variation/PaytableStatistics/@name"/>
				</xsl:attribute>
				<xsl:attribute name="type">
					<xsl:value-of select="//PaytableVariation/Variation/PaytableStatistics/@type"/>
				</xsl:attribute>
				<xsl:attribute name="maxRTP">
					<xsl:value-of select="//PaytableVariation/Variation/PaytableStatistics/@maxRTP"/>
				</xsl:attribute>
				<xsl:attribute name="minRTP">
					<xsl:value-of select="//PaytableVariation/Variation/PaytableStatistics/@minRTP"/>
				</xsl:attribute>
				<xsl:attribute name="description">
					<xsl:value-of select="//PaytableVariation/Variation/PaytableStatistics/@description"/>
				</xsl:attribute>
			</PaytableStatistics>
			<xsl:apply-templates select="//PrizeInfo[@name='PrizeInfoLines']" mode="PrizeInfo"/>
			<xsl:apply-templates select="//PrizeInfo[@name='PrizeInfoScatter']" mode="PrizeInfo"/>
			<xsl:apply-templates select="//StripInfo[@name='BaseGame']" mode="StripInfo"/>
<!-- 			<xsl:apply-templates select="//StripInfo[@name='FreeSpin']" mode="StripInfo"/> -->
			<PatternSliderInfo>
				<xsl:apply-templates select="//PatternSliderInfo" mode="PatternSliderInfo"/>
			</PatternSliderInfo>
			<xsl:apply-templates select="//AwardCapInfo" mode="AwardCapInfo"/>
			<xsl:apply-templates select="//GameData" mode="GameData"/>
			<xsl:apply-templates select="//FreeSpinInfo[@name='BaseGame.FreeSpinInfo']" mode="FreeSpinInfo"/>
		</PaytableResponse>
	</xsl:template>
	
	<xsl:template match="FreeSpinInfo" mode="FreeSpinInfo">
		<xsl:copy-of select="parent::node()/FreeSpinInfo"/>
	</xsl:template>

	<xsl:template match="PrizeInfo" mode="PrizeInfo">
		<xsl:copy-of select="parent::node()/PrizeInfo"/>
	</xsl:template>
		
	<xsl:template match="PatternSliderInfo" mode="PatternSliderInfo">
			<xsl:copy-of select="parent::node()/PatternSliderInfo/PatternInfo"/>
	</xsl:template>
	
	<xsl:template match="StripInfo" mode="StripInfo">
		<xsl:copy-of select="parent::node()/StripInfo"/>
	</xsl:template>
	
	<xsl:template match="AwardCapInfo" mode="AwardCapInfo">
		<xsl:copy-of select="parent::node()/AwardCapInfo"/>
	</xsl:template>
	
	<xsl:template match="GameData" mode="GameData">
		<xsl:copy-of select="parent::node()/GameData"/>
	</xsl:template>
	
</xsl:stylesheet>
