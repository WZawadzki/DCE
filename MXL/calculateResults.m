function [Results, EstimOpt] = calculateResults(Results, Results_old, INPUT, err_mtx, EstimOpt, OptimOpt)

b0 = Results.b0_old;

LLfun2 = @(B) LL_mxl(INPUT.YY,INPUT.XXa,INPUT.XXm,INPUT.Xs,err_mtx,EstimOpt,B);

if EstimOpt.HessEstFix == 0 % this will fail if there is no gradient available!
    try
        [Results.LLdetailed,Results.jacobian] = LLfun2(Results.bhat);
        Results.jacobian = Results.jacobian.*INPUT.W;
    catch % theErrorInfo
        Results.LLdetailed = LLfun2(Results.bhat);
        Results.jacobian2 = ...
            numdiff(@(B) INPUT.W.*LLfun2(B),Results.LLdetailed,Results.bhat, ...
            isequal(OptimOpt.FinDiffType,'central'),EstimOpt.BActive);
        Results.jacobian2 = Results.jacobian2.*INPUT.W;
    end
elseif EstimOpt.HessEstFix == 1
    if isequal(OptimOpt.GradObj,'on') && EstimOpt.NumGrad == 0
        [Results.LLdetailed,Results.jacobian] = LLfun2(Results.bhat);
        Results.jacobian = Results.jacobian.*INPUT.W;
    else
        Results.LLdetailed = LLfun2(Results.bhat);
        Results.jacobian = ...
            numdiff(@(B) INPUT.W.*LLfun2(B),Results.LLdetailed,Results.bhat, ...
            isequal(OptimOpt.FinDiffType,'central'),EstimOpt.BActive);
        Results.jacobian = Results.jacobian.*INPUT.W;
    end
elseif EstimOpt.HessEstFix == 2
    Results.LLdetailed = LLfun2(Results.bhat);
    Results.jacobian = jacobianest(@(B) INPUT.W.*LLfun2(B),Results.bhat);
elseif EstimOpt.HessEstFix == 3
    Results.LLdetailed = LLfun2(Results.bhat);
    Results.hess = hessian(@(B) sum(INPUT.W.*LLfun2(B)),Results.bhat);
elseif EstimOpt.HessEstFix == 4
    [Results.LLdetailed,~,Results.hess] = LLfun2(Results.bhat);
    % no weighting?
end
Results.LLdetailed = Results.LLdetailed.*INPUT.W;

if EstimOpt.HessEstFix == 1 || EstimOpt.HessEstFix == 2
    Results.hess = Results.jacobian'*Results.jacobian;
end
EstimOpt.BLimit = (sum(Results.hess) == 0 & EstimOpt.BActive == 1);
EstimOpt.BActive(EstimOpt.BLimit == 1) = 0;
Results.hess = Results.hess(EstimOpt.BActive == 1,EstimOpt.BActive == 1);
Results.ihess = inv(Results.hess);
Results.ihess = direcXpnd(Results.ihess,EstimOpt.BActive);
Results.ihess = direcXpnd(Results.ihess',EstimOpt.BActive);

if EstimOpt.RobustStd == 1
    if ~isfield(Results,'jacobian')
        if EstimOpt.NumGrad == 0
            [~,Results.jacobian] = LLfun2(Results.bhat);
            Results.jacobian = Results.jacobian.*INPUT.W(:,ones(1,size(Results.jacobian,2)));
        else
            Results.jacobian = ...
                numdiff(@(B) INPUT.W.*LLfun2(B),Results.LLdetailed,Results.bhat, ...
                isequal(OptimOpt.FinDiffType,'central'),EstimOpt.BActive);
        end
    end
    RobustHess = Results.jacobian'*Results.jacobian;
    Results.ihess = Results.ihess*RobustHess*Results.ihess;
end

Results.std = sqrt(diag(Results.ihess));
Results.std(EstimOpt.BActive == 0) = NaN;
Results.std(EstimOpt.BLimit == 1) = 0;
Results.std(imag(Results.std) ~= 0) = NaN;

if any(INPUT.MissingInd == 1) % In case of some missing data
    idx = sum(reshape(INPUT.MissingInd,[EstimOpt.NAlt,EstimOpt.NCT*EstimOpt.NP])) == EstimOpt.NAlt;
    idx = sum(reshape(idx,[EstimOpt.NCT,EstimOpt.NP]),1)'; % no. of missing NCT for every respondent
    idx = EstimOpt.NCT - idx;
    R2 = mean(exp(-Results.LLdetailed./idx),1);
    Results.CrossEntropy = mean(Results.LLdetailed./idx,1);
else
    R2 = mean(exp(-Results.LLdetailed/EstimOpt.NCT),1);
    Results.CrossEntropy = mean(Results.LLdetailed./EstimOpt.NCT,1);
end

if EstimOpt.Scores ~= 0
    Results.Scores = ...
        BayesScoresMXL(INPUT.YY,INPUT.XXa,INPUT.XXm,INPUT.Xs,err_mtx,EstimOpt,Results.bhat);
end

% save out_MXL1
% return

if EstimOpt.FullCov == 0
    Results.DetailsA(1:EstimOpt.NVarA,1) = Results.bhat(1:EstimOpt.NVarA);
    Results.DetailsA(1:EstimOpt.NVarA,3:4) = ...
        [Results.std(1:EstimOpt.NVarA),pv(Results.bhat(1:EstimOpt.NVarA),Results.std(1:EstimOpt.NVarA))];
    Results.DetailsV(1:EstimOpt.NVarA,1) = abs(Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2));
    Results.DetailsV(1:EstimOpt.NVarA,3:4) = ...
        [Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2), ...
         pv(Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2), ...
         Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2))];
    if EstimOpt.NVarM > 0
        Results.DetailsM = [];
        for i=1:EstimOpt.NVarM
            Results.DetailsM(1:EstimOpt.NVarA,4*i-3) = Results.bhat(EstimOpt.NVarA*(2+i-1)+1:EstimOpt.NVarA*(2+i));
            Results.DetailsM(1:EstimOpt.NVarA,4*i-1:4*i) = ...
                [Results.std(EstimOpt.NVarA*(2+i-1)+1:EstimOpt.NVarA*(2+i)), ...
                 pv(Results.bhat(EstimOpt.NVarA*(2+i-1)+1:EstimOpt.NVarA*(2+i)), ...
                 Results.std(EstimOpt.NVarA*(2+i-1)+1:EstimOpt.NVarA*(2+i)))];
        end
    end
    
    %     if any(EstimOpt.Dist == 1) %     transform normal to lognormal for display (delta):
    %         log_idx = find(EstimOpt.Dist==1);
    %         Results.DetailsA(log_idx,1) = exp(Results.DetailsA(log_idx,1) + Results.DetailsV(log_idx,1).^2./2);
    %         Results.std_lognormal = Results.std;
    %         for i = 1:size(log_idx,2)
    %             Results.std_lognormal(log_idx(i)) = (exp(2*Results.bhat(log_idx(i)) + Results.DetailsV(log_idx(i),1).^2).*...
    %                 (Results.ihess(log_idx(i),log_idx(i)) + Results.DetailsV(log_idx(i),1).*(2.*Results.ihess(log_idx(i),EstimOpt.NVarA + log_idx(i)) + Results.DetailsV(log_idx(i),1).*Results.ihess(EstimOpt.NVarA + log_idx(i),EstimOpt.NVarA + log_idx(i)))))^0.5;
    %             Results.std_lognormal(EstimOpt.NVarA + log_idx(i)) = exp(-1 + 2*abs(Results.bhat(log_idx(i))) + 2*Results.DetailsV(log_idx(i),1).^2).*...
    %                 (Results.ihess(log_idx(i),log_idx(i)) + Results.DetailsV(log_idx(i),1).*(4.*Results.ihess(log_idx(i),EstimOpt.NVarA + log_idx(i)) + 4.*Results.DetailsV(log_idx(i),1).*Results.ihess(EstimOpt.NVarA + log_idx(i),EstimOpt.NVarA + log_idx(i)))).^2;
    %         end
    %         Results.DetailsA(log_idx,3:4) = [Results.std_lognormal(log_idx),pv(Results.DetailsA(log_idx,1),Results.std_lognormal(log_idx))];
    %         Results.DetailsV(log_idx,1) = ((exp(Results.DetailsV(log_idx,1).^2) - 1).*exp(2.*Results.bhat(log_idx) + Results.DetailsV(log_idx,1).^2)).^0.5;
    %         Results.DetailsV(log_idx,3:4) = [Results.std_lognormal(EstimOpt.NVarA + log_idx),pv(Results.DetailsV(log_idx,1),Results.std_lognormal(EstimOpt.NVarA + log_idx))];
    %     end
    
    if isfield(EstimOpt,'EffectiveMoments') && EstimOpt.EffectiveMoments == 1
        if any(EstimOpt.Dist == 1) %     transform normal to lognormal for display (simulation):
            Results.DetailsA_underlying = Results.DetailsA;
            Results.DetailsV_underlying = Results.DetailsV;
            if EstimOpt.NVarM > 0
                Results.DetailsM_underlying = Results.DetailsM;
            end
            log_idx = find(EstimOpt.Dist==1);
            try % in case Results.ihess is not positive semidefinite (avoid mvnrnd error)
                bhat_sim = mvnrnd(Results.bhat(1:EstimOpt.NVarA*(2+EstimOpt.NVarM)), ...
                    Results.ihess(1:EstimOpt.NVarA*(2+EstimOpt.NVarM),...
                    1:EstimOpt.NVarA*(2+EstimOpt.NVarM)),NSdSim)';
                if EstimOpt.NVarM > 0
                    BM_i = permute(reshape(...
                        bhat_sim(EstimOpt.NVarA*2+1:EstimOpt.NVarA*2+EstimOpt.NVarA*EstimOpt.NVarM,:), ...
                        [EstimOpt.NVarA,EstimOpt.NVarM,NSdSim]),[3,1,2]);
                    bhat_new = zeros(NSdSim,5*EstimOpt.NVarA);
                    bhatM_new = zeros(NSdSim,5*EstimOpt.NVarA*EstimOpt.NVarM);
                    parfor i = 1:NSdSim
                        bhat_i = bhat_sim(:,i);
                        B0_i = mvnrnd(bhat_i(1:EstimOpt.NVarA)', ...
                                      diag(bhat_i(EstimOpt.NVarA+1:EstimOpt.NVarA*2).^2), ...
                                      NSdSim);
                        B0exp_i = B0_i;
                        B0exp_i(:,log_idx) = exp(B0exp_i(:,log_idx));
                        bhat_new(i,:) = [mean(B0exp_i),median(B0exp_i), ...
                                         std(B0exp_i),quantile(B0exp_i, ...
                                         0.025),quantile(B0exp_i,0.975)];
                        
                        B0M_i = BM_i;
                        B0M_i(:,log_idx) = ...
                            exp(B0M_i(:,log_idx) + B0_i(:,log_idx)) - B0exp_i(:,log_idx);
                        bhatM_new(i,:) = ...
                            [mean(B0M_i),median(B0M_i),std(B0M_i), ...
                             quantile(B0M_i,0.025),quantile(B0M_i,0.975)];
                    end
                else
                    bhat_new = zeros(NSdSim,5*EstimOpt.NVarA);
                    parfor i = 1:NSdSim
                        bhat_i = bhat_sim(:,i);
                        B0_i = mvnrnd(bhat_i(1:EstimOpt.NVarA)', ...
                                      diag(bhat_i(EstimOpt.NVarA+1:EstimOpt.NVarA*2).^2), ...
                                      NSdSim);
                        %     b0v = bhat_i(EstimOpt.NVarA+1:end)';
                        %     VC = tril(ones(EstimOpt.NVarA));
                        %     VC(VC==1) = b0v;
                        %     VC = VC*VC';
                        %     B0_i = mvnrnd(bhat_i(1:EstimOpt.NVarA)',VC,sim2);
                        B0_i(:,log_idx) = exp(B0_i(:,log_idx));
                        bhat_new(i,:) = ...
                            [mean(B0_i),median(B0_i),std(B0_i), ...
                             quantile(B0_i,0.025),quantile(B0_i,0.975)];
                    end
                end
                Results.DistStats_Coef = reshape(median(bhat_new,1),[EstimOpt.NVarA,5]);
                Results.DistStats_Std = reshape(std(bhat_new,[],1),[EstimOpt.NVarA,5]);
                Results.DistStats_Q025 = reshape(quantile(bhat_new,0.025),[EstimOpt.NVarA,5]);
                Results.DistStats_Q975 = reshape(quantile(bhat_new,0.975),[EstimOpt.NVarA,5]);
                Results.DetailsA(log_idx,1) = ...
                    exp(Results.DetailsA(log_idx,1) + Results.DetailsV(log_idx,1).^2./2); % We use analytical formula instead of simulated moment
                Results.DetailsA(log_idx,3:4) = ...
                    [Results.DistStats_Std(log_idx,1), ...
                     pv(Results.DetailsA(log_idx,1), ...
                     Results.DistStats_Std(log_idx,1))];
                Results.DetailsV(log_idx,1) = ...
                    ((exp(Results.DetailsV(log_idx,1).^2) - 1).* ...
                     exp(2.*Results.bhat(log_idx) + Results.DetailsV(log_idx,1).^2) ...
                    ).^0.5; % We use analytical formula instead of simulated moment
                Results.DetailsV(log_idx,3:4) = ...
                    [Results.DistStats_Std(log_idx,3), ...
                     pv(Results.DetailsV(log_idx,1), ...
                     Results.DistStats_Std(log_idx,3))];
                if EstimOpt.NVarM > 0
                    Results.DistStatsM_Coef = reshape(median(bhatM_new,1),[EstimOpt.NVarA,5]);
                    Results.DistStatsM_Std = reshape(std(bhatM_new,[],1),[EstimOpt.NVarA,5]);
                    Results.DistStatsM_Q025 = reshape(quantile(bhatM_new,0.025),[EstimOpt.NVarA,5]);
                    Results.DistStatsM_Q975 = reshape(quantile(bhatM_new,0.975),[EstimOpt.NVarA,5]);
                    %                 Results.DetailsM(log_idx,1) = Results.DistStatsM_Coef(log_idx,1);
                    Results.DetailsM(log_idx,1) = ...
                        exp(Results.DetailsA_underlying(log_idx,1) + ...
                            Results.DetailsM(log_idx,1) + ...
                            Results.DetailsV_underlying(log_idx,1).^2./2 ...
                           ) - Results.DetailsA(log_idx,1); % We use analytical formula instead of simulated moments
                    Results.DetailsM(log_idx,3:4) = ...
                        [Results.DistStatsM_Std(log_idx,1), ...
                         pv(Results.DetailsM(log_idx,1), ...
                         Results.DistStatsM_Std(log_idx,1))];
                end
            catch % theErrorInfo
                Results.DetailsA(log_idx,[1,3:4]) = NaN;
                Results.DetailsV(log_idx,[1,3:4]) = NaN;
            end
        end
    end
    
    if sum(EstimOpt.Dist == 3) > 0  % parameters with triangular distribution
        Results.DetailsA(EstimOpt.Dist == 3,1) = ...
            exp(Results.bhat(EstimOpt.Dist == 3)) + EstimOpt.Triang';
        Results.DetailsA(EstimOpt.Dist == 3,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 3)).*Results.std(EstimOpt.Dist == 3), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 3)) + EstimOpt.Triang', ...
             exp(Results.bhat(EstimOpt.Dist == 3)).*Results.std(EstimOpt.Dist == 3))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = zeros(sum(EstimOpt.Dist == 3),1);
        g = [exp(Results.bhat(EstimOpt.Dist == 3)),exp(btmp(EstimOpt.Dist == 3))];
        indx = find(EstimOpt.Dist == 3);
        for i = 1:sum(EstimOpt.Dist == 3)
            stdx(i) = sqrt(g(i,:)*Results.ihess([indx(i),indx(i)+EstimOpt.NVarA], ...
                                                [indx(i),indx(i)+EstimOpt.NVarA] ...
                                               )*g(i,:)');
        end
        %Results.DetailsV(EstimOpt.Dist == 3,1) = exp(btmp(EstimOpt.Dist == 3));
        Results.DetailsV(EstimOpt.Dist == 3,1) = ...
            exp(btmp(EstimOpt.Dist == 3)) + exp(Results.bhat(EstimOpt.Dist == 3)) + ...
            EstimOpt.Triang';
        %Results.DetailsV(EstimOpt.Dist == 3,3:4) = [stdx(EstimOpt.Dist == 3),pv(exp(btmp(EstimOpt.Dist == 3)),stdx(EstimOpt.Dist == 3))];
        Results.DetailsV(EstimOpt.Dist == 3,3:4) = ...
            [stdx,pv(exp(btmp(EstimOpt.Dist == 3)) + ...
                     exp(Results.bhat(EstimOpt.Dist == 3)) + ...
                     EstimOpt.Triang',stdx)];
    end
    if sum(EstimOpt.Dist == 4) > 0  % parameters with Weibull distribution
        Results.DetailsA(EstimOpt.Dist == 4,1) = exp(Results.bhat(EstimOpt.Dist == 4));
        Results.DetailsA(EstimOpt.Dist == 4,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 4)).*Results.std(EstimOpt.Dist == 4), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 4)), ...
             exp(Results.bhat(EstimOpt.Dist == 4)).*Results.std(EstimOpt.Dist == 4))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        Results.DetailsV(EstimOpt.Dist == 4,1) = exp(btmp(EstimOpt.Dist == 4));
        Results.DetailsV(EstimOpt.Dist == 4,3:4) = ...
            [stdx(EstimOpt.Dist == 4),pv(exp(btmp(EstimOpt.Dist == 4)),stdx(EstimOpt.Dist == 4))];
    end
    %%%% WZ21. %%%%
    if sum(EstimOpt.Dist == 9) > 0  % parameters with Uni-Log distribution
        Results.DetailsA(EstimOpt.Dist == 9,1) = exp(Results.bhat(EstimOpt.Dist == 9));
        Results.DetailsA(EstimOpt.Dist == 9,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 9)).*Results.std(EstimOpt.Dist == 9), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 9)), ...
             exp(Results.bhat(EstimOpt.Dist == 9)).*Results.std(EstimOpt.Dist == 9))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        Results.DetailsV(EstimOpt.Dist == 9,1) = exp(btmp(EstimOpt.Dist == 9));
        Results.DetailsV(EstimOpt.Dist == 9,3:4) = ...
            [stdx(EstimOpt.Dist == 9),pv(exp(btmp(EstimOpt.Dist == 9)),stdx(EstimOpt.Dist == 9))];
    end

    if sum(EstimOpt.Dist == 10) > 0  % parameters with Pareto distribution
        Results.DetailsA(EstimOpt.Dist == 10,1) = exp(Results.bhat(EstimOpt.Dist == 10));
        Results.DetailsA(EstimOpt.Dist == 10,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 10)).*Results.std(EstimOpt.Dist == 10), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 10)), ...
             exp(Results.bhat(EstimOpt.Dist == 10)).*Results.std(EstimOpt.Dist == 10))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        Results.DetailsV(EstimOpt.Dist == 10,1) = exp(btmp(EstimOpt.Dist == 10));
        Results.DetailsV(EstimOpt.Dist == 10,3:4) = ...
            [stdx(EstimOpt.Dist == 10),pv(exp(btmp(EstimOpt.Dist == 10)),stdx(EstimOpt.Dist == 10))];
    end
    
    if sum(EstimOpt.Dist == 11) > 0  % parameters with Lomax distribution
        Results.DetailsA(EstimOpt.Dist == 11,1) = exp(Results.bhat(EstimOpt.Dist == 11));
        Results.DetailsA(EstimOpt.Dist == 11,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 11)).*Results.std(EstimOpt.Dist == 11), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 11)), ...
             exp(Results.bhat(EstimOpt.Dist == 11)).*Results.std(EstimOpt.Dist == 11))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        Results.DetailsV(EstimOpt.Dist == 11,1) = exp(btmp(EstimOpt.Dist == 11));
        Results.DetailsV(EstimOpt.Dist == 11,3:4) = ...
            [stdx(EstimOpt.Dist == 11),pv(exp(btmp(EstimOpt.Dist == 11)),stdx(EstimOpt.Dist == 11))];
    end
    
    if sum(EstimOpt.Dist == 12) > 0  % parameters with Logistic distribution
        Results.DetailsA(EstimOpt.Dist == 12,1) = exp(Results.bhat(EstimOpt.Dist == 12));
        Results.DetailsA(EstimOpt.Dist == 12,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 12)).*Results.std(EstimOpt.Dist == 12), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 12)), ...
             exp(Results.bhat(EstimOpt.Dist == 12)).*Results.std(EstimOpt.Dist == 12))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        Results.DetailsV(EstimOpt.Dist == 12,1) = exp(btmp(EstimOpt.Dist == 12));
        Results.DetailsV(EstimOpt.Dist == 12,3:4) = ...
            [stdx(EstimOpt.Dist == 12),pv(exp(btmp(EstimOpt.Dist == 12)),stdx(EstimOpt.Dist == 12))];
    end
    
    if sum(EstimOpt.Dist == 13) > 0  % parameters with Log-Logistic distribution
        Results.DetailsA(EstimOpt.Dist == 13,1) = exp(Results.bhat(EstimOpt.Dist == 13));
        Results.DetailsA(EstimOpt.Dist == 13,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 13)).*Results.std(EstimOpt.Dist == 13), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 13)), ...
             exp(Results.bhat(EstimOpt.Dist == 13)).*Results.std(EstimOpt.Dist == 13))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        Results.DetailsV(EstimOpt.Dist == 13,1) = exp(btmp(EstimOpt.Dist == 13));
        Results.DetailsV(EstimOpt.Dist == 13,3:4) = ...
            [stdx(EstimOpt.Dist == 13),pv(exp(btmp(EstimOpt.Dist == 13)),stdx(EstimOpt.Dist == 13))];
    end
    
    if sum(EstimOpt.Dist == 14) > 0  % parameters with Gumbel distribution
        Results.DetailsA(EstimOpt.Dist == 14,1) = exp(Results.bhat(EstimOpt.Dist == 14));
        Results.DetailsA(EstimOpt.Dist == 14,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 14)).*Results.std(EstimOpt.Dist == 14), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 14)), ...
             exp(Results.bhat(EstimOpt.Dist == 14)).*Results.std(EstimOpt.Dist == 14))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        Results.DetailsV(EstimOpt.Dist == 14,1) = exp(btmp(EstimOpt.Dist == 14));
        Results.DetailsV(EstimOpt.Dist == 14,3:4) = ...
            [stdx(EstimOpt.Dist == 14),pv(exp(btmp(EstimOpt.Dist == 14)),stdx(EstimOpt.Dist == 14))];
    end   
    
    if sum(EstimOpt.Dist == 15) > 0  % parameters with Cauchy distribution
        Results.DetailsA(EstimOpt.Dist == 15,1) = exp(Results.bhat(EstimOpt.Dist == 15));
        Results.DetailsA(EstimOpt.Dist == 15,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 15)).*Results.std(EstimOpt.Dist == 15), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 15)), ...
             exp(Results.bhat(EstimOpt.Dist == 15)).*Results.std(EstimOpt.Dist == 15))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        Results.DetailsV(EstimOpt.Dist == 15,1) = exp(btmp(EstimOpt.Dist == 15));
        Results.DetailsV(EstimOpt.Dist == 15,3:4) = ...
            [stdx(EstimOpt.Dist == 15),pv(exp(btmp(EstimOpt.Dist == 15)),stdx(EstimOpt.Dist == 15))];
    end
    if sum(EstimOpt.Dist == 16) > 0  % parameters with Rayleigh distribution
        Results.DetailsA(EstimOpt.Dist == 16,1) = exp(Results.bhat(EstimOpt.Dist == 16));
        Results.DetailsA(EstimOpt.Dist == 16,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 16)).*Results.std(EstimOpt.Dist == 16), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 16)), ...
             exp(Results.bhat(EstimOpt.Dist == 16)).*Results.std(EstimOpt.Dist == 16))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        %Results.DetailsV(EstimOpt.Dist == 16,1) = exp(btmp(EstimOpt.Dist == 16));
        %Results.DetailsV(EstimOpt.Dist == 16,3:4) = ...
            %[stdx(EstimOpt.Dist == 16),pv(exp(btmp(EstimOpt.Dist == 16)),stdx(EstimOpt.Dist == 16))];
    end
    if sum(EstimOpt.Dist == 17) > 0  % parameters with Exponential distribution
        Results.DetailsA(EstimOpt.Dist == 17,1) = exp(Results.bhat(EstimOpt.Dist == 17));
        Results.DetailsA(EstimOpt.Dist == 17,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 17)).*Results.std(EstimOpt.Dist == 17), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 17)), ...
             exp(Results.bhat(EstimOpt.Dist == 17)).*Results.std(EstimOpt.Dist == 17))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        stdx = exp(btmp).*Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*2);
        %Results.DetailsV(EstimOpt.Dist == 17,1) = exp(btmp(EstimOpt.Dist == 17));
        %Results.DetailsV(EstimOpt.Dist == 17,3:4) = ...
            %[stdx(EstimOpt.Dist == 17),pv(exp(btmp(EstimOpt.Dist == 17)),stdx(EstimOpt.Dist == 17))];
    end
    %%%% WZ21. koniec %%%%
    
    Results.R = [Results.DetailsA,Results.DetailsV];
    if EstimOpt.NVarM > 0
        %         Results.DetailsM = [];
        %         for i=1:EstimOpt.NVarM
        %             Results.DetailsM(1:EstimOpt.NVarA,4*i-3) = Results.bhat(EstimOpt.NVarA*(2+i-1)+1:EstimOpt.NVarA*(2+i));
        %             Results.DetailsM(1:EstimOpt.NVarA,4*i-1:4*i) = [Results.std(EstimOpt.NVarA*(2+i-1)+1:EstimOpt.NVarA*(2+i)),pv(Results.bhat(EstimOpt.NVarA*(2+i-1)+1:EstimOpt.NVarA*(2+i)),Results.std(EstimOpt.NVarA*(2+i-1)+1:EstimOpt.NVarA*(2+i)))];
        %         end
        Results.R = [Results.R,Results.DetailsM];
    end
    if EstimOpt.NVarNLT > 0
        Results.DetailsNLT = [];
        for i=1:EstimOpt.NVarNLT
            Results.DetailsNLT(i,1) = ...
                Results.bhat(EstimOpt.NVarA*(2+EstimOpt.NVarM)+EstimOpt.NVarS+i);
            Results.DetailsNLT(i,3:4) = ...
                [Results.std(EstimOpt.NVarA*(2+EstimOpt.NVarM)+EstimOpt.NVarS+i), ...
                 pv(Results.bhat(EstimOpt.NVarA*(2+EstimOpt.NVarM)+EstimOpt.NVarS+i), ...
                    Results.std(EstimOpt.NVarA*(2+EstimOpt.NVarM)+EstimOpt.NVarS+i))];
        end
        Results.DetailsNLT0 = NaN(EstimOpt.NVarA,4);
        Results.DetailsNLT0(EstimOpt.NLTVariables,:) = Results.DetailsNLT;
        Results.R = [Results.R,Results.DetailsNLT0];
    end
    if EstimOpt.Johnson > 0
        Results.ResultsJ = NaN(EstimOpt.NVarA,8);
        % Location parameters
        Results.DetailsJL(:,1) = Results.bhat((end-2*EstimOpt.Johnson+1):(end-EstimOpt.Johnson));
        Results.DetailsJL(:,3) = Results.std((end-2*EstimOpt.Johnson+1):(end-EstimOpt.Johnson));
        Results.DetailsJL(:,4) = ...
            pv(Results.bhat((end-2*EstimOpt.Johnson+1):(end-EstimOpt.Johnson)), ...
               Results.std((end - 2*EstimOpt.Johnson+1):(end - EstimOpt.Johnson)));
        % Scale parameters
        Results.DetailsJS(:,1) = exp(Results.bhat((end-EstimOpt.Johnson+1):end));
        Results.DetailsJS(:,3) = ...
            exp(Results.bhat((end-EstimOpt.Johnson+1):end)).*Results.std((end-EstimOpt.Johnson+1):end);
        Results.DetailsJS(:,4) = ...
            pv(exp(Results.bhat((end-EstimOpt.Johnson+1):end)), ...
               exp(Results.bhat((end-EstimOpt.Johnson+1):end)).*Results.std((end-EstimOpt.Johnson+1):end));
        Results.ResultsJ(EstimOpt.Dist > 4 & EstimOpt.Dist <= 7,1:4) = Results.DetailsJL;
        Results.ResultsJ(EstimOpt.Dist > 4 & EstimOpt.Dist <= 7,5:8) = Results.DetailsJS;
        Results.R = [Results.R,Results.ResultsJ];
    end
    if EstimOpt.NVarS > 0
        Results.DetailsS = [];
        for i=1:EstimOpt.NVarS
            Results.DetailsS(i,1) = Results.bhat(EstimOpt.NVarA*(2+EstimOpt.NVarM)+i);
            Results.DetailsS(i,3:4) = ...
                [Results.std(EstimOpt.NVarA*(2+EstimOpt.NVarM)+i), ...
                 pv(Results.bhat(EstimOpt.NVarA*(2+EstimOpt.NVarM)+i), ...
                    Results.std(EstimOpt.NVarA*(2+EstimOpt.NVarM)+i))];
        end
        DetailsS0 = NaN(EstimOpt.NVarS,4);
        DetailsS0(1:EstimOpt.NVarS,1:4) = Results.DetailsS;
        
        if EstimOpt.NVarS <= EstimOpt.NVarA % will not work if NVarS > EstimOpt.NVarA
            Results.R = [Results.R;[DetailsS0,NaN(size(DetailsS0,1),size(Results.R,2)-size(DetailsS0,2))]];
        end
    end
    
elseif EstimOpt.FullCov == 1
    Results.DetailsA(1:EstimOpt.NVarA,1) = Results.bhat(1:EstimOpt.NVarA);
    Results.DetailsA(1:EstimOpt.NVarA,3:4) = ...
        [Results.std(1:EstimOpt.NVarA), ...
         pv(Results.bhat(1:EstimOpt.NVarA),Results.std(1:EstimOpt.NVarA))];
    Results.DetailsV = ...
        sdtri(Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA+3)/2), ...
              Results.ihess(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA+3)/2, ...
                            EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA+3)/2), ...
              EstimOpt);
    Results.DetailsV = [Results.DetailsV(:,1),zeros(EstimOpt.NVarA,1),Results.DetailsV(:,2:3)];
    if EstimOpt.NVarM > 0
        Results.DetailsM = [];
        for i=1:EstimOpt.NVarM
            Results.DetailsM(1:EstimOpt.NVarA, 4*i-3) = ...
                Results.bhat(EstimOpt.NVarA*(EstimOpt.NVarA/2+0.5+i)+1: ...
                             EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+i));
            Results.DetailsM(1:EstimOpt.NVarA, 4*i-1:4*i) = ...
                [Results.std(EstimOpt.NVarA*(EstimOpt.NVarA/2+0.5+i)+1: ...
                             EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+i)), ...
                 pv(Results.bhat(EstimOpt.NVarA*(EstimOpt.NVarA/2+0.5+i)+1: ...
                                 EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+i)), ...
                    Results.std(EstimOpt.NVarA*(EstimOpt.NVarA/2+0.5+i)+1: ...
                                EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+i)))];
        end
    end
    
    if isfield(EstimOpt,'EffectiveMoments') && EstimOpt.EffectiveMoments == 1
        if any(EstimOpt.Dist == 1) %     transform normal to lognormal for display (simulation):
            Results.DetailsA_underlying = Results.DetailsA;
            Results.DetailsV_underlying = Results.DetailsV;
            if EstimOpt.NVarM > 0
                Results.DetailsM_underlying = Results.DetailsM;
            end
            log_idx = find(EstimOpt.Dist==1);
            try % in case Results.ihess is not positive semidefinite (avoid mvnrnd error)
                bhat_sim = mvnrnd(Results.bhat,Results.ihess,NSdSim)';
                if EstimOpt.NVarM > 0
                    BM_i = permute(reshape(bhat_sim(EstimOpt.NVarA+sum(1:EstimOpt.NVarA)+1: ...
                                                    EstimOpt.NVarA+sum(1:EstimOpt.NVarA)+ ...
                                                    EstimOpt.NVarA*EstimOpt.NVarM,:), ...
                                           [EstimOpt.NVarA,EstimOpt.NVarM,NSdSim]), ...
                                   [3,1,2]);
                    bhat_new = zeros(NSdSim,5*EstimOpt.NVarA);
                    bhatM_new = zeros(NSdSim,5*EstimOpt.NVarA*EstimOpt.NVarM);
                    parfor i = 1:NSdSim
                        bhat_i = bhat_sim(:,i);
                        b0v = bhat_i(EstimOpt.NVarA+1:EstimOpt.NVarA+sum(1:EstimOpt.NVarA))';
                        VC = tril(ones(EstimOpt.NVarA));
                        VC(VC == 1) = b0v;
                        VC = VC*VC';
                        B0_i = mvnrnd(bhat_i(1:EstimOpt.NVarA)',VC,NSdSim);
                        B0exp_i = B0_i;
                        B0exp_i(:,log_idx) = exp(B0exp_i(:,log_idx));
                        bhat_new(i,:) = [mean(B0exp_i),median(B0exp_i), ...
                                         std(B0exp_i),quantile(B0exp_i,0.025), ...
                                         quantile(B0exp_i,0.975)];
                        
                        B0M_i = BM_i;
                        B0M_i(:,log_idx) = ...
                            exp(B0M_i(:,log_idx) + B0_i(:,log_idx)) - ...
                            B0exp_i(:,log_idx);
                        bhatM_new(i,:) = [mean(B0M_i),median(B0M_i), ...
                                          std(B0M_i),quantile(B0M_i,0.025), ...
                                          quantile(B0M_i,0.975)];
                    end
                else
                    bhat_new = zeros(NSdSim,5*EstimOpt.NVarA);
                    parfor i = 1:NSdSim
                        bhat_i = bhat_sim(:,i);
                        %             B0_i = mvnrnd(bhat_i(1:EstimOpt.NVarA)',diag(bhat_i(EstimOpt.NVarA+1:EstimOpt.NVarA*2).^2),NSdSim);
                        b0v = bhat_i(EstimOpt.NVarA+1:EstimOpt.NVarA+sum(1:EstimOpt.NVarA))';
                        VC = tril(ones(EstimOpt.NVarA));
                        VC(VC == 1) = b0v;
                        VC = VC*VC';
                        B0_i = mvnrnd(bhat_i(1:EstimOpt.NVarA)',VC,NSdSim);
                        B0_i(:,log_idx) = exp(B0_i(:,log_idx));
                        bhat_new(i,:) = [mean(B0_i),median(B0_i),std(B0_i), ...
                                         quantile(B0_i,0.025),quantile(B0_i,0.975)];
                    end
                end
                
                Results.DistStats_Coef = reshape(median(bhat_new,1),[EstimOpt.NVarA,5]);
                Results.DistStats_Std = reshape(std(bhat_new,[],1),[EstimOpt.NVarA,5]);
                Results.DistStats_Q025 = reshape(quantile(bhat_new,0.025),[EstimOpt.NVarA,5]);
                Results.DistStats_Q975 = reshape(quantile(bhat_new,0.975),[EstimOpt.NVarA,5]);
                Results.DetailsA(log_idx,1) = ...
                    exp(Results.DetailsA(log_idx,1) + ...
                        Results.DetailsV(log_idx,1).^2./2); % We use analytical formula instead of simulated moments
                Results.DetailsA(log_idx,3:4) = ...
                    [Results.DistStats_Std(log_idx,1), ...
                     pv(Results.DetailsA(log_idx,1),Results.DistStats_Std(log_idx,1))];
                Results.DetailsV(log_idx,1) = ...
                    ((exp(Results.DetailsV(log_idx,1).^2) - 1).* ...
                     exp(2.*Results.bhat(log_idx) + ...
                         Results.DetailsV(log_idx,1).^2) ...
                     ).^0.5; % We use analytical formula instead of simulated moments
                Results.DetailsV(log_idx,3:4) = ...
                    [Results.DistStats_Std(log_idx,3), ...
                     pv(Results.DetailsV(log_idx,1), ...
                        Results.DistStats_Std(log_idx,3))];
                if EstimOpt.NVarM > 0
                    Results.DistStatsM_Coef = reshape(median(bhatM_new,1),[EstimOpt.NVarA,5]);
                    Results.DistStatsM_Std = reshape(std(bhatM_new,[],1),[EstimOpt.NVarA,5]);
                    Results.DistStatsM_Q025 = reshape(quantile(bhatM_new,0.025),[EstimOpt.NVarA,5]);
                    Results.DistStatsM_Q975 = reshape(quantile(bhatM_new,0.975),[EstimOpt.NVarA,5]);
                    %                 Results.DetailsM(log_idx,1) = Results.DistStatsM_Coef(log_idx,1);
                    Results.DetailsM(log_idx,1) = ...
                        exp(Results.DetailsA_underlying(log_idx,1) + ...
                            Results.DetailsM(log_idx,1) + ...
                            Results.DetailsV_underlying(log_idx,1).^2./2) - ...
                        Results.DetailsA(log_idx,1); % We use analytical formula instead of simulated moments
                    Results.DetailsM(log_idx,3:4) = ...
                        [Results.DistStatsM_Std(log_idx,1), ...
                         pv(Results.DetailsM(log_idx,1), ...
                            Results.DistStatsM_Std(log_idx,1))];
                end
                
            catch % theErrorInfo
                Results.DetailsA(log_idx,[1,3:4]) = NaN;
                Results.DetailsV(log_idx,[1,3:4]) = NaN;
            end
        end
    end
    if sum(EstimOpt.Dist == 3) > 0
        Results.DetailsA(EstimOpt.Dist == 3,1) = exp(Results.bhat(EstimOpt.Dist == 3)) + EstimOpt.Triang';
        Results.DetailsA(EstimOpt.Dist == 3,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 3)).*Results.std(EstimOpt.Dist == 3), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 3)) + EstimOpt.Triang', ...
                exp(Results.bhat(EstimOpt.Dist == 3)).*Results.std(EstimOpt.Dist == 3))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = zeros(sum(EstimOpt.Dist == 3),1);
        g = [exp(Results.bhat(EstimOpt.Dist == 3)),exp(btmp(EstimOpt.Dist == 3))];
        indx = find(EstimOpt.Dist == 3);
        DiagIndex = EstimOpt.DiagIndex(EstimOpt.Dist == 3);
        for i = 1:sum(EstimOpt.Dist == 3)
            stdx(i) = sqrt(g(i,:)*Results.ihess([indx(i),DiagIndex(i)+EstimOpt.NVarA], ...
                                                [indx(i),DiagIndex(i)+EstimOpt.NVarA] ...
                                                )*g(i,:)');
        end
        Results.DetailsV(EstimOpt.Dist == 3,1) = ...
            exp(btmp(EstimOpt.Dist == 3)) + exp(Results.bhat(EstimOpt.Dist == 3)) + EstimOpt.Triang';
        Results.DetailsV(EstimOpt.Dist == 3,3:4) = ...
            [stdx,pv(exp(btmp(EstimOpt.Dist == 3))+exp(Results.bhat(EstimOpt.Dist == 3))+EstimOpt.Triang',stdx)];
    end
    if sum(EstimOpt.Dist == 4) > 0
        Results.DetailsA(EstimOpt.Dist == 4,1) = exp(Results.bhat(EstimOpt.Dist == 4));
        Results.DetailsA(EstimOpt.Dist == 4,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 4)).*Results.std(EstimOpt.Dist == 4), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 4)), ...
                exp(Results.bhat(EstimOpt.Dist == 4)).*Results.std(EstimOpt.Dist == 4))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        Results.DetailsV(EstimOpt.Dist == 4,1) = exp(btmp(EstimOpt.Dist == 4));
        Results.DetailsV(EstimOpt.Dist == 4,3:4) = ...
            [stdx(EstimOpt.Dist == 4),pv(exp(btmp(EstimOpt.Dist == 4)),stdx(EstimOpt.Dist == 4))];
    end
    if sum(EstimOpt.Dist == 5) > 0
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdtmp = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdtmp = stdtmp(EstimOpt.DiagIndex);
        Results.DetailsV(EstimOpt.Dist == 5,1) = btmp(EstimOpt.Dist == 5).^2;
        Results.DetailsV(EstimOpt.Dist == 5,3:4) = ...
            [2*btmp(EstimOpt.Dist == 5).*stdtmp(EstimOpt.Dist == 5), ...
             pv(btmp(EstimOpt.Dist == 5).^2, ...
                2*btmp(EstimOpt.Dist == 5).*stdtmp(EstimOpt.Dist == 5))];
    end
    
    %%%% WZ22. %%%%
    if sum(EstimOpt.Dist == 9) > 0
        Results.DetailsA(EstimOpt.Dist == 9,1) = exp(Results.bhat(EstimOpt.Dist == 9));
        Results.DetailsA(EstimOpt.Dist == 9,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 9)).*Results.std(EstimOpt.Dist == 9), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 9)), ...
                exp(Results.bhat(EstimOpt.Dist == 9)).*Results.std(EstimOpt.Dist == 9))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        Results.DetailsV(EstimOpt.Dist == 9,1) = exp(btmp(EstimOpt.Dist == 9));
        Results.DetailsV(EstimOpt.Dist == 9,3:4) = ...
            [stdx(EstimOpt.Dist == 9),pv(exp(btmp(EstimOpt.Dist == 9)),stdx(EstimOpt.Dist == 9))];
    end
    if sum(EstimOpt.Dist == 10) > 0
        Results.DetailsA(EstimOpt.Dist == 10,1) = exp(Results.bhat(EstimOpt.Dist == 10));
        Results.DetailsA(EstimOpt.Dist == 10,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 10)).*Results.std(EstimOpt.Dist == 10), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 10)), ...
                exp(Results.bhat(EstimOpt.Dist == 10)).*Results.std(EstimOpt.Dist == 10))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        Results.DetailsV(EstimOpt.Dist == 10,1) = exp(btmp(EstimOpt.Dist == 10));
        Results.DetailsV(EstimOpt.Dist == 10,3:4) = ...
            [stdx(EstimOpt.Dist == 10),pv(exp(btmp(EstimOpt.Dist == 10)),stdx(EstimOpt.Dist == 10))];
    end    
    if sum(EstimOpt.Dist == 11) > 0
        Results.DetailsA(EstimOpt.Dist == 11,1) = exp(Results.bhat(EstimOpt.Dist == 11));
        Results.DetailsA(EstimOpt.Dist == 11,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 11)).*Results.std(EstimOpt.Dist == 11), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 11)), ...
                exp(Results.bhat(EstimOpt.Dist == 11)).*Results.std(EstimOpt.Dist == 11))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        Results.DetailsV(EstimOpt.Dist == 11,1) = exp(btmp(EstimOpt.Dist == 11));
        Results.DetailsV(EstimOpt.Dist == 11,3:4) = ...
            [stdx(EstimOpt.Dist == 11),pv(exp(btmp(EstimOpt.Dist == 11)),stdx(EstimOpt.Dist == 11))];
    end
    if sum(EstimOpt.Dist == 12) > 0
        Results.DetailsA(EstimOpt.Dist == 12,1) = exp(Results.bhat(EstimOpt.Dist == 12));
        Results.DetailsA(EstimOpt.Dist == 12,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 12)).*Results.std(EstimOpt.Dist == 12), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 12)), ...
                exp(Results.bhat(EstimOpt.Dist == 12)).*Results.std(EstimOpt.Dist == 12))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        Results.DetailsV(EstimOpt.Dist == 12,1) = exp(btmp(EstimOpt.Dist == 12));
        Results.DetailsV(EstimOpt.Dist == 12,3:4) = ...
            [stdx(EstimOpt.Dist == 12),pv(exp(btmp(EstimOpt.Dist == 12)),stdx(EstimOpt.Dist == 12))];
    end
    if sum(EstimOpt.Dist == 13) > 0
        Results.DetailsA(EstimOpt.Dist == 13,1) = exp(Results.bhat(EstimOpt.Dist == 13));
        Results.DetailsA(EstimOpt.Dist == 13,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 13)).*Results.std(EstimOpt.Dist == 13), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 13)), ...
                exp(Results.bhat(EstimOpt.Dist == 13)).*Results.std(EstimOpt.Dist == 13))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        Results.DetailsV(EstimOpt.Dist == 13,1) = exp(btmp(EstimOpt.Dist == 13));
        Results.DetailsV(EstimOpt.Dist == 13,3:4) = ...
            [stdx(EstimOpt.Dist == 13),pv(exp(btmp(EstimOpt.Dist == 13)),stdx(EstimOpt.Dist == 13))];
    end
    if sum(EstimOpt.Dist == 14) > 0
        Results.DetailsA(EstimOpt.Dist == 14,1) = exp(Results.bhat(EstimOpt.Dist == 14));
        Results.DetailsA(EstimOpt.Dist == 14,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 14)).*Results.std(EstimOpt.Dist == 14), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 14)), ...
                exp(Results.bhat(EstimOpt.Dist == 14)).*Results.std(EstimOpt.Dist == 14))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        Results.DetailsV(EstimOpt.Dist == 14,1) = exp(btmp(EstimOpt.Dist == 14));
        Results.DetailsV(EstimOpt.Dist == 14,3:4) = ...
            [stdx(EstimOpt.Dist == 14),pv(exp(btmp(EstimOpt.Dist == 14)),stdx(EstimOpt.Dist == 14))];
    end
    if sum(EstimOpt.Dist == 15) > 0
        Results.DetailsA(EstimOpt.Dist == 15,1) = exp(Results.bhat(EstimOpt.Dist == 15));
        Results.DetailsA(EstimOpt.Dist == 15,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 15)).*Results.std(EstimOpt.Dist == 15), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 15)), ...
                exp(Results.bhat(EstimOpt.Dist == 15)).*Results.std(EstimOpt.Dist == 15))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        Results.DetailsV(EstimOpt.Dist == 15,1) = exp(btmp(EstimOpt.Dist == 15));
        Results.DetailsV(EstimOpt.Dist == 15,3:4) = ...
            [stdx(EstimOpt.Dist == 15),pv(exp(btmp(EstimOpt.Dist == 15)),stdx(EstimOpt.Dist == 15))];
    end
    if sum(EstimOpt.Dist == 16) > 0
        Results.DetailsA(EstimOpt.Dist == 16,1) = exp(Results.bhat(EstimOpt.Dist == 16));
        Results.DetailsA(EstimOpt.Dist == 16,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 16)).*Results.std(EstimOpt.Dist == 16), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 16)), ...
                exp(Results.bhat(EstimOpt.Dist == 16)).*Results.std(EstimOpt.Dist == 16))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        %Results.DetailsV(EstimOpt.Dist == 16,1) = exp(btmp(EstimOpt.Dist == 16));
        %Results.DetailsV(EstimOpt.Dist == 16,3:4) = ...
            %[stdx(EstimOpt.Dist == 16),pv(exp(btmp(EstimOpt.Dist == 16)),stdx(EstimOpt.Dist == 16))];
    end
    if sum(EstimOpt.Dist == 17) > 0
        Results.DetailsA(EstimOpt.Dist == 17,1) = exp(Results.bhat(EstimOpt.Dist == 17));
        Results.DetailsA(EstimOpt.Dist == 17,3:4) = ...
            [exp(Results.bhat(EstimOpt.Dist == 17)).*Results.std(EstimOpt.Dist == 17), ...
             pv(exp(Results.bhat(EstimOpt.Dist == 17)), ...
                exp(Results.bhat(EstimOpt.Dist == 17)).*Results.std(EstimOpt.Dist == 17))];
        btmp = Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        btmp = btmp(EstimOpt.DiagIndex);
        stdx = Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA-1)/2+2*EstimOpt.NVarA);
        stdx = stdx(EstimOpt.DiagIndex);
        stdx = exp(btmp).*stdx;
        %Results.DetailsV(EstimOpt.Dist == 17,1) = exp(btmp(EstimOpt.Dist == 17));
        %Results.DetailsV(EstimOpt.Dist == 17,3:4) = ...
            %[stdx(EstimOpt.Dist == 17),pv(exp(btmp(EstimOpt.Dist == 17)),stdx(EstimOpt.Dist == 17))];
    end
    %%%% WZ22. koniec %%%%
    
    Results.R = [Results.DetailsA,Results.DetailsV];
    if EstimOpt.NVarM > 0
        %         Results.DetailsM = [];
        %         for i=1:EstimOpt.NVarM
        %             Results.DetailsM(1:EstimOpt.NVarA,4*i-3) = Results.bhat(EstimOpt.NVarA*(EstimOpt.NVarA/2+0.5+i)+1:EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+i));
        %             Results.DetailsM(1:EstimOpt.NVarA,4*i-1:4*i) = [Results.std(EstimOpt.NVarA*(EstimOpt.NVarA/2+0.5+i)+1:EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+i)),pv(Results.bhat(EstimOpt.NVarA*(EstimOpt.NVarA/2+0.5+i)+1:EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+i)),Results.std(EstimOpt.NVarA*(EstimOpt.NVarA/2+0.5+i)+1:EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+i)))];
        %         end
        Results.R = [Results.R,Results.DetailsM];
    end
    if EstimOpt.NVarNLT > 0
        Results.DetailsNLT = [];
        for i=1:EstimOpt.NVarNLT
            Results.DetailsNLT(i,1) = ...
                Results.bhat(EstimOpt.NVarA+sum(1:EstimOpt.NVarA)+EstimOpt.NVarM+EstimOpt.NVarS+i);
            Results.DetailsNLT(i,3:4) = ...
                [Results.std(EstimOpt.NVarA+sum(1:EstimOpt.NVarA)+EstimOpt.NVarM+EstimOpt.NVarS+i), ...
                 pv(Results.bhat(EstimOpt.NVarA+sum(1:EstimOpt.NVarA)+EstimOpt.NVarM+EstimOpt.NVarS+i), ...
                    Results.std(EstimOpt.NVarA+sum(1:EstimOpt.NVarA)+EstimOpt.NVarM+EstimOpt.NVarS+i))];
        end
        Results.DetailsNLT0 = NaN(EstimOpt.NVarA,4);
        Results.DetailsNLT0(EstimOpt.NLTVariables,:) = Results.DetailsNLT;
        Results.R = [Results.R,Results.DetailsNLT0];
    end
    if EstimOpt.Johnson > 0
        Results.ResultsJ = NaN(EstimOpt.NVarA,8);
        % Location parameters
        Results.DetailsJL(:,1) = Results.bhat((end-2*EstimOpt.Johnson+1):(end-EstimOpt.Johnson));
        Results.DetailsJL(:,3) = Results.std((end-2*EstimOpt.Johnson+1):(end-EstimOpt.Johnson));
        Results.DetailsJL(:,4) = pv(Results.bhat((end-2*EstimOpt.Johnson+1):(end-EstimOpt.Johnson)), ...
                                    Results.std((end-2*EstimOpt.Johnson+1):(end-EstimOpt.Johnson)));
        % Scale parameters
        Results.DetailsJS(:,1) = exp(Results.bhat((end-EstimOpt.Johnson+1):end));
        Results.DetailsJS(:,3) = ...
            exp(Results.bhat((end-EstimOpt.Johnson+1):end)).*Results.std((end-EstimOpt.Johnson+1):end);
        Results.DetailsJS(:,4) = ...
            pv(exp(Results.bhat((end - EstimOpt.Johnson+1):end)), ...
               exp(Results.bhat((end-EstimOpt.Johnson+1):end)).*Results.std((end-EstimOpt.Johnson+1):end));
        Results.ResultsJ(EstimOpt.Dist > 4 & EstimOpt.Dist <= 7,1:4) = Results.DetailsJL;
        Results.ResultsJ(EstimOpt.Dist > 4 & EstimOpt.Dist <= 7,5:8) = Results.DetailsJS;
        Results.R = [Results.R,Results.ResultsJ];
    end
    if EstimOpt.NVarS > 0
        Results.DetailsS = [];
        for i=1:EstimOpt.NVarS
            Results.DetailsS(i,1) = Results.bhat(EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+EstimOpt.NVarM)+i);
            Results.DetailsS(i,3:4) = ...
                [Results.std(EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+EstimOpt.NVarM)+i), ...
                 pv(Results.bhat(EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+EstimOpt.NVarM)+i), ...
                    Results.std(EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5+EstimOpt.NVarM)+i))];
        end
        DetailsS0 = NaN(EstimOpt.NVarS,4);
        DetailsS0(1:EstimOpt.NVarS,1:4) = Results.DetailsS;
        if EstimOpt.NVarS == EstimOpt.NVarA % will not work if NVarS > EstimOpt.NVarA
            Results.R = [Results.R,DetailsS0];
        end
    end
    Results.chol = [Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5)), ...
                    Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5)), ...
                    pv(Results.bhat(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5)), ...
                       Results.std(EstimOpt.NVarA+1:EstimOpt.NVarA*(EstimOpt.NVarA/2+1.5)))];
    Results.DetailsVcov = tril(ones(EstimOpt.NVarA));
    choltmp = Results.chol(:,1);
    %%%% WZ23. dopisanie %%%
    if sum(EstimOpt.Dist >= 3 & EstimOpt.Dist <= 5 | EstimOpt.Dist == 9 | EstimOpt.Dist == 10 | EstimOpt.Dist == 11 | EstimOpt.Dist == 12 | EstimOpt.Dist == 13 | EstimOpt.Dist == 14 | EstimOpt.Dist == 15 | EstimOpt.Dist == 16 | EstimOpt.Dist == 17) > 0
        choltmp(EstimOpt.DiagIndex(EstimOpt.Dist >= 3 & EstimOpt.Dist <= 5 | EstimOpt.Dist == 9 | EstimOpt.Dist == 10 | EstimOpt.Dist == 11 | EstimOpt.Dist == 12 | EstimOpt.Dist == 13 | EstimOpt.Dist == 14 | EstimOpt.Dist == 15 | EstimOpt.Dist == 16 | EstimOpt.Dist == 17)) = 1;
    end
    Results.DetailsVcov(Results.DetailsVcov == 1) = choltmp;
    if sum(EstimOpt.Dist >= 3 & EstimOpt.Dist <= 5 | EstimOpt.Dist == 9 | EstimOpt.Dist == 10 | EstimOpt.Dist == 11 | EstimOpt.Dist == 12 | EstimOpt.Dist == 13 | EstimOpt.Dist == 14 | EstimOpt.Dist == 15 | EstimOpt.Dist == 16 | EstimOpt.Dist == 17) > 0
        choltmp = sqrt(sum(Results.DetailsVcov(EstimOpt.Dist >= 3 & EstimOpt.Dist <= 5 | EstimOpt.Dist == 9 | EstimOpt.Dist == 10 | EstimOpt.Dist == 11 | EstimOpt.Dist == 12 | EstimOpt.Dist == 13 | EstimOpt.Dist == 14 | EstimOpt.Dist == 15 | EstimOpt.Dist == 16 | EstimOpt.Dist == 17,:).^2,2));
        Results.DetailsVcov(EstimOpt.Dist >= 3 & EstimOpt.Dist <= 5 | EstimOpt.Dist == 9 | EstimOpt.Dist == 10 | EstimOpt.Dist == 11 | EstimOpt.Dist == 12 | EstimOpt.Dist == 13 | EstimOpt.Dist == 14 | EstimOpt.Dist == 15 | EstimOpt.Dist == 16 | EstimOpt.Dist == 17,:) = ...
            Results.DetailsVcov(EstimOpt.Dist >= 3 & EstimOpt.Dist <= 5 | EstimOpt.Dist == 9 | EstimOpt.Dist == 10 | EstimOpt.Dist == 11 | EstimOpt.Dist == 12 | EstimOpt.Dist == 13 | EstimOpt.Dist == 14 | EstimOpt.Dist == 15 | EstimOpt.Dist == 16 | EstimOpt.Dist == 17,:)./choltmp(:,ones(1,EstimOpt.NVarA));
    end
    %%%% WZ23. koniec %%%%
    Results.DetailsVcov = Results.DetailsVcov*Results.DetailsVcov';
    Results.DetailsVcor = corrcov(Results.DetailsVcov);
end

EstimOpt.params = length(b0) - sum(EstimOpt.BActive == 0) + sum(EstimOpt.BLimit == 1);
Results.stats = [Results.LL; ...
                 Results_old.MNL0.LL; ...
                 1-Results.LL/Results_old.MNL0.LL; ...
                 R2; ...
                 ((2*EstimOpt.params-2*Results.LL))/EstimOpt.NObs; ...
                 ((log(EstimOpt.NObs)*EstimOpt.params-2*Results.LL))/EstimOpt.NObs; ...
                 EstimOpt.NObs; ...
                 EstimOpt.NP; ...
                 EstimOpt.params];

%File Output
Results.EstimOpt = EstimOpt;
Results.OptimOpt = OptimOpt;
Results.INPUT = INPUT;
Results.Dist = transpose(EstimOpt.Dist);
EstimOpt.JSNVariables = find(EstimOpt.Dist > 4 & EstimOpt.Dist <= 7);

end
