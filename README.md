# COVID-19_FBA
Drug repositioning of single and drug combinations using Flux Balance Analysis

## Table of contents
* [Publication](#publication)
* [Pipeline](#pipeline)
* [Installation](#installation)
* [Analysis](#analysis)


## Publication
> Candidate selection for repositioning of metabolic drugs and drug combinations for SARS-CoV-2 infected lung tissue through network analysis.
> Ali Kishk, Maria Pires Pacheco, Thomas Sauter.
> University of Luxembourg.

## Pipeline_Overview
![Pipeline](/Figs/Fig2_Extended.png)

## Installation

Matlab:
*	COBRA Toolbox V3: https://opencobra.github.io/cobratoolbox/stable/installation.html
*	rFASTCORMICS: https://wwwen.uni.lu/research/fstm/dlsm/research_areas/systems_biology/software/rfastcormics

R: 
`apt install r-base r-base-core r-recommended r-base-dev`
#### Most needed R packages can be installed from:
`Rscript Install_R_Dependancies.R`
*	edgeR==3.30.3
*	DESeq2==1.28.1
*	FactoMineR==2.4
*	networkD3==0.4
*	ggplot==3.3.3

Python:  
`apt install python3.7`  
`pip install gseapy==0.9.17 jupyter==4.5.0 numpy pandas seaborn matplotlib  `


## Analysis

### Step 1: 
### Download the raw expression data 

#### Create a new directory to download the read count data in
`mkdir data data/time_series_study data/severity_study`

#### Begin downloading the FPKM / RPKM and metadata
##### The severity study
`wget ftp://ftp.ncbi.nlm.nih.gov/geo/series/GSE147nnn/GSE147507/suppl/GSE147507_RawReadCounts_Human.tsv.gz -P data/severity_study/`
`gunzip data/severity_study/GSE147507_RawReadCounts_Human.tsv.gz`
##### The time-series study
Download manually the FPKM for the polyA of GSE148729: https://filetransfer.mdc-berlin.de/?u=CVXckugR&p=MACT6Xw9
* SupplementaryData2_Calu3_polyA_series1_fpkm.tsv	
* SupplementaryData5_H1299_polyA_fpkm.tsv
* SupplementaryData3_Calu3_polyA_series2_fpkm.tsv

#### PCA analysis on the severity study
`mkdir Figs data/severity_study/DEGs`
`Rscript PCA_analysis.R`
#### DEG analysis on the severity study
`Rscript DEG_analysis.R`

### Step 2: 
### Calculate the differentially expressed metabolic pathways
#### Calculate differentially expressed reactions (DER) for the severity study
`matlab -nodisplay -nodesktop -r Differentially_Expressed_Reactions_Table.m`
#### Visualize DERs
`jupyter nbconvert --to notebook --inplace --execute Visualize_Differentially_Expressed_Pathways.ipynb`

### Step 3: 
### Extract the metadata from the FPKM and read count files of the severity study 
#### The time-series study
#### Extract metadata and\nDividing the lung FPKM according to ecah phenotype to a seperate csv file for model reconstruction 
`jupyter nbconvert --to notebook --inplace --execute FPKM_Dividing_Timeseries_Study.ipynb`
#### Extract gene lengths for RPKM for the severity study
`Rscript Extract_gene_lengths.R`
#### Extract metadata and calculate RPKM for model building for the severity study
`jupyter nbconvert --to notebook --inplace --execute  Calculate_RPKM.ipynb`

![Differentially Expressed Metabolic Pathways](/Figs/Differentially_Expressed_Reactions_All_Sorted.png)

### Step 4:
### Model building, then single and double gene deletion 
`mkdir models models/timeseries models/severity KO_data KO_data/timeseries KO_data/severity`

#### Model building and single and double gene deletion on the severity study
`matlab -nodisplay -nodesktop -r Model_building_severity_Recon3D.m `
`matlab -nodisplay -nodesktop -r Model_building_severity_Recon2.m`
#### Model building and single and double gene deletion on the time series study
`matlab -nodisplay -nodesktop -r Model_building_timeseries_Recon3D.m`
`matlab -nodisplay -nodesktop -r Model_building_timeseries_Recon2.m`
#### Summerize all KO results from different conditions and models
`matlab -nodisplay -nodesktop -r Summarize_KO_Results_severity.m`
`matlab -nodisplay -nodesktop -r Summarize_KO_Results_timeseries.m`

#### Pathway analysis of the SKO and DKO using KEGG
`jupyter nbconvert --to notebook --inplace --execute Enrichment_Analysis_KEGG.ipynb`
#### Metabolic Pathway Analysis of the SKO genes
`matlab -nodisplay -nodesktop -r  SKO_Metabolic_Pathway_Analysis.m`
`jupyter nbconvert --to notebook --inplace --execute Visualize_SKO_Pathways.ipynb`

### Step 5: 
### Drug Repurpusing for single and drug combinations
`mkdir drugbank`
#### Download DrugBank .xml  manually to drukbank folder
#### convert .xml to csv and integrate MedDRA side effect database
`jupyter nbconvert --to notebook --inplace --execute  DrugBank-MedDRA_Integration.ipynb`
#### Calculate essentiality and safety and apply drug repurusing using DrugBank for single and double gene deletion
`jupyter nbconvert --to notebook --inplace --execute  Drug_Repurposing_DrugBank.ipynb`
#### Build a tripartite network of all drug-gene-pathways interactions for single and double gene deletion
`jupyter nbconvert --to notebook --inplace --execute  Drug_Repurposing_Map_Drug_Gene_Pathway.ipynb`
`Rscript Visualize_Tripartite_Drug_Gene_Pathway.R`
