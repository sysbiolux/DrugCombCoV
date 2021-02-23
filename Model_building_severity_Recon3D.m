%(c) Ali Kishk, Maria Piress Pacheco & Thomas Sauter
% 01 June 2020
% Luxembourg University

addpath(genpath(pwd)); %add all files and folders in the working folder to matlab
addpath(genpath('~/cobratoolbox/'));
changeCobraSolver('ibm_cplex');

addpath(genpath('~/FASTCORMICS RNAseq/'));
solverOK=changeCobraSolver('ibm_cplex','all');

%Load Recon3D model
load('./Recon3DModel_301.mat')
%Removing gene version from the model
genes = Recon3DModel.genes;
for i=1:numel(genes)
    x = strsplit(table2array(genes(i,1)),'.');
    genes(i,1) = cellstr(x(1,1));
end
Recon3DModel.genes = genes;
%Set reversible rxns
Recon3DModel.rev= zeros(numel(Recon3DModel.rxns),1);
Recon3DModel.rev(Recon3DModel.lb<0)=1;

%setting model reconstruction parameters
already_mapped_tag = 0;
consensus_proportion = 0.9;
epsilon = 1e-4;
% inhouse dictionary for recon model
% for other models and data, the user has to create a dictionary using for~
% instance biomart or db2db
load('./dico_201911.mat')

% add viral biomass equation from https://www.ebi.ac.uk/biomodels/MODEL2003020001
% the equation metabolites was changed according to metobilte nomeclature
% in Recon3D
equation = importfile("./viral_biomass_rxn_recon.txt", [1, Inf]);
equation = table2array(equation);
Recon3DModel_inf = addReaction( Recon3DModel,'biomass_virus',cell2mat(equation));
Recon3DModel_inf.rev = Recon3DModel_inf.lb < 0; % the rev field will be a logical array
A = fastcc_4_fastcormics(Recon3DModel_inf, 1e-4, 0);
models_keep = zeros(numel(Recon3DModel_inf.rxns), 1);
models_keep(A,1) = 1;
Recon3DModel_inf = removeRxns(Recon3DModel_inf,Recon3DModel_inf.rxns(setdiff(1:numel(Recon3DModel_inf.rxns),find(models_keep(:,1)))));

optional_settings.func = {'DM_atp_c_','biomass_maintenance'};
optional_settings_.func = {'DM_atp_c_','biomass_maintenance','biomass_virus'};

rpkm = readtable('./data/severity_study/RPKM_3_all.csv');
rownames = rpkm(:,1);
rownames = table2array(rownames);
rpkm.Properties.RowNames = table2array(   rpkm(:,1));
rpkm = rpkm(:,2:end);
colnames_all_ = rpkm.Properties.VariableNames;
%Remove drug pertubation from Series16
rpkm = rpkm(:,~contains(colnames_all_,'_Rux'));
colnames_all_ = colnames_all_(~contains(colnames_all_,'_Rux'));
target_conditions = {'Series1_','Series2_','Series5_','Series6_','Series7_','Series16_'};
rpkm = table2array(rpkm);

for l=1:numel(target_conditions)
    %clear -regexp ^genes ^model ^gr

    mock_idx = find(contains(colnames_all_,'Mock') & contains(colnames_all_,target_conditions(l)));
    infected_idx = find(contains(colnames_all_,'SARS_CoV_2') & contains(colnames_all_,target_conditions(l)));

    rpkm_ctl = rpkm(:,mock_idx);
    rpkm_cov = rpkm(:,infected_idx);
    
    % Reconstruct infected model
    discretized = discretize_FPKM(rpkm_cov,infected_idx);
    [~, A] = fastcormics_2018(Recon3DModel_inf, discretized, rownames, dico, already_mapped_tag, consensus_proportion, 1e-4, optional_settings_);

    % check model consistency
    models_keep = zeros(numel(Recon3DModel_inf.rxns), 1); 
    models_keep(A,1) = 1;
    model_cov = removeRxns(Recon3DModel_inf,Recon3DModel_inf.rxns(setdiff(1:numel(Recon3DModel_inf.rxns),find(models_keep(:,1)))));
    
    % Remove unused genes
    model_cov = removeUnusedGenes(model_cov);
    % check consistency
    sanity= fastcc_4_fastcormics(model_cov,1e-4,0);
    if numel(sanity)==numel(model_cov.rxns)
        disp('Consistent Control Model')
    else
        disp('Inconsistent Control Model')
    end
    % Adjust Objective function for infected models
    model_cov = changeObjective(model_cov,'biomass_maintenance',1);
    sol=optimizeCbModel(model_cov);
    idx_biomass = find(ismember(model_cov.rxns,'biomass_maintenance'));
    idx_biomass_virus = find(ismember(model_cov.rxns,'biomass_virus'));

    model_cov.c(idx_biomass)=100;
    model_cov.c(idx_biomass_virus)=1;
    model_cov.ub(idx_biomass)=0.1 *sol.f;
    %Save the reconstructed model
    model_name = replace(target_conditions(l),'eries','');
    save('./models/severity/'+string(model_name)+'SARS_CoV_2_model_3D.mat','model_cov');
    
    % Single gene KO on the infected models
    [grRatio_cov, grRateKO_cov, grRateWT_cov, ~, ~, ~, geneList]= singleGeneDeletion_MISB(...
        model_cov, 'FBA', [], 0, 1);

    threshold = 0.2;
    genes_cov =  geneList(grRatio_cov<= threshold);

    if numel(mock_idx)>=2
        % Reconstruct infected model
        discretized = discretize_FPKM(rpkm_ctl, mock_idx);
        [~, A] = fastcormics_2018(Recon3DModel, discretized, rownames, dico, already_mapped_tag, consensus_proportion, 1e-4, optional_settings);

        % check model consistency
        models_keep = zeros(numel(Recon3DModel.rxns), 1); 
        models_keep(A,1) = 1;
        model_ctl = removeRxns(Recon3DModel,Recon3DModel.rxns(setdiff(1:numel(Recon3DModel.rxns),find(models_keep(:,1)))));

        % Remove unused genes
        model_ctl = removeUnusedGenes(model_ctl);
        % check consistency
        sanity= fastcc_4_fastcormics(model_ctl,1e-4,0);
        if numel(sanity)==numel(model_ctl.rxns)
            disp('Consistent Control Model')
        else
            disp('Inconsistent Control Model')
        end

        % Adjust Objective function for infected models
        model_ctl = changeObjective(model_ctl,'biomass_maintenance',1);
        save('./models/severity/'+string(model_name)+'Mock_model_3D.mat','model_ctl');
        
        essential_genes_in_ctl = intersect(genes_cov,model_ctl.genes);
        [grRatio_ctl, grRateKO_ctl, grRateWT_ctl, ~, ~, ~, geneList2]= singleGeneDeletion_MISB(...
            model_ctl, 'FBA', essential_genes_in_ctl, 0, 1);
        genes_ctl =  essential_genes_in_ctl(grRatio_ctl<= threshold);

        % define essential genes in the infected model, that dont exist in
        % the reconstructed mock model as unkown safety
        SKO_unk = setdiff(genes_cov,model_ctl.genes);
    else
        essential_genes_in_ctl = {'0'};
        grRatio_ctl = {'0'};
        model_ctl  = {'0'};
        genes_ctl  = {'0'};
        % define essential genes in the infected model, where there is no
        % mock model as unkown safety.
        SKO_unk = [];
    end
    %% Find SKO that is safe on healthy models
    SKO_safe = setdiff(essential_genes_in_ctl,genes_ctl);
    SKO_toxic = intersect(essential_genes_in_ctl,genes_ctl);
    %SKO_unk = setdiff(genes_cov,model_ctl.genes);
 
    % Save SKO outputs        
    save('./KO_data/severity/SKO_'+string(model_name)+'3D.mat');
end


for i=1:numel(target_conditions)
    model_name = replace(target_conditions(i),'eries','');
    % Double gene KO 
    load('./KO_data/severity/SKO_'+string(model_name)+'3D.mat');
    
    [grRatio_cov_, grRateKO_cov_, grRateWT_cov_]= doubleGeneDeletion(...
        model_cov, 'FBA');

    % Extracting Infected DKO outputs
    [DKO_all,DKO_non_ess,DKO_syn,DKO_both] = Find_Double_KO_Outputs(...
        grRatio_cov_,model_cov.genes,genes_cov);

    if numel(mock_idx)>0
        %% find DKO that is safe on healthy model
        [DKO_safe,DKO_toxic, grRateWT_ctl] = Find_Safe_DKO(...
            DKO_both,model_ctl,0.1);
    else
        DKO_toxic = DKO_both;
        DKO_safe = ['NaN','NaN'];
    end
    save('./KO_data/severity/DKO_'+string(model_name)+'3D.mat');
end