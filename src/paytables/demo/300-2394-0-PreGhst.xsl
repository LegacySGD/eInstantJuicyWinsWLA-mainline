<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:x="anything">
	<xsl:namespace-alias stylesheet-prefix="x" result-prefix="xsl" />
	<xsl:output encoding="UTF-8" indent="yes" method="xml" />
	<xsl:include href="../utils.xsl" />

	<xsl:template match="/Paytable">
		<x:stylesheet version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			exclude-result-prefixes="java" xmlns:lxslt="http://xml.apache.org/xslt" xmlns:my-ext="ext1" extension-element-prefixes="my-ext">
			<x:import href="HTML-CCFR.xsl" />
			<x:output indent="no" method="xml" omit-xml-declaration="yes" />

			<!-- TEMPLATE Match: -->
			<x:template match="/">
				<x:apply-templates select="*" />
				<x:apply-templates select="/output/root[position()=last()]" mode="last" />
				<br />
			</x:template>

			<!--The component and its script are in the lxslt namespace and define the implementation of the extension. -->
			<lxslt:component prefix="my-ext" functions="formatJson,retrievePrizeTable,getType">
				<lxslt:script lang="javascript">
				<![CDATA[
var debugFeed = [];
var debugFlag = false;
// Format instant win JSON results.
// @param jsonContext String JSON results to parse and display.
// @param translation Set of Translations for the game.
function formatJson(jsonContext, translations, prizeTable, prizeValues, prizeNamesDesc) {
    var scenario = getScenario(jsonContext);
    var scenarioExtraGridsQty = scenario.split('|')[0].split(',').slice(0, 2);
    var scenarioMainGame = scenario.split('|')[0].split(',').slice(2).join(',');
    var scenarioExtraGrids = scenario.split('|').slice(1, -1);
    var convertedPrizeValues = (prizeValues.substring(1)).split('|').map(function (item) { return item.replace(/\t|\r|\n/gm, "") });
    var prizeNames = (prizeNamesDesc.substring(1)).split(',');

    ////////////////////
    // Parse scenario //
    ////////////////////

    const gridSizes = { iMainGame: 5, iBonus: 6, iMegabonus: 7 };

    var doBonusGrids = (scenarioExtraGridsQty[0] > 0 && scenarioExtraGrids.length == scenarioExtraGridsQty[0]);
    var doMegabonusGrids = (scenarioExtraGridsQty[1] > 0 && scenarioExtraGrids.length == scenarioExtraGridsQty[1]);

    var arrGridData = [];
    var arrAuditData = [];
    var arrGrids = [];

    function getPhasesData(A_iGridSize, A_arrGridData, A_arrAuditData) {
        var arrClusters = [];
        var arrPhaseCells = [];
        var arrPhases = [];
        var cellCol = -1;
        var cellRow = -1;
        var objCluster = {};
        var objPhase = {};

        if (A_arrAuditData != '') {
            for (var phaseIndex = 0; phaseIndex < A_arrAuditData.length; phaseIndex++) {
                objPhase = { arrGrid: [], arrClusters: [] };

                for (var colIndex = 0; colIndex < A_iGridSize; colIndex++) {
                    objPhase.arrGrid.push(A_arrGridData[colIndex].substr(0, A_iGridSize));
                }

                arrClusters = A_arrAuditData[phaseIndex].split(":");
                arrPhaseCells = [];

                for (var clusterIndex = 0; clusterIndex < arrClusters.length; clusterIndex++) {
                    objCluster = { strPrefix: '', arrCells: [] };

                    objCluster.strPrefix = arrClusters[clusterIndex][0];

                    objCluster.arrCells = arrClusters[clusterIndex].slice(1).match(new RegExp('.{1,2}', 'g')).map(function (item) { return parseInt(item, 10); });

                    objPhase.arrClusters.push(objCluster);

                    arrPhaseCells = arrPhaseCells.concat(objCluster.arrCells);
                }

                arrPhases.push(objPhase);

                arrPhaseCells.sort(function (a, b) { return b - a; });

                for (var cellIndex = 0; cellIndex < arrPhaseCells.length; cellIndex++) {
                    if (cellIndex == 0 || (cellIndex > 0 && arrPhaseCells[cellIndex] != arrPhaseCells[cellIndex - 1])) {
                        cellCol = Math.floor((arrPhaseCells[cellIndex] - 1) / A_iGridSize);
                        cellRow = (arrPhaseCells[cellIndex] - 1) % A_iGridSize;

                        if (cellCol >= 0 && cellCol < A_iGridSize) {
                            A_arrGridData[cellCol] = A_arrGridData[cellCol].substring(0, cellRow) + A_arrGridData[cellCol].substring(cellRow + 1);
                        }
                    }
                }
            }
        }

        objPhase = { arrGrid: [], arrClusters: [] };

        for (var colIndex = 0; colIndex < A_iGridSize; colIndex++) {
            objPhase.arrGrid.push(A_arrGridData[colIndex].substr(0, A_iGridSize));
        }

        arrPhases.push(objPhase);

        return arrPhases;
    }

    arrGridData = scenarioMainGame.split(":")[0].split(",");
    arrAuditData = scenarioMainGame.split(":").slice(1).join(":").split(",");

    var arrGrids = [];
    var egSize = -1;

    arrGrids.push(getPhasesData(gridSizes.iMainGame, arrGridData, arrAuditData));

    if (doBonusGrids || doMegabonusGrids) {
        egSize = (doBonusGrids) ? gridSizes.iBonus : gridSizes.iMegabonus;

        for (var extraGridIndex = 0; extraGridIndex < scenarioExtraGrids.length; extraGridIndex++) {
            arrGridData = scenarioExtraGrids[extraGridIndex].split(":")[0].split(",");
            arrAuditData = scenarioExtraGrids[extraGridIndex].split(":").slice(1).join(":").split(",");

            arrGrids.push(getPhasesData(egSize, arrGridData, arrAuditData));
        }
    }

    /////////////////////////
    // Currency formatting //
    /////////////////////////

    var bCurrSymbAtFront = false;
    var strCurrSymb = '';
    var strDecSymb = '';
    var strThouSymb = '';

    function getCurrencyInfoFromTopPrize() {
        var topPrize = convertedPrizeValues[0];
        var strPrizeAsDigits = topPrize.replace(new RegExp('[^0-9]', 'g'), '');
        var iPosFirstDigit = topPrize.indexOf(strPrizeAsDigits[0]);
        var iPosLastDigit = topPrize.lastIndexOf(strPrizeAsDigits.substr(-1));
        bCurrSymbAtFront = (iPosFirstDigit != 0);
        strCurrSymb = (bCurrSymbAtFront) ? topPrize.substr(0, iPosFirstDigit) : topPrize.substr(iPosLastDigit + 1);
        var strPrizeNoCurrency = topPrize.replace(new RegExp('[' + strCurrSymb + ']', 'g'), '');
        var strPrizeNoDigitsOrCurr = strPrizeNoCurrency.replace(new RegExp('[0-9]', 'g'), '');
        strDecSymb = strPrizeNoDigitsOrCurr.substr(-1);
        strThouSymb = (strPrizeNoDigitsOrCurr.length > 1) ? strPrizeNoDigitsOrCurr[0] : strThouSymb;
    }

    function getPrizeInCents(AA_strPrize) {
        return parseInt(AA_strPrize.replace(new RegExp('[^0-9]', 'g'), ''), 10);
    }

    function getCentsInCurr(AA_iPrize) {
        var strValue = AA_iPrize.toString();

        strValue = (strValue.length < 3) ? ('00' + strValue).substr(-3) : strValue;
        strValue = strValue.substr(0, strValue.length - 2) + strDecSymb + strValue.substr(-2);
        strValue = (strValue.length > 6) ? strValue.substr(0, strValue.length - 6) + strThouSymb + strValue.substr(-6) : strValue;
        strValue = (bCurrSymbAtFront) ? strCurrSymb + strValue : strValue + strCurrSymb;

        return strValue;
    }

    getCurrencyInfoFromTopPrize();

    ///////////////
    // UI Config //
    ///////////////

    const colourBlack = '#000000';
    const colourBlue = '#99ccff';
    const colourBrown = '#990000';
    const colourGreen = '#00cc00';
    const colourLemon = '#ffff99';
    const colourLilac = '#ccccff';
    const colourLime = '#ccff99';
    const colourNavy = '#0000ff';
    const colourOrange = '#ffcc99';
    const colourPink = '#ffccff';
    const colourPurple = '#cc99ff';
    const colourRed = '#ff9999';
    const colourScarlet = '#ff0000';
    const colourWhite = '#ffffff';
    const colourYellow = '#ffff00';

    const prizeColours = [colourRed, colourOrange, colourLemon, colourLime, colourBlue, colourLilac, colourPurple];
    const specialBoxColours = [colourBrown, colourScarlet, colourNavy, colourBlack];
    const specialTextColours = [colourYellow, colourYellow, colourYellow, colourWhite];

    const symbPrizes = 'ABCDEFG';
    const symbJackpot = 'J';
    const symbBonus = 'Y';
    const symbMegabonus = 'Z';
    const symbWild = 'W';
    const symbSpecials = symbJackpot + symbBonus + symbMegabonus + symbWild;

    const cellSize = 24;
    const cellMargin = 1;
    const cellTextX = 13;
    const cellTextY = 15;

    var r = [];

    var boxColourStr = '';
    var canvasIdStr = '';
    var elementStr = '';
    var textColourStr = '';

    function showSymb(A_strCanvasId, A_strCanvasElement, A_strBoxColour, A_strTextColour, A_strText) {
        var canvasCtxStr = 'canvasContext' + A_strCanvasElement;

        r.push('<canvas id="' + A_strCanvasId + '" width="' + (cellSize + 2 * cellMargin).toString() + '" height="' + (cellSize + 2 * cellMargin).toString() + '"></canvas>');
        r.push('<script>');
        r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
        r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
        r.push(canvasCtxStr + '.font = "bold 14px Arial";');
        r.push(canvasCtxStr + '.textAlign = "center";');
        r.push(canvasCtxStr + '.textBaseline = "middle";');
        r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellMargin + 0.5).toString() + ', ' + cellSize.toString() + ', ' + cellSize.toString() + ');');
        r.push(canvasCtxStr + '.fillStyle = "' + A_strBoxColour + '";');
        r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellMargin + 1.5).toString() + ', ' + (cellSize - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
        r.push(canvasCtxStr + '.fillStyle = "' + A_strTextColour + '";');
        r.push(canvasCtxStr + '.fillText("' + A_strText + '", ' + cellTextX.toString() + ', ' + cellTextY.toString() + ');');

        r.push('</script>');
    }

    function showGridSymbs(A_strCanvasId, A_strCanvasElement, A_arrGrid) {
        var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
        var cellX = 0;
        var cellY = 0;
        var isPrizeCell = false;
        var symbCell = '';
        var symbIndex = -1;

        var gridSize = A_arrGrid.length;
        var gridCanvasHeight = gridSize * cellSize + 2 * cellMargin;
        var gridCanvasWidth = gridSize * cellSize + 2 * cellMargin;

        r.push('<canvas id="' + A_strCanvasId + '" width="' + gridCanvasWidth.toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
        r.push('<script>');
        r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
        r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
        r.push(canvasCtxStr + '.textAlign = "center";');
        r.push(canvasCtxStr + '.textBaseline = "middle";');

        for (var gridCol = 0; gridCol < gridSize; gridCol++) {
            for (var gridRow = 0; gridRow < gridSize; gridRow++) {
                symbCell = A_arrGrid[gridCol][gridRow];
                isPrizeCell = (symbPrizes.indexOf(symbCell) != -1);
                symbIndex = (isPrizeCell) ? symbPrizes.indexOf(symbCell) : symbSpecials.indexOf(symbCell);
                boxColourStr = (isPrizeCell) ? prizeColours[symbIndex] : specialBoxColours[symbIndex];
                textColourStr = (isPrizeCell) ? colourBlack : specialTextColours[symbIndex];
                cellX = gridCol * cellSize;
                cellY = (gridSize - gridRow - 1) * cellSize;

                r.push(canvasCtxStr + '.font = "bold 14px Arial";');
                r.push(canvasCtxStr + '.strokeRect(' + (cellX + cellMargin + 0.5).toString() + ', ' + (cellY + cellMargin + 0.5).toString() + ', ' + cellSize.toString() + ', ' + cellSize.toString() + ');');
                r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
                r.push(canvasCtxStr + '.fillRect(' + (cellX + cellMargin + 1.5).toString() + ', ' + (cellY + cellMargin + 1.5).toString() + ', ' + (cellSize - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
                r.push(canvasCtxStr + '.fillStyle = "' + textColourStr + '";');
                r.push(canvasCtxStr + '.fillText("' + symbCell + '", ' + (cellX + cellTextX).toString() + ', ' + (cellY + cellTextY).toString() + ');');
            }
        }

        r.push('</script>');
    }

    function showAuditSymbs(A_strCanvasId, A_strCanvasElement, A_arrGrid, A_arrData) {
        var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
        var cellX = 0;
        var cellY = 0;
        var isClusterCell = false;
        var isPrizeCell = false;
        var isSpecialCell = false;
        var isWildCell = false;
        var symbCell = '';
        var symbIndex = -1;
        var cellNum = 0;

        var gridSize = A_arrGrid.length;
        var gridCanvasHeight = gridSize * cellSize + 2 * cellMargin;
        var gridCanvasWidth = gridSize * cellSize + 2 * cellMargin;

        r.push('<canvas id="' + A_strCanvasId + '" width="' + (gridCanvasWidth + 25).toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
        r.push('<script>');
        r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
        r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
        r.push(canvasCtxStr + '.textAlign = "center";');
        r.push(canvasCtxStr + '.textBaseline = "middle";');

        for (var gridCol = 0; gridCol < gridSize; gridCol++) {
            for (var gridRow = 0; gridRow < gridSize; gridRow++) {
                cellNum++;

                isClusterCell = (A_arrData.arrCells.indexOf(cellNum) != -1);
                isWildCell = (isClusterCell && A_arrGrid[gridCol][gridRow] == symbWild);
                isSpecialCell = (isWildCell || (isClusterCell && symbSpecials.indexOf(A_arrData.strPrefix) != -1));
                isPrizeCell = (!isSpecialCell && isClusterCell && symbPrizes.indexOf(A_arrData.strPrefix) != -1);
                symbIndex = (isPrizeCell) ? symbPrizes.indexOf(A_arrData.strPrefix) : ((isSpecialCell) ? ((isWildCell) ? symbSpecials.indexOf(symbWild) : symbSpecials.indexOf(A_arrData.strPrefix)) : -1);
                boxColourStr = (isPrizeCell) ? prizeColours[symbIndex] : ((isSpecialCell) ? specialBoxColours[symbIndex] : colourWhite);
                textColourStr = (isSpecialCell) ? specialTextColours[symbIndex] : colourBlack;
                cellX = gridCol * cellSize;
                cellY = (gridSize - gridRow - 1) * cellSize;
                symbCell = ('0' + cellNum).slice(-2);

                r.push(canvasCtxStr + '.font = "bold 14px Arial";');
                r.push(canvasCtxStr + '.strokeRect(' + (cellX + cellMargin + 0.5).toString() + ', ' + (cellY + cellMargin + 0.5).toString() + ', ' + cellSize.toString() + ', ' + cellSize.toString() + ');');
                r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
                r.push(canvasCtxStr + '.fillRect(' + (cellX + cellMargin + 1.5).toString() + ', ' + (cellY + cellMargin + 1.5).toString() + ', ' + (cellSize - 2).toString() + ', ' + (cellSize - 2).toString() + ');');
                r.push(canvasCtxStr + '.fillStyle = "' + textColourStr + '";');
                r.push(canvasCtxStr + '.fillText("' + symbCell + '", ' + (cellX + cellTextX).toString() + ', ' + (cellY + cellTextY).toString() + ');');
            }
        }

        r.push('</script>');
    }

    ///////////////////////
    // Prize Symbols Key //
    ///////////////////////

    var symbDesc = '';
    var symbPrize = '';
    var symbSpecial = '';

    r.push('<div style="float:left; margin-right:50px">');
    r.push('<p>' + getTranslationByName("titlePrizeSymbolsKey", translations) + '</p>');

    r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
    r.push('<tr class="tablehead">');
    r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
    r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
    r.push('</tr>');

    for (var prizeIndex = 0; prizeIndex < symbPrizes.length; prizeIndex++) {
        symbPrize = symbPrizes[prizeIndex];
        canvasIdStr = 'cvsKeySymb' + symbPrize;
        elementStr = 'eleKeySymb' + symbPrize;
        boxColourStr = prizeColours[prizeIndex];
        symbDesc = 'symb' + symbPrize;

        r.push('<tr class="tablebody">');
        r.push('<td align="center">');

        showSymb(canvasIdStr, elementStr, boxColourStr, colourBlack, symbPrize);

        r.push('</td>');
        r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
        r.push('</tr>');
    }

    r.push('</table>');
    r.push('</div>');

    /////////////////////////
    // Special Symbols Key //
    /////////////////////////

    r.push('<div style="float:left">');
    r.push('<p>' + getTranslationByName("titleSpecialSymbolsKey", translations) + '</p>');

    r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
    r.push('<tr class="tablehead">');
    r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
    r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
    r.push('</tr>');

    for (var specialIndex = 0; specialIndex < symbSpecials.length; specialIndex++) {
        symbSpecial = symbSpecials[specialIndex];
        canvasIdStr = 'cvsKeySymb' + symbSpecial;
        elementStr = 'eleKeySymb' + symbSpecial;
        boxColourStr = specialBoxColours[specialIndex];
        textColourStr = specialTextColours[specialIndex];
        symbDesc = 'symb' + symbSpecial;

        r.push('<tr class="tablebody">');
        r.push('<td align="center">');

        showSymb(canvasIdStr, elementStr, boxColourStr, textColourStr, symbSpecial);

        r.push('</td>');
        r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
        r.push('</tr>');
    }

    r.push('</table>');
    r.push('</div>');

    r.push('<div style="clear:both">');

    ///////////
    // Grids //
    ///////////

    const bonusTriggerQty = 3;
    const jackpotWinQty = 5;
    const symbTokens = symbBonus + symbMegabonus;
    const gridMultis = { arrMainGame: [1, 1, 1, 2, 3, 5], arrBonus: [1, 1, 2, 3, 5, 10], arrMegabonus: [1, 2, 3, 5, 10, 25] };

    var clusterIndex = -1;
    var clusterQty = 0;
    var countText = 0;
    var gridMulti = 0;
    var gridStr = '';
    var gridWin = 0;
    var isCluster = false;
    var isJackpot = false;
    var isJackpotWin = false;
    var isMainGrid = false;
    var jackpotQty = 0;
    var phaseStr = '';
    var prefixIndex = -1;
    var prizeCount = 0;
    var prizeStr = '';
    var prizeText = '';
    var symbCount = '';
    var totalStr = '';
    var triggerText = '';

    var bonusTitle = (doBonusGrids) ? 'bonusGrid' : 'megabonusGrid';
    var triggerStr = (doBonusGrids) ? 'bonusGame' : 'megabonusGame';

    for (var gridIndex = 0; gridIndex < arrGrids.length; gridIndex++) {
        isMainGrid = (gridIndex == 0);
        jackpotQty = 0;
        gridWin = 0;
        clusterQty = 0;
        gridStr = (isMainGrid) ? getTranslationByName("mainGrid", translations) : (getTranslationByName(bonusTitle, translations) + ' ' + gridIndex.toString());

        r.push('<p><br>' + gridStr.toUpperCase() + '</p>');

        r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

        for (var phaseIndex = 0; phaseIndex < arrGrids[gridIndex].length; phaseIndex++) {
            //////////////////////////
            // Main Game Phase Info //
            //////////////////////////

            phaseStr = getTranslationByName("phaseNum", translations) + ' ' + (phaseIndex + 1).toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' + arrGrids[gridIndex].length.toString();

            r.push('<tr class="tablebody">');
            r.push('<td valign="top">' + phaseStr + '</td>');

            ////////////////////
            // Main Game Grid //
            ////////////////////

            canvasIdStr = 'cvsGrid' + gridIndex.toString() + '_' + phaseIndex.toString();
            elementStr = 'eleGrid' + gridIndex.toString() + '_' + phaseIndex.toString();

            r.push('<td style="padding-left:50px; padding-right:50px; padding-bottom:25px">');

            showGridSymbs(canvasIdStr, elementStr, arrGrids[gridIndex][phaseIndex].arrGrid);

            r.push('</td>');

            /////////////////////////////////////////
            // Main Game Clusters or trigger cells //
            /////////////////////////////////////////

            r.push('<td style="padding-right:50px; padding-bottom:25px">');

            for (var clusterIndex = 0; clusterIndex < arrGrids[gridIndex][phaseIndex].arrClusters.length; clusterIndex++) {
                canvasIdStr = 'cvsAudit' + gridIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString();
                elementStr = 'eleAudit' + gridIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString();

                showAuditSymbs(canvasIdStr, elementStr, arrGrids[gridIndex][phaseIndex].arrGrid, arrGrids[gridIndex][phaseIndex].arrClusters[clusterIndex]);
            }

            r.push('</td>');

            //////////////////////////////////////
            // Main Game Prizes or trigger text //
            //////////////////////////////////////

            r.push('<td valign="top" style="padding-bottom:25px">');

            if (arrGrids[gridIndex][phaseIndex].arrClusters.length > 0) {
                r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

                for (var clusterIndex = 0; clusterIndex < arrGrids[gridIndex][phaseIndex].arrClusters.length; clusterIndex++) {
                    symbPrize = arrGrids[gridIndex][phaseIndex].arrClusters[clusterIndex].strPrefix;
                    isCluster = (symbPrizes.indexOf(symbPrize) != -1);
                    isJackpot = (symbSpecials.indexOf(symbPrize) != -1);
                    canvasIdStr = 'cvsClusterPrize' + gridIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString() + symbPrize;
                    elementStr = 'eleClusterPrize' + gridIndex.toString() + '_' + phaseIndex.toString() + '_' + clusterIndex.toString() + symbPrize;
                    prefixIndex = (isCluster) ? symbPrizes.indexOf(symbPrize) : symbSpecials.indexOf(symbPrize);
                    boxColourStr = (isCluster) ? prizeColours[prefixIndex] : specialBoxColours[prefixIndex];
                    textColourStr = (isCluster) ? colourBlack : specialTextColours[prefixIndex];
                    prizeCount = arrGrids[gridIndex][phaseIndex].arrClusters[clusterIndex].arrCells.length;
                    countText = prizeCount.toString() + ' x';
                    prizeText = symbPrize + prizeCount.toString();

                    if (isCluster) {
                        gridWin += getPrizeInCents(convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)]);
                        clusterQty++;
                    }

                    if (isJackpot) {
                        jackpotQty += prizeCount;
                        isJackpotWin = (jackpotQty == jackpotWinQty);
                    }

                    prizeStr = (isCluster) ? '= ' + convertedPrizeValues[getPrizeNameIndex(prizeNames, prizeText)] : ((isJackpotWin) ? '= ' + getTranslationByName("jackpot", translations) :
                        ': ' + getTranslationByName("collected", translations) + ' ' + jackpotQty.toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' +
                        jackpotWinQty.toString());

                    r.push('<tr class="tablebody">');
                    r.push('<td align="right">' + countText + '</td>');
                    r.push('<td align="center">');

                    showSymb(canvasIdStr, elementStr, boxColourStr, textColourStr, symbPrize);

                    r.push('</td>');
                    r.push('<td>' + prizeStr + '</td>');
                    r.push('</tr>');
                }

                r.push('</table>');
            }
            else {
                r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

                for (var symbIndex = 0; symbIndex < symbTokens.length; symbIndex++) {
                    symbCount = arrGrids[gridIndex][phaseIndex].arrGrid.join('').replace(new RegExp('[^' + symbTokens[symbIndex] + ']', 'g'), '').length;

                    if (symbCount > 0) {
                        canvasIdStr = 'cvsTokens' + gridIndex.toString() + '_' + phaseIndex.toString() + '_' + symbIndex.toString();
                        elementStr = 'eleTokens' + gridIndex.toString() + '_' + phaseIndex.toString() + '_' + symbIndex.toString();
                        prefixIndex = symbSpecials.indexOf(symbTokens[symbIndex]);
                        boxColourStr = specialBoxColours[prefixIndex];
                        textColourStr = specialTextColours[prefixIndex];
                        countText = symbCount.toString() + ' x';
                        triggerText = (symbCount == bonusTriggerQty) ? ' : ' + getTranslationByName(triggerStr, translations) + ' ' + getTranslationByName("triggered", translations) : '';

                        prizeStr = ': ' + getTranslationByName("collected", translations) + ' ' + symbCount.toString() + ' ' + getTranslationByName("phaseOf", translations) + ' ' +
                            bonusTriggerQty.toString() + triggerText;

                        r.push('<tr class="tablebody">');
                        r.push('<td align="right">' + countText + '</td>');
                        r.push('<td align="center">');

                        showSymb(canvasIdStr, elementStr, boxColourStr, textColourStr, symbTokens[symbIndex]);

                        r.push('</td>');
                        r.push('<td>' + prizeStr + '</td>');
                        r.push('</tr>');
                    }
                }

                r.push('</table>');

                if (gridWin > 0) {
                    r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

                    prizeStr = getCentsInCurr(gridWin);
                    clusterIndex = Math.min(6, clusterQty) - 1;
                    gridMulti = (isMainGrid) ? gridMultis.arrMainGame[clusterIndex] : ((doBonusGrids) ? gridMultis.arrBonus[clusterIndex] : gridMultis.arrMegabonus[clusterIndex]);
                    totalStr = getCentsInCurr(gridWin * gridMulti);

                    r.push('<tr class="tablebody">');
                    r.push('<td>' + getTranslationByName("gridWin", translations) + ' : ' + prizeStr + ' x ' + gridMulti.toString() + ' = ' + totalStr + '</td>');
                    r.push('</tr>');

                    r.push('</table>');
                }
            }

            r.push('</td>');
            r.push('</tr>');
        }

        r.push('</table>');
    }

    r.push('<p>&nbsp;</p>');

						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						// !DEBUG OUTPUT TABLE
						if(debugFlag)
						{
							// DEBUG TABLE
							//////////////////////////////////////
							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							for(var idx = 0; idx < debugFeed.length; ++idx)
	 						{
								if(debugFeed[idx] == "")
									continue;
								r.push('<tr>');
 								r.push('<td class="tablebody">');
								r.push(debugFeed[idx]);
 								r.push('</td>');
 								r.push('</tr>');
							}
							r.push('</table>');
						}
						return r.join('');
					}

					function getScenario(jsonContext)
					{
						var jsObj = JSON.parse(jsonContext);
						var scenario = jsObj.scenario;

						scenario = scenario.replace(/\0/g, '');

						return scenario;
					}

					// Input: A list of Price Points and the available Prize Structures for the game as well as the wagered price point
					// Output: A string of the specific prize structure for the wagered price point
					function retrievePrizeTable(pricePoints, prizeStructures, wageredPricePoint)
					{
						var pricePointList = pricePoints.split(",");
						var prizeStructStrings = prizeStructures.split("|");

						for(var i = 0; i < pricePoints.length; ++i)
						{
							if(wageredPricePoint == pricePointList[i])
							{
								return prizeStructStrings[i];
							}
						}
						return "";
					}

					// Input: Json document string containing 'amount' at root level.
					// Output: Price Point value.
					function getPricePoint(jsonContext)
					{
						// Parse json and retrieve price point amount
						var jsObj = JSON.parse(jsonContext);
						var pricePoint = jsObj.amount;
						return pricePoint;
					}

					// Input: "A,B,C,D,..." and "A"
					// Output: index number
					function getPrizeNameIndex(prizeNames, currPrize)
					{
						for(var i = 0; i < prizeNames.length; ++i)
						{
							if(prizeNames[i] == currPrize)
							{
								return i;
							}
						}
					}

					////////////////////////////////////////////////////////////////////////////////////////
					function registerDebugText(debugText)
					{
						debugFeed.push(debugText);
					}

					/////////////////////////////////////////////////////////////////////////////////////////
					function getTranslationByName(keyName, translationNodeSet)
					{
						var index = 1;
						while(index < translationNodeSet.item(0).getChildNodes().getLength())
						{
							var childNode = translationNodeSet.item(0).getChildNodes().item(index);
							
							if(childNode.name == "phrase" && childNode.getAttribute("key") == keyName)
							{
								registerDebugText("Child Node: " + childNode.name);
								return childNode.getAttribute("value");
							}
							
							index += 1;
						}
					}

					// Grab Wager Type
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function getType(jsonContext, translations)
					{
						// Parse json and retrieve wagerType string.
						var jsObj = JSON.parse(jsonContext);
						var wagerType = jsObj.wagerType;

						return getTranslationByName(wagerType, translations);
					}
				]]>
				</lxslt:script>
			</lxslt:component>

			<x:template match="root" mode="last">
				<table border="0" cellpadding="1" cellspacing="1" width="100%" class="gameDetailsTable">
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWager']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/WagerOutcome[@name='Game.Total']/@amount" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWins']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="SignedData/Data/Outcome/ResultData/PrizeOutcome[@name='Game.Total']/@totalPay" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
				</table>
			</x:template>

			<!-- TEMPLATE Match: digested/game -->
			<x:template match="//Outcome">
				<x:if test="OutcomeDetail/Stage = 'Scenario'">
					<x:call-template name="Scenario.Detail" />
				</x:if>
			</x:template>

			<!-- TEMPLATE Name: Scenario.Detail (base game) -->
			<x:template name="Scenario.Detail">
				<x:variable name="odeResponseJson" select="string(//ResultData/JSONOutcome[@name='ODEResponse']/text())" />
				<x:variable name="translations" select="lxslt:nodeset(//translation)" />
				<x:variable name="wageredPricePoint" select="string(//ResultData/WagerOutcome[@name='Game.Total']/@amount)" />
				<x:variable name="prizeTable" select="lxslt:nodeset(//lottery)" />

				<table border="0" cellpadding="0" cellspacing="0" width="100%" class="gameDetailsTable">
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='wagerType']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="my-ext:getType($odeResponseJson, $translations)" disable-output-escaping="yes" />
						</td>
					</tr>
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='transactionId']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="OutcomeDetail/RngTxnId" />
						</td>
					</tr>
				</table>
				<br />			

				<x:variable name="convertedPrizeValues">
					<x:apply-templates select="//lottery/prizetable/prize" mode="PrizeValue"/>
				</x:variable>				
				<x:variable name="prizeNames">
					<x:apply-templates select="//lottery/prizetable/description" mode="PrizeDescriptions"/>
				</x:variable>


				<x:value-of select="my-ext:formatJson($odeResponseJson, $translations, $prizeTable, string($convertedPrizeValues), string($prizeNames))" disable-output-escaping="yes" />
			</x:template>

			<x:template match="prize" mode="PrizeValue">
					<x:text>|</x:text>
					<x:call-template name="Utils.ApplyConversionByLocale">
						<x:with-param name="multi" select="/output/denom/percredit" />
						<x:with-param name="value" select="text()" />
						<x:with-param name="code" select="/output/denom/currencycode" />
						<x:with-param name="locale" select="//translation/@language" />
					</x:call-template>
			</x:template>
			<x:template match="description" mode="PrizeDescriptions">
				<x:text>,</x:text>
				<x:value-of select="text()" />
			</x:template>

			<x:template match="text()" />
		</x:stylesheet>
	</xsl:template>

	<xsl:template name="TemplatesForResultXSL">
		<x:template match="@aClickCount">
			<clickcount>
				<x:value-of select="." />
			</clickcount>
		</x:template>
		<x:template match="*|@*|text()">
			<x:apply-templates />
		</x:template>
	</xsl:template>
</xsl:stylesheet>
