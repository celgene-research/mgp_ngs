# added to inventory generator
# 
# # Cluster.F definition from Brian Walker 2017-08-16
# We thought that for determining survival curves for sole events e.g delTP53, 
#  we should use the largest number possible.  This would mean a cluster for 
#  which we have copy number pass, age <75 and survival data.  I think this 
#  is 862 (actually 863 as there is one PFS/OS missing from each but not 
#  the same patient).
#  
# Cluster.F = (INV_Has.nd.cnv &
#                INV_Under75 &
#                INV_Has.pfsos) 


source("curation_scripts.R")
run_master_inventory()
cluster_flow(names = "Cluster.F")
