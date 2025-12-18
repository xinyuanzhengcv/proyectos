Tarea_1_series: libname series 'D:\XinYuan Zheng\OneDrive\UCM\Tecnicas estadisticas para ciencia de datos\Tarea 1_Series';

proc import datafile='D:\XinYuan Zheng\OneDrive\UCM\Tecnicas estadisticas para ciencia de datos\Tarea 1_Series\Transporte Metro_Madrid.xlsx'
    out=series.metro_madrid
    dbms=xlsx
    replace;
    sheet='Metro_Madrid'; 
    getnames=yes; 
run;
proc contents data =series.metro_madrid;
run;

/* 1.1.	Introducción: Presentación de la serie a analizar. Representar la serie, comentar el gráfico. (0.5) */
data series.metro(keep= fecha viajeros);
set series.metro_madrid;
fecha=intnx('month', '01JAN2012'd, _n_ - 1);
   	format fecha date9.;
viajeros=viajeros_transportados_miles_*1000;
run;

proc sgplot data=series.metro;
    series x=fecha y=viajeros;
    xaxis interval=year; 
    format fecha year4.; 
run;
/* 1.2.	Analizar la tabla de los estadísticos por unidad temporal. ¿Cuál es el número mínimo que ha habido? ¿Cuándo? 
¿Cuál el máximo?  (0.5) */
proc sql;
select fecha, viajeros
from series.metro;
quit;
proc sql;
select fecha, viajeros
from series.metro
where viajeros= (select min(viajeros) from series.metro);
quit;
proc sql;
select fecha, viajeros
from series.metro
where viajeros= (select max(viajeros) from series.metro);
quit;

/*1.3.	Calcular los coeficientes de estacionalidad, mostrar su tabla  y su representación junto con la componente 
irregular. ¿Qué coeficiente es el mayor? ¿Qué significa? ¿Cuál es el menor? ¿Cuál es su significado?  (1) */

proc timeseries data=series.metro plots=(decomp series)
print=(seasons decomp);
id fecha interval=month;
var viajeros;
run;

/*1.4.	Representar la serie desestacionalizada, la estimación de la tendencia y el error. 
¿Qué dirías sobre la tendencia? ¿Y sobre su comportamiento estacional? (0.5) */

proc timeseries data=series.metro plots=(decomp series)
print=(seasons decomp);
id fecha interval=month;
var viajeros;
run;

/* 2.	Encontrar el método de suavizado más adecuado a la serie teniendo en cuenta las características de la serie y 
comparando las medidas de bondad de ajuste. Para el método elegido: */

/* metodo suavizado seasonal*/
proc esm data=series.metro lead=12 back=12
print= all
plots=all;
id fecha interval=month;
forecast viajeros /model=seasonal;
run;

/* metodo suavizado Holt Winter Aditivo*/
proc esm data=series.metro lead=12 back=12
print= all
plots=all;
id fecha interval=month;
forecast viajeros /model=addwinters;
run;


/* metodo suavizado Holt Winter Multiplicativo*/
proc esm data=series.metro lead=12 back=12
print= all
plots=all;
id fecha interval=month;
forecast viajeros /model=winters;
run;

/* 2.1.	Sobre las tablas de estimadores de los coeficientes del modelo ¿Cuánto vale la estimación de los parámetros 
de suavizado? ¿Qué podemos decir sobre los coeficientes del modelo de suavizado? Escribir las ecuaciones del modelo. (1) */

/* metodo suavizado Holt Winter Multiplicativo*/
proc esm data=series.metro lead=12 back=12
print= all
plots=all;
id fecha interval=month;
forecast viajeros /model=winters;
run;
/*2.5.	Mostrar una tabla y gráfico en donde aparecen los valores observados, las predicciones  y sus intervalos de confianza, 
sólo para el último periodo que habíamos reservado.. ¿Cómo se comportan los intervalos de confianza? (1) */

proc esm data=series.metro lead=12 back=12
print= all
plots=all
outfor=series.pred_hwm;
id fecha interval=month;
forecast viajeros /model=winters;
run;

proc sql;
create table series.pred_hwm_12 as
select *
from series.pred_hwm
where fecha >= '01AUG2023'd;
quit;

proc print data=series.pred_hwm_12 label;
run;


/* 3.	Para ajustar un modelo ARIMA: */

data series.metro_train series.metro_test;
set series.metro;
if fecha<'01AUG2023'd then output series.metro_train;
else output series.metro_test ; 
run;


/* 3.1.	Representar la serie y los correlogramas. Hacer las diferenciaciones que sean necesarias.
Decidir qué modelo puede ser ajustado. (0.5) */

proc arima data=series.metro_train;
identify var=viajeros nlag=24;
run;

proc arima data=series.metro_train;
identify var=viajeros(1) nlag=24;
run;

proc arima data=series.metro_train;
identify var=viajeros(1 12) nlag=24;
run;

proc arima data=series.metro_train;
identify var=viajeros(1 12) nlag=24;
estimate p=(12);
run;
proc arima data=series.metro_train;
identify var=viajeros(1 12) nlag=24;
estimate q=(12);
run;

proc arima data=series.metro_train;
identify var=viajeros(1 12) nlag=24;
estimate q=(3)(12);
run;
proc arima data=series.metro_train;
identify var=viajeros(1 12) nlag=24;
estimate p=(3) q=(12);
run;

/*3.4.	Calcular las predicciones y los intervalos de confianza para las unidades de tiempo que se considere oportuno,
dependiendo de la serie, siguientes al último valor observado. Representarlas gráficamente. (1) */

proc arima data=series.metro_train;
identify var=viajeros(1 12) nlag=24;
estimate p=(3) q=(12);
forecast lead=12 id=fecha interval=month out=series.pred_arima printall;
quit;
data union; 
merge series.metro_test series.pred_arima(drop=viajeros); where fecha>='01AUG2023'd; by fecha; 
run;  
proc sgplot data=union;  band Upper=u95 Lower=l95 x=fecha 
      / LegendLabel="95% Confidence Limits";    scatter x=fecha y=viajeros; series x=fecha y=forecast; 
run;
proc print data=union label;
var fecha viajeros Forecast Std L95 U95;
run;
proc sql;
   create table series.pred_arima_12 as
   select fecha, viajeros, forecast, std, l95, u95
   from union;
quit;
 










































