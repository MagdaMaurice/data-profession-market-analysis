CREATE TABLE clean_survey_data AS
WITH Prepped_Survey AS (
    SELECT 
        `Unique ID`,
        `Q2 - Did you switch careers into Data?`,
        `Satisfaction_Salary`,
        `Satisfaction_WorkLife`,
        `Satisfaction_Coworkers`,
        `Satisfaction_Management`,
        `Satisfaction_Upward`,
        `Satisfaction_Learning`,
        `Q7 - How difficult was it for you to break into Data?`,
        `Q9 - Male/Female?`,
        
        -- Safe numeric conversion for Age
        CAST(`Q10 - Current Age` AS UNSIGNED) AS Age,
        
        -- Strip prefixes ("Other (Please Specify):") while keeping original column names clean
        NULLIF(TRIM(REPLACE(REPLACE(`Q4 - What Industry do you work in?`, 'Other (Please Specify):', ''), 'Other (Please Specify)', '')), '') AS `Q4 - What Industry do you work in?`,
        NULLIF(TRIM(REPLACE(REPLACE(`Q8_Most_Important_Thing`, 'Other (Please Specify):', ''), 'Other (Please Specify)', '')), '') AS Q8_Most_Important_Thing,
        NULLIF(TRIM(REPLACE(REPLACE(`Q11 - Which Country do you live in?`, 'Other (Please Specify):', ''), 'Other (Please Specify)', '')), '') AS `Q11 - Which Country do you live in?`,
        NULLIF(TRIM(REPLACE(REPLACE(`Q13 - Ethnicity`, 'Other (Please Specify):', ''), 'Other (Please Specify)', '')), '') AS Raw_Ethnicity,
        
        -- Raw source fields passed downstream
        `Q1 - Which Title Best Fits your Current Role?` AS Raw_Role,
        `Q3 - Current Yearly Salary (in USD)` AS Raw_Salary,
        `Q5 - Favorite Programming Language` AS Raw_Language,
        `Q12 - Highest Level of Education` AS Raw_Education,
        
        -- Clean_Date conversion replacing Date Taken
        STR_TO_DATE(`Date Taken (America/New_York)`, '%m/%d/%Y') AS Clean_Date
    FROM staging_survey
),
Parsed_Data AS (
    SELECT 
        `Unique ID`,
        `Q2 - Did you switch careers into Data?`,
        `Satisfaction_Salary`,
        `Satisfaction_WorkLife`,
        `Satisfaction_Coworkers`,
        `Satisfaction_Management`,
        `Satisfaction_Upward`,
        `Satisfaction_Learning`,
        `Q7 - How difficult was it for you to break into Data?`,
        `Q9 - Male/Female?`,
        Age,
        Clean_Date,
        
        -- Standardized Q8 Most Important Thing
        CASE 
            WHEN Q8_Most_Important_Thing = 'Better Salary' THEN 'Better Salary'
            WHEN Q8_Most_Important_Thing = 'Remote Work' THEN 'Remote Work'
            WHEN Q8_Most_Important_Thing = 'Good Work/Life Balance' THEN 'Good Work/Life Balance'
            WHEN Q8_Most_Important_Thing = 'Good Culture' THEN 'Good Culture'
            WHEN LOWER(Q8_Most_Important_Thing) LIKE '%learn%' 
              OR LOWER(Q8_Most_Important_Thing) LIKE '%growth%' 
              OR LOWER(Q8_Most_Important_Thing) LIKE '%advanc%' 
              OR LOWER(Q8_Most_Important_Thing) LIKE '%skill%' THEN 'Growth & Learning'
            ELSE 'Other'
        END AS Q8_Most_Important_Thing,

        -- 1. Current_Role Full Mapping
        CASE 
            WHEN LOWER(Raw_Role) LIKE '%data analyst%' OR LOWER(Raw_Role) LIKE '%business analyst%' THEN 'Data Analyst'
            WHEN LOWER(Raw_Role) LIKE '%data engineer%' OR LOWER(Raw_Role) LIKE '%analytics engineer%' THEN 'Data Engineer'
            WHEN LOWER(Raw_Role) LIKE '%data scientist%' THEN 'Data Scientist'
            WHEN LOWER(Raw_Role) LIKE '%architect%' OR LOWER(Raw_Role) LIKE '%database%' THEN 'Data Architect / Database Administrator'
            WHEN LOWER(Raw_Role) LIKE '%student%' OR LOWER(Raw_Role) LIKE '%looking%' OR LOWER(Raw_Role) LIKE '%none%' THEN 'Student / Job Seeker'
            ELSE 'Other'
        END AS Current_Role,

        -- 2. Salary Fields
        CASE Raw_Salary
            WHEN '0-40k' THEN 0
            WHEN '41k-65k' THEN 41000
            WHEN '66k-85k' THEN 66000
            WHEN '86k-105k' THEN 86000
            WHEN '106k-125k' THEN 106000
            WHEN '125k-150k' THEN 125000
            WHEN '150k-225k' THEN 150000
            WHEN '225k+' THEN 225000
            ELSE NULL
        END AS min_salary,
        
        CASE Raw_Salary
            WHEN '0-40k' THEN 40000
            WHEN '41k-65k' THEN 65000
            WHEN '66k-85k' THEN 85000
            WHEN '86k-105k' THEN 105000
            WHEN '106k-125k' THEN 125000
            WHEN '125k-150k' THEN 150000
            WHEN '150k-225k' THEN 225000
            WHEN '225k+' THEN 250000
            ELSE NULL
        END AS max_salary,

        -- 3. Favorite_Language Full Mapping
        CASE 
            WHEN LOWER(Raw_Language) LIKE '%python%' THEN 'Python'
            WHEN LOWER(Raw_Language) LIKE '%sql%' THEN 'SQL'
            WHEN LOWER(Raw_Language) LIKE '%dax%' OR LOWER(Raw_Language) LIKE '%power query%' THEN 'Power Query / DAX'
            WHEN LOWER(Raw_Language) LIKE '%javascript%' THEN 'JavaScript'
            WHEN LOWER(TRIM(REPLACE(REPLACE(Raw_Language, 'Other (Please Specify):', ''), 'Other:', ''))) = 'r' THEN 'R'
            WHEN LOWER(TRIM(REPLACE(REPLACE(Raw_Language, 'Other (Please Specify):', ''), 'Other:', ''))) IN ('c', 'c++', 'c/c++', 'c#') THEN 'C / C++'
            WHEN LOWER(Raw_Language) LIKE '%none%'
              OR TRIM(REPLACE(REPLACE(Raw_Language, 'Other (Please Specify):', ''), 'Other:', '')) = '' THEN 'None'
            ELSE 'Other'
        END AS Favorite_Language,

        -- 4. Country Full Mapping
        CASE 
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%nigeria%' THEN 'Nigeria'
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%ire%' OR LOWER(`Q11 - Which Country do you live in?`) = 'ireland' THEN 'Ireland'
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%uzb%' THEN 'Uzbekistan'
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%brazi%' THEN 'Brazil'
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%portug%' THEN 'Portugal'
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%argentin%' THEN 'Argentina'
            WHEN LOWER(`Q11 - Which Country do you live in?`) IN ('sg', 'singapore') THEN 'Singapore'
            WHEN LOWER(`Q11 - Which Country do you live in?`) = 'fin' THEN 'Finland'
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%austr%' AND LOWER(`Q11 - Which Country do you live in?`) NOT LIKE '%austria%' THEN 'Australia'
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%kenya%' OR LOWER(`Q11 - Which Country do you live in?`) = 'kenua' THEN 'Kenya'
            WHEN LOWER(`Q11 - Which Country do you live in?`) = 'leba' THEN 'Lebanon'
            WHEN LOWER(`Q11 - Which Country do you live in?`) IN ('uae', 'united arab emirates') THEN 'United Arab Emirates'
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%congo%' THEN 'Democratic Republic of the Congo'
            WHEN LOWER(`Q11 - Which Country do you live in?`) LIKE '%peru%' THEN 'Peru'
            WHEN LOWER(`Q11 - Which Country do you live in?`) = 'aisa' THEN 'Other'
            WHEN `Q11 - Which Country do you live in?` = 'turkey' THEN 'Turkey'
            WHEN `Q11 - Which Country do you live in?` = 'TUNISIA' THEN 'Tunisia'
            WHEN `Q11 - Which Country do you live in?` = 'Sri lanka' THEN 'Sri Lanka'
            WHEN `Q11 - Which Country do you live in?` = 'indonesia' THEN 'Indonesia'
            WHEN `Q11 - Which Country do you live in?` = 'ghana' THEN 'Ghana'
            ELSE TRIM(`Q11 - Which Country do you live in?`)
        END AS `Q11 - Which Country do you live in?`,

        -- 5. Education Blank Handling
        CASE 
            WHEN Raw_Education IS NULL OR TRIM(Raw_Education) = '' THEN 'Not Specified'
            ELSE Raw_Education
        END AS `Q12 - Highest Level of Education`,

        -- 6. Industry Full Mapping
        CASE 
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%defense%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%police%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%law enforcement%' THEN 'Defense & Security'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%legal%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%ngo%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%state%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%social work%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%demography%' THEN 'Legal & Public Sector'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%research%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%weather%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%science%' THEN 'Research & Science'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%outsourcing%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%staffing%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%recruiting%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%management%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%workforce%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%professional services%' THEN 'Professional Services & HR'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%supply chain%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%wholesale%' THEN 'Supply Chain'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%consumer goods%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%cosmetics%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%culinary%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%poultry%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%direct marketing%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%home and living%' THEN 'Consumer Goods'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%renewable%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%urbanism%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%energy%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%oil%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%gas%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%power generation%' THEN 'Energy & Utilities'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%tech%'
              OR LOWER(TRIM(`Q4 - What Industry do you work in?`)) = 'it'
              OR LOWER(`Q4 - What Industry do you work in?`) LIKE 'it %'
              OR LOWER(`Q4 - What Industry do you work in?`) LIKE '% it'
              OR LOWER(`Q4 - What Industry do you work in?`) LIKE '% it %'
              OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%information technology%'
              OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%software%'
              OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%data insight%'
              OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%electronics%'
              OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%sensors%' THEN 'Tech / IT'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%finance%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%bank%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%invest%' THEN 'Finance / Banking'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%health%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%med%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%pharma%' THEN 'Healthcare'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%edu%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%school%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%university%' THEN 'Education'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%reta%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%ecom%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%commerce%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%fashion%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%online store%' THEN 'Retail / E-Commerce'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%consult%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%cobsukt%' THEN 'Consulting'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%arrosp%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%aerospace%' THEN 'Aerospace'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%auto%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%car%' THEN 'Automotive'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%avia%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%air transpo%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%airline%' THEN 'Aviation & Transportation'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%cons%' AND LOWER(`Q4 - What Industry do you work in?`) NOT LIKE '%consult%' THEN 'Construction'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%consumer elec%' THEN 'Consumer Electronics'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%food%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%bece%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%beverage%' THEN 'Food & Beverage'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%manuf%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%manafuc%' THEN 'Manufacturing'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%logist%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%warehous%' THEN 'Logistics & Warehousing'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%customer service%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%customer support%' THEN 'Customer Service'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%fmcg%' THEN 'FMCG'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%gaming%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%igaming%' THEN 'Gaming / iGaming'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%sport%' THEN 'Sports'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%utili%' THEN 'Utilities'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%studying%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%student%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%not currently working%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%not working%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%unemploy%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%homeless%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%home maker%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%homemaker%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%looking%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%bootcamp%' THEN 'Student / Unemployed'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%gov%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%non-profit%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%nonprofit%' THEN 'Government / Non-Profit'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%coworking%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%workspaces%' THEN 'Real Estate'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%culture%' THEN 'Entertainment'
            WHEN LOWER(`Q4 - What Industry do you work in?`) LIKE '%none%' OR LOWER(`Q4 - What Industry do you work in?`) LIKE '%n/a%' OR `Q4 - What Industry do you work in?` IS NULL OR TRIM(`Q4 - What Industry do you work in?`) = '' THEN 'Not Specified'
            ELSE TRIM(`Q4 - What Industry do you work in?`)
        END AS `Q4 - What Industry do you work in?`,

        -- 7. Age_Brackets
        CASE
            WHEN Age < 21 THEN 'Under 21'
            WHEN Age BETWEEN 21 AND 25 THEN '21-25'
            WHEN Age BETWEEN 26 AND 30 THEN '26-30'
            WHEN Age BETWEEN 31 AND 35 THEN '31-35'
            WHEN Age BETWEEN 36 AND 40 THEN '36-40'
            WHEN Age BETWEEN 41 AND 50 THEN '41-50'
            WHEN Age > 50 THEN '50+'
            ELSE 'Not Specified'
        END AS Age_Brackets,

        -- 8. Clean Ethnicity Full Mapping
        CASE 
            WHEN LOWER(Raw_Ethnicity) LIKE '%white%' OR LOWER(Raw_Ethnicity) LIKE '%wite%' OR LOWER(Raw_Ethnicity) LIKE '%caucasian%' THEN 'White / Caucasian'
            WHEN LOWER(Raw_Ethnicity) LIKE '%asian%' OR LOWER(Raw_Ethnicity) LIKE '%indian%' OR LOWER(Raw_Ethnicity) LIKE '%chinese%' THEN 'Asian / Asian American'
            WHEN LOWER(Raw_Ethnicity) LIKE '%black%' OR LOWER(Raw_Ethnicity) LIKE '%blk%' OR LOWER(Raw_Ethnicity) LIKE '%bla%' OR LOWER(Raw_Ethnicity) LIKE '%african%' THEN 'Black / African'
            WHEN LOWER(Raw_Ethnicity) LIKE '%hispanic%' OR LOWER(Raw_Ethnicity) LIKE '%latin%' THEN 'Hispanic / Latino'
            WHEN LOWER(Raw_Ethnicity) LIKE '%mixed%' OR LOWER(Raw_Ethnicity) LIKE '%multi%' OR LOWER(Raw_Ethnicity) LIKE '%two or more%' THEN 'Multiracial'
            WHEN LOWER(Raw_Ethnicity) LIKE '%prefer not%' OR LOWER(Raw_Ethnicity) LIKE '%none%' OR Raw_Ethnicity IS NULL OR TRIM(Raw_Ethnicity) = '' THEN 'Not Specified'
            ELSE 'Other'
        END AS Clean_Ethnicity
    FROM Prepped_Survey
)
SELECT 
    `Unique ID`,
    `Q2 - Did you switch careers into Data?`,
    `Satisfaction_Salary`,
    `Satisfaction_WorkLife`,
    `Satisfaction_Coworkers`,
    `Satisfaction_Management`,
    `Satisfaction_Upward`,
    `Satisfaction_Learning`,
    `Q7 - How difficult was it for you to break into Data?`,
    `Q8_Most_Important_Thing`,
    `Q9 - Male/Female?`,
    `Q11 - Which Country do you live in?`,
    `Q12 - Highest Level of Education`,
    `Q4 - What Industry do you work in?`,
    Current_Role,
    min_salary,
    max_salary,
    (min_salary + max_salary) / 2 AS avg_salary,
    Favorite_Language,
    Clean_Date,
    Age,
    Age AS `Q10 - Current Age`,
    Age_Brackets,
    Clean_Ethnicity
FROM Parsed_Data;