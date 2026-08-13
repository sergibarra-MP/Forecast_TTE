--create or replace table meli-people.DW_PE_SHIPPING.FORECASTING_TO_FINANCIAL_PLANNING_TTE as 


SELECT 

DATE(NC.Ano, mes, 1) AS fecha_mes, -- Columna solicitada en formato DATE
NC.Ano, -- (Opcional) Puedes quitarla si ya no la necesitas
mes,    -- (Opcional) Puedes quitarla si ya no la necesitas
NC.Pais_Region,
NC.Ubicacion__Nombre AS SITE,
Ifnull(REG.nome_atual," ") AS Operational_name,
IFNULL(REG.Site, " ") AS Tipo_OPS,
countif(tipo in  ("Headcount Historico", "Headcount Actual")) as HC,
countif(tipo in  ("Headcount Historico", "Headcount Actual") AND NC.TIPO_EMPRESA = "MELI"  ) as HC_MELI,
countif(tipo in  ("Headcount Historico", "Headcount Actual") AND NC.TIPO_EMPRESA = "EXTERNOS" ) as HC_EXTERNOS,
countif(tipoBaja in ("Renuncia") ) as Renuncia,
countif(tipoBaja in ("Despido") ) as Despido,
countif(tipoBaja in ("Abandono de empleo") ) as Abandono_de_empleo,
countif(tipoBaja in ("No cuenta") and Motivo_del_evento not in ("TER_PURGE-PURGA")) as No_cuenta,
countif(tipoBaja in ("Renuncia", "Despido", "Abandono de empleo") or (tipoBaja in ("No cuenta") and Motivo_del_evento not in ("TER_PURGE-PURGA"))) as Total_Bajas,
FROM meli-people.SILVER_PE_SHIPPING.KPI_LATAM_NC_TO_ALL AS NC
LEFT JOIN meli-people.STG_PE_SHIPPING.ONLY_TTE_REG_CLASSIFICADOR REG ON UPPER(NC.Ubicacion__Nombre) = UPPER(REG.Ubicacion__Nombre)  
Where NC.Ano >= 2024
-- AND mes = 2  -- Comentado según tu ejemplo original
AND Agrupador_1 in (
"Representante", 
"Representante eventual",
"Representantes - CDBR",
"Representante Inicial",
"Rep eventual - Peak",
"Representante Externo")
AND REG.logistica IN ("MELILOG","3PL/MELILOG")
AND REG.nome_atual not like "FBM%"
AND NC.Pais_Region = "Brasil"
AND NC.Clasificacion_de_puestos_Descripcion IN ("Rep de Envio 1","Rep de Envio 2")
group by ALL
ORDER BY 1, 4 -- Ordena por fecha_mes (1) y luego por Agrupador_1 (4)