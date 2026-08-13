# Forecast TTE v0 — Guía de Proyecto para IA

> Este archivo documenta el setup, decisiones y contexto del proyecto para que cualquier IA (o persona) pueda retomar el trabajo sin fricción.

---

## 1. Contexto del Proyecto

**Objetivo:** Sistema de forecasting de Ausentismo (ABS) y Turnover (TO) para el negocio de Transporte (TTE) dentro de Shipping — Brasil.

**Owner:** Sergio Ibarra — Lead People Ops Analytics, Mercado Libre (`sergio.ibarra@mercadolibre.com.mx`)

**Referencia anterior:** Existe trabajo previo de Jhony Contreras en `../Ejemplos_Jhony/` (2 SQLs + 1 notebook CatBoost). Se usa como referencia, no como base inamovible.

**Enfoque:** Construir desde cero con rigor analítico: exploración → calidad de datos → distribuciones → outliers → feature engineering → modelado.

---

## 2. Entorno de Trabajo

- **OS:** Windows 11
- **IDE:** VS Code con extensión Jupyter
- **Python:** 3.12.10
- **Virtual env:** `.venv` en `C:\Users\sergibarra\Documents\SI_People_Analytics_2026\Forecast_TTE\`
  - El venv vive en la carpeta **padre** del proyecto, no en `Forecast_TTE_v0`
  - Al seleccionar kernel en VS Code, elegir `.venv (3.12.10) .venv\Scripts\python.exe` (marcado como "Recommended")

### Verificar que el venv correcto está activo
```powershell
python -c "import sys; print(sys.executable)"
# Debe mostrar: ...Forecast_TTE\.venv\Scripts\python.exe
```

---

## 3. Paquetes Instalados

Ver `../requirements.txt` para versiones exactas. Los paquetes principales son:

```
google-cloud-bigquery
google-cloud-bigquery-storage
pyarrow
db-dtypes
pandas
numpy
matplotlib
seaborn
plotly
ipykernel
ipywidgets
catboost
scikit-learn
python-dateutil
```

### Para reproducir el entorno desde cero
```powershell
# Desde la carpeta raíz del proyecto (Forecast_TTE/)
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

---

## 4. Conexión a BigQuery

**Autenticación:** Application Default Credentials (ADC) de Google Cloud.
```powershell
# Solo necesario una vez por máquina
gcloud auth application-default login
```

### PROBLEMA CONOCIDO: BigQuery Storage API — 403 PermissionDenied

La cuenta NO tiene permiso `bigquery.readsessions.create` en el proyecto `meli-people`. Esto hace que `.to_dataframe()` falle porque intenta usar la Storage API (gRPC) por defecto.

**Solución:** Usar siempre el helper `bq_query()` definido en Celda 2 del notebook:

```python
# NUNCA usar esto directamente:
client.query(sql).to_dataframe()  # ❌ Falla con 403

# SIEMPRE usar el helper:
def bq_query(sql: str):
    return client.query(sql).to_dataframe(create_bqstorage_client=False)

bq_query(sql)  # ✅ Funciona — usa REST/HTTP en vez de gRPC
```

> `create_bqstorage_client=False` fuerza el método HTTP clásico. La diferencia de velocidad es irrelevante para las queries de este proyecto.

---

## 5. Tablas Fuente (Solo Lectura — Sin permisos de CREATE TABLE)

| Tabla | Descripción |
|---|---|
| `meli-people.SILVER_PE_SHIPPING.LK_PE_SHIPPING_ABSENCES_PP` | Ausentismo — tabla madre |
| `meli-people.SILVER_PE_SHIPPING.KPI_LATAM_NC_TO_ALL` | Headcount / Turnover |
| `meli-people.STG_PE_SHIPPING.ONLY_TTE_REG_CLASSIFICADOR` | Clasificador de sitios TTE |

**Tablas DW de referencia** (creadas por Jhony, no controladas por nosotros, pueden no actualizarse):
- `meli-people.DW_PE_SHIPPING.FORECASTING_ABS_FINANCIAL_PLANNING_TTE`
- `meli-people.DW_PE_SHIPPING.FORECASTING_TO_FINANCIAL_PLANNING_TTE`

> **Decisión de diseño:** No dependemos de las tablas DW. Toda la data se construye con CTEs/queries directas sobre Silver, cacheadas en Parquet local.

---

## 6. Filtros de Negocio

Estos son los filtros que definen el universo TTE Brasil. **No cambiarlos sin validar con el equipo.**

```sql
-- País
COUNTRY = 'Brasil'

-- Clasificación de puestos target
JOB_CLASSIFICATION IN ('Rep de Envio 1', 'Rep de Envio 2')

-- Tipos de ausencia relevantes
ABSENCE_TYPE IN ('Dotacion', 'Gestionable')

-- Logística
REG.logistica IN ('MELILOG', '3PL/MELILOG')

-- Excluir sitios FBM
REG.nome_atual NOT LIKE 'FBM%'

-- Rango temporal
YEAR_MONTH_DAY >= DATE '2024-01-01'
```

---

## 7. Estructura de Archivos

```
Forecast_TTE/
├── .venv/                          ← Virtual environment compartido
├── requirements.txt                ← Versiones exactas de paquetes
├── Ejemplos_Jhony/                 ← Referencia del trabajo anterior
│   ├── FORECASTING_ABS_FINANCIAL_PLANNING_TTE.sql
│   ├── FORECASTING_TO_FINANCIAL_PLANNING_TTE.sql
│   └── forecast_ABS_TTE_CatBoost_only.ipynb
└── Forecast_TTE_v0/
    ├── Claude.md                   ← Este archivo
    ├── Forecast_TTE_test.ipynb     ← Notebook principal (exploración)
    └── data/                       ← Cache Parquet local (generado al correr)
        ├── abs_agregado_raw.parquet
        └── (to_agregado_raw.parquet — pendiente)
```

---

## 8. Notebook Principal: `Forecast_TTE_test.ipynb`

### Estructura de celdas

| Celda | ID | Contenido |
|---|---|---|
| 1 | `c1` | Imports, parámetros globales, configuración de `DATA_DIR` |
| 2 | `c2` | Conexión BQ + definición de `bq_query()` helper |
| 3a | `c3a` | Schema completo de la tabla madre ABS |
| 3b | `c3b` | Muestra cruda 50 filas (sin filtros de negocio) |
| 4a | `c4a` | Volumetría por País |
| 4b | `c4b` | Distribución por JOB_CLASSIFICATION |
| 4c | `c4c` | Distribución por ABSENCE_TYPE y REASON_ABSENCE |
| 4d | `c4d` | Sitios únicos con/sin match en clasificador REG |
| 5a | `c5a` | Schema tabla madre TO |
| 5b | `c5b` | Volumetría TO por País/Región |
| 5c | `c5c` | Agrupadores y clasificaciones TO |
| 5d | `c5d` | Tipos de baja TO |
| 6 | `c6` | Query de agregación ABS + cache Parquet (`cargar_abs()`) |
| 7a | `c7a` | Auditoría de nulos |
| 7b | `c7b` | Valores imposibles (Dotacion <= 0, ratios > 100%) |
| 7c | `c7c` | Duplicados en el grano |
| 7d | `c7d` | Gaps temporales por sitio |
| 8a | `c8a` | Pivot al nivel del modelo (sitio × mes) |
| 8b | `c8b` | Histogramas de distribuciones |
| 9a | `c9a` | Detección de outliers (IQR + Z-score modificado) |
| 9b | `c9b` | Boxplot interactivo Top 30 sitios |
| 9c | `c9c` | Tabla de outliers de alta confianza |
| 10a | `c10a` | Historia por sitio (meses disponibles) |
| 10b | `c10b` | Heatmap ABS_Total sitio × mes |
| 10c | `c10c` | Series temporales Top 6 sitios |

### Variables clave disponibles tras ejecutar el notebook
```python
df_abs_raw   # DataFrame crudo con todos los registros ABS agregados
df_pivot     # Pivot sitio × mes con métricas calculadas (ABS_Total, etc.)
df_out       # df_pivot filtrado (solo Dotacion > 0) con flags de outliers
df_hist      # Resumen de historia por sitio (n_meses, cobertura, etc.)
```

---

## 9. Decisiones Técnicas Tomadas

| Decisión | Razón |
|---|---|
| Cache Parquet local | Evitar hits a BQ en cada iteración de desarrollo |
| `bq_query()` helper | Workaround permanente para el 403 de Storage API |
| MELI + EXTERNO combinados | Consistente con el enfoque de Jhony; refleja la operación real |
| Outliers: IQR + Z-score modificado (MAD) | Más robusto que Z-score clásico ante distribuciones asimétricas |
| Mínimo 6 meses de historia por sitio | Necesario para lags mínimos del modelo |

---

## 10. Próximos Pasos (al terminar este notebook)

| Notebook | Qué haremos |
|---|---|
| `v1_limpieza.ipynb` | Tratamiento explícito de outliers, gaps, sitios a excluir |
| `v2_features.ipynb` | Lags, rolling means, estacionalidad, covariables externas |
| `v3_modelo_abs.ipynb` | Benchmark: Naive → SARIMA → CatBoost/LGBM → modelos fundacionales |
| `v4_modelo_to.ipynb` | Mismo proceso para Turnover |
| `v5_validacion.ipynb` | Walk-forward riguroso, métricas por sitio |
| `v6_produccion.ipynb` | Pipeline completo, schedule mensual, output a CSV/BQ |
