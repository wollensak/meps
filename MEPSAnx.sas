PROC PRINTTO;
RUN;

LIBNAME CDATA '/folders/myfolders/';
*LIBNAME CDATA "\\programs.ahrq.local\programs\meps\AHRQ4_CY2\B_CFACT\BJ001DVK\Workshop_2017\SAS\Data";
TITLE1 
	'ANALYSIS ON SEX VARIANCES FOR PEOPLE WHO REPORTED ANXIETY IN 2015 MEPS DATA';

/*Formatting values of sex and if respondant has anxiety*/
PROC FORMAT;
	VALUE SEX
     .='TOTAL' 1='MALE' 2='FEMALE';
	VALUE YESNO
     .='TOTAL' 1='YES' 2='NO';
RUN;

/*Pull out conditions with anxiety (CCS CODE='651') from 2015 PUF - HC180*/
DATA ANX;
	SET CDATA.H180;

	IF CCCODEX IN ('651');
RUN;

/*Pulls frequency table to show proportion of respondants who reported anxiety*/
TITLE3 "CHECK CCS CODES FOR ANXIETY";

PROC FREQ DATA=ANX;
	TABLES CCCODEX / LIST MISSING;
RUN;

/*Identify respondants who reported anxiety and assigns pk variable*/
PROC SORT DATA=ANX OUT=ANXPERS (KEEP=DUPERSID) NODUPKEY;
	BY DUPERSID;
RUN;

/*Creates a flag for people who reported anxiety*/
DATA FY1;
	MERGE CDATA.H181 (IN=AA) ANXPERS   (IN=BB);
	BY DUPERSID;
	LABEL ANXPERS='PERSONS WHO REPORTED ANXIETY';

	IF AA AND BB THEN
		ANXPERS=1;
	ELSE
		ANXPERS=2;
RUN;

/*Eliminates non responses from survey variables below so scale is 1-5 only*/
DATA FY2;
	SET FY1;
	LABEL MNHLTH53='Perceived mental health status from 1-5';
	LABEL ADOVER42='Can overcome illness without medical help 1-5';

	IF ADOVER42=-1 THEN
		ADOVER42=.;

	IF ADOVER42=-9 THEN
		ADOVER42=.;

	IF MNHLTH53=-1 THEN
		MNHLTH53=.;

	IF MNHLTH53=-9 THEN
		MNHLTH53=.;

	IF MNHLTH53=-8 THEN
		MNHLTH53=.;

	IF MNHLTH53=-7 THEN
		MNHLTH53=.;
RUN;

TITLE3 "Supporting crosstabs for the flag variables";
TITLE3 "UNWEIGHTED # OF PERSONS WHO REPORTED ANXIETY, 2015";

PROC FREQ DATA=FY1;
	TABLES ANXPERS ANXPERS * SEX / LIST MISSING;
	FORMAT SEX sex.
         ANXPERS yesno.;
RUN;

TITLE3 "WEIGHTED # OF PERSONS WHO REPORTED DIABETES, 2015";

PROC FREQ DATA=FY2;
	TABLES ANXPERS ANXPERS * SEX /LIST MISSING;
	WEIGHT PERWT15F;
	FORMAT SEX sex.
         ANXPERS yesno.
         ADOVER42 MNHLTH53;
RUN;

ODS GRAPHICS OFF;
ODS LISTING CLOSE;

/*Creates summary statistics for variables with weights and statrum to mitigate survey error*/
PROC SURVEYMEANS DATA=FY2 NOBS SUMWGT SUM STD MEAN STDERR;
	STRATA VARSTR;
	CLUSTER VARPSU;
	WEIGHT PERWT15F;
	DOMAIN ANXPERS('1') SEX*ANXPERS('1');
	VAR TOTEXP15 MNHLTH53 OBTOTV15 ADOVER42;
	ods output domain=work.domain_results;
RUN;

/*Prints results from previous command*/
TITLE3 
	"ESTIMATES ON VARIANCE BETWEEN SEXES FOR PERSONS WHO REPORTED ANXIETY, 2015";

PROC PRINT DATA=work.domain_results (DROP=DOMAINLABEL) NOOBS LABEL BLANKLINE=3;
	VAR SEX VARNAME N SUMWGT SUM STDDEV MEAN STDERR;
	FORMAT N comma6.0 SUMWGT SUM STDDEV comma17.0 MEAN STDERR comma9.2 ANXPERS 
		yesno.
       SEX sex.;
RUN;

PROC PRINTTO;
RUN;

/*Recalibrate data set so scale for anxiety/non-anxiety variable is 0-1*/
DATA FY3;
	SET FY2;

	IF ANXPERS=2 THEN
		ANXPERS=0;
RUN;

/*Formats so results show variables names*/
ODS GRAPHICS ON;

PROC FORMAT;
	VALUE SEX 1='MALE' 2='FEMALE';
	VALUE ANXPERS 1="REPORTED ANXIETY";
RUN;

TITLE4 'TESTING ON VARIANCE BETWEEN VARIOUS VARIABLES';

/*F-Test for pooled variance*/
/*Null: pooled variance*/
/*Alt: non pooled variance*/
/*Null: Male and female responders have the same perceived mental health status from 1-5)*/
/*Alt: Male and female responders have different perceived mental health status from 1-5*/
/*Incorporate wilcoxon test to explore further due to survey response data*/
ODS GRAPHICS OFF;

PROC TTEST DATA=FY2 H0=0 SIDES=2;
	WHERE ANXPERS=1;
	CLASS SEX;
	VAR MNHLTH53;
	WEIGHT PERWT15F;
RUN;

PROC NPAR1WAY WILCOXON MEDIAN DATA=FY3;
	WHERE ANXPERS=1;
	CLASS SEX;
	VAR MNHLTH53;
RUN;

ODS GRAPHICS ON;

/*Two-sample t test/*
/*Null: Total expenses in 2015 related to anxiety disorder are equal for male and female*/
/*Alt: Total expenses in 2015 are greater for females than males*/
PROC TTEST DATA=FY3 H0=0 SIDES=2;
	WHERE ANXPERS=1;
	CLASS SEX;
	VAR TOTEXP15;
RUN;

/*Null: Total OP visits in 2015 related to anxiety disorder are equal for male and female w/ anxiety*/
/*Alt: Total OP visits in 2015 are greater for females than males w/ anxiety*/
/*Incorporate wilcoxon test to explore further due to survey response data*/
PROC TTEST DATA=FY2 H0=0 SIDES=L;
	WHERE ANXPERS=1;
	CLASS SEX;
	VAR OBTOTV15;
	WEIGHT PERWT15F;
RUN;

PROC NPAR1WAY WILCOXON MEDIAN DATA=FY3;
	WHERE ANXPERS=1;
	CLASS SEX;
	VAR OBTOTV15;
RUN;

/*Null: Responders with anxiety disorder have equal amounts of OP visits for male and females*/
/*Alt: Overall  visits in 2015 are unequal for females than males with anxiety disorder*/
ODS GRAPHICS OFF;

PROC TTEST DATA=FY2 H0=0 SIDES=2;
	WHERE ANXPERS=1;
	CLASS SEX;
	VAR ADOVER42;
	WEIGHT PERWT15F;
RUN;

/*Null: Likelihood of reporting anxiety disorder is equal for males and femals*/
/*Alt: Likelihood of reporting anxiety disorder is greater for females than males*/
ODS GRAPHICS OFF;

PROC TTEST DATA=FY3 H0=0 SIDES=L;
	CLASS SEX;
	VAR ANXPERS;
	WEIGHT PERWT15F;
RUN;

/*Create data set that keeps only necessary variables to export*/
DATA FY4;
	SET FY3 (KEEP=ANXPERS MNHLTH53 SEX OBTOTV15 TOTEXP15 ADOVER42);
RUN;

/*exports data set to examine in tableau or excel*/
PROC EXPORT DATA=FY4 DBMS=XLS OUTFILE='/folders/myfolders/MEPS/MS48';
RUN;