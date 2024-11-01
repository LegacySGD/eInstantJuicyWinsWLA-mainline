<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:variable name="test" select="/Paytable/@test"/>
	<xsl:output encoding="UTF-8" indent="yes" method="html"/>
	
	<xsl:include href="../ForceUtils.xsl"/>

	<xsl:template match="/Paytable/PaytableData/ComponentsDataMapping">
		<html>
			<head>
				<title>Force</title>
				<script type="text/javascript">
				
				<xsl:call-template name="ForceUtils.ImportJSUtils"/>
				
				<![CDATA[
				function OnWindowLoad()
				{
				
				}

				window.onload = OnWindowLoad;
				]]>
				
				</script>
			</head>
			<body>
				<form method="get" id="Force.Form">
					<table cellpadding="0" cellspacing="0" border="0" summary="">

						<xsl:call-template name="ForceUtils.CreateForceToolSection.PopulatorWithStripMapping">
							<xsl:with-param name="executionModelName" select="'BaseGame'"/>
							<xsl:with-param name="stageComponentName" select="'BaseGame.PopulateRandoms.PresesntationStrips'"/>
						</xsl:call-template>

						<tr>
						<td>Shortcuts:</td>
						<td><button type="button" onclick="ForceUtils.SetMultipleSelectedSymbolsByIdAndSubmit('BaseGame', 'Reeler8x8x8x8x8', ['s01','w09','w09','w09','s01'])">Big Win</button></td>
						</tr>
						
						<xsl:call-template name="ForceUtils.CreateForceToolSection.PopulatorWithStripMapping">
							<xsl:with-param name="executionModelName" select="'Rising'"/>
							<xsl:with-param name="stageComponentName" select="'Rising.PopulateRandoms.PresesntationStrips'"/>
						</xsl:call-template>
						
						<tr>
							<td align="left">
								<table cellpadding="4" cellspacing="0" border="0" summary="">
									<tr>
										<td>
											<input type="submit"/>
										</td>
									</tr>
								</table>
							</td>
						</tr>
						
					</table>
				</form>
			</body>
		</html>
	</xsl:template>
	
	<xsl:template match="*|@*|text()">
		<xsl:value-of select="$test"/>
		<xsl:apply-templates/>
	</xsl:template>

</xsl:stylesheet>