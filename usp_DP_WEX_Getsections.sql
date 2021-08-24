USE [DP_PIM]
GO
/****** Object:  StoredProcedure [dbo].[usp_DP_WEX_Getsections_DEV]    Script Date: 19.08.2021 12:44:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[usp_DP_WEX_Getsections] (	
	@pSection VARCHAR(100)	
	)	
AS
BEGIN

/***************************************************************************************
*
*	Description: Retrieve Data for WEX Interface by giving certain Section 
*	
*	Author: ARI Advellence
*	Createdate: 22.06.2021
*
*	Parameter:  @pSection Defines which section need to be exported
*
*
*	Possible Sections:
*						DimensionsGlobal
*						DimensionsNAFTA
*						MainImages
*						Description
*						Features
*						Operations
*						Applications
*						CuttingConditions
*						PayloadVariant
*						PayloadPsf
*

Execution:
exec [dbo].[usp_DP_WEX_Getsections]	@pSection = 'DimensionsGlobal'
exec [dbo].[usp_DP_WEX_Getsections]	@pSection = 'DimensionsNAFTA'
exec [dbo].[usp_DP_WEX_Getsections]	@pSection = 'MainImages'
exec [dbo].[usp_DP_WEX_Getsections]	@pSection = 'Description'
exec [dbo].[usp_DP_WEX_Getsections]	@pSection = 'Features'
exec [dbo].[usp_DP_WEX_Getsections]	@pSection = 'Operations'
exec [dbo].[usp_DP_WEX_Getsections]	@pSection = 'Applications'


*
*	ChangeLog:  29.06.2021	Remove Conspath
*				29.06.2021	Add new Column Icon_DiCTid for Features 
*				05.07.2021	Add CuttingConditions
*				05.07.2021	Add PayloadVariant
*				05.07.2021	Add PayloadPsf
*				06.07.2021	Add Change Line in Applications
*				15.07.2021	Fix Dict Error
*				16.07.2021	Remove Null values for description -- AND val.PRATVALUE is not null 
*				16.07.2021	Moved Brand Logo from Dimensions to MainImages
*				16.07.2021	Added missing Images cat and remove renaming fpr 2D and 3D
*				19.07.2021	Add ICON_ID to Applications and Operations
*				19.07.2021	Add GRA_CoatingName_DICT_SEL to features
*				19.07.2021	Fix Bug PayloadPsf
*				19.07.2021	Bug fix on CuttingConditions
*				20.07.2021	Change Material id for MainImages
****************************************************************************************/
--DECLARE @pSection  VARCHAR(100) = 'MainImages'


DECLARE @consPath VARCHAR(50) = '';
DECLARE @servername Varchar(100)


IF OBJECT_ID('tempdb..#Hierarchy') IS NOT NULL
		BEGIN
			DROP TABLE #Hierarchy			
		END

	BEGIN
		CREATE TABLE #Hierarchy (
			IDX INT identity
			,VARIANT_ID INT
			,VARIANT_NAME VARCHAR(1000)
			,PRODUCT_ID INT
			,PRODUCT_NAME VARCHAR(1000)
			,PATHLEVEL INT
			,HIEPATH VARCHAR(1000)
			,[HIERARCHYID] INT
			,IDPATH VARCHAR(1000)
			,PGR_SEQORDER INT
			,PRODUCT_SEQORDER INT
			,VARIANT_SEQORDER INT
			,PRODUCT_ITEMNUMBER VARCHAR(50)
			,CHANGEDATE DATETIME
			,ISFILTER INT
			,REF_PRODUCT_ID INT
			,REF_VARIANT_ID INT
			)
		CREATE NONCLUSTERED INDEX ix_tempNCIndexBef ON #Hierarchy ([REF_VARIANT_ID],REF_PRODUCT_ID)
	END;

	WITH cte (
		PRODUCTGROUP_ID
		,PRODUCTGROUP_LEVEL
		,PRODUCTGROUP_SHORTCUT
		,PRODUCTGROUP_NAME
		,PARENT_PRODUCTGROUP_ID
		,HIEPATH
		,IDPATH
		)
	AS (
		SELECT t.PRODUCTGROUP_ID
			,t.PRODUCTGROUP_LEVEL
			,t.PRODUCTGROUP_SHORTCUT
			,t.PRODUCTGROUP_NAME
			,t.PARENT_PRODUCTGROUP_ID
			,CAST(PRODUCTGROUP_NAME AS VARCHAR(1024)) AS HIEPATH
			,CAST(PRODUCTGROUP_ID AS VARCHAR(1024)) AS IDPATH
		FROM [VW_PRODUCTGROUP_HIERARCHY] t
		WHERE productgroup_id = 369   ----> Inserts Negative CNMG
		
		UNION ALL
		
		SELECT t.PRODUCTGROUP_ID
			,t.PRODUCTGROUP_LEVEL
			,t.PRODUCTGROUP_SHORTCUT
			,t.PRODUCTGROUP_NAME
			,t.PARENT_PRODUCTGROUP_ID
			,CAST(cte.HIEPATH + '->' + CAST(t.PRODUCTGROUP_NAME AS VARCHAR(1024)) AS VARCHAR(1024)) AS HIEPATH
			,CAST(cte.IDPATH + ' ' + CAST(t.PRODUCTGROUP_ID AS VARCHAR(1024)) AS VARCHAR(1024)) AS IDPATH
		FROM [VW_PRODUCTGROUP_HIERARCHY] t
		INNER JOIN cte ON cte.PRODUCTGROUP_ID = t.PARENT_PRODUCTGROUP_ID
		)
		INSERT INTO #Hierarchy	 
		SELECT h.PRODUCTVARIANT_ID
			,h.PRODUCTVARIANT_NAME
			,h.PRODUCT_ID
			,h.PRODUCT_NAME
			,cte.PRODUCTGROUP_LEVEL AS PATHLEVEL
			,cte.HIEPATH
			,cte.PRODUCTGROUP_ID AS [HIERARCHYID]
			,IDPATH
			,h.PRODUCTGROUP_SEQORDERNR
			,h.PRODUCT_SEQORDERNR
			,h.PRODUCTVARIANT_SEQORDERNR
			,ch.PRODUCT_ORDERNR
			,ch.CHANGE_DATE
			,0 AS ISFILTER
			,h.REF_PRODUCT_ID
			,h.REF_PRODUCTVARIANT_ID
	FROM cte as cte
	INNER JOIN [VW_PRODUCTS_HIERARCHY] h ON h.PRODUCTGROUP_ID = cte.PRODUCTGROUP_ID
		INNER JOIN [VW_PRODUCTS_CHANGES] ch ON ch.PRODUCT_ID = h.REF_PRODUCTVARIANT_ID
		--where REF_PRODUCTVARIANT_ID = 169556
		WHERE productvariant_id IS NOT NULL
		--AND h.REF_PRODUCTVARIANT_ID = 8540
		--AND h.PRODUCT_NAME IN ('E610','A002', 'CNMG')   ---
		--AND h.PRODUCT_NAME = 'CNMG'   ---
		--AND h.PRODUCT_ID = 435
		--Declare output table 
		
	IF OBJECT_ID('tempdb..#print') IS NOT NULL
		BEGIN
			DROP TABLE #print			
		END

		BEGIN
			CREATE TABLE #print
			(
			MATERIAL_ID VARCHAR(500),
			PRODUCT_ID INT,
			PRODUCT_NAME VARCHAR(500),
			PRODUCT_ORDERNR INT,
			VARIANT_ID INT,
			VARIANT_NAME VARCHAR(500),
			VARIANT_ORDERNR INT,
			PRAT_NAME VARCHAR(500),
			PRAT_VALUE VARCHAR(2000),
			PRAT_DATATYPE VARCHAR(100),
			PRAT_DICTID INT,
			PRAT_ORDERNR INT,
			PRAT_TRANSLATION NVARCHAR(2000), -- Human Readable values if masterlang then Column_02_02 else Column_02_01 JOIN Dicit details
			PRAT_TRANSLATION_DICTID NUMERIC(15,0) , -- Human Readable values if masterlang then Column_02_02 else Column_02_01 JOIN Dicit details
			PRAT_HEADER NVARCHAR(2000),  ---  If NOT NULL then column_04_03 else NULL
			PRAT_HEADER_ORIENTATION INT,  ---  If NOT NULL then column_04_03 else NULL
			PRAT_ELEMETID NUMERIC(15,0), --- if Column column_04_02
			PRAT_ELEMENTPATH VARCHAR(500),
			PRAT_UOMPRINT NVARCHAR(2000),
			PRAT_UOMPRINT_DICTID NUMERIC(15,0),
			PRAT_FORMATING NVARCHAR(2000),
			PRATVALUE_DICTID NVARCHAR(2000),
			PRATVALUE_SHORTCUT NVARCHAR(2000),
			PRINT_SECTIONNAME VARCHAR(200),
			PRAT_ORDERHELPER INT,
			VARIANT_FOOTNOTEIID INT,
			ICON_DICTID INT,
			OBJECTID INT,
			OBJECTNAME NVARCHAR(200),
			GROUPLEVEL NVARCHAR(200),
			CONTEXT NVARCHAR(200),
			PRAT_HEADER_DICTID INT		
			)
		END


		---//// DEBUG
--		DELETE #Hierarchy where product_name <> 'CNMG'
--		DELETE #Hierarchy where VARIANT_NAME <> 'CNMG 120408E-NM:T8330'
	---	SELECT *FROM #Hierarchy --where PRODUCT_NAME = 'CNMG'
		----/// DEBUG

IF  (@pSection ='DimensionsGlobal' OR  @pSection ='DimensionsNAFTA' OR  @pSection ='Features')
BEGIN

	
IF OBJECT_ID('tempdb..#ValidAttributes') IS NOT NULL
		BEGIN
			DROP TABLE #ValidAttributes			
		END
	BEGIN
		CREATE TABLE #ValidAttributes (
			PRODUCT_ID INT
			,PRATVALUE_DICTID INT
			,PRATVALUE VARCHAR(2000)		
			,PRATVALUE_ORDERNR INT		
			,DICT_SHORTCUT VARCHAR(200)
			,PRAT_ID INT
			)
		CREATE NONCLUSTERED INDEX temp_tempattributes ON #ValidAttributes (PRODUCT_ID, PRAT_ID )
	END;

END


IF (@pSection = 'Description')
BEGIN
----Description
	INSERT INTO #print(MATERIAL_ID, PRODUCT_ID, PRODUCT_NAME, PRODUCT_ORDERNR, VARIANT_ORDERNR,VARIANT_ID, VARIANT_NAME,PRAT_NAME,PRAT_VALUE, PRATVALUE_DICTID, PRAT_DATATYPE,PRAT_ORDERNR,PRAT_DICTID, PRAT_TRANSLATION_DICTID, PRINT_SECTIONNAME)
	select val.PRODUCT_PRODUCTNR,  tt.PRODUCT_ID, tt.PRODUCT_NAME, tt.PRODUCT_SEQORDERNR, tt.PRODUCTVARIANT_SEQORDERNR,
	 val.PRODUCT_ID, val.PRODUCT_NAME, val.PRAT_NAME, val.PRATVALUE, val.PRATVALUE_DICTID, val.PRAT_DATATYPE, val.PRATVALUE_ORDERNR, dic.ID, dic.ID ,'Description'
	FROM VW_P_PRATVALUES val 
	INNER JOIN DICTIONARIES dic on dic.SHORTCUT COLLATE DATABASE_DEFAULT = PRAT_NAME COLLATE DATABASE_DEFAULT
	INNER JOIN [VW_PRODUCTS_HIERARCHY] tt on tt.PRODUCTVARIANT_ID = val.PRODUCT_ID
	INNER JOIN #Hierarchy hie ON REF_VARIANT_ID = val.PRODUCT_ID
	Where val.PRAT_ID IN (
	select prat_id from VW_PRAT_DETAILS where PRAT_NAME in 
		(
		'Marketing_ProductShortDescription_DICT'
		,'Marketing_ProductLongDescription_DICT'
		,'Marketing_TechnicalFeaturesBenefits_DICT'
		,'Marketing_CommercialText_DICT'
		,'WEX_AlternativeProductNote_DICT'))
	AND val.PRATVALUE is not null 


	select * from #print

END


IF (@pSection ='DimensionsGlobal' OR  @pSection ='DimensionsNAFTA')
BEGIN


		DECLARE @attributeid INT;
		DECLARE @section VARCHAR(100) = ''

		IF (@pSection ='DimensionsGlobal')
		BEGIN
			SET @section = 'DimensionsGlobal'
			SELECT @attributeid = PRAT_ID from VW_PRAT_DETAILS where PRAT_NAME = 'WEX_DimensionalTableColumns_Global_DICT'

		END
		ELSE 
		BEGIN
			SET	@section  = 'DimensionsNAFTA'
			SELECT @attributeid = PRAT_ID from VW_PRAT_DETAILS where PRAT_NAME = 'WEX_DimensionalTableColumns_NAFTA_DICT'
		END


		INSERT INTO #ValidAttributes		
		select pra1.PRODUCT_ID, pra1.PRATVALUE_DICTID, pra1.PRATVALUE, pra1.PRATVALUE_ORDERNR, pra1.DICT_SHORTCUT , det.PRAT_ID
		FROM
		VW_P_PRATVALUES pra1
		INNER JOIN #Hierarchy hie ON hie.REF_VARIANT_ID = pra1.PRODUCT_ID
		INNER JOIN VW_PRAT_DETAILS det on det.PRAT_NAME = pra1.DICT_SHORTCUT
		where pra1.PRAT_ID = @attributeid  
		AND pra1.PRATVALUE is not null

		-- here the pratvalues are inserted into print table
		INSERT INTO  #print (MATERIAL_ID, PRODUCT_ID, PRODUCT_NAME, PRODUCT_ORDERNR, VARIANT_ORDERNR, VARIANT_ID,VARIANT_NAME,PRAT_NAME,PRAT_VALUE, 
		PRATVALUE_DICTID,  PRAT_DATATYPE, PRINT_SECTIONNAME,PRAT_DICTID, PRAT_TRANSLATION_DICTID, PRAT_TRANSLATION)				
		select val.PRODUCT_PRODUCTNR, tt.PRODUCT_ID, tt.PRODUCT_NAME, tt.PRODUCT_SEQORDERNR, tt.PRODUCTVARIANT_SEQORDERNR, 
		
		val.PRODUCT_ID AS VARIANT_ID
		,val.PRODUCT_NAME AS VARIANT_NAME
		,val.PRAT_NAME
		,val.PRATVALUE
		,val.PRATVALUE_DICTID
		--,PRATVALUE_ORDERNR 
		,PRAT_DATATYPE 		
		,@section
		,dic.ID
		,dic.Id
		,dic.NAME
		from VW_P_PRATVALUES val
		INNER JOIN DICTIONARIES dic on dic.SHORTCUT COLLATE DATABASE_DEFAULT = val.PRAT_NAME COLLATE DATABASE_DEFAULT
		INNER JOIN [VW_PRODUCTS_HIERARCHY] tt on tt.PRODUCTVARIANT_ID = val.PRODUCT_ID
		INNER JOIN #ValidAttributes att on att.PRODUCT_ID = val.product_id and att.prat_id = val.prat_id
		WHERE val.PRATVALUE is not null 


		-- set correct ordernr
		UPDATE pr Set PRAT_ORDERNR = v.PRATVALUE_ORDERNR 
		FROM #print as pr
		INNER JOIN #ValidAttributes v on v.DICT_SHORTCUT  collate DATABASE_DEFAULT = pr.PRAT_NAME  collate DATABASE_DEFAULT


		--INSERT INTO  #print (MATERIAL_ID, PRODUCT_ID, PRODUCT_NAME, PRODUCT_ORDERNR, VARIANT_ID, VARIANT_NAME, PRAT_ELEMETID,PRINT_SECTIONNAME )				
		--select p.MATERIAL_ID, p.PRODUCT_ID, p.PRODUCT_NAME, p.PRODUCT_ORDERNR, p.VARIANT_ID, p.VARIANT_NAME, rel2.ELEMENT_ID, 'BrandLogo'
		-- from VW_PRODUCTS_ASSIGNED_P rel1 
		--INNER JOIN VW_PRODUCTS_ASSIGNED_E rel2 On rel2.PRODUCT_ID = rel1.X_PRODUCT_ID
		--INNER JOIN (
		--	select pr.MATERIAL_ID, pr.PRODUCT_ID, PRODUCT_NAME, PRODUCT_ORDERNR, VARIANT_ID, VARIANT_NAME 
		--	from #print pr Group by 
		--	pr.MATERIAL_ID, pr.PRODUCT_ID, PRODUCT_NAME, PRODUCT_ORDERNR, VARIANT_ID, VARIANT_NAME 
		--) as p on p.PRODUCT_ID = rel1.PRODUCT_ID
		--where  rel1.PRODTYPE = 'Brand'

		

		UPDATE pr set 
		--PRAT_TRANSLATION = Column_02_02,
		PRAT_HEADER = column_04_03 , 		 
		PRAT_ELEMETID = column_04_02,
		--PRAT_UOMPRINT = Column_05_02,
		PRAT_UOMPRINT_DICTID = Column_05_01,
		PRAT_FORMATING  = column_06_02
		from #print pr
		CROSS APPLY fnc_DP_PRINT_TranspondProdTablesGet(1,null) a
		where pr.PRAT_NAME collate DATABASE_DEFAULT = a.Column_03_03 collate DATABASE_DEFAULT
	

		UPDATE pr set PRAT_ELEMENTPATH = CONCAT(@consPath,REVERSE(SUBSTRING(REVERSE(im.ELEMENTVARIANT_FILENAME), 
                       CHARINDEX('.', REVERSE(im.ELEMENTVARIANT_FILENAME)) + 1, 999)),'.png')
		FROM #print as pr 
		INNER JOIN VW_ELEMENTS el ON el.ELEMENT_ID = pr.PRAT_ELEMETID
		INNER JOIN [dbo].[VW_IMAGES] im on im.ELEMENTVARIANT_ID = el.ELEMENTVARIANT_ID


		-- override prattranslation 
		UPDATE pr set PRAT_UOMPRINT = dict.[NAME]
		FROM #print as pr 
		INNER JOIN DICTIONARIES dict ON dict.ID = pr.PRAT_UOMPRINT_DICTID

select * from #print
		
END		


IF (@pSection ='MainImages' OR  @pSection ='MainImages')
BEGIN

	---- First query gets data from psf second from variant
	INSERT INTO  #print (MATERIAL_ID, PRODUCT_ID,PRODUCT_NAME, PRODUCT_ORDERNR, VARIANT_ID,VARIANT_NAME, VARIANT_ORDERNR, PRAT_DATATYPE, PRAT_ELEMETID, PRAT_ELEMENTPATH, PRINT_SECTIONNAME)
	SELECT  * FROM (
	SELECT hie.PRODUCT_ITEMNUMBER, tt.PRODUCT_ID, tt.PRODUCT_NAME,tt.PRODUCT_SEQORDERNR,
	tt.PRODUCTVARIANT_ID, tt.PRODUCTVARIANT_NAME, tt.PRODUCTVARIANT_SEQORDERNR, rel.ELEMENT_TYPE, rel.ELEMENT_ID,  im.ELEMENTVARIANT_FILENAME as ELEMENTPATH
	,KEYWORD 	
	FROM [VW_PRODUCTS_ASSIGNED_E] rel
	INNER JOIN [VW_PRODUCTS_HIERARCHY] tt on tt.PRODUCT_ID = rel.PRODUCT_ID	
	INNER JOIN OBJE_KEYWS vok on rel.ELEMENT_ID = vok.obje_id
	INNER join keywords kw on kw.id = vok.KEYW_ID
	INNER JOIN VW_ELEMENTS el on el.ELEMENT_ID = rel.ELEMENT_ID
	INNER JOIN VW_IMAGES im on im.ELEMENTVARIANT_ID = el.ELEMENTVARIANT_ID
	INNER JOIN #Hierarchy hie on hie.REF_VARIANT_ID = tt.PRODUCTVARIANT_ID
	
	WHERE vok.REALKEYW = 1  --- To check if this is the right way
	UNION ALL 
	SELECT rel.PRODUCT_PRODUCTNR, tt.PRODUCT_ID, tt.PRODUCT_NAME,tt.PRODUCT_SEQORDERNR,
	tt.PRODUCTVARIANT_ID, tt.PRODUCTVARIANT_NAME, tt.PRODUCTVARIANT_SEQORDERNR, rel.ELEMENT_TYPE, rel.ELEMENT_ID,im.ELEMENTVARIANT_FILENAME as ELEMENTPATH 
					   , KEYWORD 	
	FROM [VW_PRODUCTS_ASSIGNED_E] rel
	INNER JOIN [VW_PRODUCTS_HIERARCHY] tt on tt.PRODUCTVARIANT_ID = rel.PRODUCT_ID	
	INNER JOIN OBJE_KEYWS vok on rel.ELEMENT_ID = vok.obje_id
	INNER join keywords kw on kw.id = vok.KEYW_ID
	INNER JOIN VW_ELEMENTS el on el.ELEMENT_ID = rel.ELEMENT_ID
	--INNER JOIN VW_IMAGES im on im.ELEMENTVARIANT_ID = el.ELEMENTVARIANT_ID
	LEFT OUTER JOIN VW_IMAGES im on im.ELEMENTVARIANT_ID = el.ELEMENTVARIANT_ID
	INNER JOIN #Hierarchy hie on hie.REF_VARIANT_ID = tt.PRODUCTVARIANT_ID
	WHERE vok.REALKEYW = 1  --- To check if this is the right way
	) t Where t.KEYWORD in ('Photo - secondary','Photo - main','Photo - additional','Print dimension image','Print application image','Print geometry profile','Print geometry profile NAFTA','2D','3D')
	--	select 'test',* from #print --15041



	--(MATERIAL_ID, PRODUCT_ID,PRODUCT_NAME, PRODUCT_ORDERNR, VARIANT_ID,VARIANT_NAME, VARIANT_ORDERNR, PRAT_DATATYPE, PRAT_ELEMETID, PRAT_ELEMENTPATH, PRINT_SECTIONNAME)
		INSERT INTO  #print (MATERIAL_ID, PRODUCT_ID, PRODUCT_NAME, PRODUCT_ORDERNR, VARIANT_ID, VARIANT_NAME, PRAT_ELEMETID,PRINT_SECTIONNAME,PRAT_DATATYPE ,PRAT_ELEMENTPATH )				
		select hie.PRODUCT_ITEMNUMBER, hie.REF_PRODUCT_ID, hie.PRODUCT_NAME, hie.PRODUCT_SEQORDER, hie.REF_VARIANT_ID, hie.VARIANT_NAME , rel2.ELEMENT_ID, 'BrandLogo', rel2.ELEMENT_TYPE
		, im.ELEMENTVARIANT_FILENAME as ELEMENTPATH
		 from VW_PRODUCTS_ASSIGNED_P rel1 
		INNER JOIN VW_PRODUCTS_ASSIGNED_E rel2 On rel2.PRODUCT_ID = rel1.X_PRODUCT_ID
		INNER JOIN VW_ELEMENTS el on el.ELEMENT_ID = rel2.ELEMENT_ID
		INNER JOIN VW_IMAGES im on im.ELEMENTVARIANT_ID = el.ELEMENTVARIANT_ID
		INNER JOIN #Hierarchy hie ON hie.REF_PRODUCT_ID = rel1.PRODUCT_ID	
		where  rel1.PRODTYPE = 'Brand'

		UPDATE #print set PRAT_ELEMENTPATH = CONCAT(@consPath,REVERSE(SUBSTRING(REVERSE(PRAT_ELEMENTPATH), CHARINDEX('.', REVERSE(PRAT_ELEMENTPATH)) + 1, 999)),'.png') 
		WHERE PRINT_SECTIONNAME IN ('Photo - secondary','Photo - main','Photo - additional','Print dimension image','Print application image','Print geometry profile','Print geometry profile NAFTA','BrandLogo')



SELECT *FROM #print


END

IF (@pSection ='Operations' )
BEGIN
	
		INSERT INTO #print(MATERIAL_ID, PRODUCT_ID,PRODUCT_NAME,PRODUCT_ORDERNR, VARIANT_ID, VARIANT_NAME ,PRAT_NAME,PRAT_ORDERNR, PRINT_SECTIONNAME)
		SELECT pra.PRODUCT_PRODUCTNR, tt.PRODUCT_ID,tt.PRODUCT_NAME, tt.PRODUCT_SEQORDERNR, pra.PRODUCT_ID, pra.PRODUCT_NAME, col.COLLMEMBER_NAME, col.COLL_ORDER, 'Operations'
		FROM VW_P_PRATVALUES pra 
		INNER JOIN [VW_PRODUCTS_HIERARCHY] tt on tt.PRODUCTVARIANT_ID = pra.PRODUCT_ID
		INNER JOIN VW_PRAT_COLLECTIONS col ON col.COLLMANAGER_NAME = pra.PRAT_NAME
		INNER JOIN #Hierarchy hie on hie.REF_VARIANT_ID = pra.PRODUCT_ID		 
		WHERE pra.PRAT_ID IN
			(			
				SELECT prat_id FROM VW_PRAT_DETAILS where PRAT_NAME in ('PossibleApplicationsDrilling_COLL','PossibleApplicationsMilling_COLL','PossibleApplicationsThreading_COLL','PossibleApplicationsTurning_COLL','PossibleApplicationsDeburring_COLL')
			)
	

		Update pr set pr.PRAT_VALUE = val.PRATVALUE	,  pr.PRATVALUE_DICTID = val.PRATVALUE_DICTID , PRATVALUE_SHORTCUT = val.DICT_SHORTCUT, PRAT_DATATYPE = val.PRAT_DATATYPE ,PRAT_DICTID = dic.Id , PRAT_UOMPRINT = val.PRATVALUE_UNIT, PRINT_SECTIONNAME = @pSection
		FROM #print as pr 
		INNER JOIN VW_P_PRATVALUES val ON pr.VARIANT_ID = val.PRODUCT_ID and pr.PRAT_NAME collate DATABASE_DEFAULT  = val.PRAT_NAME collate DATABASE_DEFAULT
		INNER JOIN DICTIONARIES dic on   dic.SHORTCUT collate DATABASE_DEFAULT =    pr.PRAT_NAME collate DATABASE_DEFAULT
		


		UPDATE pr set 
		PRAT_ELEMETID = column_02_03
		from #print pr
		CROSS APPLY fnc_DP_PRINT_TranspondProdTablesGet(2,null) a
		where pr.PRAT_NAME collate DATABASE_DEFAULT = a.Column_03_03 collate DATABASE_DEFAULT
		AND  pr.PRATVALUE_SHORTCUT collate DATABASE_DEFAULT = a.Column_01_02 collate DATABASE_DEFAULT

		
		UPDATE pr set ICON_DICTID = Column_05_01	
		from #print pr
		CROSS APPLY fnc_DP_PRINT_TranspondProdTablesGet(2,null) a
		where pr.PRAT_NAME collate DATABASE_DEFAULT = a.Column_03_03 collate DATABASE_DEFAULT
		AND pr.PRATVALUE_SHORTCUT collate DATABASE_DEFAULT = a.Column_01_02 collate DATABASE_DEFAULT



		UPDATE pr set PRAT_ELEMENTPATH = 
		CONCAT(@consPath,REVERSE(SUBSTRING(REVERSE(im.ELEMENTVARIANT_FILENAME), 
	                   CHARINDEX('.', REVERSE(im.ELEMENTVARIANT_FILENAME)) + 1, 999)),'.png')
		from #print pr
		INNER JOIN VW_ELEMENTS el on el.ELEMENT_ID = pr.PRAT_ELEMETID
		INNER JOIN VW_IMAGES im on im.ELEMENTVARIANT_ID = el.ELEMENTVARIANT_ID

		DELETE #print where PRAT_VALUE is null OR PRAT_VALUE = 'Not recommended'
		

		SELECT *FROM #print
END

IF (@pSection = 'Features')
BEGIN

----- Consolidate with Dimension
--- Stering attribute
		INSERT INTO #ValidAttributes
		select pra1.PRODUCT_ID,pra1.PRATVALUE_DICTID, pra1.PRATVALUE, pra1.PRATVALUE_ORDERNR, pra1.DICT_SHORTCUT , det.PRAT_ID
		FROM
			VW_P_PRATVALUES pra1
			INNER JOIN #Hierarchy hie ON hie.REF_VARIANT_ID = pra1.PRODUCT_ID
			INNER JOIN VW_PRAT_DETAILS det on det.PRAT_NAME = pra1.DICT_SHORTCUT
		where pra1.PRAT_ID IN (SELECT PRAT_ID from VW_PRAT_DETAILS where PRAT_NAME = 'FeatureIcons_DICT')			
		and pra1.PRATVALUE is not null

	
		INSERT INTO  #print (MATERIAL_ID, product_id,product_name, PRODUCT_ORDERNR,  Variant_id, VARIANT_NAME, VARIANT_ORDERNR, PRAT_NAME, 
		PRAT_VALUE,PRAT_DATATYPE,PRAT_DICTID, PRAT_ORDERNR, PRATVALUE_DICTID, PRATVALUE_SHORTCUT, PRINT_SECTIONNAME, PRAT_UOMPRINT)
		select pra1.PRODUCT_PRODUCTNR, hi.PRODUCT_ID,hi.PRODUCT_NAME , hi.PRODUCT_SEQORDERNR ,  
		pra1.PRODUCT_ID, pra1.PRODUCT_NAME, pra1.PRODUCT_ORDERNR,  pra1.PRAT_NAME, pra1.PRATVALUE, pra1.PRAT_DATATYPE, 
		dic.ID, tmp.PRATVALUE_ORDERNR, pra1.PRATVALUE_DICTID, pra1.DICT_SHORTCUT, 'Features', pra1.PRATVALUE_UNIT
		from 
		VW_P_PRATVALUES pra1 
		INNER JOIN #ValidAttributes tmp ON tmp.PRODUCT_ID = pra1.product_id and tmp.prat_id = pra1.prat_id
		INNER JOIN DICTIONARIES dic ON tmp.DICT_SHORTCUT collate DATABASE_DEFAULT = dic.SHORTCUT collate DATABASE_DEFAULT
		INNER JOIN VW_PRODUCTS_HIERARCHY hi on hi.Productvariant_id = pra1.product_id
			
		--INSERT INTO  #print (PRODUCT_ID,PRODUCT_NAME, PRODUCT_ORDERNR, PRAT_NAME, PRAT_VALUE,PRAT_DATATYPE,PRAT_DICTID, PRAT_ORDERNR, PRATVALUE_DICTID, PRATVALUE_SHORTCUT, PRINT_SECTIONNAME)
		INSERT INTO  #print (MATERIAL_ID, PRODUCT_ID,PRODUCT_NAME,VARIANT_ID,VARIANT_NAME,  PRODUCT_ORDERNR, PRAT_NAME, PRAT_VALUE,PRAT_DATATYPE,PRAT_DICTID,  PRATVALUE_DICTID, PRATVALUE_SHORTCUT, PRINT_SECTIONNAME)		
		select DISTINCT rel.PRODUCT_PRODUCTNR,  val.PRODUCT_ID, val.PRODUCT_NAME, val.VARIANT_ID,val.VARIANT_NAME, pra.PRODUCT_ORDERNR,  pra.PRAT_NAME, pra.PRATVALUE, pra.PRAT_DATATYPE, 50377,--- va.PRATVALUE_ORDERNR, 
		pra.PRATVALUE_DICTID, pra.DICT_SHORTCUT, 'Features'
			FROM #print val 
			INNER JOIN VW_PRODUCTS_ASSIGNED_P rel on val.VARIANT_ID = rel.PRODUCT_ID 
			INNER JOIN VW_P_PRATVALUES pra ON pra.PRODUCT_ID = rel.X_PRODUCT_ID and pra.PRAT_NAME = 'GRA_CoatingName_DICT_SEL'
		--	INNER JOIN #ValidAttributes va on va.DICT_SHORTCUT = pra.PRAT_NAME
			where rel.PRODTYPE = 'Grade'

		UPDATE pr set PRODUCT_ORDERNR = hie.PRODUCT_SEQORDERNR
		FROM #print pr 
		INNER JOIN VW_PRODUCTS_HIERARCHY hie on hie.PRODUCT_ID = pr.PRODUCT_ID
		



		UPDATE pr set PRAT_ELEMETID = column_02_03		
		from #print pr
		CROSS APPLY fnc_DP_PRINT_TranspondProdTablesGet(2,null) a
		where pr.PRAT_NAME collate DATABASE_DEFAULT = a.Column_03_03 collate DATABASE_DEFAULT
		AND pr.PRATVALUE_SHORTCUT collate DATABASE_DEFAULT = a.Column_01_02 collate DATABASE_DEFAULT

		UPDATE pr set PRAT_ELEMETID = column_02_03		
		from #print pr
		CROSS APPLY fnc_DP_PRINT_TranspondProdTablesGet(2,null) a
		where pr.PRAT_NAME collate DATABASE_DEFAULT = a.Column_03_03 collate DATABASE_DEFAULT
		AND pr.PRAT_VALUE collate DATABASE_DEFAULT = a.Column_01_02 collate DATABASE_DEFAULT

		UPDATE pr set ICON_DICTID = Column_05_01	
		from #print pr
		CROSS APPLY fnc_DP_PRINT_TranspondProdTablesGet(2,null) a
		where pr.PRAT_NAME collate DATABASE_DEFAULT = a.Column_03_03 collate DATABASE_DEFAULT
		AND pr.PRAT_VALUE collate DATABASE_DEFAULT = a.Column_01_02 collate DATABASE_DEFAULT


		UPDATE pr set PRAT_ELEMENTPATH = 
		CONCAT(@consPath,REVERSE(SUBSTRING(REVERSE(im.ELEMENTVARIANT_FILENAME), 
	                   CHARINDEX('.', REVERSE(im.ELEMENTVARIANT_FILENAME)) + 1, 999)),'.png')
		from #print pr
		INNER JOIN VW_ELEMENTS el on el.ELEMENT_ID = pr.PRAT_ELEMETID
		INNER JOIN VW_IMAGES im on im.ELEMENTVARIANT_ID = el.ELEMENTVARIANT_ID
				
		DELETE #print where PRAT_VALUE is null OR PRAT_VALUE = 'Not recommended'

		select* from #print
	
END		

IF (@pSection = 'Applications')
BEGIN


DECLARE @temp TABLE
(
  idx int identity,
  attributename varchar(2000)
)

INSERT INTO @temp
SELECT 'MaterialApplication_P_DICT_SEL' UNION ALL
SELECT 'MaterialApplication_M_DICT_SEL' UNION ALL
SELECT 'MaterialApplication_K_DICT_SEL' UNION ALL
SELECT 'MaterialApplication_N_DICT_SEL' UNION ALL
SELECT 'MaterialApplication_S_DICT_SEL' UNION ALL
SELECT 'MaterialApplication_H_DICT_SEL'


	INSERT INTO #print(MATERIAL_ID, PRODUCT_ID, PRODUCT_NAME, PRODUCT_ORDERNR, VARIANT_ORDERNR,VARIANT_ID, VARIANT_NAME,PRAT_NAME,PRAT_VALUE, 
	PRATVALUE_DICTID, PRAT_DATATYPE,PRAT_DICTID, PRAT_TRANSLATION_DICTID, PRINT_SECTIONNAME ,PRAT_ORDERNR,PRATVALUE_SHORTCUT, PRAT_UOMPRINT)
		select val.PRODUCT_PRODUCTNR, tt.PRODUCT_ID, tt.PRODUCT_NAME, tt.PRODUCT_SEQORDERNR, tt.PRODUCTVARIANT_SEQORDERNR,
		 val.PRODUCT_ID, val.PRODUCT_NAME, val.PRAT_NAME, val.PRATVALUE, val.PRATVALUE_DICTID, val.PRAT_DATATYPE,  dic.ID, dic.ID ,@pSection , tmp.idx,val.DICT_SHORTCUT, val.PRATVALUE_UNIT
		FROM VW_P_PRATVALUES val 
			INNER JOIN  @temp tmp ON tmp.attributename collate DATABASE_DEFAULT =  val.PRAT_NAME collate DATABASE_DEFAULT
		INNER JOIN DICTIONARIES dic on dic.SHORTCUT COLLATE DATABASE_DEFAULT = PRAT_NAME COLLATE DATABASE_DEFAULT
		INNER JOIN [VW_PRODUCTS_HIERARCHY] tt on tt.PRODUCTVARIANT_ID = val.PRODUCT_ID
		INNER JOIN #Hierarchy hie on hie.REF_VARIANT_ID = val.PRODUCT_ID


		UPDATE pr set PRAT_ELEMETID = column_02_03		
		from #print pr
		CROSS APPLY fnc_DP_PRINT_TranspondProdTablesGet(2,null) a
		where pr.PRAT_NAME collate DATABASE_DEFAULT = a.Column_03_03 collate DATABASE_DEFAULT
		AND pr.PRATVALUE_SHORTCUT collate DATABASE_DEFAULT = a.Column_01_02 collate DATABASE_DEFAULT

		UPDATE pr set ICON_DICTID = Column_05_01	
		from #print pr
		CROSS APPLY fnc_DP_PRINT_TranspondProdTablesGet(2,null) a
		where pr.PRAT_NAME collate DATABASE_DEFAULT = a.Column_03_03 collate DATABASE_DEFAULT
		AND pr.PRATVALUE_SHORTCUT collate DATABASE_DEFAULT = a.Column_01_02 collate DATABASE_DEFAULT


		UPDATE pr set PRAT_ELEMENTPATH = 
		CONCAT(@consPath,REVERSE(SUBSTRING(REVERSE(im.ELEMENTVARIANT_FILENAME), 
	                   CHARINDEX('.', REVERSE(im.ELEMENTVARIANT_FILENAME)) + 1, 999)),'.png')
		from #print pr
		INNER JOIN VW_ELEMENTS el on el.ELEMENT_ID = pr.PRAT_ELEMETID
		INNER JOIN VW_IMAGES im on im.ELEMENTVARIANT_ID = el.ELEMENTVARIANT_ID
		

		DELETE #print where PRAT_NAME like 'MaterialApplication_%%_DICT_SEL' and PRAT_VALUE = 'Not recommended'		
		DELETE #print where PRAT_VALUE is null 

		SELECT * FROM #print

END 

IF (@pSection = 'CuttingConditions' OR @pSection = 'PayloadPsf')
BEGIN
DECLARE @psfvalid TABLE(
				REF_PRODUCT_ID INT
				,PRODUCT_NAME VARCHAR(1000)
				,PRODUCT_SEQORDERNR INT	
				)

		INSERT INTO @psfvalid
		SELECT tt.REF_PRODUCT_ID, tt.PRODUCT_NAME,tt.PRODUCT_SEQORDER FROM #Hierarchy tt GROUP BY tt.REF_PRODUCT_ID,tt.PRODUCT_NAME,tt.PRODUCT_SEQORDER
		
END



IF (@pSection = 'CuttingConditions')
BEGIN
	
		--INSERT INTO  #print (PRODUCT_ID,PRODUCT_NAME, PRODUCT_ORDERNR, PRAT_NAME, PRAT_VALUE,PRAT_DATATYPE,PRAT_DICTID, PRAT_ORDERNR, PRATVALUE_DICTID, PRATVALUE_SHORTCUT, PRINT_SECTIONNAME)
		--select pra1.PRODUCT_ID, pra1.PRODUCT_NAME, pra1.PRODUCT_ORDERNR,  pra1.PRAT_NAME, pra1.PRATVALUE, pra1.PRAT_DATATYPE, pra1.PRATVALUE_DICTID, tt.COLL_ORDER, pra1.PRATVALUE_DICTID, pra1.DICT_SHORTCUT, 'CuttingConditions'
		--from VW_P_PRATVALUES pra1 
		--INNER JOIN (SELECT REF_PRODUCT_ID FROM @psfvalid ) psf ON psf.REF_PRODUCT_ID = pra1.PRODUCT_ID 
		--INNER JOIN (
		--	select COLLMEMBER_NAME, COLL_ORDER from 
		--		VW_PRAT_COLLECTIONS 
		--		where COLLMANAGER_NAME collate DATABASE_DEFAULT IN 
		--			( 
		--				select PRATVALUE collate DATABASE_DEFAULT
		--				from VW_P_PRATVALUES 
		--				where PRODUCT_ID IN (SELECT REF_PRODUCT_ID FROM @psfvalid) and PRAT_NAME = 'WEX_CuttingConditionsCollectionGlobal_SEL'
		--			)
		--) as tt  on pra1.PRAT_NAME collate DATABASE_DEFAULT = tt.COLLMEMBER_NAME collate DATABASE_DEFAULT				
		--and pra1.PRATVALUE is not null
		--116
		
		INSERT INTO  #print 
		(MATERIAL_ID, 
		PRODUCT_ID,PRODUCT_NAME, VARIANT_ID, VARIANT_NAME, PRODUCT_ORDERNR, PRAT_NAME, PRAT_VALUE,PRAT_DATATYPE,
		PRAT_DICTID, PRAT_ORDERNR, PRATVALUE_DICTID, PRATVALUE_SHORTCUT, PRINT_SECTIONNAME, CONTEXT)
		SELECT 		
		hie.PRODUCT_ITEMNUMBER,
		REF_PRODUCT_ID,  
		hie.PRODUCT_NAME,				
		REF_VARIANT_ID,
		hie.VARIANT_NAME,
		hie.PRODUCT_SEQORDER,
		val2.PRAT_NAME,		
		val2.PRATVALUE, 
		val2.PRAT_DATATYPE,
		dict.ID,		
		col.COLL_ORDER, 
		val2.PRATVALUE_DICTID,
		val2.DICT_SHORTCUT, 
		@pSection,
		val.PRATVALUE
		FROM #Hierarchy hie
		INNER JOIN VW_P_PRATVALUES val on val.PRODUCT_ID = hie.REF_PRODUCT_ID and PRAT_NAME = 'WEX_CuttingConditionsCollectionGlobal_SEL'
		INNER JOIN 
		(select COLLMANAGER_NAME, COLLMEMBER_NAME, COLL_ORDER from VW_PRAT_COLLECTIONS where COLLMANAGER_NAME collate DATABASE_DEFAULT IN (
		'WEX_CuttingConditions1_Global_COLL',
		'WEX_CuttingConditions2_Global_COLL',
		'WEX_CuttingConditions3_Global_COLL',
		'WEX_CuttingConditions4_Global_COLL',
		'WEX_CuttingConditions5_Global_COLL',
		'WEX_CuttingConditions6_Global_COLL',
		'WEX_CuttingConditions7_Global_COLL')) col on COLLMANAGER_NAME = val.PRATVALUE
		INNER JOIN VW_PRAT_DETAILS det on det.PRAT_NAME = col.COLLMEMBER_NAME
		INNER JOIN VW_P_PRATVALUES val2 on val2.PRODUCT_ID = hie.REF_VARIANT_ID and val2.PRAT_ID = det.PRAT_ID
		INNER JOIN DICTIONARIES dict on dict.SHORTCUT = col.COLLMEMBER_NAME 
		--WHERE val2.PRATVALUE is not null
		--GROUP BY 
		--hie.PRODUCT_NAME,
		--hie.PRODUCT_ITEMNUMBER,
		--hie.REF_PRODUCT_ID,  
		--hie.REF_VARIANT_ID,
		--hie.VARIANT_NAME,
		--hie.VARIANT_SEQORDER,
		--val.PRAT_ID, 
		--val.PRATVALUE, 
		--col.COLLMEMBER_NAME, 
		--det.PRAT_ID , 
		--val2.PRAT_ID, 
		--val2.PRATVALUE

		DELETE #print where PRAT_VALUE is null

		
		--INSERT INTO  #print (MATERIAL_ID, PRODUCT_ID,PRODUCT_NAME, VARIANT_ID, VARIANT_NAME, PRODUCT_ORDERNR, PRAT_NAME, PRAT_VALUE,PRAT_DATATYPE,PRAT_DICTID, PRAT_ORDERNR, PRATVALUE_DICTID, PRATVALUE_SHORTCUT, PRINT_SECTIONNAME)
		--select pra1.PRODUCT_PRODUCTNR, psf.REF_PRODUCT_ID, psf.PRODUCT_NAME, pra1.PRODUCT_ID, pra1.PRODUCT_NAME, pra1.PRODUCT_ORDERNR,  pra1.PRAT_NAME, pra1.PRATVALUE, pra1.PRAT_DATATYPE, pra1.PRATVALUE_DICTID, tt.COLL_ORDER, pra1.PRATVALUE_DICTID, pra1.DICT_SHORTCUT, 'CuttingConditions'
		--from VW_P_PRATVALUES pra1 
		--INNER JOIN #Hierarchy psf ON psf.REF_VARIANT_ID = pra1.PRODUCT_ID 
		--INNER JOIN (
		--	select COLLMEMBER_NAME, COLL_ORDER from 
		--		VW_PRAT_COLLECTIONS 
		--		where COLLMANAGER_NAME collate DATABASE_DEFAULT IN 
		--			( 
		--				select PRATVALUE collate DATABASE_DEFAULT
		--				from VW_P_PRATVALUES 
		--				where PRODUCT_ID IN (SELECT REF_PRODUCT_ID FROM @psfvalid) and PRAT_NAME = 'WEX_CuttingConditionsCollectionGlobal_SEL'
		--			)
		--) as tt  on pra1.PRAT_NAME collate DATABASE_DEFAULT = tt.COLLMEMBER_NAME collate DATABASE_DEFAULT				
		--and pra1.PRATVALUE is not null



	UPDATE pr set PRAT_ELEMETID = column_04_02	
	from #print pr
	CROSS APPLY fnc_DP_PRINT_TranspondProdTablesGet(2,null) a
	where 
	CASE 
	WHEN pr.PRAT_NAME collate DATABASE_DEFAULT LIKE 'MaterialApplication_P%' THEN 'MaterialApplication_P_DICT_SEL' 
	WHEN pr.PRAT_NAME collate DATABASE_DEFAULT LIKE 'MaterialApplication_M%' THEN 'MaterialApplication_M_DICT_SEL' 
	WHEN pr.PRAT_NAME collate DATABASE_DEFAULT LIKE 'MaterialApplication_K%' THEN 'MaterialApplication_K_DICT_SEL' 
	WHEN pr.PRAT_NAME collate DATABASE_DEFAULT LIKE 'MaterialApplication_H%' THEN 'MaterialApplication_H_DICT_SEL' 
	WHEN pr.PRAT_NAME collate DATABASE_DEFAULT LIKE 'MaterialApplication_N%' THEN 'MaterialApplication_N_DICT_SEL' 
	WHEN pr.PRAT_NAME collate DATABASE_DEFAULT LIKE 'MaterialApplication_S%' THEN 'MaterialApplication_S_DICT_SEL' 
	ELSE '' END = a.Column_03_03 collate DATABASE_DEFAULT
	AND pr.PRATVALUE_SHORTCUT collate DATABASE_DEFAULT = a.Column_01_02 collate DATABASE_DEFAULT
	

	UPDATE pr SET pr.GROUPLEVEL = 
	CASE
	WHEN PRAT_NAME LIKE '%_P1_1_%' THEN 'P1.1' 
	WHEN PRAT_NAME LIKE '%_P1_2_%' THEN 'P1.2' 
	WHEN PRAT_NAME LIKE '%_P1_3_%' THEN 'P1.3' 
	WHEN PRAT_NAME LIKE '%_P1_4_%' THEN 'P1.4' 
	WHEN PRAT_NAME LIKE '%_P1_5_%' THEN 'P1.5' 
	WHEN PRAT_NAME LIKE '%_P1_6_%' THEN 'P1.6' 
	WHEN PRAT_NAME LIKE '%_P2_1_%' THEN 'P2.1' 
	WHEN PRAT_NAME LIKE '%_P2_2_%' THEN 'P2.2' 
	WHEN PRAT_NAME LIKE '%_P2_3_%' THEN 'P2.3' 
	WHEN PRAT_NAME LIKE '%_P2_4_%' THEN 'P2.4' 
	WHEN PRAT_NAME LIKE '%_P2_5_%' THEN 'P2.5' 
	WHEN PRAT_NAME LIKE '%_P2_6_%' THEN 'P2.6' 
	WHEN PRAT_NAME LIKE '%_P3_1_%' THEN 'P3.1' 
	WHEN PRAT_NAME LIKE '%_P3_2_%' THEN 'P3.2' 
	WHEN PRAT_NAME LIKE '%_P3_3_%' THEN 'P3.3' 
	WHEN PRAT_NAME LIKE '%_P3_4_%' THEN 'P3.4' 
	WHEN PRAT_NAME LIKE '%_P3_5_%' THEN 'P3.5' 
	WHEN PRAT_NAME LIKE '%_P3_6_%' THEN 'P3.6' 
	WHEN PRAT_NAME LIKE '%_P4_1_%' THEN 'P4.1' 
	WHEN PRAT_NAME LIKE '%_P4_2_%' THEN 'P4.2' 
	WHEN PRAT_NAME LIKE '%_P4_3_%' THEN 'P4.3' 
	WHEN PRAT_NAME LIKE '%_P4_4_%' THEN 'P4.4' 
	WHEN PRAT_NAME LIKE '%_P4_5_%' THEN 'P4.5' 
	WHEN PRAT_NAME LIKE '%_P4_6_%' THEN 'P4.6' 
--M
	WHEN PRAT_NAME LIKE '%_M1_1_%' THEN 'M1.1' 
	WHEN PRAT_NAME LIKE '%_M1_2_%' THEN 'M1.2' 
	WHEN PRAT_NAME LIKE '%_M1_3_%' THEN 'M1.3' 
	WHEN PRAT_NAME LIKE '%_M1_4_%' THEN 'M1.4' 
	WHEN PRAT_NAME LIKE '%_M1_5_%' THEN 'M1.5' 
	WHEN PRAT_NAME LIKE '%_M1_6_%' THEN 'M1.6' 
	WHEN PRAT_NAME LIKE '%_M2_1_%' THEN 'M2.1' 
	WHEN PRAT_NAME LIKE '%_M2_2_%' THEN 'M2.2' 
	WHEN PRAT_NAME LIKE '%_M2_3_%' THEN 'M2.3' 
	WHEN PRAT_NAME LIKE '%_M2_4_%' THEN 'M2.4' 
	WHEN PRAT_NAME LIKE '%_M2_5_%' THEN 'M2.5' 
	WHEN PRAT_NAME LIKE '%_M2_6_%' THEN 'M2.6' 
	WHEN PRAT_NAME LIKE '%_M3_1_%' THEN 'M3.1' 
	WHEN PRAT_NAME LIKE '%_M3_2_%' THEN 'M3.2' 
	WHEN PRAT_NAME LIKE '%_M3_3_%' THEN 'M3.3' 
	WHEN PRAT_NAME LIKE '%_M3_4_%' THEN 'M3.4' 
	WHEN PRAT_NAME LIKE '%_M3_5_%' THEN 'M3.5' 
	WHEN PRAT_NAME LIKE '%_M3_6_%' THEN 'M3.6' 
	WHEN PRAT_NAME LIKE '%_M4_1_%' THEN 'M4.1' 
	WHEN PRAT_NAME LIKE '%_M4_2_%' THEN 'M4.2' 
	WHEN PRAT_NAME LIKE '%_M4_3_%' THEN 'M4.3' 
	WHEN PRAT_NAME LIKE '%_M4_4_%' THEN 'M4.4' 
	WHEN PRAT_NAME LIKE '%_M4_5_%' THEN 'M4.5' 
	WHEN PRAT_NAME LIKE '%_M4_6_%' THEN 'M4.6' 

	WHEN PRAT_NAME LIKE '%_K1_1_%' THEN 'K1.1' 
	WHEN PRAT_NAME LIKE '%_K1_2_%' THEN 'K1.2' 
	WHEN PRAT_NAME LIKE '%_K1_3_%' THEN 'K1.3' 
	WHEN PRAT_NAME LIKE '%_K2_1_%' THEN 'K2.1' 
	WHEN PRAT_NAME LIKE '%_K2_2_%' THEN 'K2.2' 
	WHEN PRAT_NAME LIKE '%_K2_3_%' THEN 'K2.3' 
	WHEN PRAT_NAME LIKE '%_K3_1_%' THEN 'K3.1' 
	WHEN PRAT_NAME LIKE '%_K3_2_%' THEN 'K3.2' 
	WHEN PRAT_NAME LIKE '%_K3_3_%' THEN 'K3.3' 
	WHEN PRAT_NAME LIKE '%_K4_1_%' THEN 'K4.1' 
	WHEN PRAT_NAME LIKE '%_K4_2_%' THEN 'K4.2' 
	WHEN PRAT_NAME LIKE '%_K4_3_%' THEN 'K4.3' 
	WHEN PRAT_NAME LIKE '%_K4_4_%' THEN 'K4.4' 
	WHEN PRAT_NAME LIKE '%_K4_5_%' THEN 'K4.5' 
	WHEN PRAT_NAME LIKE '%_K5_1_%' THEN 'K5.1' 
	WHEN PRAT_NAME LIKE '%_K5_2_%' THEN 'K5.2' 
	WHEN PRAT_NAME LIKE '%_K5_3_%' THEN 'K5.3' 	

	---N
	WHEN PRAT_NAME LIKE '%_N1_1_%' THEN 'N1.1' 
	WHEN PRAT_NAME LIKE '%_N1_2_%' THEN 'N1.2' 
	WHEN PRAT_NAME LIKE '%_N1_3_%' THEN 'N1.3' 
	WHEN PRAT_NAME LIKE '%_N2_1_%' THEN 'N2.1' 
	WHEN PRAT_NAME LIKE '%_N2_2_%' THEN 'N2.2' 
	WHEN PRAT_NAME LIKE '%_N2_3_%' THEN 'N2.3'  
	WHEN PRAT_NAME LIKE '%_N3_1_%' THEN 'N3.1' 
	WHEN PRAT_NAME LIKE '%_N3_2_%' THEN 'N3.2' 
	WHEN PRAT_NAME LIKE '%_N3_3_%' THEN 'N3.3' 
	WHEN PRAT_NAME LIKE '%_N4_1_%' THEN 'N4.1' 
	WHEN PRAT_NAME LIKE '%_N4_2_%' THEN 'N4.2' 
	WHEN PRAT_NAME LIKE '%_N4_3_%' THEN 'N4.3' 	
	WHEN PRAT_NAME LIKE '%_N5_1_%' THEN 'N5.1' 

	--S
	WHEN PRAT_NAME LIKE '%_S1_1_%' THEN 'S1.1' 
	WHEN PRAT_NAME LIKE '%_S1_2_%' THEN 'S1.2' 
	WHEN PRAT_NAME LIKE '%_S1_3_%' THEN 'S1.3' 
	WHEN PRAT_NAME LIKE '%_S2_1_%' THEN 'S2.1' 
	WHEN PRAT_NAME LIKE '%_S2_2_%' THEN 'S2.2' 
	WHEN PRAT_NAME LIKE '%_S3_1_%' THEN 'S3.1' 
	WHEN PRAT_NAME LIKE '%_S3_2_%' THEN 'S3.2' 
	WHEN PRAT_NAME LIKE '%_S4_1_%' THEN 'S4.1' 
	WHEN PRAT_NAME LIKE '%_S4_2_%' THEN 'S4.2' 

	WHEN PRAT_NAME LIKE '%_H1_1_%' THEN 'H1.1' 
	WHEN PRAT_NAME LIKE '%_H1_2_%' THEN 'H1.2' 
	WHEN PRAT_NAME LIKE '%_H1_3_%' THEN 'H1.3' 
	WHEN PRAT_NAME LIKE '%_H2_1_%' THEN 'H2.1' 
	WHEN PRAT_NAME LIKE '%_H2_2_%' THEN 'H2.2' 
	WHEN PRAT_NAME LIKE '%_H2_3_%' THEN 'H2.3' 
	WHEN PRAT_NAME LIKE '%_H3_1_%' THEN 'H3.1' 
	WHEN PRAT_NAME LIKE '%_H3_2_%' THEN 'H3.2' 
	WHEN PRAT_NAME LIKE '%_H3_3_%' THEN 'H3.3' 
	WHEN PRAT_NAME LIKE '%_H4_1_%' THEN 'H4.1' 
	WHEN PRAT_NAME LIKE '%_H4_2_%' THEN 'H4.2' 
	WHEN PRAT_NAME LIKE '%_H4_3_%' THEN 'H4.3'


	WHEN CHARINDEX( '_P_',PRAT_NAME) <> 0 THEN 'P' 
	WHEN CHARINDEX( '_M_',PRAT_NAME) <> 0 THEN 'M' 
	WHEN CHARINDEX( '_K_',PRAT_NAME) <> 0 THEN 'K' 
	WHEN CHARINDEX( '_N_',PRAT_NAME) <> 0 THEN 'N' 
	WHEN CHARINDEX( '_S_',PRAT_NAME) <> 0 THEN 'S' 
	WHEN CHARINDEX( '_H_',PRAT_NAME) <> 0 THEN 'H' 
	ELSE ''END 
	from #print pr

	UPDATE #print set PRAT_HEADER = GROUPLEVEL
	DELETE #print where PRAT_VALUE = 'Not recommended'

		--	BEGIN
		--	INSERT INTO #print (PRODUCT_ID,PRODUCT_NAME,PRAT_NAME,PRAT_VALUE,PRAT_HEADER,PRAT_ELEMETID,GROUPLEVEL)									
		--	SELECT va.PRODUCT_ID,va.PRODUCT_NAME, wm.prat_name,wm.header,wm.header,elementID,wm.header 
		--	FROM #print va 			
		--	INNER JOIN 
		--	(
		--	select 'MaterialApplication_H1_1_DICT_SEL' AS prat_name  ,251934 as elementID, 'IC_WMG3_H1.1' as element_name, 'H1.1' as header UNION ALL
		--	select 'MaterialApplication_H2_1_DICT_SEL' ,251932, 'IC_WMG3_H2.1', 'H2.1' UNION ALL
		--	select 'MaterialApplication_H2_2_DICT_SEL' ,251930, 'IC_WMG3_H2.2', 'H2.2' UNION ALL
		--	select 'MaterialApplication_H3_1_DICT_SEL' ,251928, 'IC_WMG3_H3.1', 'H3.1' UNION ALL
		--	select 'MaterialApplication_H3_2_DICT_SEL' ,251926, 'IC_WMG3_H3.2', 'H3.2' UNION ALL
		--	select 'MaterialApplication_H4_1_DICT_SEL' ,251924, 'IC_WMG3_H4.1', 'H4.1' UNION ALL
		--	select 'MaterialApplication_H4_2_DICT_SEL' ,251922, 'IC_WMG3_H4.2', 'H4.2' UNION ALL
		--	select 'MaterialApplication_K1_1_DICT_SEL' ,251920, 'IC_WMG3_K1.1', 'K1.1' UNION ALL
		--	select 'MaterialApplication_K1_2_DICT_SEL' ,251918, 'IC_WMG3_K1.2', 'K1.2' UNION ALL
		--	select 'MaterialApplication_K1_3_DICT_SEL' ,251916, 'IC_WMG3_K1.3', 'K1.3' UNION ALL
		--	select 'MaterialApplication_K2_1_DICT_SEL' ,251914, 'IC_WMG3_K2.1', 'K2.1' UNION ALL
		--	select 'MaterialApplication_K2_2_DICT_SEL' ,251912, 'IC_WMG3_K2.2', 'K2.2' UNION ALL
		--	select 'MaterialApplication_K2_3_DICT_SEL' ,251910, 'IC_WMG3_K2.3', 'K2.3' UNION ALL
		--	select 'MaterialApplication_K3_1_DICT_SEL' ,251908, 'IC_WMG3_K3.1', 'K3.1' UNION ALL
		--	select 'MaterialApplication_K3_2_DICT_SEL' ,251906, 'IC_WMG3_K3.2', 'K3.2' UNION ALL
		--	select 'MaterialApplication_K3_3_DICT_SEL' ,251904, 'IC_WMG3_K3.3', 'K3.3' UNION ALL
		--	select 'MaterialApplication_K4_1_DICT_SEL' ,251902, 'IC_WMG3_K4.1', 'K4.1' UNION ALL
		--	select 'MaterialApplication_K4_2_DICT_SEL' ,251900, 'IC_WMG3_K4.2', 'K4.2' UNION ALL
		--	select 'MaterialApplication_K4_3_DICT_SEL' ,251898, 'IC_WMG3_K4.3', 'K4.3' UNION ALL
		--	select 'MaterialApplication_K4_4_DICT_SEL' ,251896, 'IC_WMG3_K4.4', 'K4.4' UNION ALL
		--	select 'MaterialApplication_K4_5_DICT_SEL' ,251894, 'IC_WMG3_K4.5', 'K4.5' UNION ALL
		--	select 'MaterialApplication_K5_1_DICT_SEL' ,251892, 'IC_WMG3_K5.1', 'K5.1' UNION ALL
		--	select 'MaterialApplication_K5_2_DICT_SEL' ,251890, 'IC_WMG3_K5.2', 'K5.2' UNION ALL
		--	select 'MaterialApplication_K5_3_DICT_SEL' ,251888, 'IC_WMG3_K5.3', 'K5.3' UNION ALL
		--	select 'MaterialApplication_M1_1_DICT_SEL' ,251886, 'IC_WMG3_M1.1', 'M1.1' UNION ALL
		--	select 'MaterialApplication_M1_2_DICT_SEL' ,251884, 'IC_WMG3_M1.2', 'M1.2' UNION ALL
		--	select 'MaterialApplication_M2_1_DICT_SEL' ,251882, 'IC_WMG3_M2.1', 'M2.1' UNION ALL
		--	select 'MaterialApplication_M2_2_DICT_SEL' ,251880, 'IC_WMG3_M2.2', 'M2.2' UNION ALL
		--	select 'MaterialApplication_M2_3_DICT_SEL' ,251878, 'IC_WMG3_M2.3', 'M2.3' UNION ALL
		--	select 'MaterialApplication_M3_1_DICT_SEL' ,251876, 'IC_WMG3_M3.1', 'M3.1' UNION ALL
		--	select 'MaterialApplication_M3_2_DICT_SEL' ,251874, 'IC_WMG3_M3.2', 'M3.2' UNION ALL
		--	select 'MaterialApplication_M3_3_DICT_SEL' ,251872, 'IC_WMG3_M3.3', 'M3.3' UNION ALL
		--	select 'MaterialApplication_M4_1_DICT_SEL' ,251870, 'IC_WMG3_M4.1', 'M4.1' UNION ALL
		--	select 'MaterialApplication_M4_2_DICT_SEL' ,251868, 'IC_WMG3_M4.2', 'M4.2' UNION ALL
		--	select 'MaterialApplication_N1_1_DICT_SEL' ,251866, 'IC_WMG3_N1.1', 'N1.1' UNION ALL
		--	select 'MaterialApplication_N1_2_DICT_SEL' ,251864, 'IC_WMG3_N1.2', 'N1.2' UNION ALL
		--	select 'MaterialApplication_N1_3_DICT_SEL' ,251862, 'IC_WMG3_N1.3', 'N1.3' UNION ALL
		--	select 'MaterialApplication_N2_1_DICT_SEL' ,251860, 'IC_WMG3_N2.1', 'N2.1' UNION ALL
		--	select 'MaterialApplication_N2_2_DICT_SEL' ,251858, 'IC_WMG3_N2.2', 'N2.2' UNION ALL
		--	select 'MaterialApplication_N2_3_DICT_SEL' ,251856, 'IC_WMG3_N2.3', 'N2.3' UNION ALL
		--	select 'MaterialApplication_N3_1_DICT_SEL' ,251854, 'IC_WMG3_N3.1', 'N3.1' UNION ALL
		--	select 'MaterialApplication_N3_2_DICT_SEL' ,251852, 'IC_WMG3_N3.2', 'N3.2' UNION ALL
		--	select 'MaterialApplication_N3_3_DICT_SEL' ,251850, 'IC_WMG3_N3.3', 'N3.3' UNION ALL
		--	select 'MaterialApplication_N4_1_DICT_SEL' ,251848, 'IC_WMG3_N4.1', 'N4.1' UNION ALL
		--	select 'MaterialApplication_N4_2_DICT_SEL' ,251846, 'IC_WMG3_N4.2', 'N4.2' UNION ALL
		--	select 'MaterialApplication_N4_3_DICT_SEL' ,251844, 'IC_WMG3_N4.3', 'N4.3' UNION ALL
		--	select 'MaterialApplication_N5_1_DICT_SEL' ,251842, 'IC_WMG3_N5.1', 'N5.1' UNION ALL
		--	select 'MaterialApplication_P1_1_DICT_SEL' ,251840, 'IC_WMG3_P1.1', 'P1.1' UNION ALL
		--	select 'MaterialApplication_P1_2_DICT_SEL' ,251838, 'IC_WMG3_P1.2', 'P1.2' UNION ALL
		--	select 'MaterialApplication_P1_3_DICT_SEL' ,251836, 'IC_WMG3_P1.3', 'P1.3' UNION ALL
		--	select 'MaterialApplication_P2_1_DICT_SEL' ,251834, 'IC_WMG3_P2.1', 'P2.1' UNION ALL
		--	select 'MaterialApplication_P2_2_DICT_SEL' ,251832, 'IC_WMG3_P2.2', 'P2.2' UNION ALL
		--	select 'MaterialApplication_P2_3_DICT_SEL' ,251830, 'IC_WMG3_P2.3', 'P2.3' UNION ALL
		--	select 'MaterialApplication_P3_1_DICT_SEL' ,251828, 'IC_WMG3_P3.1', 'P3.1' UNION ALL
		--	select 'MaterialApplication_P3_2_DICT_SEL' ,251826, 'IC_WMG3_P3.2', 'P3.2' UNION ALL
		--	select 'MaterialApplication_P3_3_DICT_SEL' ,251824, 'IC_WMG3_P3.3', 'P3.3' UNION ALL
		--	select 'MaterialApplication_P4_1_DICT_SEL' ,251822, 'IC_WMG3_P4.1', 'P4.1' UNION ALL
		--	select 'MaterialApplication_P4_2_DICT_SEL' ,251820, 'IC_WMG3_P4.2', 'P4.2' UNION ALL
		--	select 'MaterialApplication_P4_3_DICT_SEL' ,251818, 'IC_WMG3_P4.3', 'P4.3' UNION ALL
		--	select 'MaterialApplication_S1_1_DICT_SEL' ,251816, 'IC_WMG3_S1.1', 'S1.1' UNION ALL
		--	select 'MaterialApplication_S1_2_DICT_SEL' ,251814, 'IC_WMG3_S1.2', 'S1.2' UNION ALL
		--	select 'MaterialApplication_S1_3_DICT_SEL' ,251812, 'IC_WMG3_S1.3', 'S1.3' UNION ALL
		--	select 'MaterialApplication_S2_1_DICT_SEL' ,251810, 'IC_WMG3_S2.1', 'S2.1' UNION ALL
		--	select 'MaterialApplication_S2_2_DICT_SEL' ,251808, 'IC_WMG3_S2.2', 'S2.2' UNION ALL
		--	select 'MaterialApplication_S3_1_DICT_SEL' ,251806, 'IC_WMG3_S3.1', 'S3.1' UNION ALL
		--	select 'MaterialApplication_S3_2_DICT_SEL' ,251804, 'IC_WMG3_S3.2', 'S3.2' UNION ALL
		--	select 'MaterialApplication_S4_1_DICT_SEL' ,251802, 'IC_WMG3_S4.1', 'S4.1' UNION ALL
		--	select 'MaterialApplication_S4_2_DICT_SEL' ,251800, 'IC_WMG3_S4.2', 'S4.2' ) AS wm ON va.PRAT_NAME = wm.prat_name
		--END

		--return

	UPDATE pr SET pr.PRAT_ORDERNR = pr2.PRAT_ORDERNR - 1	
	FROM  #print pr 
	INNER JOIN #print pr2 On pr2.PRAT_NAME = pr.PRAT_NAME and pr2.PRAT_ORDERNR is not null
	WHERE pr.PRAT_ORDERNR is null
	
	UPDATE #print set PRINT_Sectionname = 'CuttingConditions'

	--INSERT INTO  #print (PRODUCT_ID,PRODUCT_NAME, PRODUCT_ORDERNR, PRAT_NAME, PRAT_VALUE,PRAT_DATATYPE,PRAT_DICTID, PRAT_ORDERNR, PRATVALUE_DICTID, PRATVALUE_SHORTCUT, PRINT_SECTIONNAME)
	--	select pra1.PRODUCT_ID, pra1.PRODUCT_NAME, pra1.PRODUCT_ORDERNR,  pra1.PRAT_NAME, pra1.PRATVALUE, pra1.PRAT_DATATYPE, pra1.PRATVALUE_DICTID, 0, pra1.PRATVALUE_DICTID, pra1.DICT_SHORTCUT, 'FootNotes'
	--	from VW_P_PRATVALUES pra1 
	--	WHERE pra1.product_id in (SELECT REF_PRODUCT_ID FROM #Hierarchy GROUP BY REF_PRODUCT_ID)
	--	AND pra1.prat_name IN (@conditionsnote,'Print_FootnotePSF_DICT','Print_AlternativeProductNote_DICT')
	--	and pra1.PRATVALUE is not null

	--UPDATE #print set PRINT_Sectionname = 'HeaderNotes' where PRAT_NAME = @conditionsnote


	
--IF (@isMaster = 0)
--BEGIN
--	UPDATE p set PRAT_VALUE = prl.DICT_LANG_VALUE
--	FROM #print p
--	INNER JOIN [dbo].[VW_DICTIONARY_DETAILS] prl ON prl.DICT_ID = p.PRATVALUE_DICTID and prl.DICT_LANGCOUNTRY = @pLanguage 
--END 

	--DELETE #print where VARIANT_ID is null
	

	BEGIN
		SELECT * FROM #print
	END


END 


IF (@pSection = 'PayloadPsf')
BEGIN 



	INSERT INTO #print(MATERIAL_ID, PRODUCT_ID,PRODUCT_NAME,PRODUCT_ORDERNR, PRAT_NAME,PRAT_ORDERNR, PRINT_SECTIONNAME)
		SELECT pra.PRODUCT_PRODUCTNR, pra.PRODUCT_ID,pra.PRODUCT_NAME, hie.PRODUCT_SEQORDERNR ,  col.COLLMEMBER_NAME, col.COLL_ORDER, 'PayloadPsf'
		FROM VW_P_PRATVALUES pra 		
		INNER JOIN VW_PRAT_COLLECTIONS col ON col.COLLMEMBER_NAME = pra.PRAT_NAME AND COLLMANAGER_NAME = 'WEX_PayloadPRO_COLL'
		INNER JOIN @psfvalid hie on hie.REF_PRODUCT_ID = pra.PRODUCT_ID		 
		
		----- 

		Update pr set pr.PRAT_VALUE = val.PRATVALUE	,  pr.PRATVALUE_DICTID = val.PRATVALUE_DICTID , PRATVALUE_SHORTCUT = val.DICT_SHORTCUT, PRAT_DATATYPE = val.PRAT_DATATYPE ,PRAT_DICTID = dic.Id , PRAT_UOMPRINT = val.PRATVALUE_UNIT, PRINT_SECTIONNAME = 'PayloadPsf'
		FROM #print as pr 
		INNER JOIN VW_P_PRATVALUES val ON pr.PRODUCT_ID= val.PRODUCT_ID and pr.PRAT_NAME collate DATABASE_DEFAULT  = val.PRAT_NAME collate DATABASE_DEFAULT
		INNER JOIN DICTIONARIES dic on   dic.SHORTCUT collate DATABASE_DEFAULT =    pr.PRAT_NAME collate DATABASE_DEFAULT
		

		INSERT INTO  #print (MATERIAL_ID, PRODUCT_ID,PRODUCT_NAME, PRODUCT_ORDERNR,  PRAT_DATATYPE, PRAT_ELEMETID, PRAT_ELEMENTPATH, PRINT_SECTIONNAME)
		SELECT  * FROM (
		SELECT  rel.PRODUCT_PRODUCTNR, rel.PRODUCT_ID, rel.PRODUCT_NAME,hie.PRODUCT_SEQORDERNR,
		rel.ELEMENT_TYPE, rel.ELEMENT_ID, CONCAT(@consPath,REVERSE(SUBSTRING(REVERSE(im.ELEMENTVARIANT_FILENAME), 
							CHARINDEX('.', REVERSE(im.ELEMENTVARIANT_FILENAME)) + 1, 999)),'.png') as ELEMENTPATH 
							, KEYWORD 	
		FROM [VW_PRODUCTS_ASSIGNED_E] rel
		--INNER JOIN [VW_PRODUCTS_HIERARCHY] tt on tt.PRODUCTVARIANT_ID = rel.PRODUCT_ID	
		INNER JOIN OBJE_KEYWS vok on rel.ELEMENT_ID = vok.obje_id
		INNER join keywords kw on kw.id = vok.KEYW_ID
		INNER JOIN VW_ELEMENTS el on el.ELEMENT_ID = rel.ELEMENT_ID
		INNER JOIN VW_IMAGES im on im.ELEMENTVARIANT_ID = el.ELEMENTVARIANT_ID
		INNER JOIN @psfvalid hie on hie.REF_PRODUCT_ID = rel.PRODUCT_ID
		WHERE vok.REALKEYW = 1  --- To check if this is the right way
		) t Where t.KEYWORD in ('WEX PSF image')
		--	select 'test',* from #print --15041


			



		SELECT *FROM #print



END

IF (@pSection = 'PayloadVariant')
BEGIN 


	INSERT INTO #print(MATERIAL_ID, PRODUCT_ID,PRODUCT_NAME,PRODUCT_ORDERNR, VARIANT_ID, VARIANT_NAME ,PRAT_NAME,PRAT_ORDERNR, PRINT_SECTIONNAME)
		SELECT pra.PRODUCT_PRODUCTNR, tt.PRODUCT_ID,tt.PRODUCT_NAME, tt.PRODUCT_SEQORDERNR, pra.PRODUCT_ID, pra.PRODUCT_NAME, col.COLLMEMBER_NAME, col.COLL_ORDER, 'PayloadVariant'
		FROM VW_P_PRATVALUES pra 
		INNER JOIN [VW_PRODUCTS_HIERARCHY] tt on tt.PRODUCTVARIANT_ID = pra.PRODUCT_ID
		INNER JOIN VW_PRAT_COLLECTIONS col ON col.COLLMEMBER_NAME = pra.PRAT_NAME AND COLLMANAGER_NAME = 'WEX_PayloadPRV_COLL'
		INNER JOIN #Hierarchy hie on hie.REF_VARIANT_ID = pra.PRODUCT_ID		 
		
	


		Update pr set pr.PRAT_VALUE = val.PRATVALUE	,  pr.PRATVALUE_DICTID = val.PRATVALUE_DICTID , PRATVALUE_SHORTCUT = val.DICT_SHORTCUT, PRAT_DATATYPE = val.PRAT_DATATYPE ,PRAT_DICTID = dic.Id , PRAT_UOMPRINT = val.PRATVALUE_UNIT, PRINT_SECTIONNAME = @pSection
		FROM #print as pr 
		INNER JOIN VW_P_PRATVALUES val ON pr.VARIANT_ID = val.PRODUCT_ID and pr.PRAT_NAME collate DATABASE_DEFAULT  = val.PRAT_NAME collate DATABASE_DEFAULT
		INNER JOIN DICTIONARIES dic on   dic.SHORTCUT collate DATABASE_DEFAULT =    pr.PRAT_NAME collate DATABASE_DEFAULT
		
		SELECT *FROM #print order by VARIANT_ID, PRAT_ORDERNR



END


	DROP TABLE #print
END


