USE GlobalPowerPlant


--View: list of primary fuels, types, number of plants and average capacity worldwide

GO

CREATE VIEW fuel AS
	SELECT primary_fuel,
			CASE 
				WHEN primary_fuel IN ('Solar', 'Hydro', 'Wind', 'Geothermal', 'Wave and Tidal', 'Biomass') THEN 'Renewable'
				WHEN primary_fuel IN ('Oil','Gas','Petcoke','Coal','Nuclear') THEN 'Non-Renewable'
				ELSE 'Other'
			END AS fuel_type,
			COUNT(*) AS number_of_plants,
			AVG(capacity_mw) AS avg_capacity_mw
	FROM global_power_plant_database
	GROUP BY primary_fuel

GO


--View: global power plant with fuel type (Excluding Antartica)

CREATE VIEW global_power_plant AS
	SELECT gpp.*, f.fuel_type
	FROM global_power_plant_database AS gpp
	JOIN fuel AS f
	ON gpp.primary_fuel = f.primary_fuel
	WHERE country != 'ATA'    
	
GO


--View: Country list with population and regions

CREATE VIEW countries AS     
	WITH country_total_mw AS   --Sum the total capacity for each country
		(SELECT country,
			   country_long,
			   ROUND(SUM(capacity_mw), 2) AS total_capacity_mw
		FROM global_power_plant_database
		GROUP BY country, country_long),
		
	country_region AS    -- Attach region (continent) and subregion for each country
		(SELECT loc.ISO3_code AS Code,
				loc.Location AS Country,
				sr.Location AS Subregion,
				gr.Location AS Region,
				loc.TPopulation1Jan AS Population_2022
		FROM population_2022 AS loc
			LEFT JOIN population_2022 AS sr
			ON loc.ParentID = sr.LocID
			LEFT JOIN population_2022 AS gr
			ON sr.ParentID = gr.LocID)


    --Join the 2 tables and add capacity per population column
	SELECT ISNULL(Region, Subregion) AS Region,
			Subregion,
			country AS Country,
			country_long AS Country_Long,
			total_capacity_mw AS Total_Capacity_mw,
			population_2022 AS Population_2022,
			ROUND(total_capacity_mw/(population_2022/1000000), 2) AS Capacity_Mw_per_1M_Pop
	FROM
		(SELECT cr.Region AS region,
			   cr.Subregion AS Subregion,
			   c.*,
			   ROUND(cr.Population_2022*1000, 0) AS population_2022
		 FROM country_total_mw AS c JOIN country_region as cr
			 ON  c.country = cr.Code) AS a
	
GO



--View: Subregions table with summary of total capacity, population and capcity per population

CREATE VIEW subregions AS
SELECT *,
	ROUND(Total_Capacity_Mw/(Total_Population_2022/1000000), 2) AS Capacity_Mw_per_1M_Pop
FROM
	(SELECT Region,
		   Subregion,
		   SUM(Total_Capacity_mw) AS Total_Capacity_Mw,
		   SUM(Population_2022) AS Total_Population_2022
	FROM countries
	GROUP BY Region, Subregion) AS a

GO


--View: Regions table with summary of total capacity, population and capcity per population

CREATE VIEW regions AS
SELECT *,
	ROUND(Total_Capacity_Mw/(Total_Population_2022/1000000), 2) AS Capacity_Mw_per_1M_Pop
FROM
	(SELECT Region,
		SUM(Total_Capacity_mw) AS Total_Capacity_Mw,
		SUM(Total_Population_2022) AS Total_Population_2022
	FROM subregions
	GROUP BY Region) AS a

GO


-- 

UPDATE population_2022
SET Location = 'America'
FROM population_2022
WHERE Location in ('Northern America', 'Latin America and the Caribbean')



