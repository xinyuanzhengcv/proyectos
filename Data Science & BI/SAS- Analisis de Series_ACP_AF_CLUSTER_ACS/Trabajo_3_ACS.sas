tarea3_ACS: libname series 'D:\XinYuan Zheng\OneDrive\UCM\Tecnicas estadisticas para ciencia de datos\Tarea3_ACS';
PROC IMPORT DATAFILE='D:\XinYuan Zheng\OneDrive\UCM\Tecnicas estadisticas para ciencia de datos\Tarea3_ACS\Encuesta_calefaccion_hogares'
    OUT=series.calefaccion
    DBMS=XLSX
    REPLACE;
    GETNAMES=YES; 
	SHEET='Hoja1';
RUN;
proc contents data=series.calefaccion;
run;


data series.calefaccion;
    set series.calefaccion;
    rename 
        VAR2 = Electrica
        VAR4 = Gasoleo
        Calefacci_n_de_gas___Total = Gas
        Otros_sistemas_de_calefacci_n__T = Otros
		A = Viviendas;
run;
proc contents data=series.calefaccion;
run;

/*Mostrar dataset original*/
proc print data= series.calefaccion;
run;

data series.calefaccion;
    set series.calefaccion;
    /* Cambiar el formato de las variables */
    format Electrica Gasoleo Gas Otros 8.; /* Sin decimales */
run;
proc contents data=series.calefaccion;
run;

/* Comprobar si el dataset se puede ejecutar el analisis de correspondencias*/
proc corresp data=series.calefaccion outc=Resultados_prueba chi2p all;
	var Electrica Gasoleo Gas Otros;
    id Viviendas;
    ods output RowProfiles=PerfilFila;    
    ods output ColProfiles=PerfilColumna; 
    ods output CellChiSq=Aportaciones;    
run;

/*Transformar los valores de proporcion a frecuencias absolutas de viviendas */
data series.calefaccion;
    set series.calefaccion;
    Electrica = round(Electrica * 26689 / 100);  
    Gasoleo = round(Gasoleo * 26689 / 100);
    Gas = round(Gas * 26689 / 100);
    Otros = round(Otros * 26689 / 100);
run;
proc print data= series.calefaccion;
run;


proc corresp data=series.calefaccion outc=Resultados_prueba chi2p all;
	var Electrica Gasoleo Gas Otros;
    id Viviendas;
    ods output RowProfiles=PerfilFila;    
    ods output ColProfiles=PerfilColumna; 
    ods output CellChiSq=Aportaciones;    
run;



/*a) Realizar un PROC CORRESP. Guardar los perfiles fila, perfiles columna y la tabla de las contribuciones al estadístico Chicuadrado en ficheros con la opción ODS para 
construir los gráficos de líneas y un mapa de calor. (0.5) */

proc corresp data=series.calefaccion outc=ResultadosACS chi2p all;
	var Electrica Gasoleo Gas Otros;
    id Viviendas;
    ods output RowProfiles=PerfilFila;    
    ods output ColProfiles=PerfilColumna; 
    ods output CellChiSq=Aportaciones;    
run;

/*b) Representar los gráficos de líneas de los perfiles columna y perfiles fila acompañados de las tablas de dichos perfiles que aparecen en la salida del proc corresp. Comentar 
lo más destacado de ambos gráficos (2) */


/* Verificar la estructura de PerfilColumna */
proc contents data=PerfilColumna;
run;

/* Renombrar variables en PerfilColumna */
data PerfilColumna;
    set PerfilColumna;
    rename 
        Calefacci_n_el_ctrica_Total = Electrica
        Calefacci_n_por_gas_leo___Total = Gasoleo
        Calefacci_n_de_gas___Total = Gas
        Otros_sistemas_de_calefacci_n__T = Otros;
run;

/* Gráfico de perfiles columna */
proc sgplot data=PerfilColumna;
   series x=Label y=Electrica / lineattrs=(thickness=3) legendlabel="Eléctrica";
   series x=Label y=Gasoleo / lineattrs=(thickness=3) legendlabel="Gasóleo";
   series x=Label y=Gas / lineattrs=(thickness=3) legendlabel="Gas";
   series x=Label y=Otros / lineattrs=(thickness=3) legendlabel="Otros";
   yaxis label='Proporción';
   xaxis label='Tamaño de vivienda';
   title "Perfiles Columna: Distribución de las Viviendas según el tipo de calefacción";
run;
proc print data=PerfilColumna;
run;


/* Perfil fila */

data PerfilFila;
    set PerfilFila;
    rename 
        Calefacci_n_el_ctrica_Total = Electrica
        Calefacci_n_por_gas_leo___Total = Gasoleo
        Calefacci_n_de_gas___Total = Gas
        Otros_sistemas_de_calefacci_n__T = Otros;
run;
proc contents data=PerfilFila;
run;

proc transpose data=PerfilFila out=PerfilFilaT;
id Label;
run;

proc contents data=PerfilFilaT;
run;

proc sgplot data=PerfilFilaT;
    series x=_NAME_ y=Vivienda_con_1_persona / lineattrs=(thickness=3) legendlabel="1 Persona";
    series x=_NAME_ y=Vivienda_con_2_personas / lineattrs=(thickness=3) legendlabel="2 Personas";
    series x=_NAME_ y=Vivienda_con_3_personas / lineattrs=(thickness=3) legendlabel="3 Personas";
    series x=_NAME_ y=Vivienda_con_4_o_m_s_personas / lineattrs=(thickness=3) legendlabel="4 o Más Personas";
    yaxis label='Proporcion';
    xaxis label='Tipo de calefaccion';
    title "Perfiles de Fila: Distribución de tipo de calefaccion segun tamaño de vivienda";
run;
proc print data=PerfilFila;
run;

/*c) ¿Cómo se calculan los valores de la frecuencia esperada para el cálculo del estadístico Chicuadrado? Poner el ejemplo de uno. (0.5)*/

proc corresp data=series.calefaccion outc=ResultadosACS chi2p all;
	var Electrica Gasoleo Gas Otros;
    id Viviendas;
    ods output RowProfiles=PerfilFila;    
    ods output ColProfiles=PerfilColumna; 
    ods output CellChiSq=Aportaciones;    
run;

/*d) ¿Cuánto vale el estadístico Chicuadrado? ¿Qué nos dice este estadístico sobre la independencia entre las variables estudiadas? (0.5)*/


/*e) Representar el mapa de calor de las contribuciones al estadístico Chicuadrado y la tabla correspondiente ¿Que combinaciones de categorías aportan 
más al estadístico Chicuadrado? (1)  */
proc contents data=Aportaciones;
run;
data Aportaciones;
    set Aportaciones;
    rename 
        Calefacci_n_el_ctrica_Total = Electrica
        Calefacci_n_por_gas_leo___Total = Gasoleo
        Calefacci_n_de_gas___Total = Gas
        Otros_sistemas_de_calefacci_n__T = Otros;
run;
proc contents data=Aportaciones;
run;

data Aportaciones2(drop=Sum);
    set Aportaciones;
    if Label = "Sum" then delete; 
run;
/* Reestructurar la tabla para el mapa de calor */
data Aportaciones3(keep=filas col ff);
array vector{4} Electrica Gasoleo Gas Otros;
set Aportaciones2;
a=0;
do aux = '  Electrica', 'Gasoleo', 'Gas', 'Otros';
  a = a + 1;
  filas = aux;   
  col = Label;       
  ff = vector{a};  
  output;
end;
run;

/* Mapa de calor */
proc sgplot data=Aportaciones3;
    heatmap x=filas y=col /freq=ff  colormodel=TwoColorRamp;
    title "Aportaciones a Chi-cuadrado";
    xaxis label="Tipo de calefaccion";
    yaxis label="Tamaño de vivienda";
run;
title '';

proc print data=Aportaciones;
run;






/* f) ¿Qué porcentaje de la inercia queda explicado con los dos primeros autovalores? ¿Cuánto valen dichos autovalores? (0.5) */

proc corresp data=series.calefaccion outc=ResultadosACS chi2p all;
	var Electrica Gasoleo Gas Otros;
    id Viviendas;
    ods output RowProfiles=PerfilFila;    
    ods output ColProfiles=PerfilColumna; 
    ods output CellChiSq=Aportaciones;    
run;

/* g) Para los perfiles fila contestar a las siguientes preguntas acompañadas de la tabla correspondiente. (1.5)  */
proc corresp data=series.calefaccion outc=ResultadosACS dim=2 chi2p all;
	var Electrica Gasoleo Gas Otros;
    id Viviendas;
    ods output RowProfiles=PerfilFila;    
    ods output ColProfiles=PerfilColumna; 
    ods output CellChiSq=Aportaciones;    
run;

/* h) Para los perfiles columna contestar a las siguientes preguntas acompañadas de la tabla correspondiente (1.5) */



/*i) Comentar el gráfico conjunto que representa los perfiles fila y columna en el  plano factorial.  ¿Cómo se relacionan las categorías de las dos variables? (2) */


























