

CREATE TABLE dbo.dino_coefs
(intercept float,
weight_coef float,
quadruped_coef float,
length_coef float,
jurassic_coef float,
display_coef float,
defence_coef float,
feathers_coef float)



CREATE PROCEDURE [dbo].[DinoModelCoef]

AS  
BEGIN  

	DECLARE @inquery nvarchar(max) = N'SELECT		[diet]
													,[weight (tonnes)]
													,case when [gait] = ''quadrupedal'' then 1 else 0 end as [quadruped]
													,[length (m)]
													,[Jurassic]
													,[display]
													,[defence]
													,[feathers (likely)]
												FROM [R_Experiment].[dbo].[dino_data]
												WHERE train = 1'
	INSERT INTO dbo.dino_coefs 

	EXEC sp_execute_external_script @language = N'R',  
									@script = N'

		require(nnet)
		range01 <- function(x){(x-min(x))/(max(x)-min(x))}

			data.frame(lapply(InputDataSet[-1], as.numeric)) -> d1
			lapply(d1, range01) -> d2
			data.frame(d2) -> scaled

		scaled[''diet''] <- InputDataSet[''diet'']
		model <- multinom(diet ~ weight..tonnes. + quadruped + length..m. + Jurassic + display + defence + feathers..likely., data = scaled)
		coefs <- data.frame(t(coef(model)))
	',  
								@input_data_1 = @inquery,  
								@output_data_1_name = N'coefs'
	;  
END  
GO  


-- Execute the script and populate the table with a model - the table could hold multiple models

exec [dbo].[DinoModelCoef];


-- Predict using the coeficients

select  a.name, 
		case when intercept + 
		b.weight_coef * a.[weight (tonnes)] + 
		b.quadruped_coef * case when [gait] = 'quadrupedal' then 1 else 0 end +
		b.jurassic_coef * a.jurassic +
		b.display_coef * a.display +
		b.defence_coef * a.defence +
		b.feathers_coef * a.[feathers (likely)] > 0 then 'herbivore' else 'carnivore' end as prediction
from dino_data a
join dbo.dino_coefs b
on 1 = 1
where train = 0

