tarea_2: libname series 'D:\XinYuan Zheng\OneDrive\UCM\Tecnicas estadisticas para ciencia de datos\Tarea 2_ACP AF CLUSTER';
PROC IMPORT DATAFILE='D:\XinYuan Zheng\OneDrive\UCM\Tecnicas estadisticas para ciencia de datos\Tarea 2_ACP AF CLUSTER\Eurostat_A'
    OUT=series.euro
    DBMS=XLSX
    REPLACE;
    /*SHEET=''; /* Especifica la hoja de Excel, si es necesario */
    GETNAMES=YES; /* Si la primera fila tiene nombres de columnas */
RUN;
proc contents data=series.euro;
run;

/*1. Realizar un anaisis de componentes principales sobre la matriz de correlaciones.  Con cuantas componentes nos quedariamos? (seguir el criterio 
de autovalores estrictamente mayor que 1) */
proc princomp DATA=series.euro n=7 plots=all outstat=series.euro_corr ;
   var T_UNI -- T_Mort_Accidente;
run;

/*2. Hacer de nuevo el anaisis, pero ahora indicando el numero de componentes principales que hemos decidido retener. Sobre este anaisis contestar los siguientes apartados. */
proc princomp DATA=series.euro n=6 plots=all outstat=series.euro_corr_f out=series.euro_data;
   var T_UNI -- T_Mort_Accidente;
   id PAIS;
run;

	/*2.3. Que pais tiene mayor valor en dicha componente? */
data series.euro_data_abs;
   set series.euro_data;
   Abs_Prin2 = abs(Prin2); /* Crear columna con el valor absoluto */
run;
proc sort data=series.euro_data_abs out=series.prin2_abs;
   by descending Abs_Prin2; /* Ordenar por el valor absoluto en orden descendente */
run;
proc print data=series.prin2_abs (obs=5);
   var PAIS Prin2 Abs_Prin2; 
   title "Pais con el mayor valor en Prin2";
run;
quit;

/*3. Realizar un anaisis Factorial. */
proc factor data=series.euro corr outstat=series.factor_stats out=series.factor 
	residuals msa nfact=10;
    var T_UNI -- T_Mort_Accidente;
	title "Análisis Factorial";
run;
proc factor data=series.euro (drop=IPC) corr outstat=series.factor_stats out=series.factor 
	residuals msa nfact=10;
    var T_UNI -- T_Mort_Accidente;
	title "Analisis Factorial";
run;
title;

/*4. Con el conjunto de variables que hemos decidido mantener decidir el numero de factores adecuado.  */

proc factor data=series.euro (drop=IPC) corr outstat=series.factor_stats out=series.factor 
	residuals msa nfact=5 plots=all;
    var T_UNI -- T_Mort_Accidente;
	pathdiagram fuzz=0.6 scale=0.7 factorsize=0.8 novariance; 
run;

/*4.1. Realizar una rotacion VARIMAX o QUARTIMAX (la que de mejor resultado). Comparar para la rotacion escogida como han cambiado las cargas antes y despues de la rotación. */
proc factor data=series.euro (drop=IPC) corr outstat=series.factor_v_stats out=series.factor_v 
	residuals msa nfact=5 rotate=varimax plots=all;
    var T_UNI -- T_Mort_Accidente;
	pathdiagram fuzz=0.6 scale=0.8 factorsize=1 novariance; 
run;

proc factor data=series.euro (drop=IPC) corr outstat=series.factor_q_stats out=series.factor_q 
	residuals msa nfact=5 rotate=quartimax plots=all;
    var T_UNI -- T_Mort_Accidente;
	pathdiagram fuzz=0.6 scale=1 factorsize=1 novariance; 
run;

/*CON EL MODELO FACTORIAL ROTADO*/

proc factor data=series.euro (drop=IPC) corr outstat=series.factor_v_stats out=series.factor_v 
	residuals msa nfact=5 rotate=varimax plots=all;
    var T_UNI -- T_Mort_Accidente;
	pathdiagram fuzz=0.6 scale=0.8 factorsize=1 novariance; 
run;

/*4.5.	A partir del fichero que contiene los valores que tienen los paises en los nuevos factores, obtener una tabla en donde aparezcan los  paises: Espania, Alemania y Grecia, 
y sus valores en los factores (solo estos). Comentar que significado tienen estos valores */

proc print data=series.factor_v;
   var PAIS Factor1--Factor5; 
   where PAIS='Spain'or PAIS='Germany'or PAIS='Greece';
run;


/*4.6.	Representar el mapa de Europa por paises coloreado segun el valor del Factor 1, Factor2, Factor 3 y Factor4 (solo para estos independientemente del numero de Factores). 
Comentar cada uno de los graficos. */

goptions reset=all  border;
title1 'Paises segun satisfaccion de vida: Factor 1';
proc gmap map=maps.europe
          data=series.factor_v all;
	id id;
	choro Factor1/ ;
run;
quit;

goptions reset=all  border;
title1 'Paises segun poblacion joven: Factor 2';
proc gmap map=maps.europe
          data=series.factor_v all;
	id id;
	choro Factor2/ ;
run;
quit;

goptions reset=all  border;
title1 'Paises segun composicion demografica: Factor 3';
proc gmap map=maps.europe
          data=series.factor_v all;
	id id;
	choro Factor3/ ;
run;
quit;

goptions reset=all  border;
title1 'Paises segun mortalidad: Factor 4';
proc gmap map=maps.europe
          data=series.factor_v all;
	id id;
	choro Factor4/ ;
run;
quit;
title''

/*5. Cuanto vale la raiz de la media de los cuadrados de los residuales RMSR? Que nos dice este valor? Que variable tiene mayor suma de los residuos de sus correlaciones? ?Que significa esto? */
proc factor data=series.euro (drop=IPC) corr outstat=series.factor_v_stats out=series.factor_v 
	residuals msa nfact=5 rotate=varimax plots=all;
    var T_UNI -- T_Mort_Accidente;
	pathdiagram fuzz=0.6 scale=0.8 factorsize=1 novariance; 
run;





/*ANALISIS CLUSTER*/

/*1.1.Utilizar el metodo de Ward. Incluir la opcion Standard en la sentencia inicial del procedimiento para trabajar con las variables estandarizadas. */
proc cluster data=series.euro method=ward STANDARD RSQUARE PSEUDO PRINT= 15 SIMPLE outtree=series.euro_ward plots=all;
var T_UNI -- T_Mort_Accidente;
id PAIS;
copy PAIS id;
run;

/*1.4.	Realizar un proc tree sobre la salida del proc cluster para agrupar los individuos en el numero de clusteres elegido teniendo en cuenta los dos apartados anteriores. 
Mostrar una tabla con los paises para cada cluster. */
title''

proc tree data=series.euro_ward  out=series.euro_ward_pais n=6;
copy T_UNI -- T_Mort_Accidente PAIS id;
run;
proc sort data=series.euro_ward_pais;
   by cluster;
run;
proc print data=series.euro_ward_pais;
   var PAIS cluster;
   by cluster;
run;


/*2. Realizar un analisis cluster no jerarquico utilizando el numero de clusteres elegido sobre los datos estandarizados  */
title''
proc stdize data=series.euro method=std out=series.euro_std;
   var T_UNI -- T_Mort_Accidente;
run;

proc fastclus data=series.euro_std maxc=6 out=series.euro_std_pais outstat=series.std_pais_stat distance;
   var T_UNI -- T_Mort_Accidente;
   id PAIS;
run;

proc sort data=series.euro_std_pais;
   by cluster;
run;

proc print data=series.euro_std_pais;
   var PAIS cluster;
   by cluster;
   title "Paises Agrupados por Cluster (Analisis No Jerarquico)";
run;
title''

/*3. Elegir la agrupacion mas adecuada (jerarquica o no jerarquica) y representar el mapa de Europa con los paises coloreados segun el cluster al que pertenecen. */

proc print data=series.std_pais_stat;
run;

goptions reset=all  border;
title1 'Agrupacion de los paises segun los clusteres (jerarquico)';
proc gmap map=maps.europe
          data=series.euro_ward_pais all;
	id id;
	choro CLUSTER/discrete;
run;
quit;


/*4. Utilizando como variables los factores rotados obtenidos en el apartado 4 de la primera parte: */
proc factor data=series.euro (drop=IPC) corr outstat=series.factor_v_stats out=series.factor_v 
	residuals msa nfact=5 rotate=varimax plots=all;
    var T_UNI -- T_Mort_Accidente;
	pathdiagram fuzz=0.6 scale=0.8 factorsize=1 novariance; 
run;

/*4.1. Realizar un analisis cluster jerarquico del conjunto de datos. Utilizar el metodo de Ward. Incluir la opcion Standard en la sentencia inicial del procedimiento para trabajar con las variables
estandarizadas. Representar el dendrograma. Observando solo la grafica ?Que numero de clusteres recomendarias? */
proc cluster data=series.factor_v  method=ward STANDARD RSQUARE PSEUDO PRINT= 15 SIMPLE outtree=series.factor_v_ward plots=all;
var Factor1 -- Factor5;
id PAIS;
copy PAIS;
run;


/*4.2.	Realizar un analisis cluster no jerarquico utilizando el numero de clusteres elegido antes. Puesto que las variables son factores no es necesario estandarizar. */
proc fastclus data=series.factor_v maxc=6 out=series.factor_v_no outstat=series.factor_v_no_stat distance;
   var Factor1 -- Factor5;
   id PAIS;
run;

proc sort data=series.factor_v_no;
   by cluster;
run;

proc print data=series.factor_v_no;
   var PAIS cluster;
   by cluster;
   title "Paises Agrupados por Cluster (Analisis No Jerarquico)";
run;
title''



/*4.4.	Representar los graficos caja o los histogramas (lo que resulte mas interpretable en cada caso) de los factores para cada uno de los clusteres. Teniendo en cuenta las variables que 
representa cada factor interpretar las diferencias entre los clusteres de paises segun los valores que presentan en los factores. */

proc sgpanel data=series.factor_v_no; 
   panelby cluster / layout=rowlattice;
   hbox Factor1 / category=cluster; 
   hbox Factor2 / category=cluster; 
   hbox Factor3 / category=cluster; 
   hbox Factor4 / category=cluster; 
   hbox Factor5 / category=cluster; 
   colaxis label="Valores de los Factores"; 
   rowaxis label="Clusteres"; 
   title "Distribucion de Factores por Cluster";
run;


proc sgpanel data=series.factor_v_no; 
   panelby cluster / layout=rowlattice;
   histogram Factor1 / transparency=0.2;
   histogram Factor2 / transparency=0.2; 
   histogram Factor3 / transparency=0.2; 
   histogram Factor4 / transparency=0.2;
   histogram Factor5 / transparency=0.2; 
   colaxis label="Valores de los Factores"; 
   rowaxis label="Frecuencia"; 
   title "Distribucion de Factores por Cluster (Histograma)";
run;


proc sgpanel data=series.factor_v_no; 
   panelby cluster / layout=rowlattice; 
   
   /* Histogramas y densidades */
   histogram Factor1 / transparency=0.2 fillattrs=(color=blue) name="Factor1"; 
   density Factor1 / type=kernel lineattrs=(pattern=solid color=blue) legendlabel="Kernel Factor 1";
   density Factor1 / lineattrs=(pattern=dash color=blue) legendlabel="Normal Factor 1";
   
   histogram Factor2 / transparency=0.2 fillattrs=(color=red) name="Factor2"; 
   density Factor2 / type=kernel lineattrs=(pattern=solid color=red) legendlabel="Kernel Factor 2";
   density Factor2 / lineattrs=(pattern=dash color=red) legendlabel="Normal Factor 2";
   
   histogram Factor3 / transparency=0.2 fillattrs=(color=green) name="Factor3"; 
   density Factor3 / type=kernel lineattrs=(pattern=solid color=green) legendlabel="Kernel Factor 3";
   density Factor3 / lineattrs=(pattern=dash color=green) legendlabel="Normal Factor 3";
   
   histogram Factor4 / transparency=0.5 fillattrs=(color=brown) name="Factor4"; 
   density Factor4 / type=kernel lineattrs=(pattern=solid color=brown) legendlabel="Kernel Factor 4";
   density Factor4 / lineattrs=(pattern=dash color=brown) legendlabel="Normal Factor 4";
   
   histogram Factor5 / transparency=0.5 fillattrs=(color=purple) name="Factor5"; 
   density Factor5 / type=kernel lineattrs=(pattern=solid color=purple) legendlabel="Kernel Factor 5";
   density Factor5 / lineattrs=(pattern=dash color=purple) legendlabel="Normal Factor 5";

   /* Ejes y titulos */
   colaxis label="Valores de los Factores"; 
   rowaxis label="Frecuencia"; 
   title "Distribucion de Factores por Cluster";
   
   /* Leyenda */
   keylegend / across=3 position=bottom;
run;

/*EXTRA DE GRAFICA DE HISTOGRAMA PARA CADA CLUSTERES INDEPENDIETNEMENTE*/
%macro plot_by_cluster;
    %do i=1 %to 6; /* Asume que tienes 6 clusteres */
        proc sgpanel data=series.factor_v_no(where=(cluster=&i)); 
           panelby cluster / layout=rowlattice; 
           histogram Factor1 / transparency=0.2 fillattrs=(color=blue transparency=0.2);
           density Factor1 / type=kernel lineattrs=(pattern=solid color=blue);
           density Factor1 / lineattrs=(pattern=dash color=blue);
           
           histogram Factor2 / transparency=0.2 fillattrs=(color=red transparency=0.2);
           density Factor2 / type=kernel lineattrs=(pattern=solid color=red);
           density Factor2 / lineattrs=(pattern=dash color=red);
           
           histogram Factor3 / transparency=0.2 fillattrs=(color=green transparency=0.2);
           density Factor3 / type=kernel lineattrs=(pattern=solid color=green);
           density Factor3 / lineattrs=(pattern=dash color=green);
           
           histogram Factor4 / transparency=0.5 fillattrs=(color=brown transparency=0.2);
           density Factor4 / type=kernel lineattrs=(pattern=solid color=brown);
           density Factor4 / lineattrs=(pattern=dash color=brown);
           
           histogram Factor5 / transparency=0.5 fillattrs=(color=purple transparency=0.2);
           density Factor5 / type=kernel lineattrs=(pattern=solid color=purple);
           density Factor5 / lineattrs=(pattern=dash color=purple);
           
           colaxis label="Valores de los Factores"; 
           rowaxis label="Frecuencia"; 
           title "Distribucion de Factores para Cluster &i";
        run;
    %end;
%mend;

/* Llamar al macro */
%plot_by_cluster;












