

CREATE PROCEDURE [dbo].[ScalyCluster] @inquery nvarchar(max) 

AS  
BEGIN  

	EXEC sp_execute_external_script @language = N'R',  
									@script = N'
			set.seed(20)

			range01 <- function(x){(x-min(x))/(max(x)-min(x))}

			data.frame(lapply(InputDataSet[-1], as.numeric)) -> d1
				lapply(d1, range01) -> d2
				data.frame(d2) -> scaled

			OutputDataSet <- data.frame(InputDataSet[1], kmeans(scaled, 3, nstart=20)[1])',  
								@input_data_1 = @inquery,  
								@output_data_1_name = N'OutputDataSet'
								WITH RESULT SETS (([name] varchar(max) NOT NULL, [cluster] int NOT NULL));
END  ;
GO  

create table #dino_clusters
([name] varchar(max) NOT NULL, [cluster] int NOT NULL)

insert into #dino_clusters 
exec [dbo].[ScalyCluster] @inquery = 'SELECT [name]
											,[weight (tonnes)]
											,case when [gait] = ''quadrupedal'' then 1 else 0 end as [quadruped]
											,[length (m)]
											,[Jurassic]
											,[display]
											,[defence]
											,[feathers (likely)]
										FROM [R_Experiment].[dbo].[dino_data]'
	
		
			
select cluster, 
		sum(case when diet = 'carnivore' then 1 else 0 end) as carnivores,
		sum(case when diet = 'herbivore' then 1 else 0 end) as herbivores 
from dbo.[dino_data] a
join #dino_clusters b
on a.name = b.name
group by cluster