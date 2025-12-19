##########################################################################################################################
# 1. Cargar librerías
##########################################################################################################################

if(!require('MASS')){install.packages('MASS')}
if(!require('dplyr')){install.packages('dplyr')}
if(!require('e1071')){install.packages('e1071')}
if(!require('summarytools')){install.packages('summarytools')}
if (!require("writexl")) install.packages("writexl")
if (!require("arrow")) install.packages("arrow")

library(MASS)
library(dplyr)
library(e1071)
library(summarytools)
library(writexl)
library(arrow)


##########################################################################################################################
# 2. EDA
##########################################################################################################################

setwd('D:\\XinYuan Zheng\\OneDrive\\UCM\\TFM\\TFM_Codigo')
source('FuncionesMineria.R') # Módulo con funciones auxiliares


# 2.1. Importación del conjunto de datos y extracción de nombres y registros

datos_std <- read_parquet("datos_std.parquet")
str(datos_std)


datos_std$fecha <- as.Date(datos_std$fecha)
dfSummary(datos_std)


# -----------------------------------------------------------------------------
# Librerías necesarias
if (!require("ggplot2")) install.packages("ggplot2")
if (!require("dplyr")) install.packages("dplyr")
if (!require("tidyr")) install.packages("tidyr")
if (!require("gridExtra")) install.packages("gridExtra")

library(ggplot2)
library(dplyr)
library(tidyr)
library(gridExtra)

# -----------------------------------------------------------------------------
# Grafica de linea temporal para la variable objetivo
# -----------------------------------------------------------------------------

ggplot(datos_std, aes(x = fecha, y = chamartin)) +
  geom_line(color = "steelblue", size = 0.7) +
  labs(
    #title = "Serie Temporal de Afluencia en Chamartín",
    x = "Fecha",
    y = "Afluencia"
  ) +
  theme_minimal()

# -----------------------------------------------------------------------------
# Grafica de correlacion con la varObj
# -----------------------------------------------------------------------------

# Paso 1: Filtrar solo variables numéricas continuas útiles
variables_validas <- datos_std %>%
  select(where(is.numeric)) %>%
  select_if(~ length(unique(.)) > 2) %>%
  select(-chamartin)

# Nombres de variables válidas
vars_cor <- names(variables_validas)

# Paso 2: Generar gráficos de 9 en 9
bloque <- 1
for (i in seq(1, length(vars_cor), by = 9)) {
  vars_bloque <- vars_cor[i:min(i+8, length(vars_cor))]
  
  datos_long <- datos_std %>%
    select(all_of(vars_bloque), chamartin) %>%
    pivot_longer(-chamartin, names_to = "variable", values_to = "valor")
  
  p <- ggplot(datos_long, aes(x = valor, y = chamartin)) +
    geom_point(alpha = 0.3, color = "darkblue") +
    geom_smooth(method = "lm", se = FALSE, color = "red") +
    facet_wrap(~ variable, scales = "free_x", ncol = 3) +
    labs(title = paste("Correlación con la variable objetiva 'Chamartín' - Bloque", bloque),
         x = "", y = "Chamartín") +
    theme_minimal()
  
  print(p)
  bloque <- bloque + 1
}


# -----------------------------------------------------------------------------
# Mapa de calor de correlacion 
# -----------------------------------------------------------------------------
if (!require("corrplot")) install.packages("corrplot")
if (!require("dplyr")) install.packages("dplyr")

library(corrplot)
library(dplyr)

# Seleccionar solo variables numéricas continuas y lags
cor_vars <- datos_std %>%
  select(where(is.numeric)) %>%
  select(where(~ length(unique(.)) > 2))

# Reordenar para que 'chamartin' esté en primer lugar
vars_ordenados <- c("chamartin", setdiff(colnames(cor_vars), "chamartin"))
cor_vars <- cor_vars[, vars_ordenados]

# Matriz de correlación
cor_matrix <- cor(cor_vars, use = "complete.obs")

# Mapa de calor
corrplot(cor_matrix,
         method = "color",
         type = "full",       
         tl.cex = 0.6,
         tl.col = "black",
         diag = TRUE,
         #title = "Matriz de Correlación con 'chamartin' Primero",
         mar = c(0,0,2,0))

# -----------------------------------------------------------------------------
# Distribución de Variables Dummy (0/1)
# -----------------------------------------------------------------------------

# Seleccionar variables dummy (valores 0 y 1)
dummies <- datos_std %>%
  select(where(is.integer)) %>%
  select(where(~ all(. %in% c(0, 1)))) %>%
  mutate(id = row_number()) %>%
  pivot_longer(-id, names_to = "variable", values_to = "valor")

# Gráfico de barras
ggplot(dummies, aes(x = variable, fill = factor(valor))) +
  geom_bar(position = "fill") +
  scale_y_continuous(labels = scales::percent) +
  labs(
    # title = "Distribución de Variables Dummy (0/1)",
    x = "Variable",
    y = "Proporción",
    fill = "Valor"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


##########################################################################################################################
# 2. Importación de conjunto de datos
##########################################################################################################################


# 2.1. Importación del conjunto de datos y extracción de nombres y registros

datos <- read_parquet("datos.parquet")
str(datos)


datos$fecha <- as.Date(datos$fecha)
dfSummary(datos)

##########################################################################################################################
# 3. Preprocesamiento y depuración de datos
##########################################################################################################################

# 3.1. Eliminar columnas sin variabilidad (todas 0 o todas 1)
cols_sin_var <- names(datos)[sapply(datos, function(x) length(unique(x)) == 1)]
df <- datos[, !(names(datos) %in% cols_sin_var)]

summary(df)

# Verificar si hay missing values en el conjunto de datos
sum(is.na(df))



df_clean_std=  df %>% select(-fecha)

# -----------------------------------------------------------------------------
# 3.2. Separar variable objetivo e input variables
# -----------------------------------------------------------------------------
# La variable objetivo será "chamartin"
varObj <- df_clean_std$chamartin


# Las variables de entrada serán todas las columnas excepto "chamartin"
input <- df_clean_std[, setdiff(names(df_clean_std), "chamartin")]

# Verificación rápida de los resultados
summary(input)
str(varObj)

# -----------------------------------------------------------------------------
# 8. Guardar los datos finales estandarizados
# -----------------------------------------------------------------------------
save(varObj, input, file = "df_clean_std.Rdata")
write_xlsx(df_clean_std, "df_clean_std.xlsx")



##########################################################################################################################
# 5.	Modelado y seleccion de variables 
##########################################################################################################################

library(parallel)
library(doParallel)

GS_T0 <- Sys.time()
cluster <- makeCluster(detectCores() - 1) 
registerDoParallel(cluster) 

options(width = 200)  

# ------------------------------------------
# 0. Cargar datos y librerías necesarias
# ------------------------------------------
library(caret)
library(MASS)
library(leaps)
library(Boruta)
library(MXM)
library(glmnet)
library(randomForest)


load("df_clean_std.Rdata")
source("cruzadas avnnet y lin.R")
source("funcion steprepetido.R")

data <- data.frame(chamartin = varObj, input)

# ------------------------------------------
# 1. Modelo Stepwise AIC y BIC
# ------------------------------------------
modelo_full <- lm(chamartin ~ ., data = data)

# Stepwise AIC
modelo_step_AIC <- stepAIC(modelo_full, direction = "both", trace = FALSE)
vars_AIC <- names(coef(modelo_step_AIC))[-1]
dput(vars_AIC)

# Stepwise BIC
modelo_step_BIC <- stepAIC(modelo_full, direction = "both", trace = FALSE, k = log(nrow(data)))
vars_BIC <- names(coef(modelo_step_BIC))[-1]
dput(vars_BIC)

# ------------------------------------------
# 2. Step Repetido (AIC y BIC)
# ------------------------------------------

# Para criterio AIC:
step_AIC_rep <- steprepetido(
  data = data,
  vardep = "chamartin",
  listconti = colnames(data)[-1],
  sinicio = 12345,
  sfinal = 12385,
  porcen = 0.7,
  criterio = "AIC"
)

# Mostrar la tabla de modelos obtenida
tabla_AIC <- step_AIC_rep[[1]]
print(tabla_AIC)

# Filtrar los modelos con al menos 1 variable (excluyendo el modelo nulo)
tabla_AIC_valida <- tabla_AIC %>% filter(contador > 0)

# Encontrar la frecuencia máxima
max_freq <- max(tabla_AIC_valida$Freq)

# Filtrar solo los modelos con frecuencia máxima
modelos_max_freq <- tabla_AIC_valida %>% filter(Freq == max_freq)

# Encontrar el mínimo contador entre esos modelos
min_contador <- min(modelos_max_freq$contador)

# Filtrar solo los modelos con frecuencia máxima y mínimo contador
modelo_final <- modelos_max_freq %>% filter(contador == min_contador)

# Seleccionar el primer modelo (en caso de empate)
modelo_mas_frec_AIC <- modelo_final$modelo[1]

# Buscar la posición del modelo seleccionado dentro de la tabla original
indice_AIC <- which(tabla_AIC$modelo == modelo_mas_frec_AIC)[1]

# Extraer las variables asociadas a ese modelo
vars_STEP_rep_AIC <- step_AIC_rep[[2]][[indice_AIC]]
dput(vars_STEP_rep_AIC)

# ------------------------------------------------------------------
# Para criterio BIC:
step_BIC_rep <- steprepetido(
  data = data,
  vardep = "chamartin",
  listconti = colnames(data)[-1],
  sinicio = 12345,
  sfinal = 12385,
  porcen = 0.7,
  criterio = "BIC"
)

# Mostrar la tabla de modelos obtenida
tabla_BIC <- step_BIC_rep[[1]]
print(tabla_BIC)

# Filtrar los modelos con al menos 1 variable (para evitar el modelo nulo)
tabla_BIC_valida <- tabla_BIC %>% filter(contador > 0)

# Encontrar la frecuencia máxima
max_freq <- max(tabla_BIC_valida$Freq)

# Filtrar solo los modelos con frecuencia máxima
modelos_max_freq <- tabla_BIC_valida %>% filter(Freq == max_freq)

# Encontrar el mínimo contador entre esos modelos
min_contador <- min(modelos_max_freq$contador)

# Filtrar solo los modelos con frecuencia máxima y mínimo contador
modelo_final <- modelos_max_freq %>% filter(contador == min_contador)

# Seleccionar el primer modelo (en caso de empate)
modelo_mas_frec_BIC <- modelo_final$modelo[1]

# Buscar la posición del modelo seleccionado en la tabla original
indice_BIC <- which(tabla_BIC$modelo == modelo_mas_frec_BIC)[1]

# Extraer las variables del modelo seleccionado
vars_STEP_rep_BIC <- step_BIC_rep[[2]][[indice_BIC]]
dput(vars_STEP_rep_BIC)

# ------------------------------------------
# 3. Modelo Leaps (best subsets)
# ------------------------------------------
modelo_leaps <- regsubsets(chamartin ~ ., data = data, nvmax = 20)
leaps_summary <- summary(modelo_leaps)
mejor_modelo <- which.max(leaps_summary$adjr2)
vars_LEAPS <- names(coef(modelo_leaps, mejor_modelo))[-1]
dput(vars_LEAPS)

# ------------------------------------------
# 4. Modelo RFE (Recursive Feature Elimination)
# ------------------------------------------
control_rfe <- rfeControl(functions = lmFuncs, method = "repeatedcv", number = 10, repeats = 10)
set.seed(123456)
# Usamos las columnas predictoras de "data" (todas excepto "chamartin") y la variable respuesta data$chamartin
modelo_rfe <- rfe(data[, -1], data$chamartin, sizes = c(5, 10, 15, 20), rfeControl = control_rfe)
vars_RFE <- predictors(modelo_rfe)
dput(vars_RFE)

# ------------------------------------------
# 5. Modelo Boruta
# ------------------------------------------
set.seed(123456)
modelo_boruta <- Boruta(data[, -1], data$chamartin, doTrace = 0)
modelo_boruta_fix <- TentativeRoughFix(modelo_boruta)
vars_BORUTA <- getSelectedAttributes(modelo_boruta_fix, withTentative = FALSE)
dput(vars_BORUTA)

# ------------------------------------------
# 6. Modelos MXM: MMPC y SES
# ------------------------------------------
# MMPC
set.seed(123456)
modelo_mmpc <- MMPC(target = data$chamartin, dataset = data[, -1], test = "testIndFisher")
vars_MMPC <- colnames(data)[modelo_mmpc@selectedVars]
dput(vars_MMPC)
# SES
set.seed(123456)
modelo_ses <- SES(target = data$chamartin, dataset = data[, -1], test = "testIndFisher")
vars_SES <- colnames(data)[modelo_ses@selectedVars]
dput(vars_SES)

# ------------------------------------------
# 7. Modelos LASSO y RIDGE
# ------------------------------------------
x <- as.matrix(data[, -1])
y <- data$chamartin

# LASSO
set.seed(123456)
cv_lasso <- cv.glmnet(x, y, alpha = 1)
coef_lasso <- coef(cv_lasso, s = "lambda.min")
vars_LASSO <- rownames(coef_lasso)[coef_lasso[, 1] != 0][-1]
dput(vars_LASSO)
# RIDGE
set.seed(123456)
cv_ridge <- cv.glmnet(x, y, alpha = 0)
coef_ridge <- coef(cv_ridge, s = "lambda.min")
vars_RIDGE <- rownames(coef_ridge)[coef_ridge[, 1] != 0][-1]
dput(vars_RIDGE)

# ------------------------------------------
# 8. Random Forest importancia
# ------------------------------------------
set.seed(123456)
modelo_rf <- randomForest(data[, -1], data$chamartin, importance = TRUE)
importancia_rf <- importance(modelo_rf)
vars_RF <- rownames(importancia_rf)[order(importancia_rf[, "%IncMSE"], decreasing = TRUE)][1:20]
dput(vars_RF)

# ------------------------------------------
# 9. Aplicar CV repetida y comparar modelos
# ------------------------------------------
set.seed(123456)
grupos <- 10
repe <- 10

# Cada método se evalúa usando la función 'cruzadalin' sobre el dataset "data" y las variables obtenidas del paso anterior

# Método 1: Stepwise AIC (regular) – usar vars_AIC
medias1 <- cruzadalin(data, "chamartin", 
                      listconti =c("sol", "antonio_machado", "avenida_de_la_paz", "bambu", "begona", 
                                   "colombia", "cuzco", "estrecho", "fuencarral", "hortaleza", "manoteras", 
                                   "penagrande", "pinar_de_chamartin", "plaza_de_castilla", "pio_xii", 
                                   "valdezarza", "ventilla", "dia_semana_martes", "dia_semana_miercoles", 
                                   "dia_semana_jueves", "dia_semana_viernes", "dia_semana_sabado", 
                                   "dia_semana_domingo", "tipo_dia_laborable", "lag_1", "lag_7"),
                      listclass = c(""), grupos, 123456, repe)
medias1$modelo <- "AIC"

# Método 2: Stepwise BIC (regular) – usar vars_BIC
medias2 <- cruzadalin(data, "chamartin", 
                      listconti =c("sol", "antonio_machado", "avenida_de_la_paz", "bambu", "colombia", 
                                   "cuzco", "estrecho", "fuencarral", "penagrande", "plaza_de_castilla", 
                                   "ventilla", "dia_semana_martes", "dia_semana_miercoles", "dia_semana_jueves", 
                                   "dia_semana_viernes", "dia_semana_sabado", "dia_semana_domingo", 
                                   "tipo_dia_laborable", "lag_1", "lag_7"), 
                      listclass = c(""), grupos, 123456, repe)
medias2$modelo <- "BIC"

# Método 3: STEP_rep_AIC (usando vars_STEP_rep_AIC obtenidas)
medias3 <- cruzadalin(data, "chamartin", 
                      listconti = c("plaza_de_castilla", "lag_7", "bambu", "valdezarza", "colombia", 
                                    "tipo_dia_laborable", "tipo_dia_fin_de_semana", "avenida_de_la_paz", 
                                    "begona", "dia_semana_jueves", "dia_semana_miercoles", "lag_2", 
                                    "dia_semana_viernes", "dia_semana_martes", "cuzco", "pio_xii", 
                                    "ventilla", "prec_alta"), 
                      listclass = c(""), grupos, 123456, repe)
medias3$modelo <- "STEP_rep_AIC"

# Método 4: STEP_rep_BIC (usando vars_rep_BIC obtenidas)
medias4 <- cruzadalin(data, "chamartin", 
                      listconti = c("plaza_de_castilla", "lag_7", "cuzco", "bambu", "valdezarza", 
                                    "tipo_dia_laborable"), 
                      listclass = c(""), grupos, 123456, repe)
medias4$modelo <- "STEP_rep_BIC"

# Método 5: LEAPS – usar vars_LEAPS
medias5 <- cruzadalin(data, "chamartin", 
                      listconti = c("sol", "antonio_machado", "avenida_de_la_paz", "bambu", "colombia", 
                                    "cuzco", "estrecho", "fuencarral", "penagrande", "plaza_de_castilla", 
                                    "pio_xii", "ventilla", "dia_semana_martes", "dia_semana_miercoles", 
                                    "dia_semana_jueves", "dia_semana_viernes", "dia_semana_sabado", 
                                    "tipo_dia_laborable", "lag_1", "lag_2", "tipo_dia_fin_de_semana"), 
                      listclass = c(""), grupos, 123456, repe)
medias5$modelo <- "LEAPS"

# Método 6: RFE – usar vars_RFE
medias6 <- cruzadalin(data, "chamartin", 
                      listconti =c("plaza_de_castilla", "dia_semana_sabado", "dia_semana_jueves", 
                                   "tipo_dia_laborable", "pinar_de_chamartin", "dia_semana_miercoles", 
                                   "avenida_de_la_paz", "fuencarral", "bambu", "dia_semana_martes", 
                                   "dia_semana_domingo", "dia_semana_viernes", "antonio_machado", 
                                   "penagrande", "cuzco", "ventilla", "estrecho", "pio_xii", "hortaleza", 
                                   "valdezarza", "begona", "manoteras", "lag_1", "colombia", "arturo_soria", 
                                   "prec_alta", "tetuan", "herrera_oria", "lag_7", "alfonso_xiii", 
                                   "duque_de_pastrana", "barrio_del_pilar", "sol", "nuevos_ministerios", 
                                   "valdeacederas", "hrmedia", "prec_media", "cruz_del_rayo", "santiago_bernabeu", 
                                   "concha_espina", "velmedia", "tmed", "lag_2", "tipo_dia_fin_de_semana"), 
                      listclass = c(""), grupos, 123456, repe)
medias6$modelo <- "RFE"

# Método 7: BORUTA – usar vars_BORUTA
medias7 <- cruzadalin(data, "chamartin", 
                      listconti = c("tmed", "sol", "hrmedia", "alfonso_xiii", "antonio_machado", 
                                    "arturo_soria", "avenida_de_la_paz", "bambu", "barrio_del_pilar", 
                                    "begona", "colombia", "concha_espina", "cruz_del_rayo", "cuzco", 
                                    "duque_de_pastrana", "estrecho", "fuencarral", "herrera_oria", 
                                    "hortaleza", "manoteras", "nuevos_ministerios", "penagrande", 
                                    "pinar_de_chamartin", "plaza_de_castilla", "pio_xii", "santiago_bernabeu", 
                                    "tetuan", "valdeacederas", "valdezarza", "ventilla", "dia_semana_sabado", 
                                    "dia_semana_domingo", "tipo_dia_fin_de_semana", "lag_1", "lag_2", 
                                    "lag_7"), 
                      listclass = c(""), grupos, 123456, repe)
medias7$modelo <- "BORUTA"

# Método 8: MMPC – usar vars_MMPC
medias8 <- cruzadalin(data, "chamartin", 
                      listconti = c("hrmedia", "avenida_de_la_paz", "nuevos_ministerios", "penagrande", 
                                    "pinar_de_chamartin", "lag_2"), 
                      listclass = c(""), grupos, 123456, repe)
medias8$modelo <- "MMPC"

# Método 9: SES – usar vars_SES
medias9 <- cruzadalin(data, "chamartin", 
                      listconti = c("hrmedia", "nuevos_ministerios", "pinar_de_chamartin", "lag_2"), 
                      listclass = c(""), grupos, 123456, repe)
medias9$modelo <- "SES"

# Método 10: LASSO – usar vars_LASSO
medias10 <- cruzadalin(data, "chamartin", 
                       listconti = c("tmed", "velmedia", "sol", "hrmedia", "antonio_machado", "arturo_soria", 
                                     "avenida_de_la_paz", "bambu", "barrio_del_pilar", "begona", "colombia", 
                                     "concha_espina", "cruz_del_rayo", "cuzco", "duque_de_pastrana", 
                                     "estrecho", "fuencarral", "herrera_oria", "hortaleza", "manoteras", 
                                     "nuevos_ministerios", "penagrande", "pinar_de_chamartin", "plaza_de_castilla", 
                                     "pio_xii", "santiago_bernabeu", "tetuan", "valdeacederas", "valdezarza", 
                                     "ventilla", "prec_alta", "prec_media", "dia_semana_martes", "dia_semana_miercoles", 
                                     "dia_semana_jueves", "dia_semana_viernes", "dia_semana_sabado", 
                                     "tipo_dia_laborable", "tipo_dia_fin_de_semana", "lag_1", "lag_2", 
                                     "lag_7"), 
                       listclass = c(""), grupos, 123456, repe)
medias10$modelo <- "LASSO"

# Método 11: RIDGE – usar vars_RIDGE
medias11 <- cruzadalin(data, "chamartin", 
                       listconti =c("tmed", "velmedia", "sol", "hrmedia", "alfonso_xiii", "antonio_machado", 
                                    "arturo_soria", "avenida_de_la_paz", "bambu", "barrio_del_pilar", 
                                    "begona", "colombia", "concha_espina", "cruz_del_rayo", "cuzco", 
                                    "duque_de_pastrana", "estrecho", "fuencarral", "herrera_oria", 
                                    "hortaleza", "manoteras", "nuevos_ministerios", "penagrande", 
                                    "pinar_de_chamartin", "plaza_de_castilla", "pio_xii", "santiago_bernabeu", 
                                    "tetuan", "valdeacederas", "valdezarza", "ventilla", "prec_alta", 
                                    "prec_media", "dia_semana_martes", "dia_semana_miercoles", "dia_semana_jueves", 
                                    "dia_semana_viernes", "dia_semana_sabado", "dia_semana_domingo", 
                                    "tipo_dia_laborable", "tipo_dia_fin_de_semana", "lag_1", "lag_2", 
                                    "lag_7"), 
                       listclass = c(""), grupos, 123456, repe)
medias11$modelo <- "RIDGE"

# Método 12: RF_importancia – usar vars_RF
medias12 <- cruzadalin(data, "chamartin", 
                       listconti = c("lag_7", "plaza_de_castilla", "santiago_bernabeu", "nuevos_ministerios", 
                                     "lag_1", "lag_2", "fuencarral", "concha_espina", "colombia", 
                                     "begona", "pio_xii", "ventilla", "herrera_oria", "cruz_del_rayo", 
                                     "duque_de_pastrana", "arturo_soria", "valdezarza", "penagrande", 
                                     "estrecho", "barrio_del_pilar"), 
                       listclass = c(""), grupos, 123456, repe)
medias12$modelo <- "RF"

# Unión de resultados
union_resultados <- rbind(
  medias1, medias2, medias3, medias4, medias5, medias6,
  medias7, medias8, medias9, medias10, medias11, medias12
)

orden_modelos <- union_resultados %>%
  group_by(modelo) %>%
  summarise(media_error = mean(error)) %>%
  arrange(media_error) %>%
  pull(modelo)

union_resultados$modelo <- factor(union_resultados$modelo, levels = orden_modelos)


# --------------------------------------------
# 10. Visualización gráfica del error por modelo
# --------------------------------------------
par(mar = c(8, 8, 4, 2), mgp = c(5, 1, 0))
boxplot(data = union_resultados,
        error ~ modelo,
        col = "lightpink",
        main = "Comparación de Modelos (ordenado por error)",
        ylab = "Error (MSE)",
        las = 1,
        cex.axis = 0.8)

union_resultados$error2 <- sqrt(union_resultados$error)
boxplot(data = union_resultados, error2 ~ modelo, col = "lightgreen",
        main = "Comparación RMSE por modelo", 
        xlab = "Modelo", ylab = "RMSE",
        las = 1,
        cex.axis = 0.8)

# --------------------------------------------
# 11. Tabla resumen: Número de variables, MSE y RMSE por método
# --------------------------------------------
# Primero, definimos la lista de variables para cada método:
lista_vars <- list(
  AIC = vars_AIC,
  BIC = vars_BIC,
  STEP_rep_AIC = vars_STEP_rep_AIC,
  STEP_rep_BIC = vars_STEP_rep_BIC,
  LEAPS = vars_LEAPS,
  RFE = vars_RFE,
  BORUTA = vars_BORUTA,
  MMPC = vars_MMPC,
  SES = vars_SES,
  LASSO = vars_LASSO,
  RIDGE = vars_RIDGE,
  RF_importancia = vars_RF
)

#  Tabla resumen

tabla_resumen <- union_resultados %>%
  group_by(modelo) %>%
  summarise(
    n_variables = length(lista_vars[[as.character(first(modelo))]]),
    MSE = mean(error),
    RMSE = sqrt(mean(error))
  )
print(tabla_resumen)


# --------------------------------------------
# 12. Tabla 2: Matriz de variables por método (marcando "X" si se seleccionó la variable)
# --------------------------------------------
variables_totales <- colnames(data)[-1]
matriz_seleccion <- matrix("", 
                           nrow = length(variables_totales), 
                           ncol = 12,
                           dimnames = list(variables_totales,
                                           c("AIC", "BIC", "STEP_rep_AIC", "STEP_rep_BIC", "LEAPS", "RFE", "BORUTA",
                                             "MMPC", "SES", "LASSO", "RIDGE", "RF")))
lista_vars <- list(
  AIC = vars_AIC,
  BIC = vars_BIC,
  STEP_rep_AIC = vars_STEP_rep_AIC,
  STEP_rep_BIC = vars_STEP_rep_BIC,
  LEAPS = vars_LEAPS,
  RFE = vars_RFE,
  BORUTA = vars_BORUTA,
  MMPC = vars_MMPC,
  SES = vars_SES,
  LASSO = vars_LASSO,
  RIDGE = vars_RIDGE,
  RF_Importancia = vars_RF
)
for (metodo in names(lista_vars)) {
  vars_seleccionadas <- lista_vars[[metodo]]
  matriz_seleccion[variables_totales %in% vars_seleccionadas, metodo] <- "X"
}
tabla_matriz <- as.data.frame(matriz_seleccion)
tabla_matriz <- tibble::rownames_to_column(tabla_matriz, "Variable")
print(tabla_matriz)


##########################################################################################################################
# Revisar multicolinealidad
##########################################################################################################################

if(!require('glmnet')){install.packages('glmnet')}
library(caret)
library(car)
library(glmnet)


# Calcular matriz de correlación
correlation_matrix <- cor(data[, c("plaza_de_castilla", "lag_7", "cuzco", "bambu", "valdezarza", 
                                   "tipo_dia_laborable")])


# Visualizar matriz de correlación
library(corrplot)

corrplot(correlation_matrix,
         method = "circle",           # Círculos
         type = "full",               # Mostrar matriz completa (incluyendo diagonal)
         addCoef.col = "white",       # Mostrar valores de correlación
         tl.col = "black",              # Color de los textos del eje
         tl.srt = 90,                 # Rotación de etiquetas eje X
         number.cex = 0.8,            # Tamaño de los valores dentro de los círculos
         diag = TRUE)                 # Mostrar la diagonal


set.seed(123456)
control <- trainControl(method = "repeatedcv", number = 10, repeats = 10, savePredictions = "all")
reg_rep_BIC <- train(chamartin ~ plaza_de_castilla + lag_7 + cuzco + bambu + valdezarza + tipo_dia_laborable ,
                 data = data,
                 method = "lm",
                 trControl = control)
print(summary(reg_rep_BIC$finalModel))
reg_rep_BIC$results

# Verificación de multicolinealidad
vif_values <- vif(reg_rep_BIC$finalModel)
print(vif_values)


##########################################################################################################################
##### Ajustar variables altamente correlacionados ########
##########################################################################################################################


# Calcular matriz de correlación
correlation_matrix <- cor(data[, c("plaza_de_castilla", "lag_7", "tipo_dia_laborable")])
print(correlation_matrix)

# Visualizar matriz de correlación 

corrplot(correlation_matrix,
         method = "circle",           # Círculos
         type = "full",               # Mostrar matriz completa (incluyendo diagonal)
         addCoef.col = "white",       # Mostrar valores de correlación
         tl.col = "black",              # Color de los textos del eje
         tl.srt = 90,                 # Rotación de etiquetas eje X
         number.cex = 0.8,            # Tamaño de los valores dentro de los círculos
         diag = TRUE,
         xlab(0.7))                 # Mostrar la diagonal

# Verificación de multicolinealidad
set.seed(123456)
control <- trainControl(method = "repeatedcv", number = 10, repeats = 10, savePredictions = "all")
reg_rep_BIC <-  train(chamartin ~ plaza_de_castilla + lag_7 +  tipo_dia_laborable ,
                      data = data,
                     method = "lm",
                     trControl = control)
print(summary(reg_rep_BIC$finalModel))
reg_rep_BIC$results

vif_values <- vif(reg_rep_BIC$finalModel)
print(vif_values)



##########################################################################################################################
# 6.	Evaluación de Modelos mediante Validación Cruzada Repetida
##########################################################################################################################

# --------------------------------------------------------------------
# Modelo final basado en rep BIC (con 3 variables)
# --------------------------------------------------------------------
vardep <- "chamartin"
vars_rep_BIC <-  c("plaza_de_castilla", "lag_7", "tipo_dia_laborable")
formula_rep_BIC <- as.formula(paste(vardep, "~", paste(vars_rep_BIC, collapse = " + ")))

set.seed(123456)
control <- trainControl(method = "cv", number = 10,  savePredictions = "all")
avnnetgrid <- expand.grid(size = 1:15,
                          decay = c(0.1, 0.01, 0.001),
                          bag = FALSE)

redavnnet <- train(formula_rep_BIC,
                   data = data,  # 'data' es nuestro dataset completo
                   method = "avNNet",
                   linout = TRUE,
                   maxit = 100,
                   tuneGrid = avnnetgrid,
                   trControl = control,
                   trace = FALSE)
print(redavnnet)

# Crear boxplot del modelo final
resultados <- redavnnet$results
resultados$Modelo <- paste0("size=", resultados$size, ", decay=", resultados$decay)
ggplot(resultados, aes(x = reorder(Modelo, RMSE), y = RMSE)) +
  geom_point(color = "steelblue", size = 3) +
  geom_segment(aes(xend = Modelo, y = 0, yend = RMSE), color = "lightgray") +
  labs(#title = "Comparación de RMSE por combinación de hiperparámetros",
       x = "Combinación (size, decay)", y = "RMSE") +
  scale_y_continuous(limits = c(min(resultados$RMSE) - 0.01, max(resultados$RMSE) + 0.01))+
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 60, hjust = 1))


# 723obs/20=36,15.  36,5= h(3+1)+h+1 --> h=7.03 max. 
# VAMOS A PROBAR NODOS DE 3,5,8,10

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Red neuronal
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

# Parámetros
decay_values <- c(0.1, 0.01, 0.001)
listaiter <- c( 100, 300, 500, 700, 1000)
control <- trainControl(method = "repeatedcv", number = 10, repeats = 10,
                        savePredictions = "all")

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# SEMILLA 123456
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

# NODOS = 3
medias_red3 <- data.frame()
set.seed(123456)

for (iter in listaiter) {
  modelo <- train(
    chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
    data = data,
    method = "avNNet",
    linout = TRUE,
    maxit = iter,
    trControl = control,
    tuneGrid = expand.grid(size = 3, decay = decay_values, bag = FALSE),
    trace = FALSE
  )
  
  modelo$results$itera <- iter
  medias_red3 <- rbind(medias_red3, modelo$results)
}

medias_red3$modelo <- "Red3"

# NODOS = 5
medias_red5 <- data.frame()
set.seed(123456)

for (iter in listaiter) {
  modelo <- train(
    chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
    data = data,
    method = "avNNet",
    linout = TRUE,
    maxit = iter,
    trControl = control,
    tuneGrid = expand.grid(size = 5, decay = decay_values, bag = FALSE),
    trace = FALSE
  )
  
  modelo$results$itera <- iter
  medias_red5 <- rbind(medias_red5, modelo$results)
}

medias_red5$modelo <- "Red5"

# NODOS = 8
medias_red8 <- data.frame()
set.seed(123456)

for (iter in listaiter) {
  modelo <- train(
    chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
    data = data,
    method = "avNNet",
    linout = TRUE,
    maxit = iter,
    trControl = control,
    tuneGrid = expand.grid(size = 8, decay = decay_values, bag = FALSE),
    trace = FALSE
  )
  
  modelo$results$itera <- iter
  medias_red8 <- rbind(medias_red8, modelo$results)
}

medias_red8$modelo <- "Red8"


# UNIR TODOS LOS RESULTADOS

union_redes <- rbind(
  medias_red3, medias_red5, medias_red8
)

union_redes

union_redes <- union_redes %>%
  mutate(
    size = case_when(
      grepl("Red3", modelo) ~ 3,
      grepl("Red5", modelo) ~ 5,
      grepl("Red8", modelo) ~ 8
    )
  )

library(ggplot2)

ggplot(union_redes, aes(x = itera, y = RMSE, color = as.factor(decay))) +
  geom_point(size = 3) +
  geom_line(aes(group = decay), linewidth = 1) +
  facet_wrap(~ size, labeller = label_both) +
  theme_minimal() +
  scale_y_continuous(limits = c(0.22, 0.25)) +
  theme(panel.border = element_rect(color = "black", fill = NA),
        strip.text = element_text(size = 14),
        axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(#title = "Tuneo por número de nodos (semilla 123456)",
       x = "Iteraciones", y = "RMSE", color = "Decay")



#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Validacion cruzada 
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––


control_final <- trainControl(method = "repeatedcv", number = 10, repeats = 10,
                              savePredictions = "all")

# Red3
set.seed(123456)
final_red3 <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "avNNet",
  linout = TRUE,
  maxit = 500,
  trControl = control_final,
  tuneGrid = expand.grid(size = 3, decay = 0.01, bag = FALSE),
  trace = FALSE
)

# Red5
set.seed(123456)
final_red5 <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "avNNet",
  linout = TRUE,
  maxit = 300,
  trControl = control_final,
  tuneGrid = expand.grid(size = 5, decay = 0.1, bag = FALSE),
  trace = FALSE
)

# Red8
set.seed(123456)
final_red8 <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "avNNet",
  linout = TRUE,
  maxit = 300,
  trControl = control_final,
  tuneGrid = expand.grid(size = 8, decay = 0.1, bag = FALSE),
  trace = FALSE
)



# Extraer los errores de predicción
res_red3 <- final_red3$pred %>% mutate(modelo = "Red3")
res_red5 <- final_red5$pred %>% mutate(modelo = "Red5")
res_red8 <- final_red8$pred %>% mutate(modelo = "Red8")

# Unir todos
union_redes_final <- bind_rows(res_red3, res_red5, res_red8)

# Calcular RMSE por repetición
rmse_final <- union_redes_final %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

# Boxplot comparativo
ggplot(rmse_final, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(#title = "Comparación final de RMSE por número de nodos",
       x = "Modelo", y = "RMSE") +
  theme_minimal()



r2_final <- union_redes_final %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_final, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(#title = "Comparación final de R² por número de nodos",
       x = "Modelo", y = "R²") +
  theme_minimal()


mejor_modelo_red <- final_red5$results
mejor_modelo_red



# elegimos red5 por la simpleza y menos variabilidad  sumado a la poca diferencia de RMSE comparado con red8 





#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Regresion
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––



library(caret)

control <- trainControl(method = "repeatedcv", number = 10,repeats = 10,
                        savePredictions = "all")

### SEMILLA 123456
set.seed(123456)
modelo_reg <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "lm",
  trControl = control
)
medias_reg <- modelo_reg$resample
medias_reg$modelo <- "Regresión"


# Validacion cruzada 

final_reg <- modelo_reg


# Errores individuales por repetición para gráficas
res_reg <- final_reg$pred %>%
  mutate(modelo = "Regresión")


rmse_reg <- res_reg %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_reg, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(title = "RMSE - Regresión lineal",
       x = "Modelo", y = "RMSE") +
  theme_minimal()


r2_reg <- res_reg %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_reg, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "R² - Regresión lineal",
       x = "Modelo", y = "R²") +
  theme_minimal()



mejor_modelo_reg <-  final_reg$results
mejor_modelo_reg

# MODELOS FINALES SELECCIOANDOS PARA COMPARAR 

union_modelos_finales <- bind_rows(res_reg, res_red5)

# Orden deseado de los modelos en el eje x
orden_modelos <- c("Regresión", "Red5")

# Convertir a factor ordenado
union_modelos_finales$modelo <- factor(union_modelos_finales$modelo, levels = orden_modelos)

rmse_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_union, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(title = "Comparación final de RMSE por modelo",
       x = "Modelo", y = "RMSE") +
  theme_minimal()

r2_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_union, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "Comparación final de R² por modelo",
       x = "Modelo", y = "R²") +
  theme_minimal()



#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Ridge
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
if(!require(glmnet))install.packages("glmnet")
if(!require(caret))install.packages("caret")
if(!require(dplyr))install.packages("dplyr")

library(glmnet)
library(caret)
library(dplyr)


# Detectar best_lambda inicial

set.seed(123456)
ridge_lambda <- cv.glmnet(
  as.matrix(data[,c("plaza_de_castilla", "lag_7", "tipo_dia_laborable")]),
  data$chamartin, alpha = 0, nfolds = 10
)
ridge_best_lambda <- ridge_lambda$lambda.min
ridge_best_lambda


set.seed(123456)
medias_ridge <- train(
  chamartin ~ plaza_de_castilla + lag_7 +  tipo_dia_laborable,
  data      = data,
  method    = "glmnet",
  tuneGrid  = expand.grid(alpha = 0, lambda = ridge_best_lambda),
  trControl = trainControl(method = "repeatedcv", number = 10,repeats = 10,
                           savePredictions = "all")
)

medias_ridge

# Guardamos el modelo como final
final_ridge <- medias_ridge


res_ridge <- final_ridge$pred %>%
  mutate(modelo = "Ridge")


mejor_modelo_ridge <- medias_ridge
mejor_modelo_ridge


# MODELOS FINALES SELECCIOANDOS PARA COMPARAR 
union_modelos_finales <- bind_rows(res_reg, res_red5, res_ridge)

# Orden deseado de los modelos en el eje x
orden_modelos <- c("Regresión", "Red5", "Ridge")

# Convertir a factor ordenado
union_modelos_finales$modelo <- factor(union_modelos_finales$modelo, levels = orden_modelos)

rmse_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_union, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(title = "Comparación final de RMSE por modelo",
       x = "Modelo", y = "RMSE") +
  theme_minimal()

r2_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_union, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "Comparación final de R² por modelo",
       x = "Modelo", y = "R²") +
  theme_minimal()


#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Lasso
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––


set.seed(123456)
lasso_lambda <- cv.glmnet(
  as.matrix(data[, c("plaza_de_castilla", "lag_7", "tipo_dia_laborable")]),
  data$chamartin, alpha = 1, nfolds = 10
)
lasso_best_lambda <- lasso_lambda$lambda.min
lasso_best_lambda


set.seed(123456)
medias_lasso <- train(
  chamartin ~ plaza_de_castilla + lag_7 +  tipo_dia_laborable,
  data      = data,
  method    = "glmnet",
  tuneGrid  = expand.grid(alpha = 1, lambda = lasso_best_lambda),
  trControl = trainControl(method = "repeatedcv", number = 10,repeats = 10,
                           savePredictions = "all")
)

medias_lasso

# Guardar como modelo final
final_lasso <- medias_lasso

res_lasso <- final_lasso$pred %>%
  mutate(modelo = "Lasso")


mejor_modelo_lasso <- medias_lasso
mejor_modelo_lasso


# MODELOS FINALES SELECCIOANDOS PARA COMPARAR 
union_modelos_finales <- bind_rows(res_reg, res_red5, res_ridge, res_lasso)
# Orden deseado de los modelos en el eje x
orden_modelos <- c("Regresión", "Red5", "Ridge", "Lasso")

# Convertir a factor ordenado
union_modelos_finales$modelo <- factor(union_modelos_finales$modelo, levels = orden_modelos)

rmse_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_union, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(title = "Comparación final de RMSE por modelo",
       x = "Modelo", y = "RMSE") +
  theme_minimal()

r2_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_union, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "Comparación final de R² por modelo",
       x = "Modelo", y = "R²") +
  theme_minimal()




#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Random Forest – Tuneo de ntree manual con caret
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

library(caret)
library(randomForest)
library(dplyr)

# Grid de mtry 
grid_rf <- expand.grid(mtry = 1:3)

set.seed(123456)
control_rf <- trainControl(method = "repeatedcv", number = 10,repeats = 10, 
                           savePredictions = "all", verboseIter = TRUE)
modelo_rf <- train(chamartin ~ plaza_de_castilla + lag_7 +  tipo_dia_laborable,
                   data = data,
                   method = "rf",
                   trControl = control_rf,
                   tuneGrid = grid_rf,
                   ntree = 1000, nodesize = 10, replace = TRUE,
                   importance = TRUE)

plot(modelo_rf)

# ----------------------------------
# OOB Error Evolution (randomForest directo)
# ----------------------------------
if (!require('randomForest')) install.packages("randomForest")
library(randomForest)

set.seed(123456)
rf_oob <- randomForest(chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
          data = data, mtry = 2, ntree = 1000, replace = TRUE)

# Calcular RMSE acumulado por número de árboles
rmse_oob <- sqrt(rf_oob$mse)

# Graficar
plot(rmse_oob, type = "l", lwd = 2,
     # main = "RMSE OOB vs Número de árboles (Random Forest)",
     xlab = "Número de árboles (ntree)",
     ylab = "Error OOB (RMSE)")


set.seed(123456)
rf_oob <- randomForest(chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
                       data = data, mtry = 2, ntree = 400, replace = TRUE)

# Calcular RMSE acumulado por número de árboles
rmse_oob <- sqrt(rf_oob$mse)

# Graficar
plot(rmse_oob, type = "l", lwd = 2,
     main = "RMSE OOB vs Número de árboles (Random Forest)",
     xlab = "Número de árboles (ntree)",
     ylab = "Error OOB (RMSE)")


# Tuneo 


control_rf <- trainControl(
  method = "repeatedcv",
  number = 10,
  repeats = 10,
  savePredictions = "all"
)

lista_nodesize <- c(5, 10, 20)
res_rf_nodesize <- data.frame()

# Guardamos los errores de predicción por modelo
for (n in lista_nodesize) {
  set.seed(123456)
  modelo <- train(
    chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
    data = data,
    method = "rf",
    trControl = control_rf,
    tuneGrid = expand.grid(mtry = 2),
    ntree = 200,
    nodesize = n
  )
  
  errores <- modelo$pred %>%
    mutate(modelo = paste0("RF_node", n))
  
  res_rf_nodesize <- bind_rows(res_rf_nodesize, errores)
}

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Gráficas comparativas
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

# RMSE por repetición
rmse_rf_nodesize <- res_rf_nodesize %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_rf_nodesize, aes(x = modelo, y = RMSE, fill = modelo)) +
  geom_boxplot(fill = "pink") +
  labs(# title = "Comparación RMSE por nodesize",
       x = "Modelo", y = "RMSE") +
  theme_minimal()

# R² por repetición
r2_rf_nodesize <- res_rf_nodesize %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_rf_nodesize, aes(x = modelo, y = R2, fill = modelo)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "Comparación R² por nodesize",
       x = "Modelo", y = "R²") +
  theme_minimal()


# elegimos nodesize=20, simplifca el arbol


set.seed(123456)

final_rf <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "rf",
  trControl = control_rf,   # Ya definido antes
  tuneGrid = expand.grid(mtry = 2),
  ntree = 200,
  nodesize = 20
)

# Extraer errores individuales
res_rf <- final_rf$pred %>%
  mutate(modelo = "RF")

# Mostrar mejor configuración global
mejor_modelo_rf <- final_rf$results
mejor_modelo_rf



# MODELOS FINALES SELECCIONADOS PARA COMPARAR 
union_modelos_finales <- bind_rows(res_reg, res_red5, res_ridge, res_lasso, res_rf)
# Orden deseado de los modelos en el eje x
orden_modelos <- c("Regresión", "Red5", "Ridge", "Lasso", "RF")

# Convertir a factor ordenado
union_modelos_finales$modelo <- factor(union_modelos_finales$modelo, levels = orden_modelos)

rmse_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_union, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(title = "Comparación final de RMSE por modelo",
       x = "Modelo", y = "RMSE") +
  theme_minimal()

r2_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_union, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "Comparación final de R² por modelo",
       x = "Modelo", y = "R²") +
  theme_minimal()


#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# XGBoost
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
if(!require(xgboost))install.packages("xgboost")
library(xgboost)

# Definir grid de hiperparámetros
grid_xgb <- expand.grid(
  nrounds = c(300, 500, 1000),
  eta = c(0.1, 0.01, 0.001),
  max_depth = c(3, 5),
  gamma = 0,
  colsample_bytree = 1,
  min_child_weight = c(3, 5),
  subsample = 1
)

# -------------------------
# Modelo con semilla 123456
# -------------------------
set.seed(123456)
control_xgb <- trainControl(method = "repeatedcv", number = 10,repeats = 5,
                             savePredictions = "all")
modelo_xgb <- train(chamartin ~ plaza_de_castilla + lag_7 +  tipo_dia_laborable,
                     data = data,
                     method = "xgbTree",
                     trControl = control_xgb,
                     tuneGrid = grid_xgb,
                     verbose = FALSE)


medias_xgb <- modelo_xgb$results



medias_xgb <- modelo_xgb$results %>%
  mutate(
    min_child_weight = as.factor(min_child_weight),
    eta = as.factor(eta),
    max_depth = as.factor(max_depth)
  )

# Gráfico facetado con líneas diferenciadas
ggplot(medias_xgb, aes(x = nrounds, y = RMSE, color = eta, 
                       shape = max_depth, linetype = max_depth, group = interaction(eta, max_depth))) +
  geom_point(size = 2) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~ min_child_weight, labeller = label_both) +
  theme_minimal() +
  theme(
    panel.border = element_rect(color = "black", fill = NA),
    strip.text = element_text(size = 13),
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  labs(
    # title = "Tuneo XGBoost: RMSE por número de árboles (semilla 123456)",
    x = "Número de árboles (nrounds)",
    y = "RMSE",
    color = "Eta",
    shape = "max_depth",
    linetype = "max_depth"
  )


# elegimos eta=0.01, nrounds=500 y min_child_weight=3



# Control de CV repetida
control_xgb <- trainControl(method = "repeatedcv", number = 10, repeats = 10,
                            savePredictions = "all")

#------------------------
# Entrenamiento final
#------------------------
set.seed(123456)
final_xgb <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "xgbTree",
  trControl = control_xgb,
  tuneGrid = expand.grid(
    nrounds = 500, eta = 0.01, max_depth = 3,
    gamma = 0, colsample_bytree = 1,
    min_child_weight = 5, subsample = 1
  ),
  verbose = FALSE
)
final_xgb

#------------------------
# Extracción de errores
#------------------------
res_xgb <- final_xgb$pred %>% mutate(modelo = "XGB")

# Mostrar mejor configuración global
mejor_modelo_xgb <- final_xgb$results
mejor_modelo_xgb



# MODELOS FINALES SELECCIOANDOS PARA COMPARAR 
union_modelos_finales <- bind_rows(res_reg, res_red5, res_ridge, res_lasso, res_rf, res_xgb)
# Orden deseado de los modelos en el eje x
orden_modelos <- c("Regresión", "Red5", "Ridge", "Lasso", "RF", "XGB")

# Convertir a factor ordenado
union_modelos_finales$modelo <- factor(union_modelos_finales$modelo, levels = orden_modelos)

rmse_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_union, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(title = "Comparación final de RMSE por modelo",
       x = "Modelo", y = "RMSE") +
  theme_minimal()

r2_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_union, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "Comparación final de R² por modelo",
       x = "Modelo", y = "R²") +
  theme_minimal()


#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# LightGBM
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
if (!require(lightgbm)) install.packages("lightgbm")
library(lightgbm)


# Variables predictoras
X <- as.matrix(data[, c("plaza_de_castilla", "lag_7", "tipo_dia_laborable")])
y <- data$chamartin

# GRID de parámetros
param_grid <- expand.grid(
  nrounds = c(300, 500, 1000),
  learning_rate = c(0.1, 0.01, 0.001),
  num_leaves = c(3, 5),
  colsample_bytree = 1,
  subsample = 1,
  min_data_in_leaf = c(3, 5),
  gamma = 0
)

# Semilla y folds
set.seed(123456)
folds <- createFolds(y, k = 10, list = TRUE)

# Inicializar resultados
medias_lgbm <- data.frame()

for (i in 1:nrow(param_grid)) {
  rmse_fold <- c()
  r2_fold <- c()
  
  for (fold in folds) {
    dtrain <- lgb.Dataset(data = X[-fold, ], label = y[-fold])
    
    modelo <- lgb.train(
      params = list(
        objective = "regression", metric = "rmse",
        learning_rate = param_grid$learning_rate[i],
        num_leaves = param_grid$num_leaves[i],
        min_data_in_leaf = param_grid$min_data_in_leaf[i],
        colsample_bytree = 1, subsample = 1, verbose = -1
      ),
      data = dtrain,
      nrounds = param_grid$nrounds[i]
    )
    
    pred <- predict(modelo, X[fold, ])
    yval <- y[fold]
    
    rmse_fold <- c(rmse_fold, sqrt(mean((yval - pred)^2)))
    r2_fold <- c(r2_fold, cor(yval, pred)^2)
  }
  
  medias_lgbm <- rbind(medias_lgbm, data.frame(
    nrounds = param_grid$nrounds[i],
    learning_rate = param_grid$learning_rate[i],
    num_leaves = param_grid$num_leaves[i],
    min_data_in_leaf = param_grid$min_data_in_leaf[i],
    RMSE = mean(rmse_fold),
    RMSESD = sd(rmse_fold),
    R2 = mean(r2_fold),
    R2SD = sd(r2_fold),
    modelo = "LGBM"
  ))
}

# Gráfico facetado para evaluar RMSE
medias_lgbm <- medias_lgbm %>%
  mutate(
    learning_rate = as.factor(learning_rate),
    num_leaves = as.factor(num_leaves),
    min_data_in_leaf = as.factor(min_data_in_leaf)
  )

ggplot(medias_lgbm, aes(x = nrounds, y = RMSE,
                        color = learning_rate,
                        linetype = min_data_in_leaf,
                        group = interaction(learning_rate, min_data_in_leaf))) +
  geom_point(size = 2.5) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~ num_leaves, labeller = label_both) +
  theme_minimal() +
  theme(
    panel.border = element_rect(color = "black", fill = NA),
    strip.text = element_text(size = 13),
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  labs(
    #title = "Tuneo LightGBM: RMSE vs nrounds (semilla 123456)",
    x = "nrounds", y = "RMSE",
    color = "learning_rate", linetype = "min_data_in_leaf"
  )

#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Modelo Final LGBM (mejores hiperparámetros)
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

# Crear folds para CV repetida
set.seed(123456)
folds_final <- createMultiFolds(y, k = 10, times = 10)

res_lgbm <- data.frame()

for (i in seq_along(folds_final)) {
  train_idx <- folds_final[[i]]
  test_idx <- setdiff(1:nrow(data), train_idx)
  
  dtrain <- lgb.Dataset(data = X[train_idx, ], label = y[train_idx])
  
  modelo <- lgb.train(
    params = list(
      objective = "regression", metric = "rmse",
      learning_rate = 0.1, num_leaves = 3, min_data_in_leaf = 5,
      colsample_bytree = 1, subsample = 1, verbose = -1
    ),
    data = dtrain,
    nrounds = 500
  )
  
  pred <- predict(modelo, X[test_idx, ])
  
  res_lgbm <- bind_rows(res_lgbm, data.frame(
    pred = pred, obs = y[test_idx],
    Resample = names(folds_final)[i],
    modelo = "LGBM"
  ))
}

# Guardar modelo final
final_lgbm <- modelo

# Estadísticas resumen
mejor_modelo_lgbm <- res_lgbm %>%
  summarise(
    modelo = "LGBM",
    RMSE = sqrt(mean((obs - pred)^2)),
    R2 = cor(pred, obs)^2,
    MAE = mean(abs(obs - pred))
  )
mejor_modelo_lgbm



# MODELOS FINALES SELECCIOANDOS PARA COMPARAR 
union_modelos_finales <- bind_rows(res_reg, res_red5, res_ridge, res_lasso, res_rf, res_xgb, res_lgbm)
# Orden deseado de los modelos en el eje x
orden_modelos <- c("Regresión", "Red5", "Ridge", "Lasso", "RF", "XGB", "LGBM")

# Convertir a factor ordenado
union_modelos_finales$modelo <- factor(union_modelos_finales$modelo, levels = orden_modelos)

rmse_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_union, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(title = "Comparación final de RMSE por modelo",
       x = "Modelo", y = "RMSE") +
  theme_minimal()

r2_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_union, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "Comparación final de R² por modelo",
       x = "Modelo", y = "R²") +
  theme_minimal()


#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# SVR
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––


# SVR LINEAL
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
if (!require(kernlab)) install.packages("kernlab")
library(kernlab)

# Control de CV repetida
control_svr <- trainControl(method = "repeatedcv", number = 10, repeats = 10, 
                            savePredictions = "all")

# Grid de hiperparámetros a probar
grid_svr_lineal <- expand.grid(C = c(0.5, 0.1, 0.01, 0.001))

# Entrenamiento para comparar combinaciones
set.seed(123456)
medias_svr_lineal <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "svmLinear",
  trControl = control_svr,
  tuneGrid = grid_svr_lineal
)

# Visualizar combinaciones probadas
medias_svr_lineal$results

# Extraer resultados del objeto train
df_svr_lineal <- medias_svr_lineal$results %>%
  mutate(C = as.factor(C))

# Gráfico de RMSE por C
ggplot(df_svr_lineal, aes(x = C, y = RMSE, group = 1)) +
  geom_point(size = 3, color = "blue") +
  geom_line(aes(group = 1), linewidth = 1, color = "blue") +
  theme_minimal() +
  theme(
    panel.border = element_rect(color = "black", fill = NA),
    strip.text = element_text(size = 13),
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  labs(
    #title = "Tuneo SVR Lineal: RMSE vs C (semilla 123456)",
    x = "C", y = "RMSE"
  )


# Modelo final SVR Lineal con C = 0.1

set.seed(123456)

control_final_svr <- trainControl(method = "repeatedcv",
                                  number = 10, repeats = 10,
                                  savePredictions = "all")

final_svr_lineal <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "svmLinear",
  trControl = control_final_svr,
  tuneGrid = expand.grid(C = 0.1)
)

# Ver resultado del modelo final (RMSE y R² medios)
final_svr_lineal


# Errores individuales por fold (para boxplot)

res_svr_lineal <- final_svr_lineal$pred %>%
  mutate(modelo = "SVR_lineal")
res_svr_lineal




#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Tuneo SVR Polinomial: Buscar mejor degree (grado del polinomio)
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

# Control de CV repetida
control_svr_poly <- trainControl(method = "repeatedcv", number = 10, repeats = 10, 
                                 savePredictions = "all")

# Grid para buscar mejor degree (fijamos C y scale)
grid_svr_poly <- expand.grid(
  degree = c(2, 3, 4),
  scale = c(1, 0.5, 0.1, 0.01, 0.001),
  C = c(1, 0.5, 0.1, 0.01, 0.001)
)

# Entrenamiento para tuning de degree
set.seed(123456)
medias_svr_poly <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "svmPoly",
  trControl = control_svr_poly,
  tuneGrid = grid_svr_poly
)

# Asegurar que scale y C son factores
df_svr_poly <- medias_svr_poly$results %>%
  mutate(
    degree = as.factor(degree),
    scale = as.factor(scale),
    C = as.factor(C)
  )

# Gráfico facetado por degree
ggplot(df_svr_poly, aes(x = scale, y = RMSE, color = C, group = C)) +
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  facet_wrap(~ degree, labeller = label_both) +
  theme_minimal() +
  theme(
    panel.border = element_rect(color = "black", fill = NA),
    strip.text = element_text(size = 13),
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  labs(
    # title = "Tuneo SVR Polinomial: RMSE por degree (semilla 123456)",
    x = "scale",
    y = "RMSE",
    color = "C"
  )


# Modelo final SVR Polinomial con degree = 2, scale = 0.1 y C = 0.1

set.seed(123456)

control_final_svr_poly <- trainControl(method = "repeatedcv",
                                       number = 10, repeats = 10,
                                       savePredictions = "all")

final_svr_poly <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "svmPoly",
  trControl = control_final_svr_poly,
  tuneGrid = expand.grid(
    degree = 2,
    scale = 0.1,
    C = 0.1
  )
)

# Ver resultados medios del modelo
final_svr_poly

# Extraer errores individuales para gráficos comparativos
res_svr_poly <- final_svr_poly$pred %>%
  mutate(modelo = "SVR_poli")

res_svr_poly




#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
# Tuneo SVR Radial: Buscar mejor combinación de C y sigma
#––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

# Control de CV repetida
control_svr_radial <- trainControl(method = "repeatedcv", number = 10, repeats = 10, 
                                   savePredictions = "all")

# Grid de hiperparámetros
grid_svr_radial <- expand.grid(
  sigma = c(0.001, 0.01, 0.1, 0.5),
  C = c(1, 0.5, 0.1, 0.01, 0.001)
)

# Entrenamiento
set.seed(123456)
medias_svr_radial <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "svmRadial",
  trControl = control_svr_radial,
  tuneGrid = grid_svr_radial
)

# Preparar los datos para gráfico
df_svr_radial <- medias_svr_radial$results %>%
  mutate(
    sigma = as.factor(sigma),
    C = as.factor(C)
  )

# Gráfico facetado por sigma
ggplot(df_svr_radial, aes(x = C, y = RMSE, color = sigma, group = sigma)) +
  geom_point(size = 3) +
  geom_line(linewidth = 1) +
  theme_minimal() +
  theme(
    panel.border = element_rect(color = "black", fill = NA),
    strip.text = element_text(size = 13),
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  labs(
    # title = "Tuneo SVR Radial: RMSE por combinación de C y sigma (semilla 123456)",
    x = "C", y = "RMSE", color = "Sigma"
  )



# Modelo final SVR Radial con C = 0.1 y sigma = 0.1

set.seed(123456)

control_final_svr_radial <- trainControl(
  method = "repeatedcv",
  number = 10, repeats = 10,
  savePredictions = "all"
)

final_svr_radial <- train(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "svmRadial",
  trControl = control_final_svr_radial,
  tuneGrid = expand.grid(
    C = 0.1,
    sigma = 0.1
  )
)

# Ver resultados medios del modelo
final_svr_radial

# Extraer errores individuales para boxplots y comparativas
res_svr_radial <- final_svr_radial$pred %>%
  mutate(modelo = "SVR_radial")

res_svr_radial




# MODELOS FINALES SELECCIOANDOS PARA COMPARAR 
union_svr <- bind_rows(res_svr_lineal, res_svr_poly, res_svr_radial)
# Orden deseado de los modelos en el eje x
orden_modelos <- c("SVR_lineal", "SVR_poli", "SVR_radial")

# Convertir a factor ordenado
union_svr$modelo <- factor(union_svr$modelo, levels = orden_modelos)

rmse_union <- union_svr %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_union, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(#title = "Comparación final de RMSE por modelo",
       x = "Modelo", y = "RMSE") +
  theme_minimal()

r2_union <- union_svr %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_union, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(#title = "Comparación final de R² por modelo",
       x = "Modelo", y = "R²") +
  theme_minimal()


# Mejor modelo el SVR lineal 


# Mostrar mejor configuración global
mejor_modelo_svr <- final_svr_lineal$results
mejor_modelo_svr




#############################################################################################################
# COMPARACION FINAL 
#############################################################################################################


# MODELOS FINALES SELECCIOANDOS PARA COMPARAR 
union_modelos_finales <- bind_rows(res_reg, res_red5, res_ridge, res_lasso, res_rf, res_xgb, res_lgbm, res_svr_lineal)
# Orden deseado de los modelos en el eje x
orden_modelos <- c("Regresión", "Red5", "Ridge", "Lasso", "RF", "XGB", "LGBM", "SVR_lineal")

# Convertir a factor ordenado
union_modelos_finales$modelo <- factor(union_modelos_finales$modelo, levels = orden_modelos)

rmse_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(RMSE = sqrt(mean((pred - obs)^2)), .groups = "drop")

ggplot(rmse_union, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(#title = "Comparación final de RMSE por modelo",
       x = "Modelo", y = "RMSE") +
  theme_minimal()

r2_union <- union_modelos_finales %>%
  group_by(Resample, modelo) %>%
  summarise(R2 = cor(pred, obs)^2, .groups = "drop")

ggplot(r2_union, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(# title = "Comparación final de R² por modelo",
       x = "Modelo", y = "R²") +
  theme_minimal()



#############################################################################################################
# COMPARACION FINAL 
#############################################################################################################

mejor_modelo_ridge<- mejor_modelo_ridge$results %>%
  mutate(modelo = "Ridge")

mejor_modelo_lasso <- mejor_modelo_lasso$results %>%
  mutate(modelo = "Lasso")


# Tabla de resultados de cada modelo 

mejor_modelo_reg
mejor_modelo_red
mejor_modelo_ridge
mejor_modelo_lasso
mejor_modelo_rf
mejor_modelo_xgb
mejor_modelo_lgbm
mejor_modelo_svr

# Crear tabla final solo con RMSE y R²
resultados_finales <- data.frame(
  modelo = c("Regresión", "Red5", "Ridge", "Lasso", "RF", "XGB", "LGBM", "SVR_lineal"),
  RMSE = c(
    mejor_modelo_reg$RMSE,
    mejor_modelo_red$RMSE,
    mejor_modelo_ridge$RMSE,
    mejor_modelo_lasso$RMSE,
    mejor_modelo_rf$RMSE,
    mejor_modelo_xgb$RMSE,
    mejor_modelo_lgbm$RMSE,
    mejor_modelo_svr$RMSE
  ),
  R2 = c(
    mejor_modelo_reg$Rsquared,
    mejor_modelo_red$Rsquared,
    mejor_modelo_ridge$Rsquared,
    mejor_modelo_lasso$Rsquared,
    mejor_modelo_rf$Rsquared,
    mejor_modelo_xgb$Rsquared,
    mejor_modelo_lgbm$R2,
    mejor_modelo_svr$Rsquared
  )
)


# Calcular la media de RMSE por modelo para ordenar
orden_modelos_rmse <- rmse_union %>%
  group_by(modelo) %>%
  summarise(media_rmse = mean(RMSE)) %>%
  arrange(media_rmse) %>%  # menor RMSE es mejor
  pull(modelo)

# Aplicar el nuevo orden como factor
rmse_union$modelo <- factor(rmse_union$modelo, levels = orden_modelos_rmse)

# Boxplot ordenado
ggplot(rmse_union, aes(x = modelo, y = RMSE)) +
  geom_boxplot(fill = "pink") +
  labs(#title = "Comparación final de RMSE por modelo (ordenado)",
       x = "Modelo", y = "RMSE") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


# Calcular la media de R² por modelo para reordenar
orden_modelos_r2 <- r2_union %>%
  group_by(modelo) %>%
  summarise(media_r2 = mean(R2)) %>%
  arrange(desc(media_r2)) %>%
  pull(modelo)

# Aplicar el nuevo orden como factor
r2_union$modelo <- factor(r2_union$modelo, levels = orden_modelos_r2)

# Boxplot ordenado
ggplot(r2_union, aes(x = modelo, y = R2)) +
  geom_boxplot(fill = "lightblue") +
  labs(#title = "Comparación final de R² por modelo (ordenado)",
       x = "Modelo", y = expression(R^2)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))





#############################################################################################################
# IMPORTANCIA VARIABLE SHAP
#############################################################################################################

if (!require('iml')) install.packages('iml')
if (!require('randomForest')) install.packages('randomForest')
library(iml)
library(caret)



# Datos (usa solo las variables predictoras del modelo final)
X <- as.data.frame(data[, c("plaza_de_castilla", "lag_7", "tipo_dia_laborable")])
y <- data$chamartin

# Crea el objeto Predictor para iml
predictor_rf <- Predictor$new(
  model = final_rf,
  data = X,
  y = y
)

# Importancia global por permutación (aproximación SHAP)
imp_shap <- FeatureImp$new(predictor_rf, loss = "mse")
# Convierte a data.frame para graficar
imp_df <- as.data.frame(imp_shap$results)

# Gráfico mejorado con ggplot2
ggplot(imp_df, aes(x = importance, y = reorder(feature, importance))) +
  geom_col(fill = "#3182bd", alpha = 0.7) +
  labs(
    #title = "Importancia global de variables según SHAP (permuta)",
    x = "Importancia de la variable (incremento en el error MSE)",
    y = "Variable predictora"
  ) +
  theme_minimal(base_size = 14)



# --------------------------------------------------------------------------
# --- LIME para modelo Random Forest (caret) ---
# --------------------------------------------------------------------------

# Instala y carga librerías necesarias
if (!require("lime")) install.packages("lime")
library(lime)
if (!require("ggplot2")) install.packages("ggplot2")
library(ggplot2)

# Usa solo las variables del modelo final
X <- as.data.frame(data[, c("plaza_de_castilla", "lag_7", "tipo_dia_laborable")])
y <- data$chamartin

# Crea el explicador LIME usando el modelo caret
explainer <- lime(
  x = X, 
  model = final_rf
)

# Elige la observación a explicar (fila 350 como ejemplo)
obs_explicar <- X[350, , drop = FALSE]

# Genera la explicación LIME para esa observación
exp_lime <- explain(
  obs_explicar,
  explainer = explainer,
  n_features = 3,   # Número de variables a mostrar
  n_labels = 1      # Para regresión
)

# Gráfico de la explicación LIME
plot_features(exp_lime) +
  labs(
    #title = "Explicación local LIME (observación 350)",
    x = "Contribución al resultado",
    y = "Variable (valor observado)"
  ) +
  theme_minimal(base_size = 14)




# --------------------------------------------------------------------------
# --- Arobol de decisión ---
# --------------------------------------------------------------------------

# Instala y carga librerías necesarias
if (!require('rpart')) install.packages("rpart")
if (!require('rpart.plot')) install.packages("rpart.plot")
library(rpart)
library(rpart.plot)

# Árbol de regresión simple con tus variables seleccionadas
arbol_simple <- rpart(
  chamartin ~ plaza_de_castilla + lag_7 + tipo_dia_laborable,
  data = data,
  method = "anova",               
  control = rpart.control(cp = 0.01) 
)

# Visualización del árbol de regresión
rpart.plot(
  arbol_simple,
  type = 2,         # tipo de nodo: texto debajo
  extra = 101,      # muestra el valor medio predicho y N de casos
  under = TRUE,     # texto debajo del nodo
  faclen = 0,       # no cortar nombres de variables
  main = "Árbol de decisión de regresión simple"
)

# --------------------------------------------------------------------------
# ---Interpretar regresion  ---
# --------------------------------------------------------------------------

# Regresion interpretabilidad 
summary(modelo_reg$finalModel)


# --------------------------------------------------------------------------
# ---Regresion   ---
# --------------------------------------------------------------------------

# Predicciones del modelo
y_real <- data$chamartin
y_pred <- predict(modelo_reg$finalModel, newdata = data)

# DataFrame para ggplot
df_plot <- data.frame(
  Real = y_real,
  Prediccion = y_pred
)

ggplot(df_plot, aes(x = Real, y = Prediccion)) +
  geom_point(color = "#3182bd", alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed", size = 1) +
  labs(
    title = "Predicción vs Valor Estandarizado (Regresión Lineal)",
    x = "Valor estandarizado de chamartin",
    y = "Predicción modelo"
  ) +
  theme_minimal(base_size = 14)













