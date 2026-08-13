--create or replace table meli-people.DW_PE_SHIPPING.FORECASTING_ABS_FINANCIAL_PLANNING_TTE as
SELECT
        EXTRACT(YEAR FROM YEAR_MONTH_DAY) AS ANO,
        EXTRACT(MONTH FROM YEAR_MONTH_DAY) AS MES,
        #USER_ID AS ID,
        AB.SITE,
        Ifnull(REG.nome_atual," ") AS Operational_name,
        IFNULL(REG.Site, " ") AS Tipo_OPS,
        ABSENCE_TYPE,
        UPPER(REASON_ABSENCE) AS REASON_ABSENCE,
        QUALIFIER_CODE,
        CASE 
            WHEN UPPER(REASON_ABSENCE) in ("DOTACION") then "a.Dotacion"
            WHEN UPPER(REASON_ABSENCE) IN ("AUSENCIA INJUSTIFICADA") THEN "b.Falta_Inj"
            WHEN UPPER(REASON_ABSENCE) IN ("ENFERMEDAD") THEN "c.Atestados_Medicos"
            ELSE "d.rest_abs_gestionable"
        END AS TIPO_ABS_GESTIONABLE,
        case
        WHEN EXTERNAL_CONTRACTOR = "No" then "MELI"
        WHEN EXTERNAL_CONTRACTOR = "Si" then "EXTERNO" ELSE " " END AS TIPO_CONTRATO,
        SUM(DOTACION) AS Dotacion_programada,
        SUM(ABSENCE_MANAGEABLE) AS Ausentismo_gestionable,
        -- SUM(ABSENCE_NOT_MANAGEABLE) AS Ausentismo_No_Gestionable,
        -- SUM(ABSENCE_OTHERS) AS Ausentismo_otros,
    FROM
        meli-people.SILVER_PE_SHIPPING.LK_PE_SHIPPING_ABSENCES_PP AB
    LEFT JOIN meli-people.STG_PE_SHIPPING.ONLY_TTE_REG_CLASSIFICADOR REG ON UPPER(AB.SITE) = UPPER(REG.Ubicacion__Nombre)    
    WHERE 1=1
        #AND EXTERNAL_CONTRACTOR = "No"
        AND YEAR_MONTH_DAY BETWEEN DATE "2024-01-01" AND CURRENT_DATE()
        AND COUNTRY = "Brasil"
        AND ABSENCE_TYPE IN ("Dotacion","Gestionable")
        AND REG.logistica IN ("MELILOG","3PL/MELILOG")
        AND REG.nome_atual not like "FBM%"
        -- AND JOB_CLASSIFICATION in (
        -- "Auxiliar Shipping",
        -- "Auxiliar",
        -- "Montacarguistas",
        -- "Montacarguista 0",
        -- "Montacarguista 2",
        -- "Operador Logístico 1",
        -- "Operador Logístico 2",
        -- "Operador Logístico 3",
        -- "Rep de Envio 1",
        -- "Rep de Envio 2",
        -- "Rep de Envio 3",
        -- "Rep de Envio 4",
        -- "Rep de envío inicial",
        -- "Rep eventual" )
        AND JOB_CLASSIFICATION in 
        ("Rep de Envio 1",
         "Rep de Envio 2")

    GROUP BY
        ALL

