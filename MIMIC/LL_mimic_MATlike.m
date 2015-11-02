function [LL,g,h] = LL_mimic_MATlike(Xstr, Xmea,Xmea_exp, err, EstimOpt, OptimOpt, b0)

LLfun = @(B) LL_mimic(Xstr, Xmea,Xmea_exp, err, EstimOpt,B);

% LL = LLfun(b0);
% f = sum(LL);
if isequal(OptimOpt.GradObj,'on')
    if EstimOpt.NumGrad == 0
        [f,j] = LLfun(b0);
        j(:,EstimOpt.BActive ==0) = 0;
        g = sum(j,1)'; ...
        if isequal(OptimOpt.Hessian,'user-supplied') == 1
            h = j'*j;
        end
    else % => EstimOpt.NUMGRAD == 1 
        f = LLfun(b0);  
        j = numdiff(LLfun,f,b0,isequal(OptimOpt.FinDiffType,'central'),EstimOpt.BActive);...
        g = sum(j,1)';   
        if isequal(OptimOpt.Hessian,'user-supplied') == 1
            h = j'*j;
        end
    end
else % No gradient
    EstimOpt.NumGrad = 1;
    f = LLfun(b0);   
end

LL = sum(f);
