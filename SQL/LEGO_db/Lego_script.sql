-- ** LEGO Database Query **
/*
This queries based on 2 databases:
1. Full detailed database of sets, parts, minifigures and colors from 1949 till 2024 (include 12 related tables),
   (source: https://rebrickable.com/)
2. Price table of 720~ sets from 1996 till 2018 (source: https://www.kaggle.com/datasets)
*/

-----------------------
-- DATA PREPERATION
-----------------------
-- Database: Create FK constraints for the tables (not include the price table)
ALTER TABLE dbo.elements
ADD CONSTRAINT el_col_fk FOREIGN KEY (color_id) REFERENCES dbo.colors(id),
	CONSTRAINT el_prts_fk FOREIGN KEY (part_num) REFERENCES dbo.parts(part_num);

ALTER TABLE dbo.part_relationships
ADD CONSTRAINT prtrl_prts_child FOREIGN KEY (child_part_num) REFERENCES dbo.parts(part_num),
	CONSTRAINT prtrl_prts_parent FOREIGN KEY (parent_part_num) REFERENCES dbo.parts(part_num);

ALTER TABLE dbo.parts
ADD CONSTRAINT prts_prtcat_fk FOREIGN KEY (part_cat_id) REFERENCES dbo.part_categories(id);

ALTER TABLE dbo.inventory_parts
ADD CONSTRAINT invprts_prts_fk FOREIGN KEY (part_num) REFERENCES dbo.parts(part_num),
	CONSTRAINT invprts_clrs_fk FOREIGN KEY (color_id) REFERENCES dbo.colors(id),
	CONSTRAINT invprts_inv_fk FOREIGN KEY (inventory_id) REFERENCES dbo.inventories(id);

ALTER TABLE dbo.inventory_minifigs
ADD CONSTRAINT invminifig_minifigs_fk FOREIGN KEY (fig_num) REFERENCES dbo.minifigs(fig_num),
	CONSTRAINT invminifig_inv_fk FOREIGN KEY (inventory_id) REFERENCES dbo.inventories(id);

ALTER TABLE dbo.themes
ADD CONSTRAINT thms_prntid_fk FOREIGN KEY (parent_id) REFERENCES dbo.themes(id);

ALTER TABLE dbo.sets
ADD CONSTRAINT sts_thms_fk FOREIGN KEY (theme_id) REFERENCES dbo.themes(id);

ALTER TABLE dbo.inventory_sets
ADD CONSTRAINT invsts_sts_fk FOREIGN KEY (set_num) REFERENCES dbo.sets(set_num),
	CONSTRAINT invsts_inv_fk FOREIGN KEY (inventory_id) REFERENCES dbo.inventories(id);



--------------------------------------------------

-- Prices table: Data Cleaning 

ALTER TABLE lego_sets_prices    -- Drop unnecessary columns
	DROP COLUMN num_reviews, play_star_rating, prod_long_desc, review_difficulty, star_rating, val_star_rating;
	
ALTER TABLE lego_sets_prices	-- Change type of price column to money
	ALTER COLUMN list_price money;

ALTER TABLE lego_sets_prices	-- Change type of prod_id column to varchar (for join with sets table later)
	ALTER COLUMN prod_id varchar(50);

DELETE FROM lego_sets_prices    -- Delete all non-US prices
WHERE country NOT LIKE 'US'


-- Delete duplicated prod_id
WITH dup_price AS
	(SELECT *,
		ROW_NUMBER() OVER (PARTITION BY prod_id 
							ORDER BY prod_id, list_price) AS RN
	FROM lego_sets_prices)

DELETE FROM dup_price
WHERE RN != 1

--------------------------------------------
-- Add the price column to sets table
ALTER TABLE sets
ADD price money null;
	

UPDATE sets
SET price = sp.list_price
FROM sets AS s JOIN lego_sets_prices AS sp
ON LEFT(s.set_num,CHARINDEX('-',s.set_num)-1) = sp.prod_id;

------------------------------------------------------------------
-- BASIC QUERIES
------------------------------------------------------------------
-- Q: What are the must productive years (new sets in one year)?
SELECT top 5 year, 
			 COUNT(*) AS num_of_sets
FROM sets
GROUP BY year
ORDER BY num_of_sets DESC;

/* 
A: 2021 - 1147 sets
   2019 - 1038 sets
   2020 - 1035 sets
   2022 - 1028 sets
   2023 - 1001 sets
*/
-------------------------------------------------------------------
-- Q: What themes have the highest average price and whats is the average number of parts in those sets?

SELECT TOP 5 t.name AS Theme_Name,
			 COUNT(*) AS Num_of_Sets,
			 FORMAT(AVG(s.price), 'C', 'en-us') AS Avg_Price,
	 		 AVG(s.num_parts) AS Avg_Num_Parts	 
FROM sets AS s JOIN themes AS t
	ON s.theme_id = t.id
WHERE s.price IS NOT NULL
GROUP BY s.theme_id, t.name
ORDER BY AVG(s.price) DESC;

/*
A: Ultimate Collector Series: $350, 3152 pieces (6 sets)
   Disney: $350, 4081 pieces (1 set)
   Ghostbusters: $205, 2599 pieces (2 sets)
   Pirates of the Caribbean: $200, 2294 pieces (1 set)
   Modular Buildings: $188, 2715 pieces (5 sets)

*/
------------------------------------------
-- COLORS STATISTICS
------------------------------------------
/* Creating new table: Colors Details
	1. Color Name
	2. Number of sets it's been used in
	3. First year it's been used in sets
	4. Last year it's been used in sets
	5. Number of years it's been used
*/

WITH color_year AS
	(SELECT DISTINCT
			c.id AS Color_id,
			c.name AS Color_Name,
			s.set_num,
			s.year AS Set_Year
	FROM sets AS s JOIN inventories AS i
	ON s.set_num = i.set_num
	JOIN inventory_parts AS ip
	ON i.id = ip.inventory_id
	RIGHT JOIN colors AS c
	ON ip.color_id = c.id)

SELECT *,
	   Last_Year - First_Year + 1 AS Num_Years
INTO colors_details
FROM
	(SELECT Color_Name,
		COUNT(*) AS Num_Sets,
		MIN(Set_Year) AS First_Year,
		MAX(Set_Year) AS Last_Year
	FROM color_year
	GROUP BY Color_Name) AS a

-------------------------------
-- Q: What are the 5 top used colors?
SELECT TOP 5 *
FROM colors_details
ORDER BY Num_Sets DESC

/*
A: black - 12807 sets
   white - 10578 sets
   red - 10472 sets
   yellow - 8695 sets
   blue - 8076 sets
*/

-------------------------
-- Q: How many colors used only once (number and percentage)?

DECLARE @colors_num FLOAT

SELECT @colors_num = COUNT(*)
FROM colors_details

SELECT COUNT(*) AS num_colors_used_once,
	   CONCAT(CAST((COUNT(*) / @colors_num) * 100 AS INT),'%') AS percentage
FROM colors_details
WHERE Num_Sets = 1

-- A: 68 colors used in only 1 set which are 25% of the total colors



----------------------------------------------------
/* 
Q: For each year:
	1. How many distinct colors were used?
	2. How many colors were used for first time?
	3. Whats the total amount of colors used until that year?
*/

WITH 
colors_years_sum AS     --Count for each year how many colors used for first time
	(SELECT First_Year,
			COUNT(*) AS num_of_colors
	FROM colors_details
	GROUP BY First_Year),

colors_set_years AS     --List of distinct used color-year
	(SELECT DISTINCT
			c.id AS Color_id,
			c.name AS Color_Name,
			s.year AS Set_Year
	FROM sets AS s JOIN inventories AS i
		ON s.set_num = i.set_num
	JOIN inventory_parts AS ip
		ON i.id = ip.inventory_id
	JOIN colors AS c
		ON ip.color_id = c.id)

SELECT *,
	SUM(num_of_new_colors) OVER (ORDER BY year ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS total_colors
FROM
	(SELECT csy.Set_Year AS year,
		   COUNT(*) AS num_of_colors_used,
		   ISNULL(cys.num_of_colors, 0) AS num_of_new_colors
	FROM colors_set_years AS csy LEFT JOIN colors_years_sum AS cys
	ON csy.Set_Year = cys.First_Year
	GROUP BY csy.Set_Year, cys.num_of_colors) AS a
ORDER BY year;




---------------------------------------------------
-- SETS PRICING
---------------------------------------------------
/*
Create New Table Sets Details:
  1. Theme name
  2. Set number
  3. Total quantity of parts
  4. Numbrt of distincts parts (type and color)
  5. Number of minifigures 
  6. Total retail price
  7. Parts pricing (Price/Total quantity of parts)
*/

WITH sets_distincts_parts AS   --Quantity of distinct parts (type and color) for each set
	(SELECT i.set_num,
		    COUNT(*) AS num_dist_parts
	FROM inventories AS i JOIN inventory_parts AS ip
	ON i.id = ip.inventory_id
	GROUP BY i.set_num),

sets_figs AS    --Total number of minifigures for each set
	(SELECT i.set_num,
		   COUNT(*) AS num_fig
	FROM inventories AS i JOIN inventory_minifigs AS im
	ON i.id = im.inventory_id
	GROUP BY i.set_num)


SELECT t.name AS theme_name,
	   s.name AS set_name,
	   s.set_num,
	   s.num_parts,
	   sdp.num_dist_parts,
	   ISNULL(sf.num_fig, 0) AS num_fig,
	   s.price,
	   ROUND(s.price/s.num_parts, 2) AS price_per_part
INTO sets_details
FROM sets AS s JOIN themes AS t
	ON s.theme_id = t.id
JOIN sets_distincts_parts AS sdp
	ON s.set_num = sdp.set_num
LEFT JOIN sets_figs AS sf
	ON s.set_num = sf.set_num
WHERE price IS NOT NULL AND num_parts>0
ORDER BY num_fig DESC;


-------------------------------------
/* Q: What's the correlation between:
	  1. Retail price <> total number of parts in the sets?
      2. Retail price <> number of distinct parts?
	  3. Retail price <> number of minifigures in set?
	  (for sets with 10 parts and above)
	  (based on the formula: Correlation =  (Avg(x * y) – (Avg(x) * Avg(y))) / (StDevP(x) * StDevP(y)))
*/


SELECT  ROUND((AVG(num_parts * price) - (AVG(num_parts)*AVG(price))) / (STDEVP(num_parts) * STDEVP(price)), 2) as [rp <> p],
		ROUND((AVG(num_dist_parts * price) - (AVG(num_dist_parts)*AVG(price))) / (STDEVP(num_dist_parts) * STDEVP(price)), 2) as [rp <> dp],
		ROUND((AVG(num_fig * price) - (AVG(num_fig)*AVG(price))) / (STDEVP(num_fig) * STDEVP(price)), 2) as [rp <> f]
FROM sets_details 
WHERE price IS NOT NULL AND num_parts>10;

/*
A: 1. 0.93
   2. 0.71
   3. 0.55
*/

 -----------------------------------------------------------------
-- Q: What's the 5 must expansive parts and their price?

WITH parts_details AS   --List of all distinct parts in sets, their quantity and their price ('price per part')
	(SELECT pc.name AS category_name,
		   p.name AS part_name,
		   p.part_material,
		   ip.quantity,
		   sd.price_per_part,
		   sd.price_per_part*ip.quantity AS total_part_price
	FROM parts AS p JOIN part_categories AS pc
		ON p.part_cat_id = pc.id
	JOIN inventory_parts AS ip
		ON p.part_num = ip.part_num
	JOIN inventories AS i
		ON ip.inventory_id = i.id
	JOIN sets_details AS sd
		ON i.set_num = sd.set_num)

SELECT TOP 5 part_name,
			 FORMAT(ROUND(SUM(total_part_price) / SUM(quantity), 2), 'C', 'en-us') AS avg_part_price
FROM parts_details
GROUP BY part_name
ORDER BY SUM(total_part_price) / SUM(quantity) DESC

/*
A:  Battery Pack, Rechargeable, DC, EV3 - $88.99
	Hub, EV3 Brick [Complete Assembly] - $66.38
	Sensor, Gyro, EV3 with White Case - $31.99
	Sensor, Ultrasonic, EV3 - $31.99
	Electric Adapter / Transformer - $29.99
*/



