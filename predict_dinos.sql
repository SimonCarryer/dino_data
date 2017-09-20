
CREATE TABLE dino_models
([model] varbinary(max))


CREATE PROCEDURE [dbo].[TrainDinoModel]

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
	INSERT INTO dino_models 

	EXEC sp_execute_external_script @language = N'R',  
									@script = N'
		require(nnet)
		range01 <- function(x){(x-min(x))/(max(x)-min(x))}

			data.frame(lapply(InputDataSet[-1], as.numeric)) -> d1
			lapply(d1, range01) -> d2
			data.frame(d2) -> scaled

		scaled[''diet''] <- InputDataSet[''diet'']
		model <- multinom(diet ~ weight..tonnes. + quadruped + length..m. + Jurassic + display + defence + feathers..likely., data = scaled)
		serialised <- data.frame(model=as.raw(serialize(model, NULL)))  
	',							
								@input_data_1 = @inquery,  
								@output_data_1_name = N'serialised'
	;  
END  
GO  

-- Execute the script and populate the table with a model - the table could hold multiple models

exec [dbo].[TrainDinoModel];

select * from dino_models



CREATE PROCEDURE [dbo].[PredictDino] @inquery nvarchar(max)  
AS  
BEGIN  

	DECLARE @lmodel2 varbinary(max) = (SELECT TOP 1 model  
	FROM dino_models);  

	EXEC sp_execute_external_script @language = N'R',  
									@script = N'  
		require(nnet)
		range01 <- function(x){(x-min(x))/(max(x)-min(x))}

			data.frame(lapply(InputDataSet[-2], as.numeric)) -> d1
			lapply(d1, range01) -> d2
			data.frame(d2) -> scaled

	mod <- unserialize(as.raw(model));  
	OutputDataSet <- data.frame(predict(mod, type="class", newdata=scaled))
	OutputDataSet[''name''] <- InputDataSet[''name'']
	',  
									@input_data_1 = @inquery,  
									@params = N'@model varbinary(max)',  
									@model = @lmodel2  
	WITH RESULT SETS ((predicted_diet varchar(50), name varchar(50)));  
  
END  
  
GO  



-- Run the prediction

create table #dino_predictions
(predicted_diet varchar(max) NOT NULL, name varchar(max) NOT NULL)

-- Generate some input data



DECLARE @query_string nvarchar(max)  
SET @query_string='SELECT	 [name] 
							,[diet]
							,[weight (tonnes)]
							,case when [gait] = ''quadrupedal'' then 1 else 0 end as [quadruped]
							,[length (m)]
							,[Jurassic]
							,[display]
							,[defence]
							,[feathers (likely)]
						FROM [R_Experiment].[dbo].[dino_data]
						WHERE train = 0'

insert into #dino_predictions 
EXEC [dbo].[PredictDino] @inquery = @query_string;


select a.name, a.predicted_diet, b.diet as actual_diet
from #dino_predictions a
join dbo.dino_data b
on a.name = b.name


